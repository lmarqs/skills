# Review: V42__cleanup_customers.sql

**Verdict: do not merge as-is.** All three statements are unsafe under a rolling deploy, and one of them will almost certainly fail outright at migration time. Details and a safe replacement plan below.

Assumptions: PostgreSQL, Flyway runs migrations before/while the new pods start, and old pods keep serving traffic for ~15 minutes after the migration commits.

---

## Statement-by-statement

### 1. `ALTER TABLE customers RENAME COLUMN full_name TO display_name;`

**Problem: breaks every old pod for the entire ~15-minute rollout window.**

The migration runs once, up front. The moment it commits, `full_name` no longer exists, but old-version pods (still the majority of your fleet at that point) are still issuing `SELECT ... full_name ...` and `INSERT ... (full_name, ...)`. Every one of those queries fails with `column "full_name" does not exist` until the last old pod cycles out. If a pod fails its health check because of this, the rollout can stall or flap with *both* versions erroring.

A rename is never rolling-deploy safe in one step, even though it is metadata-only and instantaneous in Postgres. It must be done expand/contract:

1. **Release N (this PR):** `ALTER TABLE customers ADD COLUMN display_name TEXT;` backfill from `full_name`; app writes **both** columns and reads `display_name` with fallback (or keep both in sync via a trigger during the transition).
2. **Release N+1:** app reads/writes only `display_name`.
3. **Release N+2 (or later migration):** drop `full_name`.

Cheaper alternative if you really want to keep it to two releases: do the rename in a *later* migration that ships **after** all pods already read/write `display_name` via an alias — but plain SQL apps can't alias a column, so in practice the add-column/backfill/dual-write route is the one that works.

### 2. `ALTER TABLE customers ALTER COLUMN phone TYPE VARCHAR(20);`

**Problem 1: full table rewrite under an ACCESS EXCLUSIVE lock.**

Widening a varchar (e.g. 20 → 100) is metadata-only in Postgres, but **narrowing (100 → 20) forces a rewrite of the whole table and its indexes**, holding an `ACCESS EXCLUSIVE` lock the entire time. On a `customers` table of any real size that means all reads and writes block for the duration — and worse, the lock request itself queues behind any long-running query/transaction touching `customers`, and *everything else queues behind the lock request*. That's a full outage vector, independent of the rolling deploy.

**Problem 2: data race on the length check.**

"We checked and nobody has phone numbers that long" is a point-in-time check. Any row inserted or updated with a >20-char value between your check and the migration running makes the `ALTER` fail with a value-too-long error — which (see below) aborts the whole migration.

**Problem 3: it buys you almost nothing.** `VARCHAR(100)` vs `VARCHAR(20)` costs nothing in storage in Postgres (varlena is length-prefixed; padding doesn't exist). This is a cosmetic tightening.

If you genuinely want to enforce the length, do it without a rewrite:

```sql
ALTER TABLE customers
  ADD CONSTRAINT customers_phone_len CHECK (char_length(phone) <= 20) NOT VALID;
-- separate migration / later:
ALTER TABLE customers VALIDATE CONSTRAINT customers_phone_len;  -- SHARE UPDATE EXCLUSIVE only
```

`NOT VALID` + `VALIDATE` enforces the rule for new writes immediately and validates existing rows without blocking traffic. Otherwise, just drop this statement.

### 3. `ALTER TABLE customers ADD COLUMN loyalty_tier VARCHAR(10) NOT NULL;`

**Problem 1: this statement fails outright on any non-empty table.**

`NOT NULL` with no `DEFAULT` means existing rows would violate the constraint, so Postgres rejects it: `column "loyalty_tier" of relation "customers" contains null values`. Since Flyway wraps the migration in a single transaction on Postgres, this failure **rolls back statements 1 and 2 too** — the whole deploy fails at migration time. (Small mercy: that failure would currently protect you from the rename outage.)

**Problem 2: even fixed with a DEFAULT, old pods don't set it.**

During the 15-minute window, old-version pods `INSERT` without `loyalty_tier`. That's only OK if the column has a `DEFAULT` (or is nullable). So `NOT NULL` without a default is doubly wrong here.

Safe pattern:

```sql
-- V42 (ships with dual-compatible app code):
ALTER TABLE customers ADD COLUMN loyalty_tier VARCHAR(10) NOT NULL DEFAULT 'basic';
```

On Postgres 11+ this is metadata-only (no table rewrite): existing rows get the default lazily, new inserts from old pods pick up the default. If a static default is wrong for existing customers, instead add it **nullable**, backfill in batches, then in a later migration:

```sql
ALTER TABLE customers
  ADD CONSTRAINT customers_loyalty_tier_nn CHECK (loyalty_tier IS NOT NULL) NOT VALID;
ALTER TABLE customers VALIDATE CONSTRAINT customers_loyalty_tier_nn;
ALTER TABLE customers ALTER COLUMN loyalty_tier SET NOT NULL;  -- PG12+: uses the validated check, no full scan
ALTER TABLE customers DROP CONSTRAINT customers_loyalty_tier_nn;
```

---

## Cross-cutting issues

- **Schema-first vs. code-second timing.** With rolling updates, every migration must be compatible with *both* the old and new app versions simultaneously. "The app code in this same PR is already updated" doesn't help — the schema change lands ~15 minutes before the code fully does. Treat the old app version as a hard consumer of the schema for the whole window.
- **No lock timeout.** Every `ALTER TABLE` here takes `ACCESS EXCLUSIVE`. Prepend to DDL migrations:

  ```sql
  SET lock_timeout = '5s';
  SET statement_timeout = '60s';  -- for the DDL session
  ```

  so a blocked lock request fails fast (and Flyway retries/you rerun) instead of stalling all traffic behind it.
- **Rollback story.** If the deploy is rolled back mid-rollout, old code returns but the rename has already happened — the rollback is also broken. Expand/contract fixes this for free: the old schema keeps working throughout.
- **Misc:** the filename says "cleanup" but this bundles three unrelated, individually risky changes. Split them so a failure in one doesn't roll back or block the others.

---

## Suggested replacement

**V42 (ship with this PR; app code dual-writes `full_name`/`display_name`, reads `display_name` with fallback, tolerates `loyalty_tier` default):**

```sql
SET lock_timeout = '5s';

ALTER TABLE customers ADD COLUMN display_name TEXT;          -- or VARCHAR to match
UPDATE customers SET display_name = full_name WHERE display_name IS NULL;  -- batch if table is large
ALTER TABLE customers ADD COLUMN loyalty_tier VARCHAR(10) NOT NULL DEFAULT 'basic';
ALTER TABLE customers
  ADD CONSTRAINT customers_phone_len CHECK (char_length(phone) <= 20) NOT VALID;
```

(For a large table, move the backfill out of the migration into a batched job, and add a sync trigger for writes from old pods.)

**V43 (next release, after all pods read/write `display_name`):**

```sql
SET lock_timeout = '5s';

ALTER TABLE customers VALIDATE CONSTRAINT customers_phone_len;
ALTER TABLE customers DROP COLUMN full_name;
```

This sequence is safe at every intermediate point: either app version works against either schema state, no statement rewrites the table, and a rollback mid-deploy leaves everything functional.
