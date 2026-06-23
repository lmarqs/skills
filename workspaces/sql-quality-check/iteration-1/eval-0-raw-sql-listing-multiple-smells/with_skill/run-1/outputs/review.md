# SQL review — orders listing endpoint

## Verdict

The query is slow for several independent reasons, and the "gets worse every week"
symptom is the tell: at least three of the problems below scale with the size of the
`orders` table (~40M rows and growing). No single tweak fixes this — the query needs to
be restructured. The findings below are ranked by impact under your actual volume.

```sql
SELECT *
FROM orders o
LEFT JOIN order_item i ON i.order_id = o.id
LEFT JOIN payment pg ON pg.order_id = o.id
LEFT JOIN customer c ON c.id = o.customer_id
WHERE DATE(o.created_at) >= '2025-01-01'
ORDER BY o.created_at DESC
LIMIT 20 OFFSET 80000;
```

Before committing to fixes, I'd want the output of:

```sql
EXPLAIN (ANALYZE, BUFFERS) <the query above>;
```

I'm fairly confident about the diagnoses below from the SQL alone, but the plan is the
arbiter — it'll confirm the sequential scan, whether any index on `created_at` is being
used, and whether the sort spills to disk. A couple of points below also depend on facts
I can't see (your indexes, what the endpoint actually renders) — I've flagged those as
questions rather than guessing.

---

## Finding 1 — `DATE(o.created_at)` disables any index on `created_at` (smell #2)

This is likely the biggest single cause of the slowdown, and it's the one that gets worse
every week.

**Impact.** Wrapping the column in `DATE()` forces Postgres to compute `DATE(created_at)`
for *every row* before it can compare. An index on `orders.created_at` is built on the raw
`timestamp` value, not on `DATE(created_at)`, so the function makes the index unusable and
the planner falls back to a sequential scan of all ~40M rows. A query that should touch a
small recent slice instead reads the whole history — and that history grows daily, which is
exactly why response time creeps up week over week.

**Corrected version.** Leave the column untouched and move the boundary onto the literal:

```sql
WHERE o.created_at >= '2025-01-01 00:00:00'  -- ideally a typed timestamptz literal
```

`created_at >= '2025-01-01'` selects the same rows as `DATE(created_at) >= '2025-01-01'`
(midnight-inclusive at the lower bound), and an index on `created_at` can now do a range
scan. This requires an index on `orders.created_at` to exist — see Finding 4.

**Tradeoff.** None on correctness for a `>=` lower bound. The only caution is type: compare
against a literal that matches the column's type (`timestamp` vs `timestamptz`) so you don't
reintroduce an implicit cast that defeats the index again. If the column is `timestamptz`,
be explicit about the time zone of the boundary.

---

## Finding 2 — Two 1:N joins multiply the result rows (smell #1)

You told me `order_item` and `payment` are both 1:N per order. That makes this a row
explosion.

**Impact.** Each order is duplicated once per `(order_item × payment)` combination. An order
with 8 line items and 2 payment rows produces 8 × 2 = 16 near-identical rows, all carrying a
full copy of the order and customer columns. The database materializes, sorts, and ships all
of that redundancy. Worse, it interacts badly with Finding 5: `LIMIT 20` is applied *after*
the joins, so "20 rows" is 20 exploded rows — you may get only 2 or 3 distinct orders on a
page, which is almost certainly not what the endpoint intends.

**Corrected version.** Page the orders first, then load the children for just that page.
Fetch one lean page of orders (one row per order), then a single batched query per child
relation keyed on the 20 order ids:

```sql
-- 1) the page: one row per order, no 1:N joins
SELECT o.id, o.created_at, o.status, o.total, o.customer_id,
       c.name, c.email
FROM orders o
JOIN customer c ON c.id = o.customer_id
WHERE o.created_at >= '2025-01-01 00:00:00'
ORDER BY o.created_at DESC, o.id DESC
LIMIT 20;  -- see Finding 3 for replacing OFFSET

-- 2) children for that page, one query each (not per-order — avoid N+1, smell #3)
SELECT * FROM order_item WHERE order_id = ANY($1);  -- $1 = the 20 order ids
SELECT * FROM payment    WHERE order_id = ANY($1);
```

Then stitch them together in the application. Alternatively, if you only need counts/sums
(e.g. item count, total paid), aggregate in-database with a correlated subquery or a
`LATERAL`/grouped subquery so each child relation still contributes exactly one row.

**Tradeoff.** You trade one query for three round trips and a small amount of application-side
assembly. That's a good trade here: three index-driven queries returning bounded rows beat one
query that explodes and sorts millions. Note this is the opposite move from N+1 — the fix is
*few batched* queries, not *one query per order*.

---

## Finding 3 — `OFFSET 80000` reads and throws away 80,000 rows (smell #8)

