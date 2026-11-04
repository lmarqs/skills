# Migration plan: split `users.name` into `first_name` + `last_name`

**Verdict:** you can't do this in one deployment. It takes five releases and one background
backfill, staged as Expand–Migrate–Contract. `name` stays the source of truth until a
verified cutover. Dropping it is the last step, and it only runs once the preconditions in
§6 hold. A database trigger keeps the columns in sync, so writers that don't use the new
model code are covered too (old pods, `QuerySet.update()`, admin, raw SQL, other
services). No step takes a lock longer than a catalog change. The one long-running piece
is the backfill, which runs in bounded, throttled batches.

## 0. Assumptions and open questions

The prompt doesn't cover these. Each one changes the plan if it's wrong. Get answers before
step 1.

| # | Assumption | Why it matters | If wrong |
|---|---|---|---|
| A1 | RDS PostgreSQL **13 or newer** | Lock and rewrite behavior below is checked against PG 16 and is the same from PG 12/13 up | On 11 or older, re-check `SET NOT NULL` and `EXECUTE FUNCTION` |
| A2 | `users.id` is an integer/bigint PK with few gaps | Keyset backfill by PK range | UUID PK: select the next N keys by `id > :last ORDER BY id LIMIT N` |
| A3 | `name` is `varchar(255) NOT NULL` (Django `CharField`) | New columns use the **same `max_length`**, so a split part can never overflow | Match whatever the real type is |
| A4 | `manage.py migrate` runs **once, as a pre-deploy pipeline step**, before any new pod starts, and a failed migrate stops the rollout | Gives every step its "migrated before deployed" ordering | If pods migrate at boot, move it into a job first. A slow DDL racing across pods is its own incident |
| A5 | The model isn't Django's `AbstractUser` | `AbstractUser` already has `first_name`/`last_name` | Reuse or rename those, and re-plan |
| A6 | Split rule: trim, collapse whitespace, **first token → `first_name`, rest → `last_name`**. A single-token name gives `last_name = ''` | Sets the backfill output for 40M rows | **This is a product decision, not an engineering one.** "Mary Ann Smith", "van der Berg", mononyms, family-name-first locales and suffixes ("Jr.") all split wrong under a naive rule. Get sign-off on the rule and on the ambiguous-row report from step 2 |
| A7 | Rolling deploy takes well under an hour. Rollback window = **14 days**, extended to cover one month-end | Sets the soak dates | Lengthen if mobile clients read an API `name` field (see A8) |
| A8 | Unknown: who else reads `users.name` (ETL/BI, DMS/Debezium/CDC, search index, other services, mobile API clients, cached/pickled `User` objects) | Each one is a reader that a grep of `main` won't find | Inventory before step 1. **Open finding** |
| A9 | Unknown: read replicas, logical replication, storage type (gp2 burst vs gp3/io1) | Sets the backfill throttle signals | Wire whichever exist into the throttle |

Open checklist findings: consumer inventory (A8), split rule sign-off (A6), backfill
throughput measured on a clone (step 0), and whether the previous release's test suite has
been run against the new schema (step 0).

## 1. The change

- **Table:** `users`, about 40M rows, the hottest table in the product.
- **Target:** two new columns, `first_name` and `last_name`. `name` is dropped after cutover.
- **Nature:** splitting a column (the "not deployable in one step" class). Turning
  `name` into two parts is **lossy**: whitespace and the original token grouping are not
  recoverable from `first_name || ' ' || last_name`. Once users can enter first and last
  names separately, the parts carry information `name` never had. So `name` is the pre-image
  until the end, and it's archived before the drop.

## 2. Risks

| Risk | Assessment |
|---|---|
| **Availability** | Every DDL step is catalog-only and takes a brief `ACCESS EXCLUSIVE` or `SHARE ROW EXCLUSIVE` lock. The real danger on a hot table is the **lock queue**: one long transaction on `users` plus one waiting `ALTER` blocks every query. Every migration sets `lock_timeout = '3s'` and is retried. The backfill rewrites 40M rows, which means WAL volume, replica lag, dead tuples and index bloat (every non-HOT update adds entries to every index on `users`), plus CDC fan-out. It's throttled and observable |
| **Compatibility** | Old pods keep writing only `name` throughout the rollout and the rollback window. The forward trigger derives the parts for them. After contract, new code writes only the parts, and the reverse trigger keeps `name` filled for the rollback target. Django lists columns explicitly in `SELECT`/`INSERT`, so adding nullable columns is safe for old code. **Check raw SQL for `SELECT * FROM users` and positional decoding** |
| **Reversibility** | Adding columns and triggers is R0 (free to undo). The backfill writes only the new columns, so `name` is untouched (R0/R1). Dropping `name` is **R3** (destroys information) because the split is lossy. It becomes R2 (recoverable from evidence) once the archive table and snapshot in §6 exist |

