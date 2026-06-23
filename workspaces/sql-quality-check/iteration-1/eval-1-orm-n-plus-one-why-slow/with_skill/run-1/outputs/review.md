# SQL review: slow invoice listing (TypeORM)

## Verdict

This is a textbook **N+1 query problem**. The slowness and the "thousands of tiny
queries" on the DB dashboard are the same fact seen from two angles. Nothing is
wrong with the data model itself — the problem is in how the data-access code
drives it.

## What the code actually does at the DB level

```ts
const invoices = await invoiceRepo.find({ where: { status: 'open' }, take: 200 }); // 1 query
for (const inv of invoices) {
  inv.customer = await customerRepo.findOne({ where: { id: inv.customerId } });    // 1 query per invoice
  inv.lines    = await lineRepo.find({ where: { invoiceId: inv.id } });            // 1 query per invoice
}
```

For a page of 200 invoices the database receives:

- 1 query to list the invoices, plus
- 200 `findOne` queries against `customer`, plus
- 200 `find` queries against `invoice_line`

= **401 round trips** for a single page render.

That matches both symptoms exactly:

- **~8s latency.** The cost here is dominated by round-trip count, not by the work
  inside each query. Each `findOne`/`find` is individually fast (indexed PK / FK
  lookup), but 400 sequential awaits each pay full network + parse + plan +
  transaction overhead. At a realistic ~15-20ms per round trip, 400 of them is
  6-8s. The DB is barely working; the application is waiting.
- **Thousands of tiny queries on the dashboard.** 400 per page, multiplied by
  concurrent users and refreshes, is exactly the "thousands of tiny queries"
  signature. Each one is small and looks innocent in isolation, which is why N+1
  hides so well.

This is smell **#3 (N+1)** — read variant — from the catalog.

## The fix: collapse N+1 into a constant number of queries

The principle: fetch the list once, then load **all** related rows for the whole
page in one query each, keyed by the IDs you already have. The 401 queries become
**3, regardless of page size.**

### Option A — three batched queries, stitched in app code (preferred)

This is the most predictable performer and avoids the row-explosion trap (see the
tradeoff on Option B).

```ts
// 1. The page of invoices
const invoices = await invoiceRepo.find({
  where: { status: 'open' },
  select: ['id', 'customerId', /* + only the invoice columns the page renders */],
  take: 200,
  order: { id: 'ASC' }, // give pagination a stable, indexed order
});

const invoiceIds  = invoices.map(i => i.id);
const customerIds = [...new Set(invoices.map(i => i.customerId))];

// 2. All customers for the page, in one query  -> SELECT ... WHERE id IN (...)
const customers = await customerRepo.find({ where: { id: In(customerIds) } });
const customerById = new Map(customers.map(c => [c.id, c]));

// 3. All lines for the page, in one query      -> SELECT ... WHERE invoiceId IN (...)
const lines = await lineRepo.find({ where: { invoiceId: In(invoiceIds) } });
const linesByInvoice = new Map<number, Line[]>();
for (const l of lines) {
  (linesByInvoice.get(l.invoiceId) ?? linesByInvoice.set(l.invoiceId, []).get(l.invoiceId)!).push(l);
}

// 4. Stitch in memory
for (const inv of invoices) {
  inv.customer = customerById.get(inv.customerId)!;
  inv.lines    = linesByInvoice.get(inv.id) ?? [];
}
```

The generated SQL is what the catalog prescribes for N+1 — a single set-based
lookup instead of a loop:

```sql
SELECT * FROM customer      WHERE id        = ANY($1);  -- $1 = array of customerIds
SELECT * FROM invoice_line  WHERE invoiceId = ANY($1);  -- $1 = array of invoiceIds
```

**Impact:** 401 round trips -> 3. Latency drops from ~8s to tens of milliseconds.
The "thousands of tiny queries" disappear from the dashboard.

**Tradeoff:** you write and maintain the in-memory stitching (the `Map`s).
Slightly more application code than letting the ORM do it, but it is explicit and
its query count is constant and obvious. De-duplicating `customerId` (the `Set`
above) avoids re-fetching the same customer when many invoices share one.

### Option B — let TypeORM eager-load via relations

```ts
const invoices = await invoiceRepo.find({
  where: { status: 'open' },
  relations: { customer: true, lines: true },
  take: 200,
});
```

How TypeORM resolves this matters, and it is worth verifying rather than assuming:

- For the **`customer` (many-to-one)** relation, TypeORM joins — cheap and correct
  (one row per invoice).