`OFFSET 80000` is a deep page, and the cost is proportional to the offset.

**Impact.** To return rows 80,001–80,020, Postgres must generate, sort, and discard the first
80,000 matching rows. Combined with the row explosion (Finding 2), it's discarding 80,000
*exploded* rows. The deeper the user pages, the slower it gets — and this cost is paid on top
of everything else.

**Corrected version.** Use keyset (cursor) pagination, anchored on the last row of the previous
page. Because `created_at` isn't unique, include a tiebreaker (`id`) in both the sort and the
cursor:

```sql
SELECT o.id, o.created_at, o.status, o.total, o.customer_id
FROM orders o
WHERE o.created_at >= '2025-01-01 00:00:00'
  AND (o.created_at, o.id) < ($last_created_at, $last_id)  -- cursor from previous page
ORDER BY o.created_at DESC, o.id DESC
LIMIT 20;
```

Per-page cost is now constant regardless of depth, and it rides the same `(created_at, id)`
index as Findings 1 and 4.

**Tradeoff.** Keyset pagination can't jump to an arbitrary page number ("go to page 4000") and
needs a stable sort key — hence the `id` tiebreaker. If the UI truly requires numbered random-
access pages, that's a product constraint worth questioning, because it's fundamentally
expensive at this volume. Most listing endpoints only need next/previous, which keyset serves
perfectly.

---

## Finding 4 — the sort needs a covering index; confirm one exists (smell #10)

`ORDER BY o.created_at DESC` over a 40M-row table.

**Impact.** Without an index that provides rows in `created_at DESC` order, Postgres must load
the filtered set and sort it — in memory if it fits `work_mem`, otherwise spilling to disk
(watch for `Sort Method: external merge Disk: …` in the plan). At this volume a disk sort is
slow and I/O-heavy. Fixing Finding 1 only helps if the index can also satisfy the ordering.

**Corrected version.** A composite index that serves both the date range filter and the sort
(and the keyset tiebreaker):

```sql
CREATE INDEX idx_orders_created_at_id ON orders (created_at DESC, id DESC);
```

This lets one index handle the `created_at >=` range, the `ORDER BY created_at DESC`, and the
`(created_at, id)` keyset comparison from Finding 3.

**Tradeoff.** Every index taxes writes (each `INSERT`/`UPDATE` to `orders` maintains it) and
consumes storage — non-trivial on a table this size. But `orders` is read-heavy on this hot
path, so the read win dominates the write cost; this is a textbook case for the index. Don't
add it speculatively *and* keep a redundant single-column `created_at` index — consolidate.
Build it with `CREATE INDEX CONCURRENTLY` in production to avoid locking the table. *Question:*
what indexes does `orders` currently have? If there's already a plain `created_at` index, this
composite likely supersedes it.

---

## Finding 5 — `SELECT *` across four joined tables (smell #5)

**Impact.** `SELECT *` pulls every column of `orders`, `order_item`, `payment`, and `customer`,
including any wide `text`/`json`/blob columns the endpoint never renders. That inflates the row
width that gets multiplied by the explosion in Finding 2, increases the bytes sorted and shipped
over the wire, and blocks index-only scans. It also couples the endpoint to the schema: add a
column to any of these tables and the payload silently changes.

**Corrected version.** Select only the columns the endpoint actually returns — as shown in the
`SELECT id, created_at, status, total, ...` lists in Findings 2 and 3. *Question:* what fields
does the listing actually display? That determines the real column list and may let an index-only
scan serve part of the query.

**Tradeoff.** Explicit column lists are more verbose and must be updated when the endpoint needs
a new field. That maintenance cost is small and worth it on a hot path.

---

## Root cause — this is one structural problem, not five

These findings cluster, and the common root is **trying to assemble a paginated, multi-relation
listing in a single flat query.** The flat shape is what forces the 1:N explosion, makes `LIMIT`
mean the wrong thing, and bloats every row with `SELECT *`. The date filter and pagination
problems then compound it as the table grows.

The durable fix is the restructure in Finding 2 + Finding 3: **page the `orders` table first
with keyset pagination on an indexed `(created_at, id)`, selecting only needed columns, then
batch-load `order_item` and `payment` for that page.** That single change dissolves Findings
1, 2, 3, and 5 at once and makes per-page cost constant as the table keeps growing. Finding 4
(the supporting index) is what makes it actually fast.

## Suggested next steps

1. Send the `EXPLAIN (ANALYZE, BUFFERS)` output so we confirm the seq scan, index usage, and
   any disk-spilling sort.
2. Tell me the current indexes on `orders` and the exact columns the endpoint renders.
3. Confirm whether the UI needs numbered random-access pages or just next/previous — this
   decides whether keyset pagination is a drop-in.