## 3. Steps

Version labels: **v1** = today's app. **v2** = Expand release (model knows the columns,
nothing reads them). **v3** = dual-aware release. **v4** = contract-code release (model no
longer has `name`).

Every Django migration that runs DDL on `users` starts with:

```python
migrations.RunSQL("SET LOCAL lock_timeout = '3s'; SET LOCAL statement_timeout = '30s';",
                  migrations.RunSQL.noop),
```

On a lock timeout the pipeline retries migrate with backoff, up to 5 times. If it still
can't get the lock, look in `pg_stat_activity` for transactions older than a few seconds
that touch `users`, deal with them, then retry. Never raise the timeout.

### Step 0. Preparation (no deploy)

1. Consumer inventory for `users.name` across every deployed repository and version, raw
   SQL, Django admin `search_fields`/`ordering`, serializers and API responses, ETL/BI,
   CDC/DMS/Debezium, search indexes, caches, and other services that query the DB. Record
   the list in the tracking issue.
2. Product sign-off on the split rule (A6).
3. **Rehearse on a clone**: restore the latest RDS snapshot to a separate instance of the
   same class. Run steps 1–2 and record: lock wait and hold for each DDL, backfill rows/s at
   batch 1000 and 5000, p99 batch time, WAL generated, table and index growth, and trigger
   overhead on `UPDATE users` p99. Put the measured numbers into this plan. Illustrative
   arithmetic only: 40M rows at 5,000 rows/s ≈ 2.2 h, at 1,000 rows/s ≈ 11.1 h.
4. CI compatibility job: run **v1's test suite against the schema after every migration in
   this plan up to step 7**. It must pass. Also add a parity test that checks the Python
   split helper against `users_split_name()` on a sample of production-shaped names.
5. Open the cleanup ticket now, with the drop SQL, the §6 preconditions and the earliest date.

### Step 1. Release v2: Expand (schema only)

Migration `00NN_users_split_name_expand` (atomic):

- `AddField` `first_name` and `last_name`: `CharField(max_length=255, null=True,
  blank=True)`. **No default and not `NULL`-constrained.** Confirm with `manage.py
  sqlmigrate` that the output is a plain `ADD COLUMN ... NULL`. A Django default would
  turn it into `ADD COLUMN ... DEFAULT ... NOT NULL`, which is the wrong shape here.
- `RunSQL` creating the split function and the **forward** sync trigger (tested on PG 16):

```sql
CREATE FUNCTION users_split_name(n text, OUT first_name text, OUT last_name text)
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT split_part(t, ' ', 1), substr(t, length(split_part(t, ' ', 1)) + 2)
  FROM (SELECT regexp_replace(btrim(n, E' \t\r\n'), '\s+', ' ', 'g') AS t) s
$$;

CREATE FUNCTION users_sync_name() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.first_name IS NULL AND NEW.last_name IS NULL AND NEW.name IS NOT NULL THEN
      SELECT s.first_name, s.last_name INTO NEW.first_name, NEW.last_name
      FROM users_split_name(NEW.name) s;
    END IF;
  ELSIF NEW.name IS DISTINCT FROM OLD.name                 -- a writer changed name ...
    AND NEW.first_name IS NOT DISTINCT FROM OLD.first_name -- ... without touching the parts
    AND NEW.last_name  IS NOT DISTINCT FROM OLD.last_name THEN
      SELECT s.first_name, s.last_name INTO NEW.first_name, NEW.last_name
      FROM users_split_name(NEW.name) s;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER users_sync_name BEFORE INSERT OR UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION users_sync_name();

COMMENT ON COLUMN users.name IS
  'DEPRECATED: replaced by first_name/last_name; drop per cleanup ticket <link>';
```

The trigger has no `UPDATE OF name` column list on purpose. A column list would create a
dependency that blocks the later `DROP COLUMN`.

| | |
|---|---|
| Code live | v1 → v2 rolling. v2 only declares the fields |
| Locks | `ADD COLUMN`: `ACCESS EXCLUSIVE`, catalog-only, milliseconds once granted. `CREATE TRIGGER`: `SHARE ROW EXCLUSIVE` (verified), which blocks writes for milliseconds. Both go through `lock_timeout` |
| Verify | Columns and trigger exist. After 10 minutes, `SELECT count(*) FROM users WHERE id > :max_id_before_deploy AND first_name IS NULL AND last_name IS NULL AND name IS NOT NULL` returns **0**. `users` write p99 is within noise of the baseline |
| Rollback target | v1 (schema-compatible). If the trigger misbehaves: `DROP TRIGGER users_sync_name ON users` (brief lock). Leave the columns alone |

