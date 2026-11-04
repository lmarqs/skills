# Review: `V42__cleanup_customers.sql`

## Verdict: do not merge as written

None of the three statements can ship in one step under a rolling deploy. Each one breaks
something on its own:

1. **`RENAME COLUMN`** breaks every v1 pod the moment it commits, for the whole ~15-minute
   rollout. It also makes rollback to v1 impossible.
2. **`ADD COLUMN loyalty_tier ... NOT NULL`** with no default fails outright on PostgreSQL if
   `customers` has any rows. If it does apply, every v1 insert fails during the rollout.
3. **`ALTER COLUMN phone TYPE VARCHAR(20)`** narrows the column, so it can lose data. It
   rewrites the table under an exclusive lock, and it rejects any write longer than 20
   characters from code that still accepts 100.

The fix is to split this into staged deployments (Expand–Migrate–Contract). The plan is at
the end of this review.

## Assumptions (please correct if wrong)

- **Engine:** PostgreSQL 12 or later, which is common for Flyway users. MySQL 8 behaves
  differently in ways that matter; each finding notes the difference.
- **Migration timing:** Flyway runs either at app startup (the Spring Boot default) or as a
  pre-deploy job/step, before or as the first v2 pods start. Either way, v1 pods keep serving
  against the new schema for about 15 minutes. If you need rollback to v1, that mixed state
  lasts until you decide rollback is no longer an option.
- **Rollback target:** the previous release (v1) has to stay deployable for some window after
  this release.
- **Table size:** unknown. Lock and rewrite costs below grow with the row count of
  `customers`.
- **Other writers:** there may be other code paths besides this service that touch
  `customers`, such as admin tools, batch jobs, other services or ETL. This needs confirming.

## Findings, ordered by severity

### 1. `phone` narrowing: data loss and outage risk (destroys information)

`ALTER TABLE customers ALTER COLUMN phone TYPE VARCHAR(20);`

- **Reversibility (data loss):** widening back to `VARCHAR(100)` gives back the capacity, not
  the characters. On PostgreSQL the `ALTER` fails with `value too long for type character
  varying(20)` if any row is longer than 20. That is the better outcome. On MySQL in non-strict
  mode the values are cut short without any error. There is no copy of the original values
  anywhere.
- **"Nobody has phone numbers that long, we checked."** This is an unverified claim until a
  query in this PR shows otherwise. Formatted numbers with extensions or notes go past 20
  easily, e.g. `+55 (11) 91234-5678 ext. 1234`. Run this on production and post the result:

  ```sql
  SELECT count(*), max(length(phone)) FROM customers WHERE length(phone) > 20;  -- expect 0
  ```

- **Compatibility:** v1, and v2 too unless its validation was changed, still accepts up to 100
  characters. During the rollout and afterwards, any write between 21 and 100 characters
  becomes a runtime error. Writes from other clients can fail the same way. The PR doesn't
  mention a limit on the app side.
- **Availability:** making a `varchar` shorter is not a binary-coercible change. PostgreSQL
  rewrites (or at least fully scans) `customers` and rebuilds any index on `phone`, all while
  holding `ACCESS EXCLUSIVE`, so every read and write on the table is blocked. MySQL needs
  `ALGORITHM=COPY`, which blocks writes. Check the exact behavior for your version.
- **What you gain:** nothing that a constraint can't do without the risk. Recommendation: skip
  the type change. Enforce the limit with a constraint you can validate online (step 6 of the
  plan). Change the type later only if there's a real reason to.

### 2. `RENAME COLUMN`: breaks v1 for the whole rollout and removes rollback

`ALTER TABLE customers RENAME COLUMN full_name TO display_name;`

- **Compatibility:** v1 pods query `full_name`. Once the rename commits, every v1 query
  touching that column fails until the last v1 pod is gone (~15 minutes). If Flyway runs after
  some v2 pods have started, those v2 pods fail until it finishes. One of the two versions is
  broken during the deploy whichever way you order it.
