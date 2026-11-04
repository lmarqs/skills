# Safe database change — knowledge base

Working notes for a future skill. Built from Raul Junco's *"Safe Database Rollback Starts
Before Deployment"* (distilled faithfully in [`source-article.md`](source-article.md)),
reorganized around a sturdier spine and extended with the parts the article leaves out.

Additions beyond the source are marked **[+]** in section headings so the provenance stays
auditable. Everything unmarked is the article's own argument, restated.

---

## 0. The essence in ten sentences

1. Rolling back code is swapping an image; rolling back a database is not, because the data
   kept changing after the release.
2. A `down` migration restores a *shape*, not the *information* the `up` migration destroyed.
3. So "can I reverse this SQL?" is the wrong question. The right one is **"can every
   application version that will be in production work against every intermediate database
   state?"**
4. **[+]** And a second right question the article never asks: **"can this change be applied
   to a live production table without locking it?"** — the most common way migrations cause
   outages is not incompatibility, it's the lock.
5. Risk is not a property of the SQL statement; it is a property of the statement *plus the
   deployment timing*. Rolling deploys mean old and new code run simultaneously, by design.
6. Any change that breaks compatibility gets split into several changes that don't:
   **Expand → Migrate → Contract**.
7. Deployment is not release: ship the code dark, turn behavior on with a flag, so recovery
   is a config change instead of a database operation.
8. Transitional code (dual writes, backfills) is where migrations actually fail — it must be
   idempotent, restartable, bounded, observable, and pausable.
9. When data is already wrong, rollback is not the tool; **roll forward with a compensating
   migration**, reconstructing truth from audit tables, CDC, logs, or a side-restored backup —
   never a full production restore, which would also erase everything valid written since.
10. All of this only works if the migration left evidence: metrics, counters, verification
    queries, and preserved pre-images. **The safest rollback is the one you designed before
    deployment.**

---

## Part I — The core argument

### 1.1 Application rollback ≠ database rollback

Code is stateless and replaceable. The database is the one component that *remembers*.
Redeploying v1 does not undo the orders, profile edits, processed messages and audit rows
that v2 wrote in the ten minutes it was live. Two consequences:

- After a failed release, the database is never in the state it was in before the release.
  There is no "back". There is only *forward to something that works*.
- A rollback plan that consists of "redeploy the previous image" is not a plan for anything
  that touched the schema or the data.

The canonical trap, in full:

| t | Action | State |
|---|--------|-------|
| 0 | `ALTER TABLE customers RENAME COLUMN full_name TO display_name` | schema v2, code v1 → **v1 is already broken** |
| 1 | Deploy v2 | working |
| 2 | Bug found (unrelated to the DB) | working but wrong |
| 3 | Redeploy v1 | v1 queries `full_name`, which no longer exists → **outage** |

Note where the breakage actually starts: at **t=0**, not t=3. The rename broke the running
system the instant it committed, and only luck (or a fast deploy) hid it.

### 1.2 Schema rollback ≠ data rollback

`up`/`down` migrations are a development-time convenience. In production the `down` direction
is a lie in every case where the `up` direction discarded information:

- Drop a `loyalty_tier` column and every `Silver`/`Gold`/`Platinum` value is gone. The schema
  matches the old definition; the customers do not have their tiers back. And when you roll
  forward again, they must earn them again.
- `VARCHAR(100)` → `VARCHAR(20)` truncates. Widening back to 100 restores capacity, not
  characters.
- The same applies to merging fields, deleting rows, free-text → enum conversions, identifier
  rewrites, in-place hashing, deduplication, unit conversions, rounding.

**Once a migration discards information, no `down` migration can reconstruct it.** Only
another source of truth can: an audit table, a pre-image you captured yourself, the WAL /
binlog, CDC, or a snapshot.

**[+] Where I'd nuance the article:** `down` migrations are not worthless. They are genuinely
useful for local development, for CI teardown, and for the *non-destructive* half of a
migration (dropping an index you just created, dropping a column you just added and nothing
has written to yet). The right rule is not "never write `down`" but:

> Write `down` for developer convenience. Never let it be the production recovery plan for a
> change that touched data.

### 1.3 The three risks of any database change **[+]**

The article treats "risk" as a single dimension (compatible vs breaking). In practice a change
carries three independent risks, and a change can be dangerous on one axis and harmless on the
others. Separating them is the single most useful reframing to add:

| Axis | Question | Failure mode | Mitigation family |
|------|----------|--------------|-------------------|
| **Availability** | Can this be applied to a live table without blocking traffic? | Locks, table rewrites, replication lag, I/O saturation — an outage *during* the migration | Online DDL, `lock_timeout` + retry, `NOT VALID` + `VALIDATE`, `CONCURRENTLY`, batching, shadow-table tools |
| **Compatibility** | Can every app version that will be running work against every intermediate state? | The migration succeeds and *then* something breaks — old pods 500ing, enum values nobody can read | Expand-Migrate-Contract, tolerant readers, deploy ordering, feature flags |
| **Reversibility** | If this turns out wrong, does the information still exist? | Silent, permanent data loss discovered days later | Pre-image capture, audit/undo ledgers, rollback windows, CDC/PITR retention |

A nullable column add: availability-risky on some engines/versions, compatibility-safe,
reversibility-safe. A `DROP COLUMN`: availability-cheap, compatibility-fatal,
reversibility-fatal. A `UPDATE ... SET price = price * 1.1`: availability-risky (long
transaction), compatibility-safe (shape unchanged), reversibility-fatal *if you didn't record
the old values* — and invisible, because nothing errors.

**Rule: classify every change on all three axes before writing the migration.**

### 1.4 The state matrix — what "compatible" actually means **[+]**

"Backward compatible" is too vague to design against. Make it concrete: enumerate the
(code version × schema version) cells the system can actually occupy, and require every
reachable cell to be green.

|  | schema S0 (before) | schema S1 (after) |
|---|---|---|
| **code v1** | ✅ the steady state you're leaving | ❓ **the cell everyone forgets** — reachable while the migration is applied ahead of the deploy, throughout a rolling deploy, and for the whole rollback window |
| **code v2** | ❓ reachable if the migration fails mid-way, if the deploy wins a race, or if you revert the migration but not the code | ✅ the steady state you're heading to |

Both `?` cells are *reachable*, not hypothetical:

- **(v1, S1)** is occupied for as long as the deployment takes — minutes in Kubernetes,
  potentially hours across regions — and for the *entire rollback window* afterwards, because
  the whole point of the window is that v1 must still be able to run.
- **(v2, S0)** is occupied if the migration fails partway, if the runner is slower than the
  rollout, if a canary pod starts before the migration finishes, or if someone reverts the
  DDL without reverting the code.

**The compatibility contract (the "N-1 rule"):**

> Every schema state must be compatible with the currently deployed application version *and*
> with the version you would roll back to. Every application version must tolerate the schema
> state before its migration and after it.

A change that cannot satisfy this in one step is not "risky" — it is **not deployable as one
step**, and must be decomposed.

### 1.5 Rolling deployments make coexistence mandatory, not optional

With `maxSurge`/`maxUnavailable`, blue-green cutovers, multi-AZ rollouts, or a client that
users must refresh, two versions in production simultaneously is the *normal case*, not an
edge case. Two corollaries:

- **v2 must not write values v1 cannot read**, until v1 is fully gone. New enum members, new
  status codes, new JSON fields with required semantics, new ID formats — all of these are
  "schema" for this purpose even when no DDL is involved.
