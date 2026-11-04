# Operational mechanics

A migration is a physical operation on a live system, not an instant logical event. Most
migration outages come from here: the lock, the rewrite, the replica, the runner. The whole
file goes beyond the source article, which only names locks and replication lag as things to
monitor.

Engine behavior below is checked against the PostgreSQL 18 and MySQL 8.4 manuals. It is
version-sensitive: confirm against the engine version in use before relying on it.

## Contents

- The lock queue
- PostgreSQL
- MySQL / InnoDB
- Size gate
- Connection pools, cached plans and ORM traps
- Replicas and replication
- Long transactions, MVCC and bloat
- The migration runner
- The schema outside the database

## The lock queue

The failure nobody expects. In PostgreSQL, a DDL statement waiting for an `ACCESS EXCLUSIVE`
lock blocks every query that arrives after it, plain `SELECT`s included. One long transaction
holding a lock plus one waiting `ALTER TABLE` is a full outage on that table, even if the
`ALTER` itself takes milliseconds. MySQL has the same pile-up through metadata locks: a long
transaction that merely touched the table blocks the DDL, and everything queues behind it.

Fail fast instead of queueing, then retry with backoff and hunt the long transaction:

```sql
SET lock_timeout = '3s';        -- PostgreSQL: give up instead of blocking traffic
SET statement_timeout = '30s';  -- never let the DDL itself run away
```

MySQL's equivalent knob is `lock_wait_timeout` for metadata locks. Set timeouts per migration,
never inherited from the application.

## PostgreSQL

- **Adding a column.** A non-volatile default is stored in the catalog, so no rewrite. A
  volatile default such as `clock_timestamp()`, a stored generated column, an identity column
  or a domain type with constraints rewrites the table and its indexes.
- **`SET NOT NULL`** scans the whole table under an exclusive lock. Cheaper path: `ADD
  CONSTRAINT c CHECK (col IS NOT NULL) NOT VALID`, then `VALIDATE CONSTRAINT c`, then `SET NOT
  NULL`, which skips the scan because the valid check proves no nulls exist. Drop the check
  afterwards if you like.
- **`VALIDATE CONSTRAINT`** takes only `SHARE UPDATE EXCLUSIVE`, which allows reads and writes.
  A foreign key also takes `ROW SHARE` on the referenced table. So `ADD CONSTRAINT ... NOT
  VALID` then `VALIDATE` turns one long exclusive lock into a short one plus a concurrent scan.
- **`CREATE INDEX CONCURRENTLY`** does not block writes but scans the table twice and waits for
  transactions that touched the table to finish. It cannot run inside a transaction block, so
  the framework's per-migration transaction must be disabled. On failure it leaves an
  `INVALID` index that still costs write overhead. Drop it, or `REINDEX INDEX CONCURRENTLY`,
  and retry. Check `pg_index.indisvalid` after every build.
- **Unique constraint without a long lock.** `CREATE UNIQUE INDEX CONCURRENTLY`, then `ALTER
  TABLE ... ADD CONSTRAINT ... UNIQUE USING INDEX`. The index cannot be partial or on
  expressions.
- **Type changes** usually rewrite the table. Binary-coercible changes do not, for example
  raising a `varchar` limit or `varchar` to `text`.
- **DDL is transactional.** A failed multi-statement migration rolls back cleanly. Use one
  migration per transaction, except where `CONCURRENTLY` forbids it.

## MySQL / InnoDB

- **State `ALGORITHM` and `LOCK` explicitly** (`ALGORITHM=INSTANT`, `INPLACE` or `COPY`;
  `LOCK=NONE`). The server then errors instead of silently falling back to a copy under a
  blocking lock. `INSTANT` is the default in 8.4 and can add a column at any position.
- **Changing a column's data type** is `ALGORITHM=COPY` only: a full rebuild that blocks
  concurrent writes. Plan `INT` to `BIGINT` as a staged change or with an online schema change
  tool.
- **Widening `VARCHAR`** is in place only within a length-prefix band: up to 255 bytes, or from
  256 bytes upward. Crossing 255 bytes needs a copy. Bytes depend on the character set, so
  `VARCHAR(64)` in `utf8mb4` is already 256 bytes. Shrinking `VARCHAR` always needs a copy.
- **Making a column `NOT NULL`** rebuilds the table in place and fails if any row is `NULL`.
- **Secondary indexes** build online and allow concurrent reads and writes.
- **Atomic DDL** exists from 8.0. On older versions a half-applied multi-statement migration
  is a real state, so write migrations to be re-runnable.