- **Rollback:** going back to v1 after this runs means an outage, unless someone renames the
  column back by hand. Reversing DDL in the middle of an incident is a second risky migration.
- **Old code and the rename in one PR:** the PR's app code uses only `display_name`. That
  guarantees the (v1 code, new schema) failure. It also means v2 can't run against the old
  schema if the migration is late or fails.
- **What else holds the old name:** views, functions, triggers, ETL/BI queries, CDC or logical
  replication consumers, and cached prepared statements. JDBC pools can raise `cached plan must
  not change result type`. Before any rename, list them, e.g. with `pg_depend` or a search of
  `pg_stat_statements` and the downstream repos.
- **Availability:** the rename only touches the catalog. Even so, it needs `ACCESS EXCLUSIVE`.
  Without `lock_timeout`, one long transaction on `customers` makes the `ALTER` wait, and
  every query that arrives after it queues behind it.

### 3. `ADD COLUMN loyalty_tier VARCHAR(10) NOT NULL`: fails or breaks v1 inserts

- **Fails on PostgreSQL:** if `customers` has any rows, PostgreSQL rejects adding a `NOT NULL`
  column with no default (`column "loyalty_tier" ... contains null values`). On PostgreSQL the
  whole V42 runs in one transaction, so it rolls back cleanly. The release then fails at the
  migration step, or at pod startup if Flyway runs on boot.
- **If the table is empty, or on MySQL:** MySQL fills existing rows with the implicit default
  `''`, which is a meaningless tier on every existing customer. After that, v1 pods inserting
  without `loyalty_tier` fail (`Field 'loyalty_tier' doesn't have a default value` in strict
  mode). "The app sets it on every insert" only holds for v2. It doesn't hold for v1 pods
  during the rollout, for v1 after a rollback, or for other writers.
- **Product question you didn't answer:** what tier should existing customers get? This
  decides the backfill. A constant default such as `'standard'` is only acceptable if a table
  where v1 pods have stamped that value means something real.

### 4. The set as a whole

- **One deploy, three breaking changes:** every reachable state is broken. That includes
  (v1, new schema) during the rollout and the rollback window, and (v2, old schema) if the
  migration is late or fails.
- **MySQL only:** DDL isn't transactional, and each `ALTER` commits as it runs. If statement 2
  or 3 fails, V42 is left half-applied: the rename is done, Flyway marks V42 failed, and you
  need a manual fix plus `flyway repair` with v1 already broken. On PostgreSQL the transaction
  saves you here.
- **PostgreSQL:** one transaction keeps `ACCESS EXCLUSIVE` from the rename through the end of
  the `phone` rewrite. On a large table that blocks all reads and writes for the full rewrite.
- **No `lock_timeout` or `statement_timeout`:** add `SET lock_timeout = '3s'; SET
  statement_timeout = ...;` to every DDL migration on a live table, and retry with backoff.
- **No recovery path, no verification, no cleanup date:** the pre-deployment checklist can't be
  answered for this PR. See the list at the end.

## Recommended staged plan

Each numbered step is its own deployment or operation. "v1" is the current release.

