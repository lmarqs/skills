# Review: `find_by_email` (SQLAlchemy)

## Verdict

One finding, and it's the important one: the query wraps the indexed column in
`func.lower(...)`, which **disables the existing unique B-tree index on `email`** and forces
a **sequential scan of all ~12M rows on every lookup**. This is smell #2 (function on a
filtered column).

The generated SQL is roughly:

```sql
SELECT users.*            -- ORM fetches the whole entity (secondary note below)
FROM users
WHERE lower(users.email) = lower(:email);   -- :email already lowercased in Python
```

## Finding 1 — `func.lower(User.email)` defeats the index (high impact at this volume)

**Impact.** The unique index is built over the *stored* value of `email`. By comparing
`lower(users.email)` instead of `users.email`, the planner can no longer probe the index by
value — it must compute `lower()` for every row before it can compare. On a 12M-row table
that turns a sub-millisecond unique-index lookup into a full sequential scan: hundreds of
milliseconds to seconds per call, scaling linearly as the table grows, and burning shared
buffers / I/O on a hot path. The unique constraint you already paid for is doing nothing for
this query.

Note that `email.lower()` on the Python side is already lowercased, so the `lower()` on the
*column* is the only thing forcing case-insensitivity at the DB — and it's the expensive half.

**Corrected version.** Which fix is right depends on one fact: **are emails stored
case-sensitively, or are they already normalized to lowercase on write?** Confirm this before
choosing.

- **If emails are already stored lowercase** (normalized on insert/update) — the cheapest fix
  is to drop the function entirely and compare the raw column. This uses the existing unique
  index directly, no schema change:

  ```python
  def find_by_email(session, email: str):
      return (
          session.query(User)
          .filter(User.email == email.lower())
          .one_or_none()
      )
  ```

- **If emails are stored with mixed case** and you genuinely need case-insensitive matching,
  add an index that matches the expression, then keep `lower()` on both sides:

  ```sql
  -- Functional (expression) index matching the predicate
  CREATE UNIQUE INDEX CONCURRENTLY idx_users_email_lower
    ON users (lower(email));
  ```

  The query (`WHERE lower(users.email) = lower(:email)`) then becomes an index lookup, and the
  unique index also enforces case-insensitive uniqueness. A `citext` column type is the other
  option — it pushes the case-insensitivity into the type, so plain `User.email == email`
  works and stays indexed.

**Tradeoff.** The first option (compare raw column) is free but is *only correct if the write
path guarantees lowercase storage* — if any row was stored with mixed case it will be missed,
silently. The functional-index option costs you a second index: extra disk and a write penalty
on every insert/update of `users` (now maintaining two unique indexes on `email`), and you may
want to drop the plain `email` unique index if the lowercased one supersedes it. `citext` is
the cleanest semantically but is a column-type migration on a 12M-row table and `citext`
comparisons carry a small per-comparison cost. Build any new index with `CREATE INDEX
CONCURRENTLY` to avoid locking writes on the live table during the migration.

## Secondary note — `session.query(User)` fetches all columns (smell #5, low priority)

This loads the full entity (`SELECT users.*`). If `users` has wide columns (bio, JSON, tokens)
and callers only need a few fields, this wastes I/O and prevents an index-only path. Minor here
since it's a single-row lookup by unique key, and you likely do want the hydrated `User` object
— flagging only for completeness, not asking you to change it.

## Validate

Confirm the fix with the plan before and after. On the current code you should see a
`Seq Scan on users` with a `Filter: (lower(email) = ...)`; after the fix you want an
`Index Scan` / `Index Only Scan` using the relevant unique index:

```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE lower(email) = 'someone@example.com';
```

## Bottom line

The change as written will full-scan 12M rows on every user lookup. Decide whether emails are
normalized-lowercase on write: if yes, drop `func.lower` on the column; if no, add a
`lower(email)` functional unique index (or move to `citext`). Then verify with `EXPLAIN
ANALYZE` that the index is actually used.
