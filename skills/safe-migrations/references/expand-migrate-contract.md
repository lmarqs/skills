# Expand – Migrate – Contract

The pattern turns **one breaking change into several compatible changes**, each individually
deployable and individually reversible. It costs temporary complexity — two columns, dual-write
code, a backfill job — and buys you a rollback option at every step. The running example: rename
`FullName` to `DisplayName`.

## Phase 1 — Expand

Add the new alongside the old. Remove nothing.

```sql
ALTER TABLE Customers ADD COLUMN DisplayName VARCHAR(100) NULL;
```

The database now supports both versions: v1 continues reading and writing `FullName` and ignores
the new column. This deployment is trivially rollback-safe — nothing depends on the new column
yet. The new column must be nullable (or defaulted); requiring it would break v1's inserts, which
is the exact failure the pattern exists to avoid.

## Phase 2 — Migrate

Deploy application code that **writes to both** and **reads the new with fallback to the old**:

```
customer.FullName    = request.Name
customer.DisplayName = request.Name
save(customer)

name = customer.DisplayName ?? customer.FullName
```

Rolling back this deployment is safe: v1 ignores `DisplayName`, and the fallback read means rows
written by either version are readable by both.

Then backfill existing rows so the two columns converge. **Backfills are production workloads,
not setup scripts.** A worker may time out after finishing a batch and retry it; two workers may
overlap ranges; the job may need to pause during peak traffic. A production backfill must be:

- **idempotent** — re-running over already-migrated rows changes nothing
- **restartable** — progress survives a crash; it resumes, not restarts
- **bounded** — small batches, never one long transaction that locks the table and starves
  customer traffic
- **observable** — emits progress (see `recovery.md` for what to track)
- **safe to pause** — stopping mid-way leaves a valid intermediate state (the fallback read
  guarantees this)

```sql
-- Loop until 0 rows affected. The WHERE clause is what makes retries safe:
-- already-migrated rows no longer match, so repeated execution is a no-op.
UPDATE Customers
SET    DisplayName = FullName
WHERE  DisplayName IS NULL
LIMIT  1000;
```

(Adapt to the engine — e.g. in PostgreSQL, batch by key range or use a CTE with `LIMIT`; the
shape is what matters: bounded batch + idempotence predicate + progress tracking.)

**Dual writes have a failure mode worth naming.** When both writes hit the same database in one
transaction, you get atomicity for free. The moment they span tables in different databases, or a
database and another service, one write can succeed while the other fails — you've traded a
migration problem for a distributed-consistency problem. Treat it as one: outbox, reconciliation
job, or accept-and-repair, but never assume both writes happen.

## Phase 3 — Contract

After the backfill completes *and is verified*, deploy code that reads and writes only
`DisplayName`. Do **not** drop `FullName` in the same deployment. Keep it through a defined
**rollback window** — the agreed period after which you call the release done — so that
redeploying the previous version remains possible the whole time. Dropping the old column is a
separate, later deployment, and it happens only after proving:

- no application version reads the old column
- no application version writes it (query logs, code search, statement stats)
- the backfill completed — zero rows where new is null but old isn't
- the new column's data is valid (verification queries, not the migration's exit code)
- the rollback window has expired

Put a date on the cleanup when you start. "Temporarily" without an owner and a deadline is how
databases fill with dual columns nobody dares touch — the pattern's cost is only temporary if
someone actually contracts.

## The full sequence

Each numbered item is an independent deployment with its own rollback story:

1. **Expand**: add `DisplayName` (nullable). — *Rollback: drop it; nothing uses it.*
2. **Migrate (code)**: dual-write, read-with-fallback. — *Rollback: redeploy v1; compatible both
   ways.*
3. **Migrate (data)**: batched idempotent backfill. — *Rollback: none needed; it only fills
   nulls.*
4. **Contract (code)**: read/write only `DisplayName`. — *Rollback: redeploy step 2's version
   any time inside the window.*
5. **Cleanup** (after window + verification): drop `FullName`. — *This is the only genuinely
   irreversible step, which is why it goes last and alone.*

The same skeleton handles type narrowing (new column with the new type, validate values as part
of the backfill), splitting or merging fields, changing units or meaning, and moving data across
tables. In each case the invariant is the same: at every step, every version in traffic can read
and write every row.
