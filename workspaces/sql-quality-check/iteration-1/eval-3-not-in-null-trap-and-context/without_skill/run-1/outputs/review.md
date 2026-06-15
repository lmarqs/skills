# SQL Review: Active, Non-Deprecated Feature Flags

## Verdict

Yes — there is a real bug. The query is vulnerable to the **`NOT IN` + NULL trap**, and it also does not filter for "active" at all.

```sql
SELECT * FROM feature_flag
WHERE id NOT IN (SELECT flag_id FROM deprecated_flag);
```

## Issue 1 (critical): `NOT IN` returns zero rows if any `flag_id` is NULL

This is the headline problem.

If the subquery `SELECT flag_id FROM deprecated_flag` returns **even one `NULL`**, the entire `NOT IN` predicate can never evaluate to `TRUE`, so the outer query returns **no rows at all** — silently.

### Why this happens

`x NOT IN (a, b, NULL)` is rewritten by SQL as:

```
x <> a  AND  x <> b  AND  x <> NULL
```

`x <> NULL` evaluates to `UNKNOWN` (not `FALSE`), and `... AND UNKNOWN` can never be `TRUE`. So every row fails the `WHERE` clause. You get an empty result set, with no error and no warning. This is one of the most common and most insidious SQL bugs because the query "looks correct" and works fine until the day a NULL lands in `deprecated_flag.flag_id`.

Given `deprecated_flag` is a config-style table likely maintained by hand or via migrations, a stray NULL `flag_id` is entirely plausible.

### Fix — use `NOT EXISTS` (recommended)

`NOT EXISTS` handles NULLs with correct, intuitive semantics and is the idiomatic choice here:

```sql
SELECT *
FROM feature_flag f
WHERE NOT EXISTS (
    SELECT 1
    FROM deprecated_flag d
    WHERE d.flag_id = f.id
);
```

### Alternative fixes

- Guard the subquery against NULLs (works, but easy to forget and less clear):

  ```sql
  SELECT * FROM feature_flag
  WHERE id NOT IN (
      SELECT flag_id FROM deprecated_flag WHERE flag_id IS NOT NULL
  );
  ```

- Or a `LEFT JOIN ... WHERE d.flag_id IS NULL` anti-join. Functionally fine; `NOT EXISTS` is cleaner.

> Note: a `NOT NULL` constraint on `deprecated_flag.flag_id` would prevent the trap at the source and is worth adding regardless.

## Issue 2: "active" is never filtered

The task says the query should return flags "that are active and not deprecated," but the query only handles the *not deprecated* half. There is no predicate for active status.

If `feature_flag` has an active/enabled column (e.g. `is_active`, `enabled`, `status`), you almost certainly need to filter on it:

```sql
SELECT *
FROM feature_flag f
WHERE f.is_active = TRUE          -- adjust to the real column/values
  AND NOT EXISTS (
      SELECT 1
      FROM deprecated_flag d
      WHERE d.flag_id = f.id
  );
```

Confirm the actual column name and semantics of "active" in the schema. (If "active" was meant to be synonymous with "not deprecated," then this point is moot — but the wording suggests two separate conditions.)

## Issue 3 (minor): `SELECT *`

For a config table this is harmless, but listing explicit columns is more robust against schema changes and clearer about intent. Low priority given the table is small and static.

## Performance

Not a concern. At ~80 rows the table is effectively static; any of the above approaches will be instantaneous. The rewrite is purely about **correctness**, not speed.

## Summary

| # | Severity | Problem | Fix |
|---|----------|---------|-----|
| 1 | Critical | `NOT IN` silently returns 0 rows if any `flag_id` is NULL | Use `NOT EXISTS` |
| 2 | Medium | "Active" condition is missing entirely | Add `WHERE is_active = TRUE` (verify column) |
| 3 | Low | `SELECT *` | List explicit columns |

### Recommended query

```sql
SELECT *               -- or explicit columns
FROM feature_flag f
WHERE f.is_active = TRUE   -- verify the real "active" column; drop if not applicable
  AND NOT EXISTS (
      SELECT 1
      FROM deprecated_flag d
      WHERE d.flag_id = f.id
  );
```
