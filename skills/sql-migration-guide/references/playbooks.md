# Playbooks

Worked sequences for the changes that come up most, the anti-patterns behind most migration
incidents, and the shape of a written plan. Everything here goes beyond the source article
except the rename, which is its running example. Each numbered step is its own deployment or
operation unless it says otherwise.

## Contents

- Rename a column
- Add a `NOT NULL` column
- `INT` to `BIGINT` primary key
- Add an enum value
- Remove an enum value
- Narrow a column
- Add a unique constraint
- Change a column's meaning or units
- Split a table
- Purge or retention delete
- Anti-patterns
- A written migration plan
- Review rules

## Rename a column

See expand-migrate-contract for the full table. Add the new column, dual-write and read with
fallback, backfill, verify, switch to new-only, wait out the window, drop the old. Never one
statement.

## Add a `NOT NULL` column

1. Add it nullable: `ADD COLUMN x TEXT NULL`.
2. Deploy code that always writes it.
3. Backfill existing rows in batches.
4. PostgreSQL: `ADD CONSTRAINT x_nn CHECK (x IS NOT NULL) NOT VALID`, then `VALIDATE
   CONSTRAINT x_nn`, then `SET NOT NULL`, which skips the scan. MySQL: `MODIFY ... NOT NULL`
   rebuilds the table, so schedule it or use an online schema change tool on large tables.
   Verify zero `NULL`s first: `gh-ost` and `pt-online-schema-change` copy rows with `INSERT
   IGNORE`, which turns a leftover `NULL` into the column's implicit default instead of failing.
5. Optionally drop the redundant check.

`ADD COLUMN x NOT NULL DEFAULT 'unknown'` in one step is only acceptable if a table full of
`'unknown'` written by old pods is genuinely fine.

## `INT` to `BIGINT` primary key

An in-place type change rewrites the table and every referencing index and foreign key, under
a long exclusive lock in PostgreSQL and a blocking copy in MySQL. Instead: add `id_new
BIGINT`, keep it in sync with a trigger, backfill in batches, build a unique index
concurrently, migrate foreign keys one child table at a time, swap in a short transaction. Or
use a table-level tool. Budget weeks, and start well before the sequence nears `INT` max,
because the safe path needs runway.

## Add an enum value

Readers first. Ship tolerant readers that map unknown values to a safe fallback and log, wait
for the full rollout and the rollback window, then let writers produce the value behind a flag.
In PostgreSQL, `ALTER TYPE ... ADD VALUE` is cheap, but the compatibility risk is in the code,
not the DDL.

## Remove an enum value

Stop writing it, migrate existing rows, verify none remain, then remove it. Slower than adding,
because existing rows still carry the value.

## Narrow a column

Do not narrow in place. Measure first: `SELECT count(*) FROM t WHERE char_length(col) > 20`.
MySQL's `length()` counts bytes, not characters. What happens to rows that do not fit is a
product decision. Capture their pre-images, transform them explicitly, and enforce the new
limit with `CHECK (char_length(col) <= 20)`. Consider the type change only afterwards, if at
all: the check gives the enforcement without irreversible truncation.

## Add a unique constraint

Assume duplicates exist. Find them, agree the merge or delete rule as a product decision,
record pre-images, resolve them, `CREATE UNIQUE INDEX CONCURRENTLY`, then attach the
constraint with `USING INDEX`. Old code that can create duplicates must be gone first, or its
writes start failing.

## Change a column's meaning or units

Add a new column with the new meaning, such as `amount_cents` beside `amount`. Dual-write,
backfill with the conversion, verify, move readers, contract. Never convert in place: mixed
rows become undecodable and both versions stay confidently wrong.

## Split a table

Table-level expand-contract: create the new tables, mirror writes, backfill, shadow-read for
parity, move reads behind a flag, soak, contract. Expect weeks and give it its own plan.

## Purge or retention delete

Archive first (`INSERT INTO archive_x_202608 SELECT ...`), delete in bounded batches, verify
counts on both sides, keep the archive for a stated period. An unbounded `DELETE` with no
archive is the most regretted statement in this guide.

## Anti-patterns

- **"We will just run the down migration."** For anything that touched data, you will not.
- **`DROP COLUMN` in the same PR as the code that stopped using it.** Guarantees the old-code,
  new-schema break during rollout.
- **One `UPDATE` over a huge table.** Locks, bloat, replica lag, and no way to stop halfway.
- **Backfill with `OFFSET` pagination.** Slower every batch, may never finish.
- **Migrations at app boot with many replicas and no advisory lock.**
- **A flag that only gates the UI** while the write path already changed.
- **Repurposing a column's meaning.** Undetectable and unfixable.
- **A non-concurrent index build on a large hot table.** Writes blocked for the duration.
- **A cleanup PR months later by someone who was not there**, with no record that the drop
  preconditions were checked.
- **An ad-hoc production `UPDATE` during an incident** with no count, no transaction, no
  pre-image and no record.
- **Trusting "migration completed" as evidence** that the data is right.

## A written migration plan

Non-trivial migrations get a short plan attached to the pull request, under six headings:

1. **The change:** what, on which tables, at what current size.
2. **Risks:** availability, compatibility and reversibility, with the reasoning.
3. **Steps:** every deploy and DDL in order, with who runs what, the expected lock and
   duration, and the code versions live during each.
4. **Verification:** the queries and their expected results, per step.
5. **Recovery:** what "wrong" looks like per step, how it is detected, the response and
   rollback target, and the evidence source with its retention.
6. **Cleanup:** the destructive step, its preconditions, and its earliest date.

If it does not fit half a page, the migration is not understood well enough to run.

## Review rules

- Destructive DDL (`DROP`, `TRUNCATE`, narrowing, `DELETE` without a bounded predicate) gets a
  second reviewer with database context.
- The reviewer checks the three risks and the reachable states, not SQL style.
- When ordering matters, the PR structure shows it: migration and application code split so
  the sequence is visible.
- Coordinate in-flight migrations. Two heavy migrations on one table, or a backfill during
  another team's batch window, is a self-inflicted incident. Each migration has an owner who
  stays reachable through its rollback window.
- The safe path loses when it is more work than the unsafe one. Linters, templates and a
  generator for the expand-contract skeleton keep it cheap.