- **v1 must not write rows v2 considers invalid.** This is the direction people forget: adding
  a `NOT NULL` column means old pods inserting without it will fail — or, if there's a default,
  will silently produce rows carrying a default that means nothing.

**[+] Tolerant reader principle.** The cheapest long-term defense is to write readers that do
not break on values they don't recognize: unknown enum → map to a safe fallback and log,
unknown JSON field → ignore, missing optional column → default. Deploy the tolerant reader one
release *before* you need it. This turns a whole class of "v2 wrote something v1 can't read"
incidents into a log line. It costs a release of lead time and buys you the ability to change
value domains without a full expand/contract cycle.

---

## Part II — Classifying changes

### 2.1 Compatibility classes

Reconstructed and extended from the article's table. "Old code" means the version you would
roll back to; "new code" means the version being deployed.

| Change | Old code survives? | Notes |
|---|---|---|
| Add table | ✅ | Invisible to old code. |
| Add **nullable** column, no default | ✅ | Safe *only if* old code doesn't `INSERT` without a column list and doesn't `SELECT *` into a strict struct. |
| Add column with a **constant** default | ✅ | Availability depends on engine/version (see §5.1). |
| Add column `NOT NULL` **without** default | ❌ | Old code's inserts fail immediately. Never do this in one step. |
| Add column `NOT NULL` **with** default | ⚠️ | Old code's inserts succeed but carry a meaningless default — silent data quality damage. |
| Add index | ✅ | Compatibility-safe, availability-risky unless `CONCURRENTLY`/online. |
| Add `UNIQUE` constraint | ⚠️ | Old code may legitimately create duplicates → its writes start failing. Also fails outright if duplicates already exist. |
| Add `FOREIGN KEY` | ⚠️ | Old code may insert orphans → failures; validation scans the table. |
| Add `CHECK` constraint | ⚠️ | Same shape: old code violates a rule it doesn't know about. |
| Widen a type (`VARCHAR(20)`→`(100)`, `INT`→`BIGINT`) | ⚠️ | Old code may truncate/overflow on read or in its own types; old *clients* (drivers, DTOs) may not fit the new range. |
| **Narrow** a type | ❌❌ | Breaks compatibility *and* destroys data. |
| Rename column/table | ❌ | Breaks old code the instant it commits. Always expand/contract. |
| Drop column/table | ❌❌ | Breaks old code *and* is irreversible. |
| Change a column's default | ⚠️ | Affects only new inserts; old and new code disagree about what "unset" means. |
| Add enum value / new status string | ⚠️ | Writers must wait until every reader tolerates it. |
| Remove enum value | ❌ | Existing rows still carry it. |
| Make a nullable column `NOT NULL` | ⚠️ | Old code that writes `NULL` starts failing; needs a completed backfill first. |
| Change semantics without changing shape (units, timezone, meaning) | ❌❌❌ | The worst case: nothing errors, nothing is detectable, and both code versions are confidently wrong. See §2.4. |
| Split one table into two / merge two into one | ❌ | A migration project, not a migration. |
| Backfill/transform existing values | ⚠️→❌❌ | Compatibility depends on the transform; reversibility is usually gone unless you captured pre-images. |

Legend: ✅ safe · ⚠️ conditionally safe — depends on timing, defaults, and what old code does ·
❌ breaks compatibility · ❌❌ also destroys information.

### 2.2 Reversibility classes **[+]**

| Class | Meaning | Examples | What you owe |
|---|---|---|---|
| **R0 — free** | Undo restores the exact prior state | add table/column/index, add `NOT VALID` constraint | Nothing. |
| **R1 — reversible with cost** | Undo is possible but expensive or slow | table rewrite, index rebuild, large but recorded backfill | A tested undo path and a time estimate. |
| **R2 — reversible only with external evidence** | The information exists somewhere else | drop of a backfilled column, value transform with an audit trail | A named, verified evidence source and its retention window. |
| **R3 — information-destroying** | Undo is impossible in principle | `DROP COLUMN` of unbacked-up data, `TRUNCATE`, narrowing truncation, field merge, in-place hashing, dedup, purge | **Capture the pre-image yourself, or don't ship it.** |

**The pre-image rule [+] — arguably the most actionable addition to the article:**

> Any R3 change must, in the same migration and before the destructive statement, write the
> information it is about to destroy somewhere durable.

```sql
-- before an irreversible transform, snapshot exactly what you're about to change
CREATE TABLE mig_2026_08_10_price_rebase_backup (
  order_id     BIGINT PRIMARY KEY,
  old_amount   NUMERIC(12,2) NOT NULL,
  captured_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO mig_2026_08_10_price_rebase_backup (order_id, old_amount)
SELECT id, amount FROM orders WHERE currency = 'BRL';
```

This converts an R3 change into an R2 change for the cost of one table you drop three months
later. It makes the compensating migration in §7.2 a mechanical `UPDATE ... FROM backup`
instead of a forensic investigation. Same trick for deletes: `INSERT INTO
archive_<table>_<date> SELECT * FROM <table> WHERE <purge predicate>` before the `DELETE`.

### 2.3 Timing is part of the risk

The article's sharpest single line: *"The SQL statement alone does not determine the risk."*
The same `ALTER TABLE ... ADD COLUMN ... NOT NULL DEFAULT 'x'` is:

- **safe** in a maintenance window with a single app version stopped;
- **safe** in a rolling deploy *if* old code never inserts and new code always supplies a value;
- **a silent data-quality incident** in a rolling deploy where old pods keep inserting rows
  that inherit a default nobody means;
- **an outage** on a 500M-row table on an engine version that rewrites the table to apply it.

So the unit of review is never the SQL file. It is **(SQL, table size, engine + version,
deployment strategy, which code versions will overlap, for how long)**.

### 2.4 Never repurpose a column **[+]**

Changing what a column *means* while leaving its type and name alone — `amount` switching from
cents to units, `created_at` switching from local time to UTC, `status = 'active'` acquiring a
new meaning, a boolean flag being reused for a second purpose — is the only change class where:

- no migration tool flags it,
- no type checker catches it,
- no compatibility test fails,
- old and new code both "work" and produce different, mutually invisible answers,
- and reversibility is destroyed the moment mixed-semantics rows exist, because you can no
  longer tell which rows are in which convention.

**Rule: a change in meaning is a new column.** Add `amount_cents` next to `amount`, backfill,
migrate readers, contract. If you truly cannot add a column, add a discriminator
(`amount_version SMALLINT`) so mixed semantics stay decodable — which is the whole point.

### 2.5 The "not deployable in one step" list **[+]**

Shorthand for review: these always decompose into ≥2 deployments, no exceptions worth arguing
about.

1. Rename anything (column, table, enum value).
2. Drop anything still referenced by deployed code.
3. Add a `NOT NULL` column with no sensible default.
4. Narrow a type or a constraint (including `UNIQUE`, `CHECK`, `FK`, length, precision).
5. Change the meaning of an existing column.
6. Move data between tables (split/merge/normalize/denormalize).
7. Change a primary key or a natural key's format.
8. Convert free text to a constrained domain (enum, lookup table).

---

## Part III — Expand · Migrate · Contract

> Turn one breaking change into several compatible changes.

### 3.1 The pattern, with deployment ordering made explicit **[+]**

The article gives three phases. The trap it doesn't spell out is the *ordering rule between DDL
and deploys*, which is what actually keeps every intermediate state green:

> **Additive (expand) DDL goes before the code that uses it.
> Destructive (contract) DDL goes after the last code that referenced the object is gone —
> plus a rollback window.**

