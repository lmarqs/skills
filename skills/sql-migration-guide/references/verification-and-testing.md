# Verification and testing

*A "success" message proves the statement ran, not that the data is right.* Every migration
step ships with what proves its own claim. Headings marked *(beyond the article)* extend the
source article.

## Contents

- What to monitor
- Verification queries
- Before dropping anything
- The compatibility test job
- Rehearsal on production-shaped data
- Migration linters
- Testing intermediate states

## What to monitor

**While a schema change runs:** execution time, locks held and lock wait time, blocked or
queued queries, replication lag, application error rate.

**For a backfill:** total, processed, remaining and failed rows, retry count, processing rate.
Add *(beyond the article)*:

- **ETA**, derived from rate and remaining. It is what people ask for.
- **Cursor position**, to show it is moving and not merely alive.
- **Batch p99 duration**, the early warning that batches are getting heavier.
- **Throttle state**, whether it is backing off and on which signal.
- **A staleness alert**, no progress in N minutes while marked running. A silent hang is the
  most common backfill failure and no counter shows it.

Emit start and end markers on the dashboards, so a latency jump at 14:07 lines up with
"migration 20260810_add_display_name ran 14:06 to 14:08".

## Verification queries

Write the check with the migration, and write the expected result next to it.

```sql
-- convergence: the two columns agree
SELECT count(*) FROM customers WHERE display_name IS DISTINCT FROM full_name;   -- expect 0

-- completeness: nothing left unmigrated
SELECT count(*) FROM customers WHERE display_name IS NULL AND full_name IS NOT NULL; -- expect 0

-- domain validity: only known values
SELECT status, count(*) FROM orders GROUP BY 1;                                  -- expect the known set

-- referential sanity after a split
SELECT count(*) FROM order_lines l LEFT JOIN orders o ON o.id = l.order_id
WHERE  o.id IS NULL;                                                             -- expect 0
```

`IS DISTINCT FROM` is PostgreSQL. In MySQL use `NOT (a <=> b)`.

*(beyond the article)* Run checks on the replicas the application reads from too. Keep the
important ones as scheduled invariant checks: the convergence query that mattered during the
migration often stays a useful data-quality alarm.

## Before dropping anything

The article's five preconditions, as a gate:

1. No application version reads it.
2. No application version writes it.
3. The backfill completed, verified independently.
4. The new field holds valid data, verified by query.
5. The rollback window expired.

**Proving 1 and 2** *(beyond the article)*. A grep of `main` is not proof.

- Search every deployed repository and every deployed version, not just the default branch.
- Check other consumers: ETL, BI, admin tools, notebooks, procedures, views, other services.
- Ask the database. PostgreSQL: `pg_stat_statements` for the column name. MySQL: the
  performance schema or the general log.
- **The strongest proof is empirical.** Rename the column to `zz_deprecated_full_name` or
  revoke access to it, wait through a full business cycle including month-end jobs, then drop.
  Anything still reading it fails loudly at a time you chose. The rename is itself breaking,
  so do it only once you believe nothing uses the column, as a deliberate test of that belief.

## The compatibility test job *(beyond the article)*

> Run the **previous release's** test suite against the **new** schema.

Check out the previous release tag, apply every migration including the new one, run its
integration tests. Red means the change is not deployable in one step. It catches renames,
drops, `NOT NULL` additions, new constraints and narrowed types with no reviewer vigilance.
The mirror job, new code against the old schema, checks whether the deploy is
order-sensitive.

## Rehearsal on production-shaped data *(beyond the article)*

Row counts, skew and bloat decide how a migration behaves, and a seeded test database has none
of them. Rehearse on a production clone, anonymized as policy requires, and record duration,
lock type and wait, rows affected, WAL generated and the verification results. That record is
the plan's evidence. Rehearse the recovery path as well: the compensating migration and the
restore-aside procedure should each have run once on the clone.

## Migration linters *(beyond the article)*

Linters encode the conditional cases and fail the pull request: `squawk` and `eugene` for
PostgreSQL DDL, Atlas for schema-as-code, `strong_migrations` for Rails. Typical rules: no
`DROP` without a deprecation record, no `NOT NULL` column without a default, no index build
without `CONCURRENTLY`, no DDL without `lock_timeout`, no `RENAME`. They move this knowledge
from what a senior engineer remembers to what CI enforces.

## Testing intermediate states *(beyond the article)*

The reachable states in the state matrix are testable. A test that starts v1, applies the
expand migration, starts v2 beside it, writes through both and asserts both readers see
correct data is worth more than any review discussion.
