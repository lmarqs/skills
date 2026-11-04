---
name: sql-migration-guide
description: >-
  Senior-engineer knowledge for changing a live SQL schema and its data without outages, broken
  rollbacks or silent data loss. Classifies every change on three risks (will it lock the table,
  can old and new code share every intermediate state, does the information survive), stages
  breaking changes with Expand–Migrate–Contract, designs batched idempotent backfills, sequences
  DDL against rolling deploys, and names the verification and recovery path before deploy. Use it
  whenever someone plans, writes or reviews a migration: ALTER TABLE, add/drop/rename a column,
  NOT NULL, a new index, constraint or enum value, type changes, splitting or merging columns or
  tables, backfills, data fixes, zero-downtime deploys, "will this lock the table", "is this
  migration safe", "can we roll this back", down migrations, or Flyway, Liquibase, Alembic,
  Django, Rails, Prisma or Knex migration files — even when nobody says "migration". Query and
  index performance belongs to sql-quality-check.
---

# SQL migration guide

Writing the SQL is the easy part of a migration. The experience lies in everything around it:
the minutes when old and new code share one database, the lock that queues every query behind
a three-millisecond `ALTER`, the backfill that runs fine on staging and starves production, the
column dropped a week before anyone noticed its values were the only copy. This guide records
that experience so the right call comes from knowledge instead of scar tissue.

Three facts sit under all of it:

- **The database is the one component that remembers.** Redeploying yesterday's binary does
  not undo today's writes. After a release that touched data there is no "back", only forward
  to something that works.
- **A `down` migration restores a shape, not information.** Once a migration drops, truncates,
  merges or rewrites values, only another source of truth brings them back. `down` is a
  development convenience. It is never the production recovery plan for a change that touched
  data.
- **The unit of risk is the statement plus its circumstances.** The same `ALTER TABLE` is
  harmless, an outage or a silent corruption depending on table size, engine version,
  deployment strategy and which code versions overlap for how long. Never judge from the SQL
  text alone.

## Three risks of every change

Classify each change on all three before writing it. They are independent: a change can be
fatal on one and harmless on the others.

| Risk | Question | How it fails |
|---|---|---|
| **Availability** | Can this run on a live table without blocking traffic? | Locks, table rewrites, replica lag, an outage *during* the migration |
| **Compatibility** | Can every code version in traffic work with every intermediate state? | The migration succeeds, then old pods error or misread new values |
| **Reversibility** | If this proves wrong, does the information still exist? | Silent, permanent loss discovered days later |

A `DROP COLUMN` is cheap to run and fatal on the other two. `UPDATE orders SET price = price *
1.1` keeps every shape intact, can hold a long transaction, and destroys the old prices unless
someone recorded them. A nullable column add is compatible and reversible, and on some engines
and versions it still rewrites the table.

## The compatibility contract

Two code versions share the database during every rolling deploy, and the previous version
must stay deployable for the whole rollback window. So the question is never "can I reverse
this SQL?" It is:

> **Can every application version in traffic work with every intermediate database state?**

Both directions matter. Old code must survive the new schema: it still inserts rows without
the new required column and still queries the renamed one. Old code must also survive the new
*data*: a new enum value or format written by v2 is unreadable to v1 even though the schema
never changed under it. A change that cannot satisfy this in one step is not risky, it is
**not deployable as one step**.

**The ordering rule** that keeps every state compatible: additive DDL ships before the code
that uses it. Destructive DDL ships after the last code that referenced the object is gone,
plus the rollback window. A migration and the code that stops using a column belong in
different deployments.

## Not deployable in one step

These always decompose into several deployments, usually with Expand–Migrate–Contract:

1. Rename anything: column, table, enum value.
2. Drop anything that deployed code still references.
3. Add a `NOT NULL` column with no sensible default, or tighten a nullable column.
4. Narrow a type or add a constraint that existing rows or old code may violate.
5. Change what a column means, its units or timezone, while keeping its name and type.
6. Move data between tables, split or merge columns, change a key's format.
7. Convert free text into a constrained domain such as an enum or lookup table.