Renaming `full_name` → `display_name`, in full, with the reachable states annotated:

| Step | Action | Running code | Reachable states, all green |
|---|---|---|---|
| **E1** | `ALTER TABLE customers ADD COLUMN display_name TEXT NULL` | v1 | v1 ignores the new nullable column |
| **M1** | Deploy **v2**: writes both columns, reads `display_name ?? full_name` | v1 + v2 | v1 rows have only `full_name` → v2's fallback covers it; v2 rows have both → v1 reads `full_name` fine |
| **M2** | Backfill `display_name` from `full_name` in batches | v2 (v1 rollback still possible) | Both columns converge; no reader depends on the backfill's completion |
| **M3** | Verify: `SELECT count(*) FROM customers WHERE display_name IS DISTINCT FROM full_name` → 0 (or a known, explained delta) | v2 | Evidence gate |
| **C1** | Deploy **v3**: reads and writes `display_name` only | v2 + v3 | v2 still writes both → v3 sees good data; v3 writes only the new column → **v2 reading `full_name` would see stale values**, so v2 must already prefer `display_name` (it does — that's M1's read order) |
| — | **Rollback window**: soak, watch, do nothing | v3 | v1 is now *not* rollback-safe; v2 is |
| **C2** | Separate deploy: `ALTER TABLE customers DROP COLUMN full_name` | v3 | v3 never touches it |

Two things this table makes visible that the prose version hides:

- **The rollback target moves.** After C1, "roll back one version" means v2, not v1. Teams
  that write "we can always roll back" in the plan usually mean v1 and are wrong by C1.
- **Reads must prefer the new column from the very first dual-writing release** (M1), or C1
  breaks the still-running v2. The fallback order is not stylistic.

### 3.2 Phase exit criteria **[+]**

Each arrow is a gate, not a schedule. Don't advance on the calendar; advance on evidence.

| Gate | Do not proceed until |
|---|---|
| E → M | Expand DDL applied to *all* environments and replicas; no lock incidents; old version still healthy |
| M1 → M2 | Dual-write release is at 100% of instances (not 90% — the stragglers are exactly the ones writing single-column rows) |
| M2 → M3 | Backfill reports 0 remaining, 0 failed, and its checkpoint says "complete", not "quiet" |
| M3 → C1 | Verification query returns the expected result *on the primary and on replicas* |
| C1 → C2 | Rollback window expired **and** the five drop preconditions (§8.4) all hold |

### 3.3 What to do if you must roll back mid-pattern **[+]**

The article never covers this, and it's the question people actually have at 2am.

- **During Expand.** Trivial — the new column is unused. Drop it or, cheaper, leave it. An
  unused nullable column costs almost nothing; leaving it avoids a second DDL under stress.
- **During Migrate (dual-write release is bad).** Roll the code back to v1. The new column
  simply stops being written; the old column is still authoritative and complete. **Nothing is
  lost.** This is the property that makes dual-write worth its ugliness — it is the phase
  where rollback is genuinely free.
