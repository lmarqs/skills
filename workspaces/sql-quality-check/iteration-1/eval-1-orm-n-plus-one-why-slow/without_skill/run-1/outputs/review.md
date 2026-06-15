# Code Review: Slow Invoice Listing Endpoint (TypeORM)

## TL;DR

This is a classic **N+1 query problem**. For 200 invoices, you fire:

- **1** query to load the invoices, then
- **200** queries to load each invoice's customer, then
- **200** queries to load each invoice's lines.

That's **401 round-trips** to the database per request. Each one carries its own
network latency, query parsing, and planning overhead. At ~20 ms each, that alone
is ~8 seconds — exactly the symptom you're seeing, and exactly why the DB dashboard
shows "thousands of tiny queries."

The fix is to let the database do the joining and fetch the related data in
**one** (or a small constant number of) queries instead of one query per row.

---

## What's actually happening

```ts
const invoices = await invoiceRepo.find({ where: { status: 'open' }, take: 200 });
for (const inv of invoices) {
  inv.customer = await customerRepo.findOne({ where: { id: inv.customerId } }); // +1 per invoice
  inv.lines    = await lineRepo.find({ where: { invoiceId: inv.id } });          // +1 per invoice
}
return invoices;
```

The loop issues queries **serially** inside `await`, so the latencies don't even
overlap — they add up. The query count scales linearly with the page size, so a
larger page makes it proportionally worse. The individual queries are fast (hence
"tiny"), but the *count* and the *serialization* are what kill you.

### Why the database dashboard shows thousands of tiny queries
Each `findOne` / `find` is a separate prepared statement + execution. 200 invoices
x 2 related lookups + 1 = ~401 statements per page load. Under any real traffic
this multiplies into the thousands.

---

## The fix

### Option A — Eager-join via relations (simplest)

If `customer` and `lines` are declared as relations on the `Invoice` entity, just
ask TypeORM to load them with the parent query:

```ts
const invoices = await invoiceRepo.find({
  where: { status: 'open' },
  relations: { customer: true, lines: true },
  take: 200,
});
return invoices;
```

TypeORM resolves this into a small, fixed number of queries instead of 401.

> ⚠️ **Pagination caveat with `take` + collection relations.** When you join a
> one-to-many (`lines`) *and* use `take`, TypeORM's QueryBuilder path applies the
> limit on a distinct set of root ids (it runs a separate id query, then loads the
> rows) precisely so `take: 200` means 200 *invoices*, not 200 joined rows. The
> `find({ relations })` API handles this correctly. If you ever hand-write a
> `leftJoinAndSelect` with `.limit(200)`, you'll get 200 *joined rows* — wrong.
> Use `.take(200)` (not `.limit`) with the QueryBuilder so TypeORM does the
> distinct-id trick.

### Option B — QueryBuilder, explicit control

```ts
const invoices = await invoiceRepo
  .createQueryBuilder('invoice')
  .leftJoinAndSelect('invoice.customer', 'customer')
  .leftJoinAndSelect('invoice.lines', 'line')
  .where('invoice.status = :status', { status: 'open' })
  .take(200) // NOT .limit() — see caveat above
  .getMany();
```

### Option C — Split / batched loading (best when `lines` is large)

A single join that fans out invoices x lines can produce a large, redundant result
set (customer columns repeated per line). TypeORM's `relationLoadStrategy: 'query'`
loads each relation as **one** additional batched `IN (...)` query instead of a
join — turning 401 queries into ~3, without the row-multiplication of a big join:

```ts
const invoices = await invoiceRepo.find({
  where: { status: 'open' },
  relations: { customer: true, lines: true },
  relationLoadStrategy: 'query', // 1 query for invoices, 1 for customers, 1 for lines
  take: 200,
});
```

This is often the sweet spot: it avoids both the N+1 explosion *and* the
join-fan-out blowup, and pagination on the root behaves correctly.

---

## If you can't use relations (raw batching)

If `customer`/`lines` aren't mapped as relations, batch the lookups by collecting
ids and issuing **two** queries total with `In(...)`:

```ts
import { In } from 'typeorm';

const invoices = await invoiceRepo.find({ where: { status: 'open' }, take: 200 });

const customerIds = [...new Set(invoices.map(i => i.customerId))];
const invoiceIds  = invoices.map(i => i.id);

const [customers, lines] = await Promise.all([
  customerRepo.find({ where: { id: In(customerIds) } }),
  lineRepo.find({ where: { invoiceId: In(invoiceIds) } }),
]);

const customerById = new Map(customers.map(c => [c.id, c]));
const linesByInvoice = new Map<number, Line[]>();
for (const l of lines) {
  (linesByInvoice.get(l.invoiceId) ?? linesByInvoice.set(l.invoiceId, []).get(l.invoiceId)!).push(l);
}

for (const inv of invoices) {
  inv.customer = customerById.get(inv.customerId);
  inv.lines    = linesByInvoice.get(inv.id) ?? [];
}
return invoices;
```

This goes from **401 serial queries** to **3** (1 + 2 run in parallel). Note the
`new Set` to de-duplicate `customerId` — many invoices likely share a customer, so
you fetch each customer once.

---

## Supporting fixes / things to verify

1. **Indexes.** Make sure these columns are indexed, or the batched queries still
   do table scans:
   - `invoice.status` (and ideally a composite that supports the page ordering)
   - `invoice_line.invoiceId` (FK column — frequently un-indexed by default)
   - `customer.id` (PK, already indexed)

2. **Select only what you need.** If the endpoint serializes a subset of columns,
   add a `select` to avoid hauling back wide rows x 200.

3. **Deterministic ordering for pagination.** `take: 200` without an `order` makes
   "page 2" undefined. Add an `order: { id: 'ASC' }` (or your sort key).

4. **Don't mutate-and-return managed entities.** Assigning `inv.customer = ...` on
   entities loaded by the repo is fine here, but if these are tracked/cached
   instances, prefer returning a DTO mapped from the query result.

---

## Recommendation

Go with **Option A** for readability, or **Option C** (`relationLoadStrategy:
'query'`) if `lines` per invoice is sizeable — that combination eliminates the N+1
and avoids join row-multiplication while keeping `take: 200` semantically correct.
Add the `invoice_line.invoiceId` index. Expected result: page render drops from
~8 s and ~401 queries to well under a few hundred ms and a handful of queries.
