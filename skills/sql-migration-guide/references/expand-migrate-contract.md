# Expand – Migrate – Contract

The pattern turns one breaking change into several compatible changes, each deployable and
reversible on its own. It costs temporary complexity, two columns, dual-write code and a
backfill job, and buys a rollback option at every step. Headings marked *(beyond the article)*
extend the source article.

## Contents

- The sequence, with reachable states
- Gates between phases
- Rolling back mid-pattern
- Dual writes: three implementations
- Dual writes across stores
- Read migration and shadow reads
- Contract discipline
- Table-level expand and contract

## The sequence, with reachable states

Running example: rename `full_name` to `display_name`. Each row is a separate deployment or
operation.

| Step | Action | Code live | Why every state works |
|---|---|---|---|
| **E1 Expand** | `ALTER TABLE customers ADD COLUMN display_name TEXT NULL` | v1 | v1 ignores a nullable column it never selects |
| **M1 Dual-write** | Deploy v2: writes both columns, reads `display_name ?? full_name` | v1 + v2 | v1 rows have only `full_name`, which v2's fallback covers. v2 rows have both, so v1 reads `full_name` fine |
| **M2 Backfill** | Fill `display_name` from `full_name` in batches, guarded by `display_name IS DISTINCT FROM full_name` | v2, rollback to v1 still safe | Both columns converge, including rows v1 updated after v2 had written them. No reader depends on completion |
| **M3 Verify** | `count(*) WHERE display_name IS DISTINCT FROM full_name` returns 0 | v2 | Evidence gate |
| **M4 Relax old** | `ALTER TABLE customers ALTER COLUMN full_name DROP NOT NULL`, if it was required | v2 | Both versions still write it. Without this, v3's inserts fail |
| **C1 Contract code** | Deploy v3: reads and writes `display_name` only | v2 + v3 | v2 already prefers `display_name`, so v3's single-column rows read correctly |
| — | Rollback window: soak and change nothing | v3 | v2 is the rollback target now. v1 is not |
| **C2 Cleanup** | Separate deploy: `ALTER TABLE customers DROP COLUMN full_name` | v3 | v3 never touches it |

The new column is nullable or defaulted. Requiring it would break v1's inserts, the exact
failure the pattern exists to prevent.

Two things the table makes visible *(beyond the article)*:

- **The rollback target moves.** After C1, "roll back one version" means v2, not v1. A plan
  that says "we can always roll back" usually means v1 and is wrong from C1 on.
- **Reads prefer the new column from the first dual-writing release.** Otherwise C1 breaks the
  still-running v2. The fallback order is load-bearing.
- **The fallback hides v1's updates.** While v1 and v2 overlap, v1 updates `full_name` on rows
  v2 already wrote, and v2 keeps serving the stale `display_name`. The backfill must re-sync
  every row where the columns differ, not only rows where `display_name IS NULL`. A trigger
  avoids the problem.

**The ordering rule** behind every row: additive DDL before the code that uses it, destructive
DDL after the last referencing code is gone plus the rollback window.

The same skeleton handles type narrowing, splitting or merging fields, changing units or
meaning, and moving data across tables. The invariant is always that every version in traffic
can read and write every row.

## Gates between phases *(beyond the article)*

Advance on evidence, not on the calendar.

| Gate | Do not proceed until |
|---|---|
| E to M | Expand DDL is applied in every environment and on replicas, with no lock incidents |
| M1 to M2 | The dual-write release runs on 100% of instances. Stragglers are the ones writing single-column rows |
| M2 to M3 | The backfill reports 0 remaining and 0 failed, and its checkpoint says complete |
| M3 to C1 | Verification passes on the primary and on the replicas the app reads from |
| C1 to C2 | The rollback window expired and every drop precondition holds. See verification-and-testing |

## Rolling back mid-pattern *(beyond the article)*

- **During Expand.** The new column is unused. Leave it rather than run a second DDL under
  stress.
- **During Migrate, the dual-write release is bad.** Roll back to v1. The old column is still
  complete and authoritative. Nothing is lost, which is why dual-write is worth its cost. Rows
  v1 updates from then on leave `display_name` stale, so the backfill re-syncs on difference.