### Step 2. Backfill (operation, not a deploy)

This can start once step 1 is verified, because the trigger already covers new writes. Run
it as a Django management command from a single worker, with a durable checkpoint and a
pause switch:

```sql
CREATE TABLE IF NOT EXISTS migration_progress (
  migration_id text PRIMARY KEY, last_id bigint NOT NULL, processed bigint NOT NULL DEFAULT 0,
  failed bigint NOT NULL DEFAULT 0, updated_at timestamptz NOT NULL DEFAULT now());

-- one batch, own transaction; checkpoint row updated in the same transaction
SET LOCAL lock_timeout = '2s'; SET LOCAL statement_timeout = '10s';
UPDATE users u
SET    (first_name, last_name) = (SELECT s.first_name, s.last_name FROM users_split_name(u.name) s)
WHERE  u.id >  :last_id
  AND  u.id <= :last_id + :batch            -- start 1000; tune from the rehearsal
  AND  u.first_name IS NULL AND u.last_name IS NULL AND u.name IS NOT NULL;  -- idempotency guard
UPDATE migration_progress SET last_id = :last_id + :batch, processed = processed + :rowcount,
       updated_at = now() WHERE migration_id = 'users_split_name';
```

- The backfill leaves `name` unchanged, so the trigger does nothing on these rows
  (verified). The PK range walk uses the primary key index, so no extra index is needed.
- Don't use `SKIP LOCKED` with a single moving cursor, because locked rows would fall behind
  it. A batch that hits `lock_timeout` (rows hot in the app) is retried with backoff, then
  halved, then parked in a `migration_failures` table. The final sweep (step 3) catches
  them.
- **Throttle** between batches. Back off exponentially when RDS `ReplicaLag` > 5 s,
  `CPUUtilization` > 70%, `BurstBalance` falls (gp2), `DiskQueueDepth` rises, `users` p99
  goes over SLO, or a replication slot's lag grows (`OldestReplicationSlotLag`). Pause
  entirely during peak hours if the rehearsal shows contention.
- **Bloat:** before starting, set `ALTER TABLE users SET (autovacuum_vacuum_scale_factor =
  0.01, autovacuum_vacuum_cost_limit = 2000)` (`SHARE UPDATE EXCLUSIVE`, doesn't block reads
  or writes), and reset it afterwards. Check that `FreeStorageSpace` has room for roughly
  2× the size of `users` plus its indexes. Run `VACUUM (ANALYZE) users` at the end.
- **CDC:** if Debezium/DMS/logical replication streams `users`, the backfill sends about 40M
  update events downstream. Warn consumers and size them for it. Add the new columns to any
  logical-replication subscriber *before* step 1.
- **Metrics:** processed, remaining, failed, rate, ETA, cursor position, batch p99, throttle
  state, plus an alert when there's been no progress for 10 minutes while running.

| | |
|---|---|
| Code live | v2 (v1 still a safe rollback) |
| Locks | Row locks on ≤ `batch` rows per transaction, held under a second |
| Rollback | Pause the job. `name` was never touched. If the transform turns out wrong, fix `users_split_name` and re-run forward over the affected rows. Never "reverse" a backfill |

### Step 3. Verify the backfill (gate, run on the primary and on read replicas)

```sql
-- completeness (also the final sweep: re-run the batch loop from id 0 if > 0)
SELECT count(*) FROM users
WHERE first_name IS NULL AND last_name IS NULL AND name IS NOT NULL;            -- expect 0

-- convergence: parts recompose to the normalized name
SELECT count(*) FROM users
WHERE regexp_replace(btrim(name, E' \t\r\n'), '\s+', ' ', 'g')
      IS DISTINCT FROM btrim(concat_ws(' ', first_name, last_name));           -- expect 0

-- ambiguity report for product (not a pass/fail)
SELECT count(*) FILTER (WHERE last_name = '')            AS single_token,
       count(*) FILTER (WHERE last_name LIKE '% %')      AS three_plus_tokens,
       count(*) FILTER (WHERE name ~ '[^\x00-\x7F]')     AS non_ascii
FROM users;
```

These are full scans of 40M rows, so run them on a replica or off-peak. Also check that
`migration_failures` is empty or that every row in it is resolved. Proceed only when all of
the above holds.

