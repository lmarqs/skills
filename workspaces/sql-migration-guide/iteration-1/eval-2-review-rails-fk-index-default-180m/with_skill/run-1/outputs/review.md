# Review: `AddFulfillmentToOrders`

**Verdict: do not merge as written.** Running it locks `orders` against reads and writes for as long as it takes to build two indexes over 180M rows. It also marks every existing and every future order as fulfilled. Both problems go away if you split it into the staged migrations below. Every change in it is additive, so nothing is lost permanently yet.

## Assumptions (stated instead of asked)

- Rails 7.1 defaults: each migration runs in one transaction, `datetime` maps to `timestamp(6)` without time zone, and `prepared_statements` is on.
- No `lock_timeout` is set for the migration connection, and `strong_migrations` is not installed. If it were, it would reject this file.
- `warehouses` is small: hundreds to thousands of rows.
- v1 is the code running now and the rollback target. It never reads or writes the new columns.
- "Fulfilled" today is derived from something else (`status`, shipments). `NULL` in `fulfilled_at` is meant to mean "not fulfilled yet".
- I have no timings for this table. Every duration below has to be measured on an RDS snapshot restore before deploy.

## Findings, by severity

### 1. The default `now()` silently corrupts data (reversibility and compatibility)

`default: -> { 'now()' }` does not cause a rewrite on PG 15. `now()` is STABLE, not volatile, so Postgres evaluates it once when the `ALTER` runs and stores the result as the catalog default. The damage is to the meaning of the data:

- **All ~180M existing rows** read back `fulfilled_at` = the timestamp of the migration transaction. Every historical order, shipped or not, now looks fulfilled at deploy time.
- **Every new insert** gets `fulfilled_at = now()`. That includes v1 pods during the rollout and v2 after it, so new orders look fulfilled the moment they are created. The column stops meaning "when it shipped". Once v2 overwrites the value on ship, the rows fall into three groups that cannot be told apart: real ship time, creation time, and migration time.
- No error and no failing test will show this. Reports and logic that filter on `fulfilled_at IS NOT NULL` will be wrong from the first minute.

**Fix:** make `fulfilled_at` nullable with no default. If historical orders need a value, backfill it from the real source of truth (shipment events or status history) as a separate, batched job. Never use a timestamp invented at migration time.

### 2. One transaction holds `ACCESS EXCLUSIVE` on `orders` through both index builds (availability, the outage)

Rails wraps the whole `change` in one transaction. The first `ADD COLUMN` takes `ACCESS EXCLUSIVE` on `orders`, and Postgres holds that lock until commit. So every statement after it runs under a lock that blocks **all** reads and writes on `orders`:

| Statement | On its own | Inside this transaction |
|---|---|---|
| `add_reference` adds column `warehouse_id bigint` | catalog-only, milliseconds | takes `ACCESS EXCLUSIVE`, held to commit |
| `add_reference index: true`: `CREATE INDEX` (not concurrent) on `warehouse_id` | `SHARE` lock: blocks writes for a full scan and sort of 180M rows. NULLs are indexed too | runs under the exclusive lock |
| `foreign_key: true`: validated `FOREIGN KEY` | `SHARE ROW EXCLUSIVE` on **both** `orders` and `warehouses`, plus a validation scan of `orders` | also blocks writes to `warehouses` until commit |
| `add_index [:status, :created_at]` (not concurrent) | a second full build over 180M rows | runs under the exclusive lock |
| `add_column fulfilled_at` | catalog-only (see finding 1) | under the exclusive lock |

The outcome is a full outage on your biggest table for the combined build time. I have not measured it, but at this size expect minutes, not seconds. At 2k writes/sec, requests queue, connection pools run out, and the pre-deploy step may time out partway. If it does, Postgres rolls the transaction back (DDL is transactional), and you get the outage without the schema change.

There is a second problem with no `lock_timeout`. If any long transaction is open on `orders` (a report, a stuck job, autovacuum is fine but analytics queries are not), the very first `ALTER` waits behind it. While it waits, every query that arrives after it queues behind the `ALTER`, plain `SELECT`s included. That is an outage before any work has started.

I did not check the exact SQL Rails 7.1 emits for `add_reference ... foreign_key: true` (FK inline in the `ADD COLUMN` or a separate `ADD CONSTRAINT`). Either way the FK is validated, and the conclusion stands. Confirm by running the migration against a snapshot restore with SQL logging on.

### 3. The `[:status, :created_at]` index does not belong in this migration

