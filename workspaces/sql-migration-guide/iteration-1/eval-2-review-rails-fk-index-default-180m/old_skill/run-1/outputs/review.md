# Review: `AddFulfillmentToOrders` (orders, ~180M rows, PG 15 / RDS, ~2k writes/s)

**Verdict: do not merge as written.** Two problems:

1. **Bad data.** `fulfilled_at` with `default: -> { 'now()' }` marks every existing order, and every order inserted afterwards, as fulfilled. Neither the database nor the code can tell those fake values from real ship times. This is a data-compatibility bug, and it is the most important finding.
2. **Locks on `orders`.** Rails wraps the whole `change` in one transaction. The `ALTER TABLE ... ADD COLUMN` from `add_reference` takes an `ACCESS EXCLUSIVE` lock on `orders` and holds it until commit. That covers two non-concurrent index builds over 180M rows and a full-table FK validation scan. For that whole time, every read and write on your biggest table is blocked. The pre-deploy step will look like an outage.

Each of the three statements is fine in intent. The problem is how they are written and that they are bundled together. A staged version is below.

## Assumptions (not stated in the prompt)

- The `warehouses` table already exists and is much smaller than `orders`.
- The old app version (v1) never reads `fulfilled_at` or `warehouse_id`. It runs alongside v2 during the rolling update and remains the rollback target.
- No `strong_migrations`-style gem, and no `lock_timeout` or `statement_timeout`, is configured for the migration connection. If one is, some of the lock findings change from "outage" to "migration fails". That is still not mergeable.
- "Not fulfilled" is supposed to be `NULL`. The prompt says v2 sets `fulfilled_at` when an order ships, which implies this.

## Findings, by statement

### 1. `add_column :orders, :fulfilled_at, :datetime, default: -> { 'now()' }`: data compatibility, hard to repair (blocker)

- **Mechanism.** `now()` is `STABLE`, not volatile. On PG 11+ that means a fast default: PG evaluates it once at `ALTER` time and stores it as the column's "missing value", so the table is not rewritten. The result is that all ~180M existing rows read back with the **same timestamp, the moment the migration ran**. Every row inserted later gets its insert time.
- **Failure scenario.**
  - During and after rollout, each order v1 or v2 creates gets `fulfilled_at = created_at` (approximately) before it has shipped.
  - Each historical order, shipped or not, looks fulfilled at the migration time.
  - Any v2 logic or reporting that treats `fulfilled_at IS NOT NULL` as "shipped" is wrong from the first second.
  - Nothing raises an error. This is the silent "change of meaning" class, the worst kind, because both versions keep running while the data degrades.
- **Why it is costly to undo.** The true state is "never fulfilled", and that is never recorded. Repair means a compensating `UPDATE` across 180M rows. It can match the identical migration timestamp for old rows. For new rows it has to guess (`fulfilled_at ≈ created_at` and not shipped), and that guess is fragile once v2 also writes real values.
- **Fix.** Make it nullable with no default: `add_column :orders, :fulfilled_at, :datetime`. This is fully compatible: v1 ignores it, and inserts succeed with `NULL`. If you need a value for historically shipped orders, write a separate batched backfill from your actual ship data.

### 2. `add_reference :orders, :warehouse, foreign_key: true, index: true`: locks, plus a conditional constraint

- `ADD COLUMN warehouse_id bigint` (nullable) is compatible and catalog-only, but it still takes `ACCESS EXCLUSIVE` briefly. With no `lock_timeout`, it waits in the lock queue behind any long-running query on `orders`, and every query that arrives after it queues too. At 2k writes/s that pile-up is an outage on its own, even before the transaction issue.
- `index: true` produces a plain `CREATE INDEX`. The build scans 180M rows and holds a `SHARE` lock that blocks writes. Inside this transaction it runs under the `ACCESS EXCLUSIVE` lock already held, so reads are blocked too.
- `foreign_key: true` runs `ADD CONSTRAINT ... FOREIGN KEY` with immediate validation, which is a full scan of `orders`. It also takes `SHARE ROW EXCLUSIVE` on **`warehouses`**, so writes to `warehouses` are blocked for the duration as well.
- **Conditional compatibility of the FK.** Once v2 writes `warehouse_id`, a value that isn't in `warehouses` will fail the ship operation. Any existing code path that deletes warehouses will also start failing, because the FK defaults to `NO ACTION`. Check both before enabling the FK.

### 3. `add_index :orders, [:status, :created_at]`: lock, plus unrelated scope

- This is also a non-concurrent build over 180M rows, inside the same transaction. Same blocking as above.
- The new shipping code doesn't seem to need this index; the prompt doesn't mention any query that uses it. Ship it in its own migration and PR so a failure or slow build doesn't hold up the fulfillment feature (checklist item 10). Whether the index is worth its write amplification at 2k writes/s is a query-performance question, outside this review.

### 4. Rollback: the auto-generated `down` is destructive

