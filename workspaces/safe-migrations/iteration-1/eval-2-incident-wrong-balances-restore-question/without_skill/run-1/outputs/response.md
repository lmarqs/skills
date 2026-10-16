# Recommendation: Do NOT restore the snapshot in place — reconstruct balances instead

## TL;DR

Restoring last night's pre-migration snapshot over production and "calling it a day" is the wrong call. It would fix the `accounts` table by destroying a full day of legitimate data — every deposit, withdrawal, new account, and every other table's writes since ~last night. You would be trading a *correctable* data-quality incident for an *uncorrectable* data-loss incident.

The right move: use PITR to restore a **copy** of the database to the instant before the migration, and use it — together with the intact, append-only `transactions` table — to recompute correct balances and apply a forward-fix to production.

## Why the snapshot-restore-and-done plan fails

1. **RDS restores don't merge; they replace.** A snapshot/PITR restore creates a new instance frozen at the restore point. Cutting over to it discards everything written since — not just the bad balances, but all of today's legitimate transactions, and writes to *every other table* (users, sessions, audit logs, orders, whatever else lives in that DB).
2. **The transactions are real money movements.** Customers made deposits and withdrawals all day. Silently erasing them is a far worse customer, financial, and possibly regulatory outcome than balances that are wrong for a few more hours.
3. **It doesn't even fully fix balances.** The restored balances would be correct *as of last night*, then immediately wrong again because today's activity is gone. You'd have consistent-looking but factually false balances.

The only scenario where restore-and-cutover is defensible is if the business decides today's transactions must be voided entirely — and that's a business/finance decision, not a DBA shortcut.

## Recommended plan

### Phase 0 — Stabilize and preserve (do this first, now)

- **Snapshot current production immediately** (manual snapshot). Whatever we do next, we must be able to get back to the current state. Never run a repair without a fresh backup of the broken state.
- Confirm the exact **timestamp of the migration** (call it `T`) from deploy logs / migration logs / binlogs.
- Decide with product/support whether to **temporarily disable balance-sensitive actions** (overdraft-gated withdrawals, transfers) until fixed. Balances are known-wrong; every hour of activity against them creates more second-order effects. If a short write freeze on `accounts` is tolerable, it makes the fix simpler and the verification cleaner.

### Phase 1 — Restore a reference copy, not production

- Use PITR to restore a **new instance** at `T - ε` (just before the migration ran). This gives us the authoritative pre-migration balance for all ~2M accounts: `correct_balance_at_T(account_id)`.
- Production stays up and untouched.

### Phase 2 — Recompute correct balances

Because `transactions` is append-only and intact, the correct current balance is:

```
correct_balance = correct_balance_at_T            -- from the PITR copy
                + SUM(transaction deltas WHERE ts > T)  -- from prod's transactions table
```

Two ways to apply it, depending on whether you can pause writes:

**Option A — brief write freeze (simplest, safest):** pause writes to `accounts`, compute `correct_balance` per account, `UPDATE` in batches, verify, unfreeze.

**Option B — additive correction under live traffic:** if a freeze isn't acceptable, note that if every post-migration write to `account_balance` is an increment/decrement (`balance = balance + delta`), the migration's error is a **constant per-account offset**:

```
offset(account)   = correct_balance_at_T - wrong_balance_at_T
UPDATE accounts SET account_balance = account_balance + offset  -- commutes with concurrent deltas
```

where `wrong_balance_at_T` can be derived either by re-applying the known wrong-rate transformation to the PITR copy, or as `current_balance - SUM(deltas since T)`. This is safe under concurrent traffic **only if** no code path sets the balance absolutely or computes fees as a function of the (wrong) balance — verify that assumption in the app code before choosing this path.

Operational hygiene for the fix itself:

- Write it as a reviewed, idempotent script; **dry-run it against the PITR copy first** and diff expected vs. actual.
- Update in **batches** (e.g., 5–10k rows per transaction) to avoid long locks, replication lag, and a 2M-row single transaction.
- Keep a **correction audit table** (`account_id, old_balance, new_balance, offset, applied_at`) so the fix itself is auditable and reversible.

### Phase 3 — Verify

- Reconcile: for every account, `account_balance` must equal `opening_balance_from_PITR + SUM(all transaction deltas since T)`. Zero mismatches (or a triaged explanation for each) before declaring done.
- Global invariants: total sum of balances, counts, spot-check high-value accounts.
- Have finance/support sample-verify a handful of real customer accounts.

### Phase 4 — Second-order cleanup (don't skip this)

The balances were wrong all day, so decisions made *against* them may be wrong even though the fix restores the numbers:

- Withdrawals wrongly **declined** (balance understated) or wrongly **allowed** (overstated) → possible negative balances after correction.
- Overdraft fees, interest accruals, or notifications computed from wrong balances.
- Statements, emails, or downstream systems (data warehouse, reporting) that consumed wrong values.

Enumerate these with product/finance and remediate explicitly; some are customer-comms issues, not SQL issues.

## Bottom line

Your teammate's instinct ("the snapshot has the right numbers") identifies the right *ingredient* but the wrong *recipe*. The snapshot/PITR copy is the source of truth for pre-migration balances — as **reference data for a forward fix**, not as a replacement for a production database that has since accumulated a day of real customer activity. With an intact append-only ledger, correct balances are fully reconstructable with zero data loss. Take the extra few hours and do it that way.