- **During Migrate, the backfill is wrong.** Pause it. It only wrote the new column, so the
  old one is intact. Fix the transform and re-run it forward. Never reverse a backfill.
- **During Contract, v3 is bad.** Roll back to v2, which still writes both. That is why C1 and
  C2 are separate deploys.
- **After cleanup.** The pattern no longer protects you. Roll forward, see recovery.

At every point, rolling back exactly one release must be safe. A step that breaks that is
mis-sequenced.

## Dual writes: three implementations *(beyond the article)*

The article shows application dual writes. For two columns in one database there are better
options:

1. **Database trigger.** A `BEFORE INSERT OR UPDATE` trigger keeps both columns in sync for
   every writer, including batch jobs, admin consoles, other services and manual fixes. It
   adds a small per-write cost and one more object to drop at cleanup.
2. **Generated column.** `ADD COLUMN display_name TEXT GENERATED ALWAYS AS (full_name)
   STORED` in PostgreSQL 12+ needs no application change and cannot drift. It is read-only,
   so it covers only the read migration, and PostgreSQL 13+ converts it to a plain column with
   `ALTER COLUMN ... DROP EXPRESSION` at cutover. Adding a stored generated column rewrites the
   table, so it is an availability risk on large tables. Check for your engine and version.
3. **Application dual write.** Explicit and reviewable, but it covers only writers that go
   through that code path. The failure mode is a writer you forgot, found during Contract when
   the "converged" columns diverge.

Same database: let the database keep the columns in sync and use the application only for
values only it can compute.

## Dual writes across stores

Two writes in one transaction against one database are atomic. Across databases or services
they are not, and one write can succeed while the other fails. That is a distributed
consistency problem, not a migration detail. Use what exists for it:

- **Transactional outbox.** Write the row and an outbox record in one local transaction. A
  relay applies it to the other store, at least once, idempotently.
- **Change data capture.** Let the database log feed the second store, so the write path stays
  single-store.
- **One-way sync with reconciliation.** Accept eventual consistency and run a job that
  compares, repairs and emits a divergence metric.

Make the second write idempotent and keyed so retries converge.

## Read migration and shadow reads *(beyond the article)*

1. Read old.
2. Read new, fall back to old. Safe during the backfill.
3. **Shadow read.** Read both, serve old, emit a metric when they differ. Run it across the
   weekly and monthly cycles that produce odd rows.
4. Read new only, behind a flag, ramped by percentage, with the divergence metric still on.

A divergence rate that will not reach zero is a finding. It usually means an unknown writer or
an edge the transform misses: nulls, empty strings, unicode, rows from a long-dead system.

## Contract discipline *(beyond the article)*

The article bolds that both fields are kept *temporarily*, so the database does not fill with
debt. Make that structural:

- Open the cleanup ticket during Expand, with the drop statement, its preconditions and the
  earliest date. An expand change without one is incomplete.
- Name the debt in the schema: `COMMENT ON COLUMN customers.full_name IS 'DEPRECATED
  2026-08-10, drop after 2026-09-15, replaced by display_name'`. It outlives team turnover.
- Where possible, have CI refuse a `DROP` or `RENAME` without a matching deprecation older than
  the window.
- Track open expand-contract cycles as a number. The failure is never one forgotten column, it
  is twelve.

## Table-level expand and contract *(beyond the article)*

When column-level staging is too small, such as repartitioning, changing a primary key,
retyping a huge column or changing collation, apply the pattern one level up:

1. Create the new table with the target shape.
2. Mirror writes from the old table with triggers.
3. Backfill in throttled batches.
4. Verify parity with counts, checksums and sampled row comparison.
5. Swap in one short transaction: `ALTER TABLE t RENAME TO t_old; ALTER TABLE t_new RENAME TO
   t;`
6. Keep `t_old` through the rollback window, then drop it.

Online schema change tools automate this: `gh-ost` and `pt-online-schema-change` for MySQL,
`pgroll` and Reshape for expand-contract on PostgreSQL, `pg_repack` for reorganizing. Prefer a
tool over hand-rolling it. The sharp edges are trigger recursion, the cutover lock, foreign
keys pointing at the old table, and replication.
