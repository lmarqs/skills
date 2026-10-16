---
name: safe-migrations
description: >-
  Plan, review, and stage database schema migrations so rollback stays possible after production
  data has changed — application rollback is not database rollback, and a down migration cannot
  restore information it discarded. The governing question is not "can I reverse this SQL?" but
  "can both application versions work with every intermediate database state?" Classifies changes
  by compatibility risk, splits breaking ones
  into Expand–Migrate–Contract with dual writes and batched idempotent backfills, separates
  deployment from release, delays destructive cleanup past a rollback window, and plans recovery
  (compensating migrations, not full restores) before deploying. Use it whenever someone writes or
  reviews a migration or ALTER TABLE diff, renames/drops/narrows a column, adds a NOT NULL column
  or enum value, plans a backfill or zero-downtime change, asks "is this migration safe?", or a
  bad migration already shipped. Query performance belongs to sql-quality-check; deployment and
  rollback safety belongs here.
---

# Safe migrations: rollback safety starts before deployment

Everybody knows how to migrate a database forward. The hard part is the moment a deployment fails
*after* the migration has already changed production data — the old code no longer understands the
schema, and the schema now holds values the old code cannot process. Two facts shape everything
this skill does:

- **Application rollback ≠ database rollback.** Code is replaceable; production data keeps
  changing after every deployment. Redeploying yesterday's binary does not undo today's writes.
- **Schema rollback ≠ data rollback.** The `up`/`down` migration model works in development and is
  unreliable in production. Once a migration discards information — a dropped column, a
  `VARCHAR(100) → VARCHAR(20)` truncation, merged fields, free text coerced into an enum,
  rewritten identifiers — the down migration restores the *shape* but the values are gone unless
  another source of truth exists. Often this loss is silent.

So the question to ask about any schema change is never *"can I reverse this SQL?"* It is:

> **Can every application version in traffic work with every intermediate database state?**

"In traffic" includes the rolling-deploy window where old and new versions run *simultaneously*,
and "intermediate" includes every state between the first migration step and the final cleanup.
Compatibility must hold at each of those points, not just before and after.

## How to work

You'll be in one of three modes — **planning** a schema change, **reviewing** a migration or PR
diff, or **responding** to a migration that already went wrong. The same method drives all three;
an incident just enters at step 3.

1. **Classify the change by compatibility, not by SQL syntax.** Read
   `references/compatibility.md`. Decide: can the previous app version run against the new schema,
   and can both versions run at once? The SQL text alone doesn't determine the risk — deployment
   timing does. Adding a `NOT NULL` column looks harmless until the still-running v1 inserts a row
   without it; a new enum value written by v2 is unreadable by the v1 still serving traffic. When
   the answer to either question is no, the change is breaking — never ship it as one deployment.

2. **Split breaking changes into compatible stages.** Read
   `references/expand-migrate-contract.md`. Expand (add the new alongside the old), Migrate
   (dual-write, read-new-fall-back-to-old, backfill in bounded idempotent batches), Contract
   (switch to the new, keep the old through a defined rollback window, drop it in a *separate,
   later* deployment only after verification). Transitional code must survive retries, partial
   failures, and overlapping workers — design it like the distributed-systems problem it is.

3. **Plan recovery and verification before anyone deploys.** Read `references/recovery.md`.
   Separate deployment from release with a feature flag so risky behavior can be switched off
   without touching the schema. Decide now how you'd repair wrong data — usually a *compensating
   forward migration*, almost never a full point-in-time restore, which destroys the valid writes
   made since. Make the migration observable enough that recovery has evidence to work from.

Gather context before judging: what's the table size and write rate? How is the app deployed
(rolling, blue/green, all-at-once)? Is there one consumer of this schema or many? Can this change
interact with other in-flight migrations? When a conclusion hinges on something you can't infer,
ask — a staged plan built on a wrong assumption is worse than a question.

## The pre-deployment checklist

A migration is ready for production when the team can answer all ten. Use these as the spine of
any plan or review — in a review, unanswered questions *are* the findings:

1. Can the previous application version run against the new schema?
2. Can old and new instances run at the same time?
3. Does the migration delete or transform information? (If yes: where does the original live?)
4. Can the migration run safely more than once?
5. Can a large backfill stop and resume?
6. How will we verify the resulting data is correct — not just that the SQL "completed"?
7. Can we disable the new behavior without reverting the schema?
8. What is the recovery path if the data becomes incorrect?
9. When will destructive cleanup happen, and what must be proven before it does?
10. Are there other concurrent migrations or releases that could interact with this one?

The goal is not to make every change reversible — you can't. It is to avoid inventing a recovery
plan during the incident.

## Output

Match the mode. A **plan** is a numbered sequence of deployments, each one compatible with the
versions in traffic during it, with the backfill contract, rollback window, verification queries,
and cleanup deployment spelled out. A **review** anchors findings to the offending statements:
name the compatibility class, the failure scenario (which version breaks, during which window),
and the staged alternative — lead with anything irreversible, since a lost-data finding outranks
every other. An **incident response** identifies what information was lost or corrupted, whether a
source of truth survives, and the compensating path — and says explicitly why a full restore is or
isn't on the table. In every mode, keep schema and identifier names verbatim; write the analysis
in English unless asked otherwise.

## References

- `references/compatibility.md` — the risk classification: which changes preserve compatibility,
  which conditionally, which break it; why deployment timing changes the answer; the rolling-deploy
  and enum traps. Read it when classifying any change (step 1).
- `references/expand-migrate-contract.md` — the three phases in detail with SQL and dual-write
  examples; the backfill contract (idempotent, restartable, bounded, observable, pausable); the
  rollback window; what to verify before dropping anything. Read it when staging a breaking change
  (step 2).
- `references/recovery.md` — separating deployment from release with flags (and their limits);
  compensating migrations; restore-aside-and-repair instead of full restores; the observability
  and verification queries that make recovery possible. Read it when planning recovery (step 3) or
  handling an incident.

---

Based on Raul Junco's ["Safe Database Rollback Starts Before
Deployment"](https://newsletter.systemdesignclassroom.com/p/safe-database-rollback-starts-before-deployment)
(System Design Classroom).
