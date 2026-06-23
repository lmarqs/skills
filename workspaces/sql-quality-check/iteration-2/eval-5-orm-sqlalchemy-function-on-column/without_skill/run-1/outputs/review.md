# Review: `find_by_email` (SQLAlchemy)

```python
def find_by_email(session, email: str):
    return (
        session.query(User)
        .filter(func.lower(User.email) == email.lower())
        .one_or_none()
    )
```

## Verdict

Functionally correct, but it has a **performance bug** that will hurt at 12M rows. Needs a change before merge.

## Main issue: `func.lower(User.email)` defeats the index (full table scan)

There is a unique B-tree index on `email`, but the query filters on `lower(email)`, not on `email`. A plain B-tree index on a column **cannot** be used to satisfy a predicate that wraps that column in a function. The expression in the index (`email`) and the expression in the `WHERE` clause (`lower(email)`) don't match, so the planner falls back to a **sequential scan**, evaluating `lower()` on every one of the ~12M rows.

The generated SQL is roughly:

```sql
SELECT ... FROM users WHERE lower(email) = lower($1);
```

Even though `email` is unique and indexed, this query gets slower linearly with table growth — exactly the access pattern (single-row lookup by email) where you want O(log n).

This is a classic "non-sargable predicate" — the wrapped column makes the existing index unusable.

## How to fix

Pick one, depending on the case-sensitivity requirement:

### Option A — If lookups should be case-insensitive (likely intent)

Add a **functional (expression) index** that matches the predicate:

```sql
CREATE UNIQUE INDEX CONCURRENTLY ix_users_email_lower ON users (lower(email));
```

Then `lower(User.email) == email.lower()` becomes an index scan. Use `CONCURRENTLY` to avoid a long write lock on a 12M-row table. Note this *also* enforces case-insensitive uniqueness, which the plain unique index on `email` does not — so confirm there are no rows that collide only by case before creating it (the index build will fail otherwise).

On PostgreSQL, the cleaner alternative is the **`citext`** type for the column, which makes `=` case-insensitive natively and keeps the predicate sargable without the explicit `lower()`.

### Option B — If emails are already normalized/stored lowercase

Drop the function entirely and compare directly so the existing unique index is used:

```python
def find_by_email(session, email: str):
    return (
        session.query(User)
        .filter(User.email == email.lower())
        .one_or_none()
    )
```

This requires that emails are always written in lowercase (normalize on insert/update). Best long-term: normalize-on-write so the stored column and the lookup agree, and the single existing index does the job.

## Secondary notes

- **Whitespace / normalization:** the input is only lowercased, not trimmed. If callers can pass untrimmed strings, consider `email.strip().lower()` and normalize on write to match.
- **`one_or_none()` is the right choice** for a unique column — returns `None` for no match and raises `MultipleResultsFound` if the uniqueness assumption is ever violated, which is a useful invariant check.
- **`None` input:** `email.lower()` raises `AttributeError` if `email` is `None`. Fine if the type hint (`str`) is enforced by callers; add a guard if not.
- **Style:** `session.query(...)` is the legacy 1.x API. If on SQLAlchemy 2.0, prefer `session.scalars(select(User).where(...)).one_or_none()`. Not blocking.

## Bottom line

The case-insensitive match is the likely intent and is reasonable, but as written it forces a sequential scan over 12M rows on every lookup. Either add a `lower(email)` expression index (Option A / `citext`) or normalize emails on write and drop the `lower()` from the query (Option B). Do not merge as-is.