- For the **`lines` (one-to-many)** relation, a naive `LEFT JOIN` would multiply
  rows: 200 invoices x average lines-per-invoice = a large, duplicated result set
  that the ORM then de-duplicates in memory. That is smell **#1 (cartesian / row
  explosion)** — you trade N+1 round trips for one fat, redundant result. Modern
  TypeORM mitigates this: with `find` + `relations`, it typically loads
  one-to-many collections in a **separate batched query** (similar to Option A)
  rather than one big join, so you usually get ~2-3 queries, not a row explosion.

**Impact:** same order-of-magnitude win as Option A when TypeORM batches the
collection load.

**Tradeoff:** you are trusting the ORM's strategy, which differs between
`find({ relations })` and `QueryBuilder().leftJoinAndSelect()` (the latter *does*
emit a single multiplying join and will row-explode the `lines` relation).
**Confirm the actual SQL** before relying on it — see the verification step below.
Less code than Option A, less control over the exact query shape.

## Secondary findings (smaller, but worth fixing in the same pass)

### Fetching whole entities when the page renders a few fields (smell #5)

`invoiceRepo.find(...)` and the related fetches pull every column of every entity.
If `invoice`, `customer`, or `invoice_line` carry wide columns (notes, JSON
payloads, addresses), you transfer data the page never shows, and you block any
index-only-scan opportunity on the lookups.

- **Impact:** wasted I/O and bandwidth per row, multiplied across the page.
- **Correction:** add `select: [...]` listing only the columns the response needs
  (shown in Option A).
- **Tradeoff:** the query becomes coupled to the view's field list — add a field
  to the response and you must add it to `select`. Acceptable for a hot listing
  endpoint; skip it if the entities are narrow.

### Make sure the FK lookups are actually indexed

The batched fixes turn into two `WHERE col IN (...)` lookups. They only stay fast
if the columns are indexed:

- `invoice_line.invoiceId` — **must** be indexed. A one-to-many child FK is very
  often left unindexed, which would turn query #3 into a sequential scan of the
  whole `invoice_line` table. This is the single most likely hidden cliff here.
- `customer.id` — already the primary key, so covered.

```sql
CREATE INDEX idx_invoice_line_invoice_id ON invoice_line (invoiceId);
```

- **Tradeoff:** the index taxes every write to `invoice_line` and costs storage.
  For a FK that is constantly queried this way, it pays for itself many times over
  (data is read far more than written).

### `status = 'open'` and pagination / growth

`invoice` is a **transactional table** — it grows without bound. Two related
points (smells #4, #8, #10):

- `take: 200` with no `order` is a non-deterministic page. Add a stable, indexed
  `ORDER BY` (e.g. `id` or `created_at`) so pages are reproducible.
- Filtering on `status = 'open'` is naturally self-limiting (open invoices get
  closed), so a date filter is less critical here than on a status-agnostic scan —
  but if the open set can grow large, a **partial index** on the hot predicate
  keeps the listing fast:

```sql
CREATE INDEX idx_invoice_open ON invoice (id) WHERE status = 'open';
```

- **Tradeoff:** a partial index helps only queries whose predicate matches
  (`status = 'open'`); it is useless for other statuses, but that is exactly why
  it stays small and cheap.

## Validate with the execution plan / query log

Don't take any of this on faith — measure it. Turn on TypeORM query logging
(`logging: true` in the DataSource) and watch the query **count** per request drop
from ~401 to ~3. Then `EXPLAIN (ANALYZE, BUFFERS)` the two batched lookups:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM invoice_line WHERE invoiceId = ANY('{...}');
```

- Confirm an `Index Scan` (not `Seq Scan`) on `invoice_line` — if you see a
  `Seq Scan` with high `Rows Removed by Filter`, the `invoiceId` index is missing.
- If you chose Option B with `leftJoinAndSelect`, check the plan for a row
  multiplication on the `lines` join and the result-set size — that is the smell
  #1 signature.

## Summary

| Finding | Smell | Fix | Round trips |
|---|---|---|---|
| N+1 on `customer` and `lines` in the loop | #3 | Batch with `In(ids)` + stitch, or `relations` | 401 -> 3 |
| Whole entities fetched, few fields used | #5 | Add `select: [...]` | — |
| `invoice_line.invoiceId` possibly unindexed | (#4 root) | `CREATE INDEX` on the FK | keeps batched lookup fast |
| Non-deterministic / unbounded-growth listing | #8, #10 | Stable `ORDER BY`, partial index on `status='open'` | — |

The root cause is not the schema — it is the per-item access pattern. Fix the N+1
first (the ~8s and the query flood both come from it); the other items are
hardening so the fix stays fast as the tables grow.
