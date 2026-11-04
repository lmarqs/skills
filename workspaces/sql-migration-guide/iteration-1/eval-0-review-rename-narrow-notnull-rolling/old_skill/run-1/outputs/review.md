# Review: `V42__cleanup_customers.sql`

**Verdict: do not merge as written.** All three statements are unsafe under a rolling deploy, and
one of them discards information permanently. Split this into staged deployments (plan below).

**Assumptions** (not stated in the PR; each one changes details, not the verdict):

- Engine is PostgreSQL (the `RENAME COLUMN` / `ALTER COLUMN ... TYPE` syntax matches it). Engine-specific notes for MySQL are called out where behavior differs.
- Flyway runs before or at the start of the rollout (init container, pre-deploy job, or first new pod on startup), so the new schema exists while v1 pods are still serving traffic for the ~15-minute rollout.
- `customers` is non-empty and receives inserts/updates during the rollout.
- You want to keep the option of redeploying v1 for some period after release (the rollback window). Until that window closes, v1 counts as "in traffic".

## Findings (most severe first)

### 1. `ALTER COLUMN phone TYPE VARCHAR(20)` — narrowing, lossy, breaking

- **Class:** breaking. Narrowing a type discards information; widening back to `VARCHAR(100)` restores the shape, not the values. A Flyway undo/down migration cannot recover them.
- **"We checked" is not enough evidence.** A check only covers the rows that existed when you ran it, and only if it ran against production. It does not cover:
  - rows written between the check and the migration;
  - writes from the v1 pods during the 15-minute rollout, which still accept up to 100 characters;
  - writes from v1 after a rollback, for the whole rollback window;
  - other consumers of this table (imports, admin tools, other services), if any.
  Realistic phone values exceed 20 characters: `+1 (555) 123-4567 ext. 1234` is 27.