- No partial indexes, and no `UPDATE ... FROM`. Batch backfills by primary-key range.
- For what `INSTANT` and `INPLACE` cannot do, use `gh-ost` or `pt-online-schema-change`.

## Size gate

For any table above a size the team agrees on, often around ten million rows, the plan states
each step's expected lock, its duration measured on a production-sized clone, and the abort
procedure.

## Connection pools, cached plans and ORM traps

- **Cached plans.** After DDL, PostgreSQL sessions with prepared statements can fail with
  `cached plan must not change result type`. Common with JDBC, Rails and long-lived pools.
  Retry on that error, recycle connections after migrations, or avoid shape changes to hot
  queries mid-rollout.
- **`SELECT *` and column-less `INSERT`** turn the safest change, adding a column, into a
  compatibility risk for code that decodes rows by position or into a strict struct.
- **Schema caches.** Rails' schema cache, Hibernate metadata and generated clients may read the
  schema at boot. Pods started before and after the migration can disagree.
- **Dependent objects.** Views, materialized views, triggers, procedures, generated columns,
  row-level security policies and partition parents all reference columns. A rename can break
  a view three layers away. Enumerate dependencies first, for example through `pg_depend` or
  `information_schema`.

## Replicas and replication

- **Replica lag.** A large backfill generates WAL or binlog volume and can push lag from
  milliseconds to minutes. It shows up as stale reads in the application, not as a migration
  error. Throttle the backfill on measured lag.
- **DDL replays on replicas.** On PostgreSQL physical replicas, replaying an exclusive-lock DDL
  conflicts with long queries there: either the query is cancelled or replay stalls, governed
  by `max_standby_streaming_delay`.
- **Logical replication and CDC pipelines.** PostgreSQL logical replication does not carry
  DDL. Publications, subscribers and downstream consumers must accept the new shape before the
  producer emits it: the same expand-contract ordering, applied to the pipeline.
- **Blue/green database deployments** such as RDS Blue/Green give a copy to rehearse on before
  cutover. They move where the compatibility problem shows up, they do not remove it.

## Long transactions, MVCC and bloat

- An `UPDATE` over every row of a large table writes a new version of every row: table and
  index bloat, an autovacuum storm afterwards, possibly a disk-space incident.
- A long transaction holds back vacuum, blocks concurrent index builds and, in the extreme,
  pushes toward transaction ID wraparound. **A single-statement backfill over a large table is
  a long transaction**, which is the real reason to batch.
- Plan the aftermath: `VACUUM (ANALYZE)` and fresh statistics, or `pg_repack` to reclaim space.
  Otherwise the first queries after a successful migration pick bad plans.

## The migration runner

- **Migrations at app boot** mean every pod races to migrate on deploy. At minimum, take an
  advisory lock so one wins. A slow migration then blocks readiness probes and can fail the
  rollout. A separate pipeline step or a Kubernetes job is safer and gives a place to stand
  between "migrated" and "deployed", which the ordering rule needs.
- **Transactions per migration.** Frameworks wrap each migration in a transaction by default.
  Concurrent index builds need it off: Rails `disable_ddl_transaction!`, Django `atomic =
  False`, Alembic `autocommit_block()`, Flyway `executeInTransaction=false`.
- **Checksums and ordering.** Flyway and Liquibase checksums catch edited history. Parallel
  branches produce out-of-order versions that behave differently in staging and production.
  Decide the policy on purpose.
- **Idempotency.** `IF NOT EXISTS` and existence guards make a retry safe. A migration that
  works exactly once cannot be retried during an incident.

## The schema outside the database

The "old readers, new writers" problem exists wherever the shape is stored.

| Carrier | The problem | The fix |
|---|---|---|
| Queues and in-flight jobs | v2 enqueues a new payload shape and v1 workers crash on it. Messages outlive the deploy, and dead-letter queues outlive it longer | Version payloads, deploy tolerant consumers first, drain or dual-format during the transition |
| Caches | Serialized objects in the old shape meet the new class, and rolled-back v1 reads what v2 cached | Version the cache key namespace with the schema |
| Event streams | Events are immutable and read by code that does not exist yet | Schema registry with compatibility checks, additive changes, upcasting on read |
| Search indexes and read models | Derived stores lag or keep the old mapping | Reindex as an explicit migration step |
| Analytics and ETL | A rename breaks the nightly job or, worse, produces wrong dashboards | A consumer inventory before any rename or drop |
| APIs and mobile clients | Old app versions live on phones for months | Client version decay sets the window for anything user-facing |

**The rollback window is bounded by the slowest thing that still holds the old shape**,
usually a mobile client or a dead-letter queue, not a pod.