- **During Migrate (the backfill is wrong).** Stop the worker (it's pausable, §6.1). The
  backfill only ever wrote the *new* column, so the old column is intact and authoritative;
  re-run the corrected backfill forward. **Never** "roll back" a backfill by reversing it —
  fix the transform and re-run it idempotently.
- **During Contract (v3 is bad).** Roll back to v2, which still reads and writes both. Safe
  precisely because C2 hasn't happened. This is why C1 and C2 are separate deploys.
- **After Contract (column dropped, v3 is bad).** You are outside the pattern's protection.
  Now it's Part VII: roll forward, or restore-aside-and-repair.

**Rule of thumb: the pattern is designed so that at every point, "roll back exactly one
release" is safe. Any step that breaks that property is mis-sequenced.**

### 3.4 Dual writes: three implementations, ranked **[+]**

The article shows app-level dual writes. In practice there are three options and the app-level
one is usually the *worst* of the three for a single-database rename:

1. **Generated / computed column** (best, when applicable). `ALTER TABLE customers ADD COLUMN
   display_name TEXT GENERATED ALWAYS AS (full_name) STORED`. Zero application changes, no
   drift possible, covers every writer. Limits: the new column is read-only, so it only works
   for the read-migration half; you convert it to a plain column at cutover.
2. **Database trigger** (best general-purpose). A `BEFORE INSERT OR UPDATE` trigger keeping the
   two columns in sync covers writers the application team doesn't control — batch jobs, admin
   consoles, the data team's scripts, that one legacy service, manual `UPDATE`s during an
   incident. Costs a small per-write overhead and one more thing to remember to drop.
3. **Application dual write** (the article's version). Explicit and reviewable, but it only
   covers the writers that go through that code path. **The failure mode is a writer you
   forgot**, and you find it during Contract, when the "converged" columns silently diverge.

**Decision rule:** if the two targets are in the same database, prefer the database to keep
them in sync (1 or 2) and use the application only for values it alone can compute. If the two
targets are in *different* stores, none of these apply — see below.

### 3.5 Dual writes across stores are a distributed-transaction problem

The article is right and the point deserves emphasis: two writes in one transaction against one
database are atomic; two writes across databases/services are not, and no amount of `try/catch`
makes them so. When you find yourself writing:

```
write to old_store
write to new_store   // <- what happens if this throws? if the process dies between them?
```

...you have built a dual-write consistency problem, one of the classic ways to lose data
quietly. Use the patterns that exist for it:

- **Transactional outbox** — write the row and an outbox record in one local transaction; a
  relay publishes to the other store with at-least-once delivery and idempotent apply.
- **CDC / log tailing** (Debezium et al.) — let the database's own log be the single source of
  writes to the second store. The write path stays single-store; the replication is derived.
- **One-way sync with reconciliation** — accept eventual consistency, and run a periodic job
  that compares and repairs, with a divergence metric you alert on.

Whatever you choose, **make the second write idempotent and keyed**, so retries converge rather
than duplicate.

### 3.6 Read migration and shadow reads **[+]**

Switching reads is the risky half, and it's usually done blind. Stage it:

1. **Read old.** (baseline)
2. **Read new, fall back to old.** Safe during backfill.
3. **Shadow read / dark read.** Read both, serve the old one, and emit a metric when they
   differ. Run it long enough to cover the weekly/monthly cycles that produce weird rows. This
   is the cheapest possible proof that your backfill and dual-write are correct, on *real
   production traffic*, with zero user impact.
4. **Read new only.** Flip via feature flag, percentage-ramped, with the divergence metric
   still wired up.

A shadow-read divergence rate that won't go to zero is a finding, not a nuisance — it usually
means a writer you don't know about (§3.4) or a transform that doesn't handle a real-world
edge (nulls, empty strings, unicode, historical rows written by a system that's been dead for
five years).

### 3.7 Contract discipline: the debt you promised to pay **[+]**

The article bolds *"temporarily… so you don't forget and end up with a DB full of technical
debt."* Make that structural rather than aspirational:

- **Create the contract ticket during Expand**, not after. It carries the drop statement, the
  preconditions, and the earliest-execution date. An expand PR without a contract ticket is
  incomplete.
- **Name the debt in the schema.** Comment the column: `COMMENT ON COLUMN customers.full_name
  IS 'DEPRECATED 2026-08-10, drop after 2026-09-15, replaced by display_name (JIRA-1234)'`.
  It survives team turnover in a way a Jira ticket does not.
- **Enforce the window mechanically.** A CI check that refuses a `DROP`/`RENAME` unless a
  matching deprecation record exists and is older than the policy window.
- **Track open expand/contract cycles as a number** on the team dashboard. The failure mode is
  not one forgotten column; it's twelve, in a schema nobody dares touch.

### 3.8 Table-level expand/contract **[+]**

When the change is too big for column-level staging (repartitioning, changing a primary key,
re-typing a huge column, changing collation), the same pattern applies one level up:

1. Create the new table with the target shape.
2. Add triggers on the old table that mirror writes into the new one.
3. Backfill in batches, throttled.
4. Verify parity (counts, checksums, sampled row comparison).
5. Swap in a single short transaction: `ALTER TABLE t RENAME TO t_old; ALTER TABLE t_new
   RENAME TO t;`
6. Keep `t_old` for the rollback window, then drop it.

This is exactly what the online-schema-change tools automate — `gh-ost` and
`pt-online-schema-change` for MySQL, `pg_repack` for bloat/reorganization, `pgroll` and
`Reshape` for expand/contract-with-views on Postgres. **Use the tool rather than hand-rolling
this**; the sharp edges (trigger recursion, the cutover lock, foreign keys pointing at the old
table, replication implications) are already handled there.

---

## Part IV — Separate deployment from release

### 4.1 The sequence

```
1. Expand schema (additive, compatible)         <- reversible, boring
2. Deploy code, feature OFF                     <- reversible by redeploy
3. Enable for internal users / 1% / canary      <- reversible by config
4. Ramp: 10% → 50% → 100%                       <- reversible by config
5. Soak (the rollback window)                   <- do nothing on purpose
6. Contract (destructive)                       <- one-way door, gated on evidence
```

The gain: for steps 3–5, **recovery is a config change, not a database operation**. That moves
the mean time to recovery from "however long a migration takes" to "seconds", and — crucially —
it means the recovery action is one that a tired on-call engineer can take safely.

### 4.2 What flags do not do

The article's caveat, expanded:

- **Flags don't repair data.** Turning the feature off stops the bleeding; the rows already
  written wrong stay wrong. You still need Part VII.
- **Flags are debt.** Every flag is a branch in the code and a state in the test matrix.
  Removal is part of the change, not an optional follow-up. Same discipline as §3.7.
- **A flag that gates writes must respect the compatibility contract.** Flipping a flag can
  make v2 start writing values v1 can't read — the flag flip is *itself* a schema-semantics
  change, and must not precede the reader rollout.
- **[+] Flags multiply the state matrix.** With a flag, the reachable states are
  (v1) × (v2 flag-off) × (v2 flag-on) × (S0, S1). Test the off path as seriously as the on
  path; "flag off" is what you'll be running during the incident.
- **[+] Flag-off must be genuinely safe, not just untested.** If the code writes new-format
  data before checking the flag, or the flag only gates the UI while the write path already
  changed, the kill switch is decorative.

### 4.3 Kill switch vs rollback vs roll forward **[+]**

A quick decision rule for the incident:

| Situation | Action |
|---|---|
| New behavior is wrong, data written is still valid | **Flag off.** Fastest, safest. |
| Code is wrong, schema is compatible with the previous release | **Roll back code.** Confirm the previous version is still schema-compatible *first* (§1.4). |
| Data written is wrong | **Roll forward** with a compensating migration (§7.2). Rolling back code stops new damage but repairs nothing. |
| Migration itself is failing/hanging | **Cancel it and release the locks** (§5.1) — the blocked query pile-up is usually the real outage, not the migration. |
| Schema change is incompatible and code is already rolled back | You are in the state the whole document exists to prevent. Re-apply the expand step forward, don't fight it backward. |

---

## Part V — The mechanics the article skips **[+]**

This entire part is an addition. The article treats a migration as an instantaneous logical
event. In production it is a physical operation against a live system, and *that* is where most
migration outages actually come from.

### 5.1 Locks, rewrites, and online DDL

**The failure mode nobody expects: the lock queue.** In PostgreSQL, a DDL statement waiting for
an `ACCESS EXCLUSIVE` lock **blocks every query that arrives behind it**, including plain
`SELECT`s. So one long-running transaction holding a read lock + one `ALTER TABLE` waiting
behind it = a full outage on that table, even though the `ALTER` itself would take 3
milliseconds. The migration didn't need to be slow; it only needed to *wait*.

Mitigation, and it belongs in every Postgres migration runner:

```sql
SET lock_timeout = '3s';        -- fail fast instead of queueing behind a long query
SET statement_timeout = '30s';  -- and never let the DDL itself run away
-- then retry the migration with backoff; also hunt the long transaction that blocked you
```

Engine-specific notes worth internalizing (**verify against your exact engine version — these
are version-sensitive**):

*PostgreSQL*

- Adding a column with a **constant** default no longer rewrites the table (since PG 11); a
  **volatile** default still does.
- `SET NOT NULL` scans the whole table. Cheaper path: add a `CHECK (col IS NOT NULL) NOT
  VALID`, `VALIDATE CONSTRAINT` (weaker lock, allows reads and writes), then `SET NOT NULL`,
  which PG 12+ can prove instantly from the validated check.
- Foreign keys and check constraints: `ADD CONSTRAINT ... NOT VALID` then `VALIDATE
  CONSTRAINT` — the split turns one long exclusive lock into a short one plus a concurrent scan.
- `CREATE INDEX CONCURRENTLY` doesn't block writes, but: it cannot run inside a transaction
  block (frameworks need their per-migration transaction disabled), it takes roughly twice as
  long, it waits for existing transactions to drain, and **on failure it leaves an `INVALID`
  index behind** that must be `DROP INDEX CONCURRENTLY`-ed before retrying. Check
  `pg_index.indisvalid` after every concurrent build.
- Unique constraint without a long lock: `CREATE UNIQUE INDEX CONCURRENTLY`, then `ALTER TABLE
  ... ADD CONSTRAINT ... UNIQUE USING INDEX`.
- DDL is transactional — a failed multi-statement migration rolls back cleanly. This is a real
  advantage; use it (one migration = one transaction) except where `CONCURRENTLY` forbids it.
- Type changes generally rewrite. Exceptions that don't: `varchar(n)` → `varchar(m)` for m > n,
  and `varchar` → `text`.

*MySQL / InnoDB*

- `ALGORITHM=INSTANT` / `INPLACE` / `COPY` and `LOCK=NONE|SHARED|EXCLUSIVE`: state them
  explicitly so the server *errors* instead of silently falling back to a full copy under an
  exclusive lock.
- **Metadata locks**: a long-running transaction that merely touched the table blocks DDL, and
  everything queues behind it — the same pile-up as Postgres, different mechanism.
- Atomic DDL landed in 8.0 (data-dictionary based); on older versions a partially applied
  multi-statement migration is a real state you can end up in. Design migrations to be
  re-runnable rather than assuming atomicity.
- For anything `INSTANT`/`INPLACE` can't do, use `gh-ost` or `pt-online-schema-change` rather
  than a maintenance window.

**Practical gate:** for any table above a size threshold the team agrees on (10M rows is a
common line), the migration plan must state the expected lock type, expected duration measured
on a production-sized clone, and the abort procedure.

### 5.2 Connection pools, cached plans, and ORM traps

- **Cached/prepared statement plans.** After DDL, Postgres sessions holding prepared statements
  can fail with `cached plan must not change result type` — classic with JDBC, Rails, and
  anything with a long-lived pool. Mitigations: application-side retry on that SQL state, a
  connection recycle after migrations (`max_lifetime`), or avoiding shape changes to hot
  queries mid-flight. It's a self-healing error only if something is making it heal.
- **Connection poolers.** PgBouncer in transaction pooling mode and server-side prepared
  statements interact badly on older versions; a migration is often when it first bites.
- **`SELECT *`** turns "add a column" — the safest change there is — into a compatibility risk,
  because the row shape changes under code that positionally decodes it or maps into a strict
  struct. Same for `INSERT` without an explicit column list.
- **Schema caches.** Rails' schema cache, Hibernate's metadata, generated clients, and typed
  query builders may be validated at boot: a pod that started before the migration and a pod
  that started after can genuinely disagree about the schema.
- **Dependent objects.** Views, materialized views, triggers, stored procedures, computed
  columns, row-level-security policies and partitioned-table parents all hold references. A
  `RENAME` that looks local can break a view three layers away, or silently keep working
  against a stale definition. Enumerate dependencies (`pg_depend`, `information_schema`) before
  touching a column.

### 5.3 Replicas and replication

- **Read replicas lag.** A big backfill generates WAL/binlog volume and can push replica lag
  from milliseconds to minutes, which surfaces as stale reads in the *application*, not as a
  migration error. **Throttle the backfill on measured replica lag** (§6.3).
- **DDL propagates too** and can be slow or blocking on replicas; on Postgres physical
  replication, a replica applying an exclusive-lock DDL can conflict with long-running queries
  there (`max_standby_streaming_delay` — either the query is cancelled or replay stalls).
- **Logical replication and CDC pipelines break on DDL**, since DDL isn't replicated logically:
  publications need the new column added, downstream consumers need updating first. Order
  matters: the consumer must tolerate the new shape before the producer emits it — the same
  expand/contract logic, applied to the pipeline.
- **Blue/green database deploys** (e.g. RDS Blue/Green) give you a staged copy to apply and
  test the migration on before cutover, but they don't remove the compatibility problem; they
  just move where you discover it.

### 5.4 Long transactions, MVCC, and bloat

- An `UPDATE` that touches every row of a large table writes a new version of every row: table
  and index bloat, an autovacuum storm afterwards, and possibly a disk-space incident.
- A long-running transaction holds back the vacuum horizon, blocks `CONCURRENTLY` builds, and
  in the extreme threatens transaction-ID wraparound. **A single-statement backfill over a huge
  table is a long-running transaction**, which is exactly why the article's "batch it" advice
  matters beyond politeness.
- Plan for post-backfill maintenance: `VACUUM (ANALYZE)` (or `pg_repack` for reclaiming space)
  and refreshed statistics, or the first queries after your successful migration will pick bad
  plans and everyone will blame the schema.

### 5.5 The migration runner itself

- **Who runs it and when?** App-boot migrations mean N pods racing to migrate on every deploy;
  at minimum take a database advisory lock so exactly one wins, and remember that a slow
  migration then blocks readiness probes and can fail the whole rollout. A separate pipeline
  step (or a Kubernetes Job/init container with a lock) is generally safer and gives you a
  place to stand between "migrated" and "deployed" — which the ordering rule in §3.1 requires.
- **Checksum drift and out-of-order migrations.** Flyway/Liquibase-style checksums catch edited
  history; concurrent feature branches produce out-of-order versions that behave differently in
  staging than production. Decide the policy deliberately.
- **Idempotency.** `IF NOT EXISTS` / existence guards make re-runs safe; a migration that only
  works exactly once is a migration you cannot retry during an incident.
- **Timeouts.** Set `lock_timeout` and `statement_timeout` per-migration, not globally, and
  never inherit the application's timeouts for DDL.
- **Migrations are code.** They get reviewed, tested, versioned, and *rehearsed* — see Part IX.

### 5.6 The schema lives outside the database too **[+]**

The article's compatibility contract stops at the database. In a real system, the same "old
readers, new writers" problem exists in at least five other places, and they fail the same way:

| Carrier | The problem | The fix |
|---|---|---|
| **Message queues / in-flight jobs** | v2 enqueues a job with a new payload shape; v1 workers dequeue it and crash or mis-process. Messages sit in queues across the entire deploy — and in DLQs long after. | Version the payload, deploy tolerant consumers first, never remove a field consumers still read, drain or dual-format during transition. |
| **Caches** | Redis/memcached hold serialized objects in the old shape; v2 deserializes them into the new class. And rolled-back v1 reads entries v2 wrote. | Version the cache key namespace with the schema version; never mutate the shape under a stable key. |
| **Event streams / event sourcing** | Events are immutable and forever. An event written today will be read by code that doesn't exist yet. | Schema registry with compatibility enforcement, additive-only changes, upcasting on read. |
| **Search indexes / read models** | Derived stores rebuilt from the primary lag behind it or hold the old mapping. | Reindex as an explicit migration step; treat mapping changes as their own expand/contract. |
| **Analytics / ETL / BI** | A rename silently breaks the nightly job or, worse, produces wrong dashboards. Downstream consumers you've never met depend on the column name. | Data contracts, ownership metadata, a consumer inventory before any rename or drop. |
| **API responses / mobile clients** | Old app versions live on users' phones for *months*. That's the longest-lived "previous version" you have. | The rollback window for anything user-facing is set by client version decay, not by your deploy. |

**Rule: the rollback window is bounded by the slowest thing that still holds the old shape** —
which is usually a mobile client or a DLQ, not a pod.

---

## Part VI — Backfills

### 6.1 The five properties, made operational

The article's list, each with what it concretely means:

| Property | Concretely |
|---|---|
| **Idempotent** | Re-processing a batch changes nothing. Achieved by a guard predicate (`WHERE new_col IS NULL`) or a natural convergence (`SET new = f(old)` where `f` is deterministic) — never by `SET counter = counter + 1`. |
| **Restartable** | Progress is persisted outside the worker (a checkpoint row), so a crash resumes at the right place rather than at zero or at "wherever the developer thinks it got to". |
| **Bounded batches** | Each transaction touches a known number of rows, sized so it holds locks for well under a second. |
| **Observable** | Total / processed / remaining / failed / retries / rate / ETA, exported as metrics, not printed to a log nobody reads. |
| **Pausable** | A kill switch that stops it *between* batches, leaving a consistent state. You will need this during an unrelated incident. |

**[+] Add a sixth: throttled.** A backfill that runs as fast as the database allows is a
self-inflicted load test on production. See §6.3.

### 6.2 Batching mechanics

**Use keyset (seek) pagination, not `OFFSET`.** `OFFSET 5000000` makes the database read and
discard five million rows per batch; the backfill gets quadratically slower and eventually
never finishes.

```sql
-- one batch: bounded, resumable, idempotent
WITH batch AS (
  SELECT id
  FROM   customers
  WHERE  id > :last_id          -- keyset cursor, from the checkpoint
    AND  display_name IS NULL   -- idempotency guard: already-migrated rows are skipped
  ORDER  BY id
  LIMIT  1000                   -- bounded
  FOR    UPDATE SKIP LOCKED     -- optional: safe under multiple workers
)
UPDATE customers c
SET    display_name = c.full_name
FROM   batch b
WHERE  c.id = b.id
RETURNING c.id;                 -- max(id) becomes the next checkpoint
```

Details that matter:

- **The driving predicate needs an index**, or every batch seq-scans looking for unmigrated
  rows. A partial index (`CREATE INDEX CONCURRENTLY ... ON customers (id) WHERE display_name IS
  NULL`) is ideal: it shrinks as the backfill progresses and you drop it at the end.
- **Checkpoint durably**, in a table, in the same transaction as the batch where possible:
  `migration_progress(migration_id, last_id, processed, failed, updated_at)`.
- **`SKIP LOCKED`** lets multiple workers cooperate without overlapping ranges — the article's
  "two workers may process overlapping ranges" hazard, solved at the database level.
- **Don't hold one transaction across batches**, and don't wrap the whole backfill in a
  transaction "for safety" — that's the exact anti-pattern (§5.4).
- **New rows keep arriving.** The backfill must handle rows created *during* it, which is why
  dual-write comes first: new rows are already correct, and the guard predicate skips them.

### 6.3 Throttling and adaptive pacing **[+]**

Between batches, sleep — and make the sleep adaptive:

```
if replica_lag > 5s or db_cpu > 70% or p99_latency > SLO:
    backoff (exponential, capped)
else:
    reduce sleep toward the floor
```

Feedback signals worth wiring: replica lag, primary CPU/IO, lock wait time, application p99,
error rate. A backfill that finishes in six hours without anyone noticing beats one that
finishes in twenty minutes and pages the team.

### 6.4 Failure handling

- **Per-row failures**: don't let one poison row kill the run. Record it (`migration_failures`
  with the id, the error, and the attempt count), skip it, continue, and alert on the count.
  Failed rows are a *finding* about your data, usually the most interesting output of the
  backfill.
- **Batch failures**: retry with backoff; after N attempts, halve the batch size (often a
  timeout caused by an unusually heavy range) and, failing that, park and page.
- **Completion is a claim that needs proof**: "0 remaining" from the worker is not the same as
  "0 rows match the unmigrated predicate". Verify with an independent query (§8.3).

### 6.5 Sizing and rehearsal

Measure on a production-sized clone: rows/second per batch size, p99 batch duration, lock
duration, WAL generated. Then compute the wall-clock estimate and *state it in the plan*. "We'll
backfill 400M rows" without a duration is not a plan — if it takes eleven days, that changes
the rollback window, the contract date, and possibly the whole approach.

---

## Part VII — When rollback is no longer enough

### 7.1 Roll forward is the default posture **[+]**

For anything that touched data, "roll forward" should be the assumed recovery mode and rollback
the special case, because:

- rollback can't restore destroyed information (Part I),
- rollback reintroduces the (v1, S1) compatibility problem in the worst possible conditions,
- and the newer code is the one the team has in their heads right now.

**Rollback is for code defects with an unchanged data contract. Everything else rolls forward.**

### 7.2 Compensating migrations

A new forward operation that corrects a known error. It works when you can (a) identify the
affected records and (b) reconstruct the correct value.

```sql
-- correcting a bad transform, using the pre-image captured in §2.2
BEGIN;

-- 1. blast radius FIRST, always
SELECT count(*) FROM orders o
JOIN   mig_2026_08_10_price_rebase_backup b ON b.order_id = o.id
WHERE  o.amount <> b.old_amount * 1.10;

-- 2. the repair, scoped to exactly the damaged set, batched if large
UPDATE orders o
SET    amount = b.old_amount * 1.10,
       corrected_by = 'INC-4471'
FROM   mig_2026_08_10_price_rebase_backup b
WHERE  o.id = b.order_id
  AND  o.amount <> b.old_amount * 1.10;

-- 3. verify before committing
SELECT count(*) FROM orders o
JOIN   mig_2026_08_10_price_rebase_backup b ON b.order_id = o.id
WHERE  o.amount <> b.old_amount * 1.10;   -- expect 0

COMMIT;
```

Rules for compensating migrations, learned the hard way:

- **Estimate the blast radius before you write.** `SELECT count(*)` with the exact `WHERE` of
  the `UPDATE`. If it returns a number you didn't expect, stop.
- **Scope precisely.** Repair only rows you can prove are damaged — a repair that also touches
  correct rows is a second incident.
- **Mark what you touched** (`corrected_by`, `corrected_at`) so the next investigator can tell
  your repair from the original damage.
- **They are migrations too**: batched, idempotent, observable, reviewed. Under incident
  pressure this is exactly when people run a bare `UPDATE` in a psql session. Don't.
- **Capture pre-images of the repair itself.** Yes, again. Compensating migrations are written
  fast, under stress, by tired people.
- **Rows changed by users after the damage** are the hard case: a naive repair overwrites
  legitimate newer edits. Bound the repair by `updated_at <= <incident window end>` or exclude
  rows with subsequent activity, and hand-handle the remainder.

### 7.3 Sources of truth, ranked by how much you'll wish you had them

1. **A pre-image table you wrote yourself** (§2.2) — exact, scoped, instantly queryable.
2. **Application-level audit/history tables** — usually complete for domain events, and already
   understood by the team.
3. **CDC stream / outbox** (Debezium → Kafka) — a full change log if your retention covers the
   incident. *Retention is the catch.*
4. **WAL / binlog** — complete but low-level; recovering a specific value means tooling
   (`pg_waldump`, `mysqlbinlog`) and time you don't have. Retention is usually days.
5. **Snapshots / PITR** — complete as of a point in time, but coarse and slow to use.
6. **Backups** — the last resort, and the slowest.

**[+] Retention rule:** *every evidence source's retention must exceed your rollback window,
which must exceed your realistic mean time to detect.* If your MTTD for a data-quality bug is
two weeks (it often is — quiet corruption is found by a customer, not a monitor) and your WAL
retention is three days, then the evidence you're counting on doesn't exist. Write that down
and reconcile it before you need it.

### 7.4 Why a full restore is usually the wrong move

Restoring production to a point before the migration also deletes every valid order, payment,
signup and message created since. You trade a known, bounded data-quality problem for an
unbounded data-*loss* problem, and you take a full outage to do it.

**The pattern that works:**

1. Restore the backup/PITR snapshot into a **separate instance**.
2. Extract only the affected records/columns from it.
3. Load them into production as a staging table.
4. Run a scoped, verified repair (§7.2).
5. Reconcile with anything that changed in between.

Full restore is defensible in exactly two situations: the damage is total and recent, or the
system is genuinely offline anyway. Both are rare enough to be decided by a named human, not by
a runbook step.

### 7.5 Recovery objectives, made real **[+]**

- **RPO** (how much data you can afford to lose) and **RTO** (how long recovery may take) must
  be stated as numbers, per system.
- **Restore time is not backup time.** A 2 TB database restores in hours, not minutes. If
  nobody has actually timed a restore this quarter, the RTO is fiction.
- **An untested backup is not a backup.** Restore rehearsals belong on the calendar, and the
  rehearsal output is a *measured number* that goes into the migration plan.

---

## Part VIII — Observability and verification

### 8.1 What to emit for schema changes

Duration, lock type acquired and lock wait time, blocked/queued query count while running,
replication lag delta, error rate, rows affected. Emit a start and end **event** (an
annotation/deploy marker on your dashboards) so that when latency doubles at 14:07, someone can
see "migration 20260810_add_display_name ran 14:06–14:08" instead of guessing.

### 8.2 What to emit for backfills

The article's list — total, processed, remaining, failed, retry count, rate — plus:

- **ETA** (derived from rate and remaining) — the number people actually ask for.
- **Current cursor position** — so you know it's *moving*, not merely alive.
- **Batch p99 duration** — the early warning that batches are getting heavier.
- **Throttle state** — whether it's backing off, and on which signal.
- **A staleness alert**: "no progress in N minutes while marked running" catches the silent
  hang, which is the most common backfill failure and the one no counter reveals.

### 8.3 Verification queries — the point the article makes best

*A "success" message proves the statement executed, not that the data is correct.* Every
migration ships with the query that proves its own claim, and the expected result:

```sql
-- convergence: no row where the two disagree
SELECT count(*) FROM customers WHERE display_name IS DISTINCT FROM full_name;   -- expect 0

-- completeness: nothing left unmigrated
SELECT count(*) FROM customers WHERE display_name IS NULL;                       -- expect 0

-- domain validity: no value outside the new contract
SELECT status, count(*) FROM orders GROUP BY 1;                                  -- expect known set only

-- referential sanity after a split
SELECT count(*) FROM order_lines l LEFT JOIN orders o ON o.id = l.order_id
WHERE o.id IS NULL;                                                              -- expect 0
```

**[+] Run verification on the replicas too.** "Correct on the primary" and "correct where the
application actually reads" are different claims.

**[+] Keep the important ones as permanent invariant checks.** The convergence query that
mattered during the migration is often a data-quality invariant worth monitoring forever. A
scheduled job that asserts a handful of invariants and alerts on violation catches the next
silent corruption long before a customer does.

### 8.4 The five preconditions before dropping anything

Straight from the article, and worth treating as a literal checklist gate:

1. No application version **reads** it.
2. No application version **writes** it.
3. The backfill **completed** (verified independently, §6.4).
4. The new field contains **valid data** (verified, §8.3).
5. The **rollback window expired**.

**[+] How to actually prove 1 and 2** — "we grepped the repo" is not proof:

- Grep every deployed repo *and* every deployed *version*, not just `main`.
- Check the other consumers: ETL jobs, BI queries, admin tools, notebooks, stored procedures,
  views, other services' read replicas.
- Ask the database. Postgres: `pg_stat_statements` scanned for the column name; column-level
  statistics; `pg_stat_user_tables` sequential-scan counts. MySQL: the performance schema and
  the general/slow logs.
- **The strongest proof is empirical**: rename the column to `zz_deprecated_full_name` (or
  revoke access to it), watch for errors through a full business cycle including month-end
  batch jobs, and *then* drop. If something still reads it, you find out with a loud error at a
  time of your choosing rather than a silent wrong answer at 3am. Note the tradeoff: the rename
  is itself a breaking change, so this only applies once you believe nothing uses it — it's a
  *test* of that belief, run deliberately.

---

## Part IX — Testing and CI **[+]**

Entirely absent from the article, and it's where the compatibility contract stops being
aspirational.

### 9.1 The compatibility test job

> Run the **previous release's** test suite against the **new** schema.

This single CI job mechanizes the article's central question. Concretely: check out the
previous release tag, apply all migrations including the new one, run its integration tests.
Red = the change is not deployable in one step. It catches renames, drops, `NOT NULL` additions,
new constraints, and narrowed types automatically, with no reviewer vigilance required.

The mirror job — new code against the old schema — catches the (v2, S0) cell and tells you
whether the deploy is order-sensitive.

### 9.2 Rehearse on production-shaped data

Row counts, data skew, and index bloat determine migration behavior, and none of them exist in
a seeded test database. Rehearse on a restored production clone (anonymized as policy requires)
and record: duration, lock type and wait, rows affected, WAL generated, and the verification
query results. That recording is the migration plan's evidence section.

**Rehearse the recovery path too.** The compensating migration and the restore-aside procedure
should each have been executed once, in anger, on the clone, before you need them.

### 9.3 Automated migration linting

Tools encode the "conditionally safe" column of §2.1 and fail the PR:
**squawk** and **eugene** (Postgres DDL linting), **atlas** (schema-as-code with lint rules),
**strong_migrations** (Rails), plus whatever your ORM offers. Typical rules: no `DROP` without a
deprecation record, no `ADD COLUMN NOT NULL` without a default, no `CREATE INDEX` without
`CONCURRENTLY`, no multi-statement DDL without `lock_timeout`, no `RENAME`. Cheap to add, and it
moves this whole knowledge base from "things a senior engineer remembers" to "things CI
enforces".

### 9.4 Test the intermediate states, not just the endpoints

The states in §1.4 and the phase table in §3.1 are testable. A test that starts v1, applies the
expand migration, starts v2 alongside, writes through both, and asserts both readers see correct
data is worth more than any amount of review discussion.

---

## Part X — Process and people **[+]**

### 10.1 The migration plan

Non-trivial migrations get a short written plan attached to the PR. Six headings, no more:

1. **The change** — what, on which tables, at what current row count.
2. **Risk classification** — availability / compatibility / reversibility (§1.3), with the
   reasoning.
3. **The phases** — every deploy and DDL step, in order, with who runs what.
4. **Verification** — the queries and their expected results, per phase.
5. **Recovery** — what "wrong" looks like, the detection signal, and the response for each
   phase (§3.3), including the evidence source and its retention.
6. **Contract** — the destructive step, its preconditions, and its earliest date.

If a migration can't fill this in half a page, it isn't understood well enough to run.

### 10.2 Review rules

- Destructive DDL (`DROP`, `TRUNCATE`, type narrowing, `DELETE` without a bounded predicate)
  requires a second reviewer with database context. Two-person rule, same as production access.
- The reviewer's job is the three axes and the state matrix, not SQL style.
- **Migrations and application code in the same PR is an anti-pattern** when the ordering
  matters — the PR structure should make the ordering constraint visible, not hide it.

### 10.3 Coordination

The article's checklist item 10 — *"are there other concurrent migrations or releases that could
interact?"* — deserves a mechanism, not just a question. Two heavy migrations on the same table,
or a backfill running during another team's peak batch window, is a self-inflicted incident. A
shared calendar of in-flight migrations, and an owner per migration who stays reachable through
its rollback window, covers most of it.

### 10.4 The organizational failure mode

The pattern in this document costs three deploys where a naive rename costs one. Teams abandon
it under delivery pressure, and abandon it *silently*, one "this one's small" at a time. The
counter-pressure is making the safe path the cheap path: linters, templates, a generator for the
expand/contract skeleton, a runbook, and a shared vocabulary. **If the safe path is more work
than the unsafe path, the safe path loses** — that's an engineering-process problem, not a
discipline problem.

---

## Part XI — Playbooks

### 11.1 Pre-deployment checklist

The article's ten, verbatim in substance, with additions marked:

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
11. **[+]** What lock does this take, for how long, on a table of this size — and what is the
    abort procedure?
12. **[+]** If this destroys information, where is the pre-image, and how long does it live?
13. **[+]** What else holds this shape — queues, caches, event streams, search indexes, mobile
    clients, downstream analytics — and which of them sets the real rollback window?
14. **[+]** Has the previous release's test suite been run against this schema?
15. **[+]** Who owns this migration through its rollback window, and what will page them?

### 11.2 Incident decision tree

```
Something is wrong after a release that touched the database.

├─ Is the migration still running / hanging?
│   └─ Cancel it. Check for a lock queue — the pile-up behind it is usually the outage.
│      Find and kill the blocking long transaction. Then diagnose.
│
├─ Is data being written incorrectly right now?
│   ├─ Yes → STOP THE BLEEDING FIRST
│   │   ├─ Feature flag available? → turn it off. (seconds)
│   │   ├─ No flag, previous version schema-compatible? → roll back code. (minutes)
│   │   └─ Neither? → disable the specific write path / degrade the feature / read-only mode.
│   └─ No → continue.
│
├─ Is existing data already wrong?
│   ├─ No  → code rollback or flag-off is sufficient. Verify and stand down.
│   └─ Yes → ASSESS BEFORE ACTING
│       ├─ 1. Blast radius: how many rows, which, since when? (SELECT count first)
│       ├─ 2. Evidence: pre-image? audit table? CDC? WAL? PITR? within retention?
│       ├─ 3. Reconstructable? → compensating migration (§7.2), batched and verified.
│       ├─ 4. Not reconstructable from production → restore aside, extract, repair (§7.4).
│       └─ 5. Not reconstructable at all → contain, quantify exactly, escalate; this is now
│              a business decision (customer comms, manual repair, accepted loss),
│              not an engineering one.
│
└─ Always: annotate the timeline, keep every query you ran, and do not drop anything
   during the incident. The evidence you destroy at 03:00 is the evidence you need at 09:00.
```

### 11.3 Worked examples

**Rename a column** → §3.1. Three deploys. Never in one.

**Add a `NOT NULL` column**
1. Add nullable (`ADD COLUMN x TEXT NULL`).
2. Deploy code that always writes it.
3. Backfill existing rows in batches.
4. `ADD CONSTRAINT chk_x_nn CHECK (x IS NOT NULL) NOT VALID` → `VALIDATE CONSTRAINT` →
   `SET NOT NULL` (cheap on PG 12+; skip straight to `SET NOT NULL` only on small tables).
5. Optionally drop the now-redundant check.
*Never* `ADD COLUMN x NOT NULL DEFAULT 'unknown'` as one step unless you're genuinely happy
with a table full of `'unknown'` written by old pods.

**`INT` → `BIGINT` primary key** (the classic "we have 3 weeks before ID exhaustion")
In-place type change rewrites the table and every referencing index and FK — usually hours of
exclusive lock. Instead: add `id_new BIGINT`, dual-write, backfill in batches, add a unique
index concurrently, migrate FKs one child table at a time, swap in a short transaction. Or use
a table-level tool (§3.8). Budget weeks, not an afternoon — and start before you're at 80% of
`INT_MAX`, because the safe path needs the runway.

**Add an enum value / new status**
Readers first, always. Ship tolerant readers (unknown → safe fallback + log), wait for full
rollout, *then* let writers produce it — behind a flag so you can stop instantly. Removing a
value is the reverse and slower: stop writing it, migrate existing rows, verify none remain,
then remove.

**Narrow `VARCHAR(100)` → `VARCHAR(20)`**
Don't, in place. Measure first (`SELECT count(*) WHERE length(col) > 20`), decide what happens
to those rows as a *product* question, capture pre-images, transform explicitly, add a
`CHECK (length(col) <= 20)` as the constraint, and only consider the type change afterwards —
if at all. The check constraint gives you the enforcement without the irreversible truncation.

**Add a `UNIQUE` constraint**
Duplicates almost certainly exist. Find them, decide the merge/deletion rule (a product
decision), record pre-images, resolve them, `CREATE UNIQUE INDEX CONCURRENTLY`, then attach the
constraint. Old code that could create duplicates must be gone first, or its writes start
failing.

**Split a table**
Table-level expand/contract (§3.8): create, trigger-mirror or dual-write, backfill, shadow-read
for parity, cut reads over behind a flag, soak, then contract. Expect weeks and treat it as a
project with its own plan.

**Purge / retention deletion**
Archive first (`INSERT INTO archive_x_YYYYMM SELECT ...`), delete in bounded batches, verify
counts on both sides, keep the archive for a stated period. A `DELETE` with an unbounded
predicate and no archive is the single most-regretted statement in this whole document.

### 11.4 Anti-patterns, named

- **"We'll just run the down migration."** For anything that touched data: no, you won't.
- **`DROP COLUMN` in the same PR as the code that stopped using it.** Guarantees the (v1, S1)
  break during rollout.
- **One giant `UPDATE` over a 200M-row table** — locks, bloat, replication lag, and no way to
  stop it halfway.
- **Backfill with `OFFSET` pagination** — quadratic, and never finishes.
- **Migrations at app boot with N replicas and no advisory lock.**
- **A flag that only gates the UI while the write path already changed.** A kill switch that
  doesn't kill anything.
- **Repurposing a column's meaning.** Undetectable, unfixable.
- **`CREATE INDEX` (non-concurrently) on a large hot table** — writes blocked for the duration.
- **A `DROP` "cleanup PR" written six months later by someone who wasn't there**, with no
  record of whether the preconditions were ever checked.
- **Fixing production data with an ad-hoc `UPDATE` in a psql session during an incident**, with
  no count first, no transaction, no pre-image, and no record of what ran.
- **Trusting "0 rows affected"** as evidence of anything.

---

## Part XII — Beyond relational **[+]**

The problem is not caused by SQL. It is caused by *persistent state outliving the code that
wrote it*, so it exists everywhere state does.

- **Document stores / schemaless.** "No schema" means the schema moved into the application,
  where it is unenforced and unversioned. The same expand/contract applies: write both shapes,
  read tolerantly, migrate lazily on access or with a background job, then stop writing the old
  shape. Add a `_v` field to documents from day one — it costs a byte and makes every future
  migration decidable.
- **Event sourcing.** Events are immutable and are read by code that doesn't exist yet, so
  compatibility is permanent, not windowed. Additive-only changes; **upcasting** on read to
  translate old events into the current shape; never rewrite history except to redact.
- **Kafka / schema registry.** The compatibility modes are exactly the state matrix, formalized:
  *backward* (new readers read old data — upgrade consumers first), *forward* (old readers read
  new data — upgrade producers first), *full* (both — the safe default when you don't control
  rollout order). Choosing the mode *is* choosing your deploy ordering.
- **Data warehouse / lakehouse.** Downstream models, dashboards and contracts break on rename
  the same way application code does, but the feedback loop is a day long and the person who
  notices is an executive looking at a wrong number.
- **Object/blob storage and file formats.** Same rules, longest lifetimes, weakest tooling.

---

## Glossary

| Term | Meaning |
|---|---|
| **Expand / Migrate / Contract** | Decomposing a breaking schema change into additive → transitional → destructive phases, each individually compatible. |
| **Rollback window** | The period after a release during which the previous version must remain deployable. Bounds when destructive cleanup may happen. |
| **Compensating migration** | A new forward operation that corrects a known data error, used instead of reversing a migration. |
| **Pre-image** | A durable copy of data captured *before* a destructive change, so the change becomes reversible. |
| **Backfill** | Batched population of new columns/tables for pre-existing rows. |
| **Dual write** | Writing the same information to both the old and new location during transition. |
| **Shadow / dark read** | Reading both old and new paths, serving the old, and alerting on divergence. |
| **Tolerant reader** | A reader that degrades gracefully on values or fields it doesn't recognize. |
| **Online DDL** | Schema changes applied without blocking reads/writes (`CONCURRENTLY`, `ALGORITHM=INPLACE`, gh-ost). |
| **Lock queue pile-up** | A waiting exclusive-lock DDL blocking every query behind it, turning a fast migration into an outage. |
| **N-1 compatibility** | The rule that every schema state works with both the current and the previous application version. |
| **CDC** | Change data capture — streaming the database's change log to other systems; also an evidence source for recovery. |
| **PITR** | Point-in-time recovery — restoring to an arbitrary timestamp from base backup + WAL/binlog. |
| **RPO / RTO** | Maximum tolerable data loss / maximum tolerable recovery time. |
| **MTTD** | Mean time to detect — the number that must be smaller than your evidence retention. |
