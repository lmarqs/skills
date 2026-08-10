# Classifying schema changes by compatibility

The unit of risk is not the SQL statement — it is the *combination* of the statement and the
deployment window in which old and new application versions share the database. Classify every
change before deciding how many deployments it needs.

## The three classes

**Compatible — old code keeps working, deploy in one step.**

| Change | Why it's safe |
|---|---|
| Add a nullable column | Old version ignores fields it doesn't select; inserts succeed without it |
| Add a new table | Nothing existing references it |
| Add an index (concurrently) | Semantics unchanged; watch locks and write amplification, not compatibility |
| Widen a type (`VARCHAR(20) → VARCHAR(100)`) | Every old value remains valid |
| Add a column with a database-side default | Old inserts get the default — but see the timing caveat below |

**Conditionally compatible — safe only if the surrounding conditions hold. Verify, don't assume.**

| Change | Breaks when… |
|---|---|
| Add a `NOT NULL` column | …v1 is still inserting rows during the rollout and supplies no value. Needs a default, or nullable-first then tighten later |
| Add a new enum/status value | …v2 writes `PendingReview` while v1 — which only knows `Pending`, `Approved`, `Rejected` — is still reading. The schema is intact; the *data* is now unreadable by old code |
| Add a constraint (unique, check, FK) | …existing rows or in-flight v1 writes violate it. Validate against production data first; prefer `NOT VALID` + `VALIDATE` phases where the engine supports them |
| Backfill/transform values in place | …the transformation is lossy, or old code interprets the new representation differently |

**Breaking — the old version fails the moment the migration lands. Never one deployment.**

| Change | What breaks | Staged alternative |
|---|---|---|
| Rename a column/table | v1 queries the old name and errors immediately | Expand–Migrate–Contract (see its reference) |
| Drop a column/table | v1 reads/writes it; and the data is *gone* — no down migration recovers it | Stop using it first, drop after the rollback window |
| Narrow a type (`VARCHAR(100) → VARCHAR(20)`) | Truncation destroys information silently; widening back does not restore it | Add new column, validate/migrate values, contract |
| Change a column's meaning or units | Both versions "work" while silently corrupting each other's data — the worst case, because nothing errors | New column with the new meaning |
| Merge/split columns, rewrite identifiers | Original values unrecoverable once overwritten | Expand–Migrate–Contract with the originals kept |

## Why timing changes the answer

During a rolling deployment there is a window where **both versions serve traffic against one
schema**. A change that would be fine in an atomic all-at-once cutover can break in that window:

- v1 keeps inserting rows shaped the old way → a required-column or constraint addition fails
  those writes.
- v2 starts writing values v1 can't interpret (new enum members, new formats, new semantics) →
  v1 reads break *even though the schema never changed under it*. Compatibility is a property of
  the data, not just the DDL.
- The window isn't only the rollout. It lasts as long as rollback to v1 must remain possible —
  the rollback window. Until it expires, treat v1 as "in traffic".

So for every change, ask the two questions in order:

1. **Can v1 run against the new schema?** (schema compatibility)
2. **Can v1 read and write every value v2 will produce?** (data compatibility)

Both must be yes for a single-deployment change. If either is no, split it into stages where each
stage keeps both answers yes — that is exactly what Expand–Migrate–Contract does.

## Reviewing a diff

When classifying a migration in a PR:

- Classify each statement, then classify the *set* — two individually-compatible statements can
  combine into a breaking pair (add `NOT NULL` column + code that assumes it's populated).
- Flag anything lossy loudly and separately: information loss is not a compatibility bug you ride
  out, it is permanent. Ask where the original values will live during the transition.
- Check what the down migration actually restores. If it drops a column that v2 wrote data into,
  the "rollback" is itself a destructive migration — say so.
- Ask how the app is deployed. A team doing blue/green with instant cutover and no rollback
  window has a different (smaller, but not empty) risk surface than one doing hour-long rollouts.
