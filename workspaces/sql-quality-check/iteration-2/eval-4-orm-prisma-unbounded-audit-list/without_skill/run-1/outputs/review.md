# PR Review: Audit-Log Listing Endpoint

**Verdict: Request changes.** This endpoint will not survive contact with production. Against a table of tens of millions of rows that grows daily, it has at least one guaranteed outage-class problem (unbounded result set) plus serious security and correctness gaps.

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

---

## Blocking issues

### 1. Unbounded query — fetches the entire table (or entire type partition)

`findMany` has no `take` (LIMIT) and no pagination. On a table with tens of millions of rows:

- If `req.query.type` is omitted, `where: { type: undefined }` collapses to **no filter** in Prisma — the query becomes "select every audit event ever written." That is a full table scan loading tens of millions of rows into Node memory, serializing them all to JSON, and shipping them in one response.
- Even with a `type` filter, a common event type can easily be millions of rows.

Expected consequences: query timeouts, exhausted DB connections, Node process OOM / event-loop stall, and a multi-hundred-MB (or GB) response. This is a self-inflicted denial of service and the single most important reason to block the PR.

**Fix:** mandatory pagination. Use `take` with a hard server-side cap (e.g. default 50, max 100) plus cursor-based pagination (`cursor` + `skip: 1`) keyed on `createdAt`/`id`. Avoid large `OFFSET` paging — deep offsets degrade badly on big tables.

```ts
const take = Math.min(Number(req.query.limit) || 50, 100);
const events = await prisma.auditEvent.findMany({
  where: { ...(type ? { type } : {}) },
  take,
  ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
  orderBy: { createdAt: 'desc' },
  include: { user: true, metadata: true },
});
```

### 2. No authentication / authorization

Audit logs are among the most sensitive data in a system — they reveal who did what, when, and often contain PII in `metadata`. This handler has **no auth middleware and no role check**. As written, anyone who can reach `/audit` can read the entire audit trail of every user.

Audit data is also frequently in scope for SOC 2 / ISO 27001 / GDPR. Exposing it without access control is both a security and a compliance problem.

**Fix:** require authentication and restrict to an admin/security role. Where applicable, scope results to data the caller is permitted to see (e.g. tenant isolation).

### 3. `include: { user: true, metadata: true }` leaks data and amplifies payload

- `user: true` returns the **full user record** — likely including email, password hash, tokens, and other fields that must never appear in an API response. Eager-including the whole relation is a classic over-exposure bug.
- Combined with the unbounded result set, every joined row inflates the already-fatal payload size.

**Fix:** use `select` to return only the fields the client needs (e.g. `user: { select: { id, name } }`), and define an explicit response DTO rather than returning Prisma models directly.

---

## High-severity issues

### 4. Unvalidated, unsanitized query input

`req.query.type as string` is a blind type assertion. `type` may be `undefined`, an array (`?type=a&type=b` yields `string[]`), or an object (`?type[x]=y`). Passing an array/object into the Prisma `where` can throw or produce unintended queries. The `as string` cast hides this from the compiler rather than handling it.

**Fix:** validate/parse query params (zod or similar). Reject or normalize unexpected shapes; treat missing `type` as an explicit "no filter" decision (which, combined with issue #1, must still be paginated).

### 5. Likely missing index for the access pattern

The query filters on `type` and orders by `createdAt desc`. Without a composite index such as `(type, createdAt)` (and an index on `createdAt` for the no-filter case), each request is a large scan + sort on a multi-tens-of-millions-row table. This compounds issue #1 and will hurt even after pagination is added.

**Fix:** add/verify a `@@index([type, createdAt])` and confirm the pagination path uses it.

---

## Medium / lower-severity issues

### 6. No error handling

The `await` is unguarded. A DB timeout or connection error becomes an unhandled rejection (or leaks a raw stack trace, depending on the Express error setup). Wrap in try/catch or route through centralized error-handling middleware, returning a sanitized error.

### 7. No rate limiting

A heavy, sensitive endpoint with no throttling is an easy abuse/DoS vector. Apply rate limiting appropriate to an admin endpoint.

### 8. Returning DB models directly couples the API to the schema

`res.json(events)` serializes raw Prisma entities. Beyond the leakage in #3, this makes the schema part of your public contract — future column additions silently leak. Map to an explicit response shape.

### 9. Result ordering / stability for pagination

`orderBy: { createdAt: 'desc' }` alone is not a stable sort if multiple rows share a timestamp; cursor pagination needs a tiebreaker. Order by `[{ createdAt: 'desc' }, { id: 'desc' }]`.

---

## Suggested minimum bar before merge

1. Add authentication + admin/role authorization (blocking).
2. Add mandatory, capped, cursor-based pagination (blocking).
3. Replace `include` with `select` of safe fields; return a DTO (blocking — data leak).
4. Validate query params; handle missing/array `type` explicitly.
5. Confirm a `(type, createdAt)` index exists.
6. Add try/catch + rate limiting.

As written, this is not safe to approve.
