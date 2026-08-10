# Source: "Safe Database Rollback Starts Before Deployment"

Raul Junco — *System Design Classroom*, 25 Jul 2026.
Subtitle: *How to deploy schema changes without painting yourself into a corner.*

This file is a faithful distillation of the source, kept separate from
`knowledge-base.md` so that "what the article actually says" stays distinguishable from
"what we added". Nothing here is an addition; bracketed notes mark the few places where
content lived in an image that did not travel with the HTML export.

---

## Thesis

> Application rollback != database rollback.
> Code is replaceable, but production data keeps changing after every deployment.
> That is why safe database rollback starts before deployment, when you decide how the old
> code, new code, and the changing schema will coexist.

The framing scenario: v2 ships a schema change, the migration succeeds, traffic hits v2,
users create records in the new structure. Ten minutes later a critical bug appears. The
obvious response — redeploy v1 — fails, because v1 may no longer understand the schema and
the database may already hold values the old code cannot process.

Everyone documents *how to migrate*; almost nobody documents *what happens when the deploy
fails after the migration already changed production data*.

## Section by section

### 1. Why database rollback is hard

Rolling back code means swapping a binary or image. The database is different because it
holds persistent state: redeploying the old application does not undo new orders, updated
profiles, processed messages, or records created after the release.

Worked example — a column rename [SQL in image: `ALTER TABLE Customers RENAME COLUMN
FullName TO DisplayName`]. Migration succeeds; v2 then turns out to have a bug unrelated to
the database; you redeploy v1, which still queries `FullName`. Old app and database are each
individually valid, but no longer compatible with each other.

Worse when the migration changes *values* rather than names: restoring the old schema does
not restore the old data.

### 2. Schema rollback is not data rollback

Migration frameworks teach `up` → apply change, `down` → reverse change. That model works
for simple development workflows; the author explicitly refuses to rely on it in production
— "it is totally unreliable in production."

Two examples of the failure:

- **Loyalty tier.** A release adds a `LoyaltyTier` column [image]; the app writes `Silver`,
  `Gold`, `Platinum`. The `down` migration drops the column [image]. The schema returns to
  its original shape, and every loyalty value is gone forever — and when you roll forward
  again, customers have to redo the whole process. *This can happen silently and you never
  notice.*
- **Narrowing a type.** `VARCHAR(100)` → `VARCHAR(20)`. If the migration truncates longer
  values, widening back to `VARCHAR(100)` does not restore the missing characters.

Same risk when you merge fields, delete records, convert free text into enums, or rewrite
identifiers. Generalized: *once a migration discards information, rollback cannot reconstruct
it unless you have another source of truth (logs, snapshots, CDC, etc.).*

**The reframe** — the article's pivot point:

> Instead of trying to answer "Can I reverse this SQL?" we should be focused on:
> **"Can both application versions work with every intermediate database state?"**

### 3. Classify changes by risk

Some schema changes preserve compatibility; others remove rollback options immediately.
Adding a nullable column usually lets the old version keep running because it ignores the new
field. Dropping or renaming a column can break the old version as soon as the migration
finishes. [A compatibility table lived in an image here.]

> The SQL statement alone does not determine the risk. Deployment timing matters too.

- Adding a *required* column looks harmless, but during a rolling deployment v1 keeps
  inserting rows without that value while v2 already expects it.
- Enum changes are the same shape of problem: v2 writes `PendingReview` while v1 only
  understands `Pending`, `Approved`, `Rejected`. The schema is fine; the old code can no
  longer interpret the data.

Rule that follows: **when a change breaks compatibility, do not perform it in one deployment
— split it into stages using Expand, Migrate, Contract.**

### 4. Expand — Migrate — Contract

> The whole idea is to turn one breaking change into several compatible changes.

Renaming `FullName` → `DisplayName`, staged:

- **Expand.** Add the new column without removing the old one [image]. The database now
  supports both versions; v1 keeps using `FullName`.
- **Migrate.** Deploy code that writes to both columns:
  ```
  customer.FullName    = request.Name
  customer.DisplayName = request.Name
  save(customer)
  ```
  Reads prefer the new value and fall back to the old one:
  ```
  name = customer.DisplayName ?? customer.FullName
  ```
  Then backfill existing rows so the fields are in sync. **For large tables, process records
  in batches rather than one long transaction** — don't keep the DB so busy it can't serve
  customer orders. Track progress and make each batch safe to rerun.
- **Contract.** Deploy a version that reads and writes only `DisplayName`. **Do not drop
  `FullName` immediately.** Keep it within a defined *rollback window* — "the period after
  deployment when you feel safe to call it done" — so the previous version can still run.
  Remove it later, in a **separate deployment**, after proving no code reads or writes it.

