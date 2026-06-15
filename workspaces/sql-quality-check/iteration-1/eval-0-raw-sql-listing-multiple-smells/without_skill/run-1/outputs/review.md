# SQL Review: Orders Listing Query

## Summary

The query is slow (~6s) and degrading weekly because of a combination of issues
that compound as the `orders` table grows toward 40M+ rows. The headline problems
are: **deep `OFFSET` pagination**, a **non-sargable `WHERE` predicate** that
defeats indexing, and **row multiplication from joining two 1:N tables at once**,
all returning `SELECT *`. None of these scale, and the deep-offset and row-fanout
costs grow as data accumulates — which is exactly the "worse every week" symptom.

---

## Findings (ordered by impact)

### 1. Deep `OFFSET 80000` pagination — the primary cause of "worse every week"

```sql
ORDER BY o.created_at DESC
LIMIT 20 OFFSET 80000;
```

`OFFSET 80000` forces the database to generate, sort, and **discard 80,000 rows**
just to return 20. The cost grows linearly with how deep users page, and as the
table grows the reachable offset range grows too — so the worst-case page gets
slower every week. This is the single biggest reason the query degrades over time.

**Fix — keyset (seek) pagination.** Instead of an offset, page by the last seen
sort key. Order by a unique, monotonic tiebreaker alongside `created_at` so the
cursor is deterministic:

```sql
-- First page
SELECT ...
FROM orders o
WHERE o.created_at >= '2025-01-01'
ORDER BY o.created_at DESC, o.id DESC
LIMIT 20;

-- Next page: pass the last row's (created_at, id) as the cursor
SELECT ...
FROM orders o
WHERE o.created_at >= '2025-01-01'
  AND (o.created_at, o.id) < (:last_created_at, :last_id)
ORDER BY o.created_at DESC, o.id DESC
LIMIT 20;
```

Keyset pagination is O(page size) regardless of depth and stays flat as the table
grows. If the product truly needs jump-to-page-4000 UX, that's rare; most listings
are "next page" and keyset covers them. (Caveat: keyset doesn't support arbitrary
`OFFSET`-style random page jumps — confirm the UI only needs next/prev.)

### 2. Non-sargable filter: `DATE(o.created_at) >= '2025-01-01'`

Wrapping the column in `DATE()` prevents the optimizer from using an index on
`created_at` — it must compute `DATE()` for every row. Rewrite as a half-open
range on the bare column:

```sql
WHERE o.created_at >= '2025-01-01'
-- if you must exclude a future bound, use a half-open range:
-- WHERE o.created_at >= '2025-01-01' AND o.created_at < '2026-01-01'
```

This is also semantically equivalent here (`DATE(x) >= '2025-01-01'` is the same
set as `x >= '2025-01-01 00:00:00'`) and lets an index range scan kick in.

### 3. Row multiplication from two independent 1:N joins

```sql
LEFT JOIN order_item i ON i.order_id = o.id
LEFT JOIN payment   pg ON pg.order_id = o.id
```

Joining `order_item` (N rows/order) and `payment` (M rows/order) in the same query
produces an **N × M Cartesian fan-out per order**. An order with 5 items and 3
payments yields 15 rows. This:

- Inflates the result set the database must build, sort, and ship.
- **Breaks the `LIMIT 20`** semantically — you get the first 20 *fanned-out rows*,
  not 20 orders. The page boundary is non-deterministic and may show a partial
  order.

The `LIMIT`/`OFFSET` and `ORDER BY` should operate on **orders**, not on the joined
product. Two robust approaches:

**Option A — paginate orders first, then fetch children (recommended).**
Run the keyset query against `orders` (+ `customer`, which is 1:1) to get 20 order
IDs, then issue follow-up queries for items and payments scoped to those 20 IDs:

```sql
SELECT * FROM order_item WHERE order_id IN (:ids);
SELECT * FROM payment    WHERE order_id IN (:ids);
```

Assemble in application code. This keeps each query cheap and the page boundary
correct.

**Option B — aggregate children before joining** (if you need a single round-trip),
e.g. join to subqueries that pre-aggregate items/payments to one row per order
(counts, sums, JSON-aggregated arrays). This avoids fan-out but only fits when you
need aggregates rather than full child rows.

### 4. `SELECT *` across four joined tables

`SELECT *` pulls every column from `orders`, `order_item`, `payment`, and
`customer` — combined with the fan-out in #3 this moves a lot of unnecessary bytes
per row, prevents covering-index optimizations, and is fragile to schema changes.
Select only the columns the endpoint actually renders.

---

## Indexing

For the corrected query, ensure these indexes exist:

- `orders (created_at DESC, id DESC)` — supports the range filter, the
  `ORDER BY`, and keyset cursor comparison in one index. (A plain
  `orders (created_at, id)` also works; match the direction to your sort.)
- `order_item (order_id)` and `payment (order_id)` — for the child fetches /
  joins. These are commonly the FK and may already exist; verify.
- `orders (customer_id)` and PK on `customer (id)` — for the customer join (likely
  already present).

Run `EXPLAIN` (or `EXPLAIN ANALYZE`) on the rewritten query and confirm an index
range scan on `orders.created_at` and no full sort of a huge intermediate set.

---

## Recommended rewrite (Option A shape)

```sql
-- Step 1: page the orders (+ 1:1 customer) with keyset pagination
SELECT o.id, o.created_at, o.customer_id, o.status, o.total,   -- explicit columns
       c.id AS customer_id, c.name, c.email
FROM orders o
LEFT JOIN customer c ON c.id = o.customer_id
WHERE o.created_at >= '2025-01-01'
  AND (o.created_at, o.id) < (:last_created_at, :last_id)   -- omit on first page
ORDER BY o.created_at DESC, o.id DESC
LIMIT 20;

-- Step 2: fetch children for the 20 returned order ids
SELECT order_id, ... FROM order_item WHERE order_id IN (:ids);
SELECT order_id, ... FROM payment    WHERE order_id IN (:ids);
```

## Expected impact

- Removing the deep `OFFSET` and the `DATE()` wrapper lets the query become an
  index range scan + small limited read — turning the ~6s page into single- or
  low-double-digit milliseconds.
- Eliminating the N×M fan-out makes the page size correct and bounds the work.
- Crucially, the cost no longer grows with table size or page depth, fixing the
  "worse every week" trend.