- **Failure modes:**
  - PostgreSQL: if any existing value is longer than 20, the `ALTER` fails with `value too long`. After it succeeds, every v1 write longer than 20 fails. Shrinking a `VARCHAR` also rewrites or scans the table under an `ACCESS EXCLUSIVE` lock, which blocks all reads and writes on `customers` for the duration. (Inference: the lock cost depends on table size, which the PR doesn't give.)
  - MySQL in non-strict mode: over-long values are **silently truncated**. You lose data with no error, which is the worst case.
- **Question to answer first:** what does narrowing buy you? If the goal is validation, enforce it in the application, or add `CHECK (char_length(phone) <= 20) NOT VALID`, then `VALIDATE CONSTRAINT` once you've checked production data. That gives the same guarantee without discarding anything and can be removed instantly. If you really need the type change, use Expand–Migrate–Contract: add `phone_v2 VARCHAR(20)`, backfill it with validation that reports rows that don't fit instead of truncating them, then contract.

### 2. `RENAME COLUMN full_name TO display_name` — breaking for the entire rollout

- **Class:** breaking. A v1 query that touches `full_name` fails the moment the migration commits.
- **Failure scenario:** for about 15 minutes, every v1 pod still serving traffic errors on every read or write of `customers` that names `full_name`. That likely covers most customer-facing paths. Redeploying v1 to roll back fails the same way, because v1 cannot run against this schema at all. Rollback would mean writing a reverse-rename migration under incident pressure.
- The fact that the app code in this PR uses `display_name` everywhere is exactly the problem: v2 does not work on the old schema and v1 does not work on the new one, so no version works across the transition.
- **Staged alternative:** Expand–Migrate–Contract (see the plan below).

### 3. `ADD COLUMN loyalty_tier VARCHAR(10) NOT NULL` — fails on existing rows, then breaks v1 inserts

- **Class:** conditionally compatible. In this form, the conditions are not met.
- **Existing rows:** in PostgreSQL, adding a `NOT NULL` column with no default to a non-empty table fails (`column "loyalty_tier" contains null values`). In practice this statement will likely fail in production even if it passed against an empty dev or CI database. In MySQL, existing rows silently get `''`, which is a value your domain probably considers invalid.
- **Rolling window:** even with existing rows handled, v1 pods don't set `loyalty_tier`, so every v1 insert fails for the ~15-minute rollout and after any rollback. The fact that v2 sets it on every insert doesn't help v1.
- **Staged alternative:** add it nullable, or with a database default that is a valid tier (for example `DEFAULT 'standard'`, if such a tier exists; that needs a product decision). Deploy v2 so it always writes the column, backfill existing rows, verify, then `SET NOT NULL` in a later migration. On PostgreSQL ≥ 12 on a large table, add `CHECK (loyalty_tier IS NOT NULL) NOT VALID`, `VALIDATE` it, then `SET NOT NULL`. This avoids a long full-table scan under an exclusive lock.
- **Open question:** what tier should the existing customers get? That is a business decision the migration currently makes implicitly, or fails to make.

### 4. The set: one migration, mixed concerns, partial-application risk

- PostgreSQL runs a Flyway migration in one transaction, so if statement 3 fails, the whole of V42 rolls back. That is the good outcome, because the deploy fails loudly.
- MySQL DDL is not transactional. A failure partway through leaves the rename (and possibly the narrowing) applied, Flyway marks V42 as failed, and v1 is broken against a half-migrated schema.
- Each change has a different rollback story, so each needs its own migration and deployment.

## Pre-deployment checklist, as applied to this PR

| # | Question | Answer for V42 as written |
|---|---|---|
| 1 | Can v1 run against the new schema? | **No.** The rename breaks all `full_name` access; `NOT NULL` breaks v1 inserts; the narrowing breaks v1 writes over 20 chars. |
| 2 | Can v1 and v2 run at the same time? | **No.** Same reasons, for the full ~15 min. |
| 3 | Does it delete or transform information? | **Yes:** `phone` narrowing. No copy of the original values is kept. |
| 4 | Safe to run more than once? | Not applicable as one Flyway version. The staged backfills below must be idempotent. |
| 5 | Can a backfill stop and resume? | No backfill exists. The staged plan needs two: `display_name` and `loyalty_tier`. |
| 6 | How is the resulting data verified? | Not specified. |
| 7 | Can new behavior be disabled without a schema revert? | No. There is no flag, and the schema change is itself the behavior change. |
| 8 | Recovery path if data is wrong? | None for truncated or rejected `phone` values. The original is gone. |
| 9 | When does destructive cleanup happen? | Immediately, in the same deployment (the rename effectively drops `full_name`). |
| 10 | Interacting migrations/releases? | Unknown. Confirm nothing else touches `customers` in this release. |

## Recommended staged plan

Each step is a separate deployment that is compatible with every version in traffic during it.

**Deploy 1: Expand (schema only, plus v1 code unchanged)**

```sql
-- V42__expand_customers.sql
ALTER TABLE customers ADD COLUMN display_name VARCHAR(<same length as full_name>) NULL;
ALTER TABLE customers ADD COLUMN loyalty_tier VARCHAR(10) NULL;   -- or DEFAULT '<valid tier>'
-- phone: no change. If you want the 20-char limit, add it as a constraint (see Deploy 4).
```

Rollback: v1 ignores both columns. Dropping them is safe because nothing writes to them.

**Deploy 2: Migrate (code)**

- Write `full_name` **and** `display_name`. Read `display_name` and fall back to `full_name` when it is null.
- Always write `loyalty_tier`.
- Optional: put the read switch behind a feature flag so it can be turned off without a schema change.
- Rollback: redeploying v1 is safe. v1 ignores the new columns, and the fallback read handles rows written by either version.

**Deploy 3: Migrate (data): batched, idempotent backfills**

```sql
-- repeat until 0 rows affected; the IS NULL predicate makes retries no-ops
UPDATE customers SET display_name = full_name
WHERE id IN (SELECT id FROM customers WHERE display_name IS NULL AND full_name IS NOT NULL LIMIT 1000);

UPDATE customers SET loyalty_tier = '<agreed default tier>'
WHERE id IN (SELECT id FROM customers WHERE loyalty_tier IS NULL LIMIT 1000);
```

- Requirements: small batches with no long transaction, progress recorded so a crash resumes the job, and metrics for total, processed, remaining, failed, and retries.

**Verify before going further** (these queries are the evidence, not the migration's exit code):

```sql
SELECT COUNT(*) FROM customers WHERE display_name IS NULL AND full_name IS NOT NULL;   -- expect 0
SELECT COUNT(*) FROM customers WHERE display_name IS DISTINCT FROM full_name;          -- expect 0 while dual-writing
SELECT COUNT(*) FROM customers WHERE loyalty_tier IS NULL;                             -- expect 0
SELECT COUNT(*) FROM customers WHERE char_length(phone) > 20;                          -- run against production, now
```

**Deploy 4: Contract (code + tighten)**

- Read and write only `display_name`. **Keep `full_name` in place.**
- Tighten `loyalty_tier` with `CHECK (loyalty_tier IS NOT NULL) NOT VALID`, then `VALIDATE CONSTRAINT`, then `ALTER COLUMN loyalty_tier SET NOT NULL`. This is safe because every version in traffic (Deploy 2 and later) writes it.
- `phone`, if the limit is still wanted and the count above is 0: `ADD CONSTRAINT phone_len CHECK (char_length(phone) <= 20) NOT VALID`, then `VALIDATE CONSTRAINT phone_len`. Do this only after every version in traffic enforces the limit in the application. Otherwise v1/v2 writes over 20 characters start failing.
- Rollback: redeploy the Deploy 2 version at any point in the window. The constraint additions can be dropped without data loss.

**Deploy 5: Cleanup (after the rollback window plus verification; put a date and an owner on it now)**

```sql
ALTER TABLE customers DROP COLUMN full_name;
```

- Proceed only after confirming that no version reads or writes `full_name` (code search plus statement stats), the backfill converged, and the rollback window expired. This is the only irreversible step, so it runs last and on its own.
- Narrowing `phone`'s type is not needed if the `CHECK` constraint already exists. If you still want the `VARCHAR(20)` type, do it here as its own migration, after the constraint proves no value exceeds 20, and plan for the table lock.

## Before merging, please confirm

1. The engine and how Flyway is triggered relative to the rollout (pre-deploy job vs. on pod start).
2. The `customers` row count and write rate. These size the backfill batches and the lock risk of any type change.
3. The tier value existing customers should get.
4. Whether the `phone` length check ran against production and when. Also why the type must shrink, rather than being validated.
5. Whether anything other than this service reads or writes `customers`.