It has nothing to do with fulfillment. It adds permanent write amplification on a table taking 2k writes/sec, and building it is the most expensive step here. Ship it in its own PR with `algorithm: :concurrently`, after showing the query that needs it (query and index design is sql-quality-check's job). Check whether an existing index already covers `status` first.

### 4. Old pods during the rollout (compatibility, minor)

Adding nullable columns keeps v1 working: Rails inserts name their columns, and v1 ignores columns it does not know. There is one known catch with prepared statements. Pods with cached plans for `SELECT "orders".*` can raise `cached plan must not change result type` once the columns appear. Rails retries this outside a transaction but **not inside one**, so expect a short burst of errors on order paths that run in transactions. Watch error rates for the first minutes after the migration. Recycling connections after it runs also clears the cache.

### 5. The `down` path is lossy once v2 has written

`change` reverses to `remove_column`. After v2 has set `warehouse_id` and `fulfilled_at` on shipped orders, running `down` destroys that data. Recovery is "roll back the code to v1, keep the columns". v1 runs fine against the new schema. Do not run `db:rollback` in production.

## Staged alternative

Every step is additive (R0) and v1 runs against each intermediate state, so the rollback target throughout is "v1 code, schema left as is". All of it can still run as pre-deploy steps.

**Deploy A: migrations only, no code change.**

```ruby
# 1. Columns: catalog-only, a lock lasting milliseconds; fails fast instead of queueing
class AddFulfillmentColumnsToOrders < ActiveRecord::Migration[7.1]
  def up
    execute "SET LOCAL lock_timeout = '3s'"
    add_column :orders, :warehouse_id, :bigint, if_not_exists: true
    add_column :orders, :fulfilled_at, :datetime, if_not_exists: true   # nullable, NO default
  end

  def down
    remove_column :orders, :fulfilled_at, if_exists: true
    remove_column :orders, :warehouse_id, if_exists: true
  end
end

# 2. Index before FK, so deletes/updates on warehouses do not scan orders
class IndexOrdersOnWarehouseId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :orders, :warehouse_id, algorithm: :concurrently, if_not_exists: true
    # Option: where: "warehouse_id IS NOT NULL" makes it far smaller while most rows are NULL
  end
end

# 3. FK without validation: brief lock on both tables; already enforced for new writes
class AddWarehouseFkToOrders < ActiveRecord::Migration[7.1]
  def up
    execute "SET LOCAL lock_timeout = '3s'"
    add_foreign_key :orders, :warehouses, validate: false
  end

  def down
    remove_foreign_key :orders, :warehouses
  end
end

# 4. Validate: SHARE UPDATE EXCLUSIVE on orders, so reads and writes continue
class ValidateWarehouseFkOnOrders < ActiveRecord::Migration[7.1]
  def change
    validate_foreign_key :orders, :warehouses
  end
end
```

Notes for step A:

- A lock-timeout failure in steps 1 and 3 is expected now and then. Retry the step, and find the long transaction (`pg_stat_activity` where `xact_start` is old).
- Step 2 (`CREATE INDEX CONCURRENTLY`) scans the table twice and waits for open transactions. Make sure no `statement_timeout` (from `database.yml` or the RDS parameter group) kills it, and that the pre-deploy step's own timeout can cover it. If either is in doubt, run step 2 out of band before the deploy. If it fails, it leaves an `INVALID` index that still costs write overhead: drop it and retry.
- Adding the FK before any code writes `warehouse_id` means no invalid value can get in, so step 4 cannot fail on data that v2 wrote.
- Step 4 is the only long scan, and it does not block traffic.

**Deploy B: v2 code** sets `warehouse_id` and `fulfilled_at` on ship. You can put this behind a flag so you can turn the writes off without a schema change.

**Separate PR: `[:status, :created_at]`** with `disable_ddl_transaction!` + `algorithm: :concurrently`, once a query justifies it.

**Optional separate job: historical backfill** of `fulfilled_at` and `warehouse_id` from the real shipment data. Use keyset batches over `id`, an idempotency guard (`WHERE fulfilled_at IS NULL`), throttling on replica lag, and a checkpoint. Run it only after deploy B, so new rows are already correct.

## Verification per step

```sql
-- after A1: columns exist, nullable, no default
SELECT column_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'orders' AND column_name IN ('warehouse_id', 'fulfilled_at');
-- expect 2 rows, is_nullable = YES, column_default NULL

-- after A2: no invalid indexes on orders
SELECT indexrelid::regclass FROM pg_index
WHERE indrelid = 'orders'::regclass AND NOT indisvalid;          -- expect 0 rows

-- after A4: FK validated
SELECT conname, convalidated FROM pg_constraint
WHERE conrelid = 'orders'::regclass AND contype = 'f'
  AND confrelid = 'warehouses'::regclass;                         -- expect convalidated = true

-- after B (adjust to your real status values): writes line up with shipping
SELECT count(*) FROM orders
WHERE fulfilled_at IS NOT NULL AND status <> 'shipped';           -- expect 0
SELECT count(*) FROM orders
WHERE status = 'shipped' AND updated_at > :deploy_b_time
  AND (warehouse_id IS NULL OR fulfilled_at IS NULL);             -- expect 0
```

While each step runs, watch lock waits and blocked queries on `orders`, order write latency and error rate, and RDS replica lag if you read from replicas.

## Open questions (each one is a finding until answered)

1. How long does each concurrent index build take on a snapshot restore of `orders`, and does the pre-deploy step's timeout cover it?
2. Is `statement_timeout` set for the migration role or in the RDS parameter group?
3. How big is `warehouses` and how often is it written? Steps 3 and 4 lock it briefly.
4. Do historical orders need `fulfilled_at`/`warehouse_id`, and where is the authoritative ship data?
5. Do other consumers read `orders` (CDC/Debezium, ETL, BI) and need to accept the new columns?
6. Is any other migration or backfill on `orders` in flight?
7. Has the previous release's test suite run against the new schema?
8. Consider adding `strong_migrations`. It flags findings 2 and 3 automatically in CI.
