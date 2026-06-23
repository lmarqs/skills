# Modeling, indexing, and execution-plan validation

The smells in `references/smells.md` are symptoms; their root cause is usually the data model. This file
holds the modeling and indexing guidance the recommendations draw on, and how to validate a query with
the execution plan. Read it for schema/design audits and to confirm a query's real behavior.

## Modeling and indexing guidance

Always state the tradeoff involved when recommending any of these — none is free:

- **Optimize for reads**, since reads are the predominant operation (data is written once, read many
  times). The cost: a little more work or storage on the rarer write path.
- **Denormalize frequently-read data**, especially transactional data, when the gain outweighs the cost
  of maintaining copies. The cost: duplicated data you must keep consistent on write.
- **Respect column order in composite indexes**: the column used in equality (or the most selective one)
  comes first, and the index is only usable when the query uses its prefix. A composite index on
  `(a, b)` helps a filter on `a` or on `a AND b`, but not a filter on `b` alone.
- **Use partial indexes** for recurring filters (e.g. `WHERE status = 'active'`) — a smaller index that
  covers only the rows you actually query. The cost: it helps only queries matching the predicate.
- **Avoid an excess of indexes** — each one taxes every write and takes space. Add indexes for the reads
  that matter, not speculatively.
- **Use appropriate data types**, avoiding the implicit conversions described in smell #2. A column typed
  to match how it's compared sidesteps a whole class of index-disabling casts.

## Validate with the execution plan

For any suspect query, examine the execution plan before considering it adequate. The plan confirms index
use and reveals sequential scans on large tables and sorts spilling to disk. Suggest or request the plan
as evidence — don't judge from the SQL text alone. The command varies by database; in PostgreSQL:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM table WHERE created_at > now() - interval '7 days';
```

What to look for in the plan:

- **`Seq Scan` on a large table** — the query is reading every row. Fine on a small lookup table; a red
  flag on a big transactional one. Cross-check against smells #2, #4, and #6, which all force scans.
- **An expected index not appearing** (`Index Scan` / `Index Only Scan` absent) — confirms the index
  isn't being used, often because of a cast/function on the column or a type mismatch.
- **`Sort` with disk spill** (`Sort Method: external merge  Disk: …`) — the sort exceeded `work_mem` and
  went to disk; points at smell #10 (unindexed sort).
- **Row estimates far from actuals** (with `ANALYZE`) — the planner is working from stale statistics, so
  its plan choice may be wrong; suggest refreshing statistics.
- **`Rows Removed by Filter` very high** — the query reads far more than it returns, a sign the filter
  isn't index-backed.

The execution plan is the arbiter: a query that looks clean can still scan, and a query that looks scary
can be fine on the actual data. Let the plan settle it.
