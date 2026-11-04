# Classifying a change

The unit of risk is the statement *plus* the deployment window in which old and new code
share the database. Classify every change on availability, compatibility and reversibility
before deciding how many deployments it needs. Headings marked *(beyond the article)* extend
the source article.

## Contents

- The state matrix
- Compatibility per change
- Reversibility classes and the pre-image rule
- Why timing changes the answer
- Never repurpose a column
- Tolerant readers
- Classifying a diff

## The state matrix *(beyond the article)*

"Backward compatible" is too vague to design against. List the code-version × schema-version
cells the system can actually occupy and require every reachable one to work.

| | Schema S0, before | Schema S1, after |
|---|---|---|
| **Code v1** | the steady state you leave | reachable while the migration runs ahead of the deploy, through the whole rollout, and for the whole rollback window |
| **Code v2** | reachable if the migration fails midway, the runner is slower than the rollout, a canary starts early, or someone reverts DDL without reverting code | the steady state you head to |

The two off-diagonal cells are the ones people forget. The (v1, S1) cell lasts as long as
rollback to v1 must stay possible, not just for the rollout.

**The N-1 rule:** every schema state works with the deployed version and with the version you
would roll back to. Every application version tolerates the schema before and after its own
migration.

## Compatibility per change

"Old code" is the version you would roll back to.

| Change | Old code survives? | Notes |
|---|---|---|
| Add table | yes | Invisible to old code. |
| Add nullable column, no default | yes | Only if old code never does `INSERT` without a column list or `SELECT *` into a strict struct. |
| Add column with a constant default | yes | Availability depends on engine and version. See operational-mechanics. |
| Add `NOT NULL` column without default | **no** | Old code's inserts fail at once. |
| Add `NOT NULL` column with default | conditional | Old inserts succeed carrying a default that means nothing. Silent data-quality damage. |
| Add index | yes | Compatibility-safe. Availability risk unless built concurrently or online. |
| Add `UNIQUE`, `CHECK` or `FOREIGN KEY` | conditional | Old code may write rows that violate a rule it does not know. Existing rows may already violate it. |
| Widen a type (`VARCHAR(20)` to `(100)`, `INT` to `BIGINT`) | conditional | Old drivers, DTOs or client-side types may not fit the new range. |
| Narrow a type | **no, and lossy** | PostgreSQL and strict-mode MySQL reject it if any value is too long, so it fails mid-deploy. Non-strict MySQL, or a `USING substr(...)`, truncates silently, and widening back restores capacity, not characters. Old code writing long values starts failing either way. |
| Rename column or table | **no** | Breaks old code the instant it commits. |
| Drop column or table | **no, and lossy** | Breaks old code and is irreversible. |
| Change a column default | conditional | Old and new code disagree about what "unset" means. |
| Add enum value or status string | conditional | Writers must wait until every reader tolerates it. |
| Remove enum value | **no** | Existing rows still carry it. |
| Make a nullable column `NOT NULL` | conditional | Old code writing `NULL` starts failing. Needs a completed backfill first. |
| Change meaning without changing shape | **no, silently** | The worst case. See below. |
| Split or merge tables | **no** | A migration project, not a migration. |
| Backfill or transform values in place | conditional to lossy | Compatibility depends on the transform. Reversibility is gone unless pre-images exist. |

## Reversibility classes and the pre-image rule *(beyond the article)*

| Class | Meaning | Examples | What you owe |
|---|---|---|---|
| **R0 free** | Undo restores the exact prior state | add table, column or index; add a `NOT VALID` constraint | Nothing. |
| **R1 costly** | Undo works but is slow or expensive | table rewrite, index rebuild, a recorded large backfill | A tested undo path and a time estimate. |
| **R2 needs evidence** | The information exists elsewhere | drop of a backfilled column, a transform with an audit trail | A named, verified evidence source and its retention. |
| **R3 destroys** | Undo is impossible in principle | drop of unbacked data, `TRUNCATE`, truncating narrowing, field merge, in-place hashing, dedup, purge | Capture the pre-image, or do not ship it. |

**Pre-image rule:** an R3 change writes the information it is about to destroy somewhere
durable, in the same migration, before the destructive statement.

```sql
CREATE TABLE mig_2026_08_10_price_rebase_backup (
  order_id    BIGINT PRIMARY KEY,
  old_amount  NUMERIC(12,2) NOT NULL,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO mig_2026_08_10_price_rebase_backup (order_id, old_amount)
SELECT id, amount FROM orders WHERE currency = 'BRL';
```

This turns R3 into R2 for the cost of one table dropped months later. It makes a later repair
a mechanical `UPDATE ... FROM backup` instead of forensics. For deletes, archive first:
`INSERT INTO archive_<table>_<date> SELECT * FROM <table> WHERE <purge predicate>`.

## Why timing changes the answer

The article's sharpest line: *the SQL statement alone does not determine the risk.* The same
`ADD COLUMN ... NOT NULL DEFAULT 'x'` is:

- safe in a maintenance window with the app stopped;
- safe in a rolling deploy if old code never inserts and new code always supplies a value;
- a silent data-quality incident when old pods keep inserting rows that inherit a default
  nobody meant;
- an outage on a huge table on an engine version that rewrites the table to apply it.

During a rolling deploy both versions serve traffic. v1 keeps inserting old-shaped rows, so a
new required column or constraint fails them. v2 starts writing values v1 cannot interpret, so
v1 breaks with no DDL change at all: **compatibility is a property of the data, not just the
DDL.** The window lasts as long as rollback to v1 must stay possible.

Ask both questions, in order. Can v1 run against the new schema? Can v1 read and write every
value v2 will produce? Both must be yes for a one-step change.

## Never repurpose a column *(beyond the article)*

Changing what a column means while keeping its name and type is the one class where no tool
flags it, no type checker catches it, no test fails, and both versions confidently produce
different answers. Examples: `amount` switching from cents to units, `created_at` from local
time to UTC, a boolean reused for a second purpose. Reversibility dies as soon as mixed rows
exist, because nobody can tell which convention a row follows.

A change in meaning is a new column: add `amount_cents` beside `amount`, backfill, move
readers, contract. When a new column is truly impossible, add a discriminator such as
`amount_version SMALLINT` so mixed rows stay decodable.

## Tolerant readers *(beyond the article)*

Readers that do not break on unknown values are the cheapest long-term defense. An unknown
enum maps to a safe fallback and logs. An unknown JSON field is ignored. A missing optional
column takes a default. Ship the tolerant reader one release before it is needed. It turns a
class of "v2 wrote something v1 cannot read" incidents into a log line.

## Classifying a diff

- Classify each statement, then the set. Two compatible statements can combine into a
  breaking pair, such as a nullable column plus code that assumes it is populated.
- Read the application code in the same diff. A migration and the code that stops using a
  column in one PR guarantees the (v1, S1) break during rollout.
- Flag anything lossy first and separately. Ask where the original values live during the
  transition. "We checked, nothing is that long" is a claim to verify with a query, not a
  premise.
- Check what the down migration actually restores. A `down` that drops a column v2 already
  wrote into is itself a destructive migration.
- Ask how the app deploys. Blue/green with instant cutover and no rollback window has a
  smaller risk surface than an hour-long rolling deploy, but not an empty one.
- Check availability per statement against the table size and engine version. See
  operational-mechanics.