### Step 4. Release v3: dual-aware code

- **Writes:** every write path sets all three fields consistently. If the user edits first
  and last, set `name = f"{first} {last}".strip()`. If a legacy path sets `name`, derive the
  parts with the Python helper that matches `users_split_name`. The trigger remains the
  safety net.
- **Reads:** behind flag `users_split_name_reads`, read `first_name`/`last_name`, falling
  back to the helper applied to `name` when both are `NULL`. With the flag off, behavior is
  identical to v1.
- **Input:** behind flag `users_split_name_input`, forms and APIs accept separate first and
  last names. **Keep emitting `name` in API responses**, composed from the parts, for old
  mobile clients.
- **Ramp:** turn on reads for internal users, then 10% / 50% / 100%. While input is still
  off, shadow-compare the read value against `name` and emit a divergence metric (expect 0).
  Then ramp input the same way.

| | |
|---|---|
| Code live | v2 + v3 |
| Locks | None (no migration) |
| Verify | Divergence metric at 0 while input is off. After input ramps, the step 3 convergence query still returns 0 (v3 keeps `name` = composed parts) |
| Rollback target | Flag off first. Then redeploy v2, which is safe because `name` is complete and authoritative. Known degradation: if a v1/v2 writer later edits `name` on a row with a user-entered split, the trigger re-derives the parts and the user's split is lost |

### Step 5 (optional). Make the parts `NOT NULL`

Do this only if A3 holds (`name` is never `NULL`), and only after step 3. **Don't** let
Django `AlterField(null=False)` emit `SET NOT NULL` directly: on 40M rows that's a full scan
under `ACCESS EXCLUSIVE`, which means an outage. Use `SeparateDatabaseAndState`. The state
side is `AlterField(null=False)`. The database side, run in three separate migrations:

```sql
ALTER TABLE users ADD CONSTRAINT users_first_name_nn CHECK (first_name IS NOT NULL) NOT VALID;  -- brief lock
ALTER TABLE users VALIDATE CONSTRAINT users_first_name_nn;  -- SHARE UPDATE EXCLUSIVE, scan, reads/writes continue
ALTER TABLE users ALTER COLUMN first_name SET NOT NULL;     -- uses the valid check, no scan
ALTER TABLE users DROP CONSTRAINT users_first_name_nn;
-- repeat for last_name
```

This is compatible with v1, v2 and v3: v1/v2 inserts without the parts still pass, because
the `BEFORE INSERT` trigger fills them before the constraint is checked. Measure the
`VALIDATE` duration on the clone.

### Step 6. Release v4: contract the code

The pre-deploy migration (atomic, with `lock_timeout`) does three things:

1. `ALTER TABLE users ALTER COLUMN name DROP NOT NULL` takes a brief `ACCESS EXCLUSIVE`
   (verified) and scans nothing, so inserts without `name` can't fail even if the trigger is
   removed later.
2. `CREATE OR REPLACE FUNCTION users_sync_name()` with the **bidirectional** body. This takes
   no lock on `users` (verified). It adds two branches: on `INSERT` with `name IS NULL` and
   the parts present, set `name := btrim(concat_ws(' ', first_name, last_name))`. On
   `UPDATE` where the parts changed and `name` did not, recompose `name` the same way. The
   forward branches stay. (Full body tested on PG 16. Copy it from the step 1 body and add
   these two branches.)
3. App code: `SeparateDatabaseAndState(state_operations=[RemoveField("user", "name")],
   database_operations=[])`. The model forgets `name`, and the column stays. Remove every
   code reference: admin, serializers, `ordering`, `search_fields`, raw SQL. Make the flags
   permanent and delete them.

| | |
|---|---|
| Code live | v3 + v4 |
| Verify | After 1 h: `SELECT count(*) FROM users WHERE name IS NULL` returns 0 (the reverse trigger fills it for v4 inserts). The convergence query still returns 0 |
| Rollback target | **v3**, not v1. v3 reads the parts first and writes all three. The reverse trigger keeps `name` current, so v3 and any remaining `name` reader keep working |

### Step 7. Soak (change nothing)

Wait at least **14 days, including one month-end**, or longer if A8 found mobile clients or
batch jobs with longer cycles. Watch `pg_stat_statements` for any statement that still
references `name` on `users`: `SELECT query, calls FROM pg_stat_statements WHERE query ILIKE
'%"users"."name"%' OR query ~* 'users.*\mname\M'`. Snapshot `calls` at the start and end of
the soak. Any increase is a reader that has to be removed first.

### Step 8. Brownout: prove nothing reads `name`