The article flags the cost in bold: you keep both fields *temporarily*, "so you don't forget
and end up with a DB full of technical debt." The pattern "trades one risky change for
several smaller, recoverable steps."

### 5. Separate deployment from release

For large and destructive schema changes, deploying code and enabling a feature should not
happen at the same moment. [Sequence diagram in image: deploy → migrate → enable flag.]

A feature flag gives a recovery option that does not require reverting the database. If v2's
new checkout flow writes extra payment metadata and error rate rises after activation, you
disable the feature and leave code and schema in place. It also enables canary releases —
enable for a small traffic percentage, inspect the new writes, then expand.

Two caveats the author insists on:

- Flags "don't fix data that is already wrong, and they create cleanup work if teams leave
  them in place forever." They reduce the number of incidents needing emergency rollback;
  they are not a cure.
- **A flag must still respect the compatibility rules**: the flag must not let v2 write
  values v1 can't read while v1 is still in traffic.

### 6. Design transitional logic for failure

> Temporary migration code often looks safer on a diagram than it behaves in production.

- **Dual writes.** Same database, single transaction → you usually get atomicity. Across
  services or databases → "a different animal": treat the migration like any other
  distributed consistency problem. If the two writes span separate tables, databases, or
  services, one may succeed while the other fails, and you have created a consistency problem
  instead of solving a migration problem.
- **Backfills.** A worker may time out after completing a batch and then retry the same
  records; two workers may process overlapping ranges. A production backfill must be:
  **idempotent · restartable · processed in bounded batches · observable · safe to pause.**
  [Example SQL in image; the article notes "the final condition makes repeated execution
  safer because already-migrated rows remain unchanged" — i.e. a `WHERE new_col IS NULL`-style
  guard.]
- **Rolling deployments.** Both versions may run at the same time. The new version must not
  write values the old version cannot understand until v1 has fully left production.
  *Compatibility must hold during every intermediate state, not only before and after.*

### 7. When rollback is no longer enough

If a migration computes the wrong balance for two million accounts, redeploying the old
application stops new bad writes but does not repair existing values.

- **Compensating migration** — "a new forward operation that corrects the known error."
  Works when you can identify affected records and reconstruct the correct value from
  existing data, audit history, or another source of truth.
- When the original information is gone: transaction logs, change data capture, snapshots,
  backups, point-in-time recovery.
- **Be careful with full database restores; the author rarely recommends them.** Restoring to
  a point before the migration also removes valid orders and updates created afterwards. The
  safer approach: restore the backup into a **separate environment**, extract the missing
  data, and repair only the affected records in production.

> Recovery succeeds faster when the migration leaves enough evidence to show what changed.

### 8. Making a migration observable

A migration that reports only "completed" or "failed" gives operators too little information.

- **Schema changes:** monitor execution time, locks, blocked queries, replication lag, error
  rates.
- **Backfills:** track total rows, processed rows, remaining rows, failed rows, retry count,
  processing rate.
- **Verification queries.** The success message when the SQL command completes does not prove
  the resulting data is correct.

Before dropping an old column, confirm all five:

1. No application version reads it
2. No application version writes it
3. The backfill completed
4. The new field contains valid data
5. The rollback window expired

> Observability and verification are what turn your assumptions into an evidence-based decision.

### 9. Pre-deployment checklist

Ten questions, to be answered *before* production, not during a fire:

1. Can the previous application version run against the new schema?
2. Can old and new instances run at the same time?
3. Does the migration delete or transform information?
4. Can the migration run safely more than once?
5. Can a large backfill stop and resume?
6. How will we verify the resulting data?
7. Can we disable the new behavior without reverting the schema?
8. What is the recovery path if the data becomes incorrect?
9. When will destructive cleanup happen?
10. Are there other concurrent migrations or releases that could interact with this one?

> A migration should not reach production until the team can answer these questions.
> Sometimes it will fail no matter what, but your goal is to avoid having to invent a
> recovery plan during the incident.

### 10. Closing

> You cannot make every database change reversible. But you can keep your recovery options
> open because they save data and jobs. Use backward-compatible changes, migrate data in
> stages, and delay destructive cleanup until you know the new version is stable.
> **The safest rollback is the one you planned before deployment.**

---

## Notes on fidelity

- All SQL snippets, the compatibility table, the deploy/release sequence diagram, the
  Expand-Migrate-Contract timeline, the backfill example and the compensating-migration
  example were **images** in the HTML and are not recoverable from the export. Their content
  is inferable from the surrounding prose and is reconstructed — clearly as reconstruction —
  in `knowledge-base.md`.
- The sponsor block (Tiger Data / TimescaleDB 2.27) and the AWS-bill aside are promotional /
  anecdotal and carry no technical claims relevant to the skill.
