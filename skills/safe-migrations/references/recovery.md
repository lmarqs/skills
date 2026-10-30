# Recovery: flags, compensating migrations, and the evidence they need

Compatibility staging protects the schema transition. This reference covers the rest: keeping a
kill switch that doesn't touch the schema, repairing data when prevention failed, and the
observability that makes either possible.

## Separate deployment from release

For large or destructive changes, deploying code and activating behavior should not be the same
moment. The safer sequence:

1. Deploy the schema change (expanded, compatible).
2. Deploy the new code **dark** — behind a feature flag, default off.
3. Enable for a small slice of traffic (canary); inspect the writes it produces.
4. Widen the rollout; keep watching.
5. Only then treat the release as live.

The flag is a recovery path that requires **no database revert**: if error rates rise after
activation, disable the feature and both code and schema stay in place while you investigate.

Two constraints keep flags honest:

- **A flag must respect the compatibility rules.** Flipping it on must not let v2 write values v1
  can't read while v1 is still in traffic — the flag changes *when* the risk activates, not
  whether the change was classified correctly.
- **Flags don't fix data that is already wrong**, and they become debt when left in place. Give
  each migration flag the same cleanup deadline as the old column it protects.

## When rollback is no longer enough

Suppose a migration computes the wrong balance for two million accounts. Redeploying the old
application stops *new* bad writes; it repairs nothing. The recovery ladder, safest first:

**1. Compensating migration** — a new *forward* operation that corrects the known error:

```sql
UPDATE Accounts a
SET    Balance = <recomputed correct value>
WHERE  a.MigratedAt >= '<migration start>'
  AND  <predicate identifying the affected rows>;
```

This works when you can identify the affected records and reconstruct the correct value from data
still present — original columns kept by an Expand phase, audit history, event logs. It is the
strongest argument for delaying destructive cleanup: the old column you didn't drop is the source
of truth that makes the repair a one-statement job.

**2. Dig into secondary sources** when the live data no longer holds the answer: transaction
logs / WAL, change-data-capture streams, snapshots, backups, point-in-time recovery.

**3. Restore-aside-and-repair, not restore-over.** A full restore to a pre-migration point also
destroys every *valid* order, signup, and update written since — it converts a partial data bug
into a total data loss for the interim period. Instead: restore the backup into a **separate
environment**, extract only the missing or correct values, and repair only the affected rows in
production. Reserve in-place point-in-time restore for the case where essentially all
post-migration writes are worthless.

Whichever rung you use, the repair job is a backfill and inherits the backfill contract:
idempotent, restartable, bounded, observable, pausable.

## Observability: leave evidence before you need it

Recovery succeeds fast when the migration recorded what it changed. "Completed" / "failed" is not
enough for an operator at 11 PM.

**While a schema migration runs**, watch: execution time, locks held, blocked queries,
replication lag, application error rates.

**For a backfill**, track and expose: total rows, processed rows, remaining rows, failed rows,
retry count, processing rate. (These six also tell you whether "pause" is safe and "resume" is
working.)

**Verification queries, not exit codes.** The success message proves the statement ran, not that
the data is right. Write the checks alongside the migration:

```sql
-- backfill converged?
SELECT COUNT(*) FROM Customers WHERE DisplayName IS NULL AND FullName IS NOT NULL;

-- new data valid? (whatever "valid" means for the change)
SELECT COUNT(*) FROM Customers WHERE DisplayName = '' OR LENGTH(DisplayName) > 100;

-- old column really unused? (engine-specific: query stats, logs, code search)
```

**Mark what you touch.** Where practical, have migrations and backfills stamp affected rows
(`MigratedAt`, a batch id) or log affected key ranges. That stamp is what turns "two million
accounts, somewhere" into a `WHERE` clause for the compensating migration.

The through-line of all of it: you cannot make every change reversible, but you can keep recovery
options open — backward-compatible steps, staged data migration, destructive cleanup delayed
until the new version has proven itself, and enough evidence to repair what does go wrong. The
safest rollback is the one planned before anyone clicked Deploy.
