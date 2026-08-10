# Recommendation: do NOT restore the snapshot over production. Repair forward with a compensating migration.

## Bottom line

Restoring last night's RDS snapshot (or PITR) **in place** is the wrong call. It would fix
`account_balance` as of last night by **destroying every legitimate write made since** — the full
day of deposits and withdrawals you just said are real, plus everything else the app wrote today
(new accounts, new rows in `transactions`, any other table). You'd be converting a
one-column data bug into total data loss for a 12+ hour window. In-place restore is only
justified when essentially *all* post-migration writes are worthless; yours are explicitly not.

The good news: you have everything needed for a clean surgical repair, because two sources of
truth survive:

1. The **pre-migration snapshot / PITR point** — the correct balances as of the instant before
   the migration ran.
2. The **append-only, intact `transactions` table** — every legitimate delta applied since.

That combination makes this a *compensating forward migration* (a targeted backfill), not a
restore.

## What actually happened to the data

- The migration overwrote `account_balance` for ~2M rows with values computed at the wrong
  exchange rate. The pre-migration values are gone **from the live table** (overwritten in place,
  no old column kept) — but not gone from the world: the snapshot has them.
- Rolling the app back this morning stopped nothing retroactively — application rollback is not
  database rollback. It only prevented further bad recalculation.
- All day, deposits and withdrawals applied *correct deltas on top of wrong bases*. So today's
  state is: `current_wrong = wrong_post_migration_base + Σ(today's transaction deltas)`. The
  deltas are fine; the base is wrong. That decomposition is exactly what makes the repair safe.

## The repair plan: restore-aside-and-repair

**Step 0 — Contain and preserve.**
- Take a fresh snapshot of production *now* (preserves evidence and gives you an undo point for
  the repair itself).
- Pause or gate anything downstream that *consumes* balances and can cause harm — interest
  accrual, overdraft fees, low-balance alerts, statements, exports — until repair is verified.
  If you have a flag for those, use it; that's your kill switch that touches no schema.
- Confirm no instance of the migration code can run again.

**Step 1 — Restore aside, never over.**
Restore the pre-migration snapshot (or PITR to the minute before the migration started) into a
**separate RDS instance**. Extract one dataset from it: `(account_id, account_balance)` as of
pre-migration. Load it into production as a scratch table, e.g.
`balance_repair_2026_08_10 (account_id PK, pre_migration_balance, correct_target, applied_at NULL)`.

**Step 2 — Compute the correction per account.**
Decide what "correct" means: if the migration was *supposed* to recalculate at the right rate,
compute `correct_pre = f(pre_migration_balance, correct_rate)`; if the recalculation shouldn't
have happened at all, `correct_pre = pre_migration_balance`.

Then the per-account fix is a **delta, not an absolute value**:

```
correction = correct_pre − wrong_post_migration_base
```

where `wrong_post_migration_base` is derivable two independent ways — cross-check them:
- re-apply the known wrong formula to `pre_migration_balance`, and
- `current account_balance − Σ(deltas in transactions since migration start)`.

If the two disagree for an account, flag it for manual review instead of auto-repairing.

Applying an additive correction (`SET account_balance = account_balance + correction`) is what
lets you repair **while customers keep transacting**: deposits/withdrawals commute with the
correction, so you don't race live traffic and don't need a write freeze. An absolute
`SET account_balance = <value>` would silently clobber any transaction that lands mid-repair.

**Step 3 — Run it as a real backfill, under the backfill contract.**
This is a production workload, not a script:
- **Idempotent**: additive updates are *not* naturally idempotent, so stamp progress — set
  `applied_at` in the scratch table in the same transaction as each `UPDATE`, and only select
  rows `WHERE applied_at IS NULL`. Re-running is then a no-op.
- **Bounded**: batches of ~1k–5k by `account_id` range; never one 2M-row transaction (lock
  pileups, replication lag, WAL bloat on RDS).
- **Restartable / pausable**: progress lives in the scratch table; stopping mid-way leaves a
  valid state (some accounts fixed, some not — none made worse).
- **Observable**: emit total / processed / remaining / failed rows and rate; watch replication
  lag and lock waits while it runs.

**Step 4 — Verify with queries, not exit codes.**
- Convergence: `SELECT COUNT(*) FROM balance_repair_2026_08_10 WHERE applied_at IS NULL;` → 0.
- Reconciliation (the strong check): for every account, assert
  `account_balance = correct_pre + Σ(transactions deltas since migration start)`. Count and
  list mismatches; they should be exactly the manually-flagged set from Step 2.
- Aggregate sanity: total sum of balances vs. (pre-migration total, corrected, plus net
  transaction flow for the day).
- Only after these pass: re-enable the paused downstream jobs, and decide whether any fees or
  alerts fired today off wrong balances need their own compensation.

**Step 5 — Keep the evidence, put a date on cleanup.**
Keep the restored-aside instance and the scratch table until reconciliation has been stable
for an agreed window (e.g. 7–14 days), then tear down — with an owner and a deadline, or the
scratch table becomes permanent furniture.

## Why the snapshot-restore instinct is wrong here (say this to the teammate)

- A restore answers "what did the data look like at time T?" It cannot answer "keep today's
  valid writes but fix yesterday's bad ones" — that's inherently a row-level repair, and you
  have the two inputs (snapshot-aside + append-only `transactions`) that make the repair exact.
- Even "restore then replay today's transactions" is strictly worse than the plan above: it
  still loses every non-`transactions` write of the day, requires a long outage, and replay
  ordering/side effects are a project of their own. The compensating migration needs no
  downtime at all.

## For the postmortem (brief)

The incident was expensive because the migration violated three pre-deployment checklist items:
it **transformed data in place with no surviving original** (an Expand step — write recalculated
balances to a new column, verify, then cut over — would have made this a one-statement fix), it
**left no stamp** of what it touched (`migrated_at` / batch id would have handed you the repair
`WHERE` clause), and it shipped with **no verification queries**, so wrongness was discovered by
customers rather than by the migration itself. Any future balance recalculation should run as
Expand–Migrate–Contract with a rollback window before anything is overwritten or dropped.
