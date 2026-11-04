# Backfills

**A backfill is a production workload, not a setup script.** A worker may time out after
finishing a batch and retry it. Two workers may overlap ranges. The job may need to pause
during peak traffic or during an unrelated incident. Headings marked *(beyond the article)*
extend the source article.

## Contents

- The six properties
- Order: dual-write first
- Batching mechanics
- Throttling
- Failure handling
- Sizing and rehearsal
- Data fixes are backfills

## The six properties

The article names five. The sixth is an addition.

| Property | Concretely |
|---|---|
| **Idempotent** | Re-processing a batch changes nothing. Use a guard predicate such as `WHERE new_col IS NULL`, or a deterministic `SET new = f(old)`. Never `SET n = n + 1`. |
| **Restartable** | Progress lives outside the worker in a checkpoint row, so a crash resumes where it stopped. |
| **Bounded** | Each transaction touches a known, small number of rows and holds locks well under a second. Never one transaction over the table. |
| **Observable** | Total, processed, remaining, failed, retries, rate and ETA, exported as metrics. |
| **Pausable** | A switch that stops it between batches and leaves a valid state. |
| **Throttled** *(beyond the article)* | It paces itself on database health instead of running as fast as the database allows. |

## Order: dual-write first

New rows keep arriving during the backfill. Deploy the code that writes the new column
*before* starting the backfill, so new rows are already correct and the guard predicate skips
them. A backfill started before dual-write chases a moving target and leaves a tail of
unmigrated rows.

## Batching mechanics *(beyond the article)*

**Use keyset pagination, not `OFFSET`.** `OFFSET 5000000` reads and discards five million rows
per batch, so each batch gets slower and the job may never finish.

PostgreSQL, one batch:

```sql
WITH batch AS (
  SELECT id
  FROM   customers
  WHERE  id > :last_id           -- keyset cursor from the checkpoint
    AND  display_name IS NULL    -- idempotency guard
  ORDER  BY id
  LIMIT  1000                    -- bounded
  FOR    UPDATE SKIP LOCKED      -- lets several workers cooperate without overlap
)
UPDATE customers c
SET    display_name = c.full_name
FROM   batch b
WHERE  c.id = b.id
RETURNING c.id;                  -- max(id) becomes the next checkpoint
```

MySQL has no `UPDATE ... FROM` or partial indexes. Walk the primary key in fixed ranges:

```sql
UPDATE customers
SET    display_name = full_name
WHERE  id >  :last_id
  AND  id <= :last_id + 1000
  AND  display_name IS NULL;
-- advance :last_id by 1000 until it passes MAX(id), checkpointing each step
```

Details that matter:

- **Index the driving predicate**, or every batch scans for unmigrated rows. In PostgreSQL a
  partial index such as `CREATE INDEX CONCURRENTLY ... ON customers (id) WHERE display_name IS
  NULL` shrinks as the job advances. Drop it at the end.
- **Checkpoint durably** in a table, in the same transaction as the batch where possible:
  `migration_progress(migration_id, last_id, processed, failed, updated_at)`.
- **Commit between batches.** Wrapping the whole job in one transaction "for safety" recreates
  the long-transaction problem. See operational-mechanics.
- **Sparse keys.** Fixed-width ranges over a key with large gaps produce empty batches. Select
  the next N keys instead when gaps are large.

## Throttling *(beyond the article)*

Sleep between batches, and adapt the sleep:

```
if replica_lag > 5s or db_cpu > 70% or p99_latency > SLO:
    back off, exponential and capped
else:
    shorten the sleep toward a floor
```

Signals worth wiring: replica lag, primary CPU and IO, lock wait time, application p99 and
error rate. A backfill that takes six hours unnoticed beats one that takes twenty minutes and
pages the team.

## Failure handling *(beyond the article)*

- **Per-row failures.** Do not let one bad row stop the run. Record it in
  `migration_failures` with the key, error and attempt count, skip it, continue, and alert on
  the count. Failed rows are findings about your data, often the most useful output.
- **Batch failures.** Retry with backoff. After a few attempts, halve the batch size, since a
  timeout often means an unusually heavy range. Then park and page.
- **Completion is a claim.** "0 remaining" from the worker is not "0 rows match the
  unmigrated predicate". Verify with an independent query. See verification-and-testing.

## Sizing and rehearsal *(beyond the article)*

Measure on a production-sized clone: rows per second at a given batch size, p99 batch time,
lock time, WAL or binlog generated. Compute the wall-clock estimate and put it in the plan.
"We will backfill 400M rows" without a duration is not a plan: if it takes eleven days, that
changes the rollback window, the cleanup date and maybe the approach.

## Data fixes are backfills

A one-off data correction, a compensating migration or a retention purge carries the same
contract: count the target rows first, batch, guard for idempotency, checkpoint, verify. Under
pressure people run a bare `UPDATE` in a console. That is how a data-quality problem becomes
data loss.