The `down` that `change` generates drops `warehouse_id` and `fulfilled_at`. Once v2 has shipped orders, running it deletes real fulfillment data, and `up` cannot bring it back. Application rollback (redeploying v1) needs no schema rollback here, because the nullable columns are harmless to v1. So the plan should be "roll back code only, never run `db:rollback` on this after release". If you can, make that explicit by raising `ActiveRecord::IrreversibleMigration` in `down` for the column migration, or document it.

## Staged alternative

Each step is a separate migration. Steps A–D can go in one PR, but they must be separate migration files so each gets its own transaction semantics. Set `lock_timeout` on every one and retry on timeout rather than waiting in the lock queue.

```ruby
# A — Expand: catalog-only, compatible with v1. Brief ACCESS EXCLUSIVE, bounded by lock_timeout.
class AddFulfillmentColumnsToOrders < ActiveRecord::Migration[7.1]
  def change
    execute "SET LOCAL lock_timeout = '5s'"
    add_reference :orders, :warehouse, index: false, foreign_key: false
    add_column :orders, :fulfilled_at, :datetime   # nullable, no default
  end
end

# B — Index without blocking writes. No DDL transaction (CONCURRENTLY can't run in one).
class AddIndexOrdersOnWarehouseId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    add_index :orders, :warehouse_id, algorithm: :concurrently, if_not_exists: true
  end
end

# C — FK without validating existing rows. Brief lock only, no scan.
class AddOrdersWarehouseFk < ActiveRecord::Migration[7.1]
  def change
    execute "SET LOCAL lock_timeout = '5s'"
    add_foreign_key :orders, :warehouses, validate: false
  end
end

# D — Validate. Takes SHARE UPDATE EXCLUSIVE on orders, which doesn't block reads/writes; scans the table.
class ValidateOrdersWarehouseFk < ActiveRecord::Migration[7.1]
  def change
    validate_foreign_key :orders, :warehouses
  end
end

# Separate PR — the unrelated composite index.
class AddIndexOrdersOnStatusCreatedAt < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    add_index :orders, [:status, :created_at], algorithm: :concurrently, if_not_exists: true
  end
end
```

Notes on the stages:

- **Pre-deploy step duration.** A `CONCURRENTLY` build over 180M rows does two table scans and waits for running transactions to finish. It can run for a long time, and I haven't estimated how long for your hardware. Check that your deploy pipeline's timeout and the migration's `statement_timeout` allow for it. Otherwise, run steps B and D out-of-band before the release PR. Watch replica lag on RDS while they run.
- **Failed concurrent builds leave an `INVALID` index**, and `if_not_exists` will then skip it. Check after B and before retrying:
  `SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;` Drop any invalid index you find with `DROP INDEX CONCURRENTLY`, then rerun B.
- **Code.** Deploy v2's writes to `warehouse_id` and `fulfilled_at` only after A has landed, which the pre-deploy ordering already guarantees. A feature flag on the "set on ship" path is cheap insurance. If v2 writes bad warehouse ids, you can turn it off without touching the schema.

## Pre-deployment checklist

| # | Question | Status for the staged version |
|---|---|---|
| 1 | Can v1 run on the new schema? | Yes. Nullable columns, no default. **No** for the original: v1 inserts get a fake `fulfilled_at` |
| 2 | Can v1 and v2 run together? | Yes. v1 never writes the new columns, and v2 writes only when an order ships |
| 3 | Is information deleted or transformed? | No, as long as `down` is never run after release (finding 4) |
| 4 | Is it safe to rerun? | A/C: rerunning after success errors on the duplicate, so guard with `if_not_exists` / `column_exists?` if your tooling retries. B: yes with `if_not_exists`, after clearing invalid indexes |
| 5 | Can a large backfill stop and resume? | No backfill needed. If you later backfill `fulfilled_at` for historical orders, make it batched, idempotent (`WHERE fulfilled_at IS NULL`), and resumable |
| 6 | How do we verify? | `SELECT convalidated FROM pg_constraint WHERE conrelid = 'orders'::regclass AND contype = 'f' AND confrelid = 'warehouses'::regclass;` is true after D; no invalid indexes; `SELECT count(*) FROM orders WHERE fulfilled_at IS NOT NULL` is proportional to orders shipped since release, **not ~180M** |
| 7 | Can we disable the new behavior without a schema revert? | Only if the ship path is behind a flag. Recommended |
| 8 | What is the recovery path for bad data? | Compensating `UPDATE ... SET warehouse_id/fulfilled_at = NULL` for the affected ship events, batched. Not a restore |
| 9 | When does destructive cleanup happen? | None planned. Keep it that way: no `db:rollback` |
| 10 | Can this interact with concurrent changes? | Yes. Split the `[:status, :created_at]` index out. Don't run other DDL on `orders` or `warehouses` while B or D is running |

## Monitor while it runs

- Lock waits on `orders` and `warehouses`, from `pg_stat_activity` where `wait_event_type = 'Lock'`
- Blocked queries and app error rate during A and C, which are the brief-lock steps
- Index build progress (`pg_stat_progress_create_index`) during B
- Replica lag on RDS during B and D
