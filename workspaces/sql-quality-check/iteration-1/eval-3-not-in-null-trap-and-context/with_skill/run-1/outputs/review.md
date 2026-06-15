# SQL review: active, non-deprecated feature flags

```sql
SELECT * FROM feature_flag
WHERE id NOT IN (SELECT flag_id FROM deprecated_flag);
```

Short version: the performance angle here is a non-issue — at ~80 static rows a
sequential scan is the right plan and nothing to worry about. But there are **two
correctness problems**, and the first one can silently return zero rows in
production. That matters far more than speed on a table this small.

---

## 1. The `NOT IN` + NULL trap (the dangerous one)

**Impact.** `NOT IN (SELECT flag_id FROM deprecated_flag)` is unsafe whenever
`flag_id` is nullable. If that subquery returns *even a single* `NULL`, the whole
`NOT IN` evaluates to `UNKNOWN` for every row and the query returns an **empty
result set** — no error, no warning. The reason is three-valued logic:
`id NOT IN (1, 2, NULL)` is `id <> 1 AND id <> 2 AND id <> NULL`, and `id <> NULL`
is never `TRUE`, so no row ever qualifies.

This is the worst kind of bug: it depends on data, not on the query. It works
perfectly until someone inserts a `deprecated_flag` row with a `NULL` `flag_id`
(or an orphaned/placeholder row), and then your feature-flag lookup quietly
returns nothing and every flag reads as "off." On a config table that drives
behavior, that's an outage waiting on a single bad row.

**Corrected version.** Use `NOT EXISTS`, which is immune to the NULL problem
because it correlates on a comparison rather than membership:

```sql
SELECT *
FROM feature_flag f
WHERE NOT EXISTS (
  SELECT 1 FROM deprecated_flag d WHERE d.flag_id = f.id
);
```

**Tradeoff.** Essentially none here. `NOT EXISTS` is correct regardless of
nullability and the planner treats it as an anti-join — at 80 rows the plan and
performance are indistinguishable from the original. The only "cost" is that
`NOT EXISTS` is slightly more verbose than `NOT IN`. If you would rather keep
`NOT IN`, you must instead guarantee `flag_id` is `NOT NULL` (add the column
constraint, or write `... FROM deprecated_flag WHERE flag_id IS NOT NULL`) — but
`NOT EXISTS` removes the footgun entirely and is the safer default.

---

## 2. The query never filters for "active" (likely a logic gap)

You said this is *supposed* to return **active** feature flags that aren't
deprecated — but the query only excludes deprecated ones. There is no predicate
on an active/enabled/status column anywhere.

So either:

- there's an `active` (or `enabled` / `status`) column on `feature_flag` that
  should be in the `WHERE`, and it's missing — in which case the query returns
  inactive-but-not-deprecated flags too; or
- "active" and "not deprecated" mean the same thing in this schema, and the
  query is complete as far as that intent goes.

**Which is it?** If `feature_flag` has an active/enabled flag column, the intended
query is probably:

```sql
SELECT *
FROM feature_flag f
WHERE f.active            -- or f.enabled = true / f.status = 'active'
  AND NOT EXISTS (
    SELECT 1 FROM deprecated_flag d WHERE d.flag_id = f.id
  );
```

I can't infer the column name or whether it exists from the SQL alone, so I'm
flagging it rather than guessing.

---

## 3. `SELECT *` — minor, worth noting

`SELECT *` couples callers to the table's column layout (adding a column silently
changes every result) and pulls back columns nobody may use. On an 80-row static
config table the I/O cost is irrelevant — this is a maintainability nit, not a
performance one. Select the columns the caller actually reads if you want the
contract to be explicit; otherwise it's safe to leave as-is here.

---

## Bottom line

| # | Finding | Severity in this context |
|---|---------|--------------------------|
| 1 | `NOT IN` over a possibly-nullable `flag_id` can silently return **zero rows** | Fix this — it's a latent correctness bug |
| 2 | No `active` predicate despite the stated intent | Confirm: is there an active/status column to filter on? |
| 3 | `SELECT *` couples callers to schema | Optional; no perf impact at this size |

The table being tiny and static means you can ignore the usual `NOT IN`
performance concern — but it does **not** make you safe from the NULL trap, which
is about correctness, not volume. Switch to `NOT EXISTS` and confirm the "active"
filter.
