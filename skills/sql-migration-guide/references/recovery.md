# Recovery

A plan names its recovery path before deploy, so nobody invents one during the incident. This
file covers keeping a kill switch that does not touch the schema, choosing the response, and
repairing data. Headings marked *(beyond the article)* extend the source article.

## Contents

- Separate deployment from release
- What flags do not do
- Flag-off, rollback or roll forward
- Compensating migrations
- Sources of truth and their retention
- Restore aside, not over production
- Recovery objectives

## Separate deployment from release

For large or destructive changes, deploying code and turning on behavior are different moments:

```
1. Expand the schema, additive and compatible      reversible, boring
2. Deploy code with the feature off                reversible by redeploy
3. Enable for internal users or a canary slice     reversible by config
4. Ramp: 10%, 50%, 100%                            reversible by config
5. Soak through the rollback window                change nothing on purpose
6. Contract, the destructive step                  one-way, gated on evidence
```

From step 3 to 5, recovery is a config change instead of a database operation. That is fast,
and it is an action a tired on-call engineer can take safely. Inspect the writes the canary
produces before widening.

## What flags do not do

- **Flags do not repair data.** Turning the feature off stops new damage. Rows already written
  wrong stay wrong.
- **A flag that gates writes obeys the compatibility rules.** Turning it on must not let v2
  write values v1 cannot read while v1 is still in traffic. The flag changes when the risk
  starts, not whether the change was classified correctly.
- **Flags are debt.** Give each migration flag the same cleanup deadline as the column it
  protects.
- *(beyond the article)* **Flags multiply the states.** With a flag the reachable states are
  v1, v2 flag-off and v2 flag-on, against each schema. Test flag-off as seriously as flag-on:
  it is what runs during the incident.
- *(beyond the article)* **Flag-off must really be safe.** If the write path changed before the
  flag check, or the flag only gates the UI, the kill switch is decorative.

## Flag-off, rollback or roll forward *(beyond the article)*

| Situation | Response |
|---|---|
| New behavior is wrong, the data it wrote is valid | Flag off |
| Code is wrong, schema is compatible with the previous release | Roll back code, after confirming that compatibility |
| Data written is wrong | Roll forward with a compensating migration. A rollback stops new damage and repairs nothing |
| The migration itself hangs | Cancel it and release its locks. The queue behind it is usually the real outage |

**Rollback is for code defects with an unchanged data contract.** Anything that changed data
rolls forward: a rollback cannot restore destroyed information and reintroduces the (v1, S1)
state under the worst conditions.

## Compensating migrations

A new forward operation that corrects a known error. It works when you can identify the
affected rows and reconstruct the right value from data still present: columns kept by an
Expand phase, audit history, event logs, a pre-image table. That is the strongest argument for
delaying destructive cleanup and capturing pre-images.

```sql
BEGIN;

-- 1. blast radius first, with the exact predicate of the repair
SELECT count(*) FROM orders o
JOIN   mig_2026_08_10_price_rebase_backup b ON b.order_id = o.id
WHERE  o.amount <> b.old_amount * 1.10;

-- 2. repair exactly the damaged set, in batches if large
UPDATE orders o
SET    amount = b.old_amount * 1.10, corrected_by = 'INC-4471'
FROM   mig_2026_08_10_price_rebase_backup b
WHERE  o.id = b.order_id
  AND  o.amount <> b.old_amount * 1.10;

-- 3. verify before committing: expect 0
SELECT count(*) FROM orders o
JOIN   mig_2026_08_10_price_rebase_backup b ON b.order_id = o.id
WHERE  o.amount <> b.old_amount * 1.10;

COMMIT;
```

Rules *(beyond the article)*:

- **Count before writing.** If the count is not what you expected, stop.
- **Scope precisely.** A repair that also touches correct rows is a second incident.
- **Mark what you touched** so the next investigator can tell the repair from the damage.
- **Treat it as a backfill**: batched, idempotent, observable, reviewed. See backfills.
- **Rows users changed after the damage** are the hard case. A naive repair overwrites their
  legitimate edits. Bound the repair by the incident window or exclude rows with later
  activity, and handle the rest by hand.

## Sources of truth and their retention *(beyond the article)*

Ranked by how much you will wish you had them:

1. A pre-image table you wrote yourself: exact, scoped, queryable.
2. Application audit or history tables.
3. A change-data-capture stream or outbox, if retention covers the incident.
4. WAL or binlog: complete but low-level, with retention usually in days.
5. Snapshots and point-in-time recovery: complete but coarse and slow.
6. Backups: the last resort.

**Retention rule:** every evidence source must outlive the rollback window, and the window must
outlive the realistic time to detect. Quiet corruption is often found by a customer after
weeks. If WAL retention is three days, the evidence the plan counts on will not exist.

## Restore aside, not over production

A full restore to before the migration also deletes every valid order, payment and signup
written since, and takes an outage to do it. Instead:

1. Restore the backup or snapshot into a separate instance.
2. Identify the affected rows with a diff query.
3. Extract only the affected values.
4. Load them into production as a staging table.
5. Run a scoped, verified repair.

A full in-place restore is defensible only when essentially every post-migration write is
worthless, and a named person decides it, not a runbook step.

## Recovery objectives *(beyond the article)*

- State the recovery point objective (how much data may be lost) and recovery time objective
  (how long recovery may take) as numbers per system.
- Restore time is not backup time. A multi-terabyte database restores in hours. If nobody has
  timed a restore recently, the recovery time objective is fiction.
- An untested backup is not a backup. Restore rehearsals produce a measured number for the
  plan.