One migration, one short transaction with `lock_timeout`:

```sql
DROP TRIGGER users_sync_name ON users;
ALTER TABLE users RENAME COLUMN name TO zz_deprecated_name;
```

Any reader still left now fails loudly, at a time you chose. Wait through at least one more
full business cycle (≥ 7 days, including a weekly batch run). To undo it: rename back and
recreate the trigger. Both are instant. After that, the new step 2 backfill re-derives
nothing because the parts are already set. The only side effect is that `name` is stale for
rows edited during the brownout. Recompose it with a batched `UPDATE ... SET name =
btrim(concat_ws(' ', first_name, last_name)) WHERE ...`.

## 4. Verification summary

| Step | Evidence | Expected |
|---|---|---|
| 1 | New-row completeness query, write p99 | 0, baseline |
| 2 | Backfill metrics, `migration_failures` | remaining 0, failed 0 or resolved |
| 3 | Completeness + convergence on primary and replicas | 0 and 0 |
| 4 | Shadow divergence metric, convergence | 0, 0 |
| 5 | `pg_constraint.convalidated`, `\d users` | true, `not null` |
| 6 | `name IS NULL` count, convergence | 0, 0 |
| 7 | `pg_stat_statements` calls delta for `name` | 0 |
| 8 | App and ETL errors mentioning `name` | none |

Mark every migration's start and end on the dashboards.

## 5. Recovery

| What "wrong" looks like | Detected by | Response |
|---|---|---|
| A DDL waits on a lock and traffic queues | `lock_timeout` error, `pg_locks` | The migration aborts itself after 3 s. Find the long transaction and retry |
| The trigger adds unacceptable write latency | `users` write p99 after step 1 | `DROP TRIGGER`, roll back to v1. Columns are unused, so leave them |
| The backfill causes lag, CPU or IO pressure | Throttle signals, `ReplicaLag` | The throttle backs off. Pause switch. No data at risk |
| The split rule is wrong for a class of names | Ambiguity report, product review, support tickets | Fix `users_split_name` and the Python helper, then roll forward with a scoped re-backfill of the affected rows (`WHERE <predicate>`). Exclude rows where users entered their own split (track with an `name_parts_source` column if that distinction matters, which is a product call) |
| v3 has a bug | Errors, divergence metric | Flag off, then redeploy v2 |
| v4 has a bug | Errors | Redeploy v3. The `name` column still exists and is current |
| Bad data found **after the drop** | Customer report | Restore-aside: restore the snapshot into a separate instance, or read the archive table, then run a scoped, verified repair `UPDATE ... FROM users_name_archive_<date>`. Never restore over production |

Evidence sources: `name` itself (until the §6 drop), the archive table (kept 180 days after the
drop), and a manual RDS snapshot taken right before the drop (same retention). Automated
backup retention alone (at most 35 days on RDS) doesn't cover a slow detection window.

## 6. Cleanup (destructive, last)

**Earliest date:** step 8 start + 7 days, which is no earlier than about 21 days after v4
reached 100%. Put the actual date in the cleanup ticket.

**Preconditions:** all must hold, and a second reviewer with database context signs off.

1. No application version reads `name`: step 7 delta is 0 and step 8 caused no errors.
2. No application version writes `name`: v4 is at 100%, and v3 is no longer a rollback
   target.
3. The backfill completed and was verified independently (step 3 queries re-run today: 0, 0).
4. The parts hold valid data (convergence 0 at the moment the trigger was dropped, and
   product accepted the ambiguity report).
5. The rollback window expired. Consumer inventory items (A8) are all migrated.

**Release v5** (migrations only, `lock_timeout` on the DDL):

```sql
-- pre-image: plain read, ACCESS SHARE, doesn't block writes; minutes on 40M rows
CREATE TABLE users_name_archive_<yyyymmdd> AS SELECT id, zz_deprecated_name AS name FROM users;
SELECT (SELECT count(*) FROM users) = (SELECT count(*) FROM users_name_archive_<yyyymmdd>);  -- expect true
-- take a manual RDS snapshot here; record its ID in the ticket

ALTER TABLE users DROP COLUMN zz_deprecated_name;     -- brief ACCESS EXCLUSIVE, catalog-only; also drops indexes on it
DROP FUNCTION users_sync_name();
DROP FUNCTION users_split_name(text);
DROP TABLE migration_progress, migration_failures;    -- if dedicated to this migration
```

Database side only. The state side of this migration is a no-op, because v4 already removed
the field from the model. Open a follow-up ticket to drop the archive table and snapshot on
the date their retention ends.
