# PR review: `GET /audit` listing endpoint

**Verdict: request changes.** This is not a stylistic nit — under the stated volume (tens of millions of `auditEvent` rows, growing daily, written by every service) this endpoint will scan and load a large fraction of the table on a hot path. It is a latent outage. The handler is small, but it triggers four of the worst patterns at once, and that clustering points at a missing API contract, not a query to tune line-by-line.

```ts
router.get('/audit', async (req, res) => {
  const events = await prisma.auditEvent.findMany({
    where: { type: req.query.type as string },
    include: { user: true, metadata: true },
    orderBy: { createdAt: 'desc' },
  });
  return res.json(events);
});
```

`auditEvent` is the textbook **transactional table**: append-only, timestamped (`createdAt`), written by every service, unbounded growth. Every query against it must bound the window read and cap the rows returned. This one does neither.

---

## Finding 1 — Unbounded result set (no `LIMIT`, no pagination)

**Impact.** `findMany` with no `take` returns *every* matching row. If a common `type` covers millions of rows, the database materializes them, Prisma hydrates them all into JS objects, and `res.json` serializes the lot into one response. This blows out database memory, application heap (likely OOM), and response time, all on a public-ish list endpoint. A single call can take the process down.

**Corrected version.** Always cap the page, and paginate by keyset (cursor) rather than offset so cost stays constant as users page deeper — offset pagination on a transactional table re-reads and discards everything before the page.

```ts
const take = Math.min(Number(req.query.limit) || 50, 100);
const events = await prisma.auditEvent.findMany({
  where: {
    type: req.query.type as string,
    // keyset cursor: pass the last createdAt seen from the previous page
    ...(req.query.before ? { createdAt: { lt: new Date(req.query.before as string) } } : {}),
  },
  orderBy: { createdAt: 'desc' },
  take,
  select: { id: true, type: true, createdAt: true, userId: true }, // see Finding 4
});
```

**Tradeoff.** Keyset pagination can't jump to an arbitrary page number ("go to page 500") and is awkward if `createdAt` isn't unique (tie-break on `(createdAt, id)`). For an audit log — almost always browsed newest-first or filtered by range — that's the right trade. If product genuinely needs page numbers, accept offset only with a small hard cap.

## Finding 2 — Query on a transactional table with no date filter

**Impact.** Even with `type` applied, there is no time window. The endpoint is willing to read the entire history of that `type` back to the beginning of the table. What is fast at 100k rows is unusable at 50M. This is the omission that degrades soonest as the table grows — and it's already growing daily.

**Corrected version.** Require (or default) a bounded time window, and index it. Make a date range part of the contract:

```ts
const from = req.query.from ? new Date(req.query.from as string) : new Date(Date.now() - 7 * 864e5);
// where: { type, createdAt: { gte: from, ...(to ? { lte: to } : {}) } }
```

```sql
-- supports both the type filter and the createdAt ordering/window
CREATE INDEX idx_audit_event_type_created_at
  ON "auditEvent" (type, "createdAt" DESC);
```

**Tradeoff.** A default window means a caller who wants older data must ask for it explicitly — that's a behavior change for any existing consumer, so call it out in the API docs. The composite index costs write throughput and storage on a table every service writes to; given it's write-heavy, keep indexes lean and add only the ones the real read paths need (this one earns its place).

## Finding 3 — Unindexed sort + unindexed filter (sequential scan likely)

**Impact.** `where: { type }` + `orderBy: { createdAt: 'desc' }` with no covering index forces a sequential scan and then an in-memory/on-disk sort of the matched set. On a table this size the sort spills to disk (`Sort Method: external merge`), and the scan reads far more than it returns.

**Corrected version.** The composite index in Finding 2, `(type, "createdAt" DESC)`, lets the planner satisfy both the equality filter and the ordering from the index, and pairs with the `LIMIT` so it stops after one page.

**Tradeoff.** Same as Finding 2 — index maintenance cost on write. If `type` is low-cardinality (few distinct values) the index helps less for the filter alone, but it still serves the ordering+limit, which is the expensive part.

**Validate it.** Confirm with the plan before merging:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, type, "createdAt", "userId"
FROM "auditEvent"
WHERE type = $1 AND "createdAt" < $2
ORDER BY "createdAt" DESC
LIMIT 50;
```

Want to see `Index Scan` using the new index and no `Seq Scan` / external-merge `Sort`. If a `Seq Scan` remains, the filter/order aren't being served by the index.

## Finding 4 — `include` of full relations + selecting everything

**Impact.** `include: { user: true, metadata: true }` fetches every column of `auditEvent` plus the full `user` and full `metadata` for each row. `metadata` on an audit event is very often a bulky JSON/text blob — multiply that by the row count and you've magnified Findings 1–3. Pulling whole relations also blocks index-only scans and couples the response to the schema (adding a column silently changes the payload). If `metadata` is a one-to-many relation, the eager join also multiplies result rows (cartesian-style fan-out), making the row count worse than it looks.

**Corrected version.** `select` only the fields the response needs (see the `select` in Finding 1). Resolve `user` to just the display fields you render (`select: { user: { select: { id: true, name: true } } }`), and pull `metadata` only on a detail endpoint (`GET /audit/:id`), not in the list.

**Tradeoff.** An explicit `select` must be maintained as the UI's needs change, and dropping `metadata` from the list means a second call to see details — but that's exactly the point: the list stays cheap, the heavy payload moves to the rare single-row fetch.

## Finding 5 (correctness) — unvalidated `type` query param

`req.query.type as string` is a cast, not validation. If `type` is omitted, `where: { type: undefined }` makes Prisma drop the filter entirely — turning this into "scan the whole table, every type, no window, no limit," i.e. the worst case of every finding above. If it arrives as an array (`?type=a&type=b`), the `as string` cast lies and you may get a runtime error or a malformed query. Validate and require it (or reject the request) before it reaches the database.

---

## Root cause

These aren't five independent tweaks — they share one cause: **the endpoint has no contract for how much data it returns.** No window, no page size, no field projection, no input validation, on the single most write-heavy table in the system. Fixing the symptoms one at a time isn't enough; define the contract:

1. **Required/validated `type`** (reject if missing or malformed).
2. **Bounded time window** (`from`/`to`, with a sane default like last 7 days).
3. **Mandatory page cap** with keyset pagination (`take`, cursor on `createdAt`/`id`).
4. **Explicit `select`** — list view returns lightweight fields; `metadata` lives on a detail endpoint.
5. **Index** `(type, "createdAt" DESC)` to back filter + sort + limit, verified with `EXPLAIN (ANALYZE, BUFFERS)`.

With those, per-request cost becomes roughly constant regardless of how large `auditEvent` grows — which is the only safe property for an endpoint over an unbounded, ever-growing table.

**Questions for the author before approving:**
- Is `metadata` a single related row or a collection (one-to-many)? That determines whether Finding 4 also causes row fan-out.
- Who consumes this endpoint, and do any callers rely on getting the full unfiltered history? That sets how aggressive the default window can be.
- Is `type` always a single value, or can it be multi-valued? Affects validation and index selectivity.