## How to use this guide

Ask for what decides the answer before giving it: engine and version, table size and write
rate, how the app deploys and how long a rollout takes, who else reads the schema. Infer what
the context shows and say what you assumed. Lock behavior is version-specific, so ask the
engine version before giving lock advice.

A **plan** is a numbered sequence of deployments and operations. Each step names what runs,
which code versions are live during it, its lock and expected duration on a table that size,
how its success is verified, and which version is the rollback target if it goes wrong. The
destructive cleanup is its own last step with its preconditions and a date. A **review**
classifies each statement and the set together on the three risks. It leads with anything
that destroys information, names which version breaks during which window, and gives the
staged alternative. In both, the checklist's unanswered questions are findings. Keep schema
and identifier names verbatim.

## Pre-deployment checklist

A migration is ready when the team can answer all of these. The first ten are the article's.
The rest go beyond it.

1. Can the previous application version run against the new schema?
2. Can old and new instances run at the same time?
3. Does the migration delete or transform information? Where does the original live?
4. Can the migration run safely more than once?
5. Can a large backfill stop and resume?
6. How will we verify the resulting data, beyond the statement completing?
7. Can we disable the new behavior without reverting the schema?
8. What is the recovery path if the data becomes incorrect?
9. When will destructive cleanup happen, and what must be proven first?
10. Do other migrations or releases in flight interact with this one?
11. What lock does each step take, for how long on a table this size, and how do we abort?
12. If this destroys information, where is the pre-image and how long is it kept?
13. What else holds this shape: queues, caches, events, search indexes, mobile clients, ETL?
14. Has the previous release's test suite run against the new schema?

## References

Read the one that matches the question. Each stands alone.

- [`references/change-classification.md`](references/change-classification.md) — per-change
  compatibility table, reversibility classes and the pre-image rule, why timing changes the
  answer, repurposed columns, and how to classify a diff. Read it to classify any change.
- [`references/expand-migrate-contract.md`](references/expand-migrate-contract.md) — the
  pattern step by step with its gates, the moving rollback target, rolling back mid-pattern,
  dual-write options, shadow reads, contract discipline, and the table-level variant. Read it
  to stage a breaking change.
- [`references/operational-mechanics.md`](references/operational-mechanics.md) — locks, lock
  queues and online DDL for PostgreSQL and MySQL, ORM and connection-pool traps, replicas,
  bloat, migration runners, and the schema living outside the database. Read it for the
  availability risk of any step.
- [`references/backfills.md`](references/backfills.md) — the six backfill properties, a keyset
  batch template, checkpoints, throttling, failure handling, and sizing. Read it before writing
  any data migration or bulk update.
- [`references/verification-and-testing.md`](references/verification-and-testing.md) — what to
  monitor, verification queries, proving a column is unused before dropping it, the CI
  compatibility job, rehearsal, and linters. Read it to define "done" for each step.
- [`references/recovery.md`](references/recovery.md) — deployment versus release with feature
  flags, choosing between flag-off, rollback and roll-forward, compensating migrations,
  evidence sources and their retention, and restoring aside instead of over production. Read
  it to write a plan's recovery path.
- [`references/playbooks.md`](references/playbooks.md) — worked sequences for renames, `NOT
  NULL`, `INT` to `BIGINT` keys, enums, narrowing, unique constraints, table splits and purges,
  plus named anti-patterns and the shape of a written migration plan. Read it when the change
  matches a known case.

---

Grounded in Raul Junco's ["Safe Database Rollback Starts Before
Deployment"](https://newsletter.systemdesignclassroom.com/p/safe-database-rollback-starts-before-deployment)
(System Design Classroom), extended with operational practice. Each reference marks what goes
beyond the article.