| # | What runs | Code live | Lock / cost | Verify before moving on | Rollback target |
|---|---|---|---|---|---|
| 1 | **V42 (expand):** `ADD COLUMN display_name VARCHAR(n) NULL` (same type as `full_name`); `ADD COLUMN loyalty_tier VARCHAR(10) NULL`; sync trigger (below). With `lock_timeout`. | v1 | Catalog-only adds; brief `ACCESS EXCLUSIVE` | Columns and trigger exist; no lock waits logged | v1 (leave the columns in place) |
| 2 | **Deploy v2:** reads `COALESCE(display_name, full_name)` (new column first), writes **both** columns, sets `loyalty_tier` on every insert | v1 + v2 | none | 100% of pods on v2; error rate flat | v1 |
| 3 | **Backfill** `display_name` from `full_name`, and `loyalty_tier` with the product-approved value, in keyset batches by `id`, throttled on replica lag, resumable | v2 | Row locks per batch only | `SELECT count(*) FROM customers WHERE display_name IS DISTINCT FROM full_name;` = 0; `SELECT count(*) FROM customers WHERE loyalty_tier IS NULL;` = 0 (primary and read replicas) | v1 still works |
| 4 | **V43 (enforce):** `ADD CONSTRAINT customers_loyalty_tier_nn CHECK (loyalty_tier IS NOT NULL) NOT VALID;` then `VALIDATE CONSTRAINT customers_loyalty_tier_nn;` then `ALTER COLUMN loyalty_tier SET NOT NULL;` (skips the scan on PG 12+), optionally drop the check. Only after v1 is out of the rollback window, because v1 doesn't write `loyalty_tier`. | v2 | Short exclusive lock; validate takes `SHARE UPDATE EXCLUSIVE` (reads and writes continue) | `\d customers` shows `NOT NULL` | v2 |
| 5 | **Deploy v3:** reads and writes `display_name` only. First make `full_name` nullable (or have the trigger fill it), otherwise v3 inserts fail if `full_name` is `NOT NULL`. | v2 + v3 | none | Errors flat; the step 3 convergence query still 0 for rows v2 wrote | v2 (not v1 from here on) |
| 6 | **Phone, separately:** run the length query above. Make the app enforce ≤ 20 first. Then `ADD CONSTRAINT customers_phone_len CHECK (length(phone) <= 20) NOT VALID;` and `VALIDATE CONSTRAINT customers_phone_len;`. If any rows are longer, decide what happens to them, copy them into a backup table before changing anything, then transform them. | v2/v3 | Online validation | Validation succeeds; no write errors on `phone` | Drop the constraint (fully reversible) |
| 7 | **Cleanup (contract):** after the rollback window, and only after proving nothing reads `full_name` (`pg_stat_statements`, ETL/BI, other services), drop the trigger, then `ALTER TABLE customers DROP COLUMN full_name;`. Set a date now and open the ticket during step 1. | v3 | Catalog-only drop, brief exclusive lock | Drop preconditions recorded on the ticket | Forward only |

Sync trigger for step 1 (PostgreSQL). It covers v1 and any writer that only knows about
`full_name`:

```sql
CREATE FUNCTION customers_sync_display_name() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.display_name := COALESCE(NEW.display_name, NEW.full_name);
  ELSIF NEW.full_name IS DISTINCT FROM OLD.full_name
        AND NEW.display_name IS NOT DISTINCT FROM OLD.display_name THEN
    NEW.display_name := NEW.full_name;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER customers_sync_display_name
BEFORE INSERT OR UPDATE ON customers
FOR EACH ROW EXECUTE FUNCTION customers_sync_display_name();
```

**Changes to this PR:** replace V42 with step 1 only. Change the app code to read with
fallback and write both columns (step 2) instead of using `display_name` only. Move the
`phone` change out of this PR.

## Checklist questions this PR leaves open (findings)

1. **Can v1 run against the new schema?** No. The rename and the `NOT NULL` add both break it.
2. **Can v1 and v2 run side by side?** No, for the ~15-minute rollout.
3. **Does it destroy information?** The `phone` narrowing can. There's no copy of the
   original values.
4. **Engine and version, and table size of `customers`?** Needed to confirm the lock and
   rewrite cost.
5. **When does Flyway run: app boot (with how many replicas) or a separate job?** This decides
   which version breaks.
6. **What should existing customers' `loyalty_tier` be?** This is a product decision.
7. **What else reads `full_name` or `customers`?** Views, ETL/BI, other services, CDC,
   caches.
8. **How will the result be verified, and what is the recovery path?** Neither is defined.
9. **When is `full_name` dropped, and what has to be proven first?** Not defined.
10. **Has the previous release's test suite been run against the new schema?** Doing so would
    have caught all three problems.
