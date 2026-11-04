# Plan: split `users.name` into `first_name` / `last_name` (zero downtime)

**Verdict:** this is a *breaking* change: it splits one column into two, then drops one. It is
also *lossy* in both directions. Splitting a free-text name is a heuristic, and rebuilding `name`
from the parts does not reproduce the original string. Ship it as **seven separate releases**
using Expand–Migrate–Contract. A Postgres trigger keeps the columns in sync, and `name` stays as
the source of truth until the final, separate drop. Every step before the drop can be rolled back
by redeploying the previous version.

---

## 0. Assumptions (confirm before starting; each one changes the plan if wrong)

| # | Assumption | If wrong |
|---|---|---|
| A1 | `users.name` is `varchar(255) NOT NULL`. The PK is `id bigint`. | Adjust the types in step 1. If `name` is nullable, the backfill and verification queries already skip NULLs. |
| A2 | Postgres ≥ 12 on RDS. | `EXECUTE FUNCTION` needs ≥ 11. The `SET NOT NULL`-via-CHECK shortcut (optional, step 4) needs ≥ 12. |
| A3 | Django migrations run as a pre-deploy job, *before* the rolling rollout. So the schema change is always live while the **previous** app version is serving traffic. | If migrations run after the rollout, every schema step must still be compatible with the *next* version. The ordering below still works. |
| A4 | Every writer to `users.name` is this Django app: ORM `save()`, `QuerySet.update()`, `bulk_create`/`bulk_update`, admin, raw SQL, management commands. | Other writers (another service, ETL, support tooling) are the reason the sync lives in a **DB trigger** and not in `Model.save()`. Still inventory the *readers* (analytics, BI, replicas, search indexer, public API serializers) before step 7. |
| A5 | Split rule: first whitespace-delimited token → `first_name`, the rest → `last_name`. Whitespace is collapsed, `''` (not NULL) when empty. `"Mary Ann Smith"` → `Mary` / `Ann Smith`. `"Cher"` → `Cher` / `''`. | This is a **product decision**, not an engineering one. Get it signed off before step 1. Step 3 measures how many rows are ambiguous (3+ tokens, 1 token). |
| A6 | The rollback window is **14 days** per contract step. | Set it to whatever your release process calls "done". Put the dates in the tracking issue at kickoff. |
| A7 | No other migration on `users` is in flight during this work. | Serialize them. Two concurrent changes on the hottest table break the "every intermediate state is compatible" reasoning. |

## 1. Why a trigger, not just app-level dual writes

During the rolling deploy, and for the whole rollback window, old code (v1) keeps writing **only**
`name`. With app-only dual writes, a v1 `UPDATE ... SET name = 'Ada King'` on an already
backfilled row leaves `first_name`/`last_name` stale, and new code reads the wrong value. Django
also has write paths that skip `save()` (`QuerySet.update`, `bulk_update`, raw SQL). A `BEFORE`
row trigger covers every writer, in the same transaction, so the dual write is atomic.

The trigger's rules:

| Write | Trigger action |
|---|---|
| INSERT with only `name` (v1) | derive `first_name`/`last_name` from `name` |
| INSERT with parts and empty/NULL `name` (code after `name` stops being written) | build `name` from the parts |
| UPDATE that changes `name` only (v1, or any name-only writer) | re-derive the parts |
| UPDATE that changes the parts only, on a row that was **already populated** | rebuild `name` (keeps v1 rollback working) |
| UPDATE that fills NULL parts (the backfill) | nothing. The original `name` is **not** rewritten, so the backfill is non-lossy. |
| UPDATE that changes all three consistently (dual-writing code) | nothing. Trusts the values as given. |

All of the above was run on Postgres 14 in a scratch container, using the exact SQL below:
v1 inserts and updates, backfill re-runs, part-only edits, and inserts without `name`.

---

## 2. Release sequence

Each release ships on its own and has its own rollback story. Do not merge two of them.

### Release 1: Expand (schema only, no app behavior change)

Django migration `users/0NNN_split_name_expand.py`:

```python
from django.db import migrations, models

SPLIT_FN = r"""
CREATE OR REPLACE FUNCTION users_split_name(n text, OUT first_name text, OUT last_name text)
LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(substring(norm FROM '^\S+'), ''),
         regexp_replace(norm, '^\S+\s*', '')
  FROM (SELECT btrim(regexp_replace(n, '\s+', ' ', 'g')) AS norm) s
  WHERE n IS NOT NULL
$$;
"""

SYNC_FN = r"""
CREATE OR REPLACE FUNCTION users_sync_name() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE s record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.first_name IS NULL AND NEW.last_name IS NULL THEN
      s := users_split_name(NEW.name);
      NEW.first_name := s.first_name;
      NEW.last_name  := s.last_name;
    ELSIF NEW.name IS NULL OR NEW.name = '' THEN
      NEW.name := concat_ws(' ', nullif(NEW.first_name, ''), nullif(NEW.last_name, ''));
    END IF;
  ELSIF NEW.name IS DISTINCT FROM OLD.name
        AND NEW.first_name IS NOT DISTINCT FROM OLD.first_name
        AND NEW.last_name  IS NOT DISTINCT FROM OLD.last_name THEN
    s := users_split_name(NEW.name);
    NEW.first_name := s.first_name;
    NEW.last_name  := s.last_name;
  ELSIF NEW.name IS NOT DISTINCT FROM OLD.name
        AND OLD.first_name IS NOT NULL          -- skip the backfill's initial fill
        AND (NEW.first_name IS DISTINCT FROM OLD.first_name
             OR NEW.last_name IS DISTINCT FROM OLD.last_name) THEN
    NEW.name := concat_ws(' ', nullif(NEW.first_name, ''), nullif(NEW.last_name, ''));
  END IF;
  RETURN NEW;
END $$;
"""

class Migration(migrations.Migration):
    dependencies = [("users", "0NNN_previous")]

    operations = [
        # Hottest table: an ACCESS EXCLUSIVE lock queued behind a long transaction blocks all
        # traffic. Fail fast and retry the deploy instead of queueing.
        migrations.RunSQL("SET LOCAL lock_timeout = '3s';", migrations.RunSQL.noop),
        migrations.AddField("user", "first_name",
                            models.CharField(max_length=255, null=True, blank=True)),
        migrations.AddField("user", "last_name",
                            models.CharField(max_length=255, null=True, blank=True)),
        migrations.RunSQL(SPLIT_FN, "DROP FUNCTION IF EXISTS users_split_name(text);"),
        migrations.RunSQL(SYNC_FN, "DROP FUNCTION IF EXISTS users_sync_name();"),
        migrations.RunSQL(
            """CREATE TRIGGER users_sync_name
                 BEFORE INSERT OR UPDATE OF name, first_name, last_name ON users
                 FOR EACH ROW EXECUTE FUNCTION users_sync_name();""",
            "DROP TRIGGER IF EXISTS users_sync_name ON users;",
        ),
    ]
```

- Nullable columns with no default are a catalog-only change. There is no table rewrite. Do
  **not** give them a Python `default=`. NULL means "not yet backfilled", and the backfill and
  the trigger both depend on that.
- `CREATE TRIGGER` takes a SHARE ROW EXCLUSIVE lock, which blocks writes for a moment. The same
  `lock_timeout` covers it. Run the release off-peak, and first check `pg_stat_activity` for
  long-running transactions on `users`.
- The app code may add the fields to the model but **must not read them yet**.
- Measure trigger overhead on staging with a production-like write rate, and watch p99 write
  latency on `users` after the deploy.

**Rollback:** reverse the migration (drop the trigger, functions and columns). Nothing reads the
columns yet, so nothing is lost.

### Release 2: Backfill (operational job, not a Django migration)

A 40M-row UPDATE must never run inside the pre-deploy `migrate` step. Run it as a management
command (`manage.py backfill_user_name_split`) from one worker, with a persisted cursor.

```sql
-- once, before the first run: freeze the upper bound. Rows above it are handled by the trigger.
CREATE TABLE IF NOT EXISTS migration_progress (
  job text PRIMARY KEY, last_id bigint NOT NULL, upper_id bigint NOT NULL,
  rows_updated bigint NOT NULL DEFAULT 0, batches bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now());
INSERT INTO migration_progress (job, last_id, upper_id)
SELECT 'users_split_name', 0, max(id) FROM users
ON CONFLICT (job) DO NOTHING;

-- per batch, in its own short transaction (:lo = last_id, :hi = least(last_id + :batch, upper_id))
SET LOCAL statement_timeout = '5s';
SET LOCAL lock_timeout = '1s';
UPDATE users u
SET    (first_name, last_name) =
       (SELECT s.first_name, s.last_name FROM users_split_name(u.name) s)
WHERE  u.id > :lo AND u.id <= :hi
  AND  u.first_name IS NULL AND u.last_name IS NULL      -- idempotence predicate
  AND  u.name IS NOT NULL;
UPDATE migration_progress
SET    last_id = :hi, rows_updated = rows_updated + :rowcount, batches = batches + 1,
       updated_at = now()
WHERE  job = 'users_split_name';
COMMIT;
```

The backfill contract:

- **Idempotent.** Rows that already have parts no longer match the predicate, so re-running a
  batch is a no-op. Verified.
- **Restartable.** `last_id` is committed in the same transaction as the batch, so a crash
  resumes from the last committed batch.
- **Bounded.** Batches walk `id` ranges, not `LIMIT` with a predicate, so each batch is a PK
  index range scan. Start with 1,000–5,000 ids per batch plus a short sleep, and tune by
  measurement. The numbers are a starting point, not a verified figure for your hardware.
- **Pausable.** A kill switch (env var or settings flag) is checked before each batch. Stopping
  anywhere leaves a valid state: unfilled rows have NULL parts, and readers fall back (Release 3).
- **Observable.** Log total, processed, remaining (`upper_id - last_id`), failed batches, retries
  and rows/sec. Expose them on a dashboard.
- **Throttled on RDS signals.** Pause automatically when `ReplicaLag` exceeds a threshold, when
  the write-IOPS or burst balance drops, or when p99 latency on `users` endpoints rises.
- **Vacuum and bloat.** 40M row updates create 40M dead tuples. Watch `n_dead_tup` and
  autovacuum progress on `users`. Consider lowering `autovacuum_vacuum_scale_factor` on the table
  for the duration (`ALTER TABLE users SET (...)` is a light lock, but still use a lock timeout).
  Expect WAL volume to rise. Check storage headroom and snapshot/backup size first.

**Rollback:** none needed. The job only fills NULLs and never touches `name`.

### Release 3: Read new, fall back to old (behind a flag)

```python
# users/models.py
first_name = models.CharField(max_length=255, null=True, blank=True)
last_name  = models.CharField(max_length=255, null=True, blank=True)

@property
def display_first_name(self):
    if settings.FLAGS.users_read_split_name and self.first_name is not None:
        return self.first_name
    return split_name(self.name)[0]        # same rule as users_split_name(); tested against it
```

- Writes are unchanged. The app still writes only `name`, and the trigger derives the parts. So
  this release produces no data that v1 can't read.
- Turn the flag on for a canary slice, then everyone. The flag is the kill switch. Turning it off
  needs no schema change.
- The Python `split_name()` is only a fallback for rows not yet backfilled. Add a test that runs
  both implementations over a sample of production names and requires identical output.

**Rollback:** turn the flag off, or redeploy Release 2's code. Both are fully compatible.

**Gate before Release 4:** the backfill is complete and the verification queries in §3 pass.

### Release 4: Write the parts (new forms/API accept `first_name` / `last_name`)

- The app now writes `first_name`/`last_name` directly wherever the user supplies them. It keeps
  `name` in the model and does not compute it. The trigger rebuilds `name` from the parts. A v1
  instance still in the rollout, or redeployed during rollback, keeps reading a correct `name`.
- Remove the read fallback: reads use only the parts.
- Optional hardening (only if the parts must be NOT NULL): `ADD CONSTRAINT ... CHECK (first_name
  IS NOT NULL) NOT VALID`, then `VALIDATE CONSTRAINT` in a separate migration, then `SET NOT NULL`
  (on PG ≥ 12 the valid CHECK skips the full scan), then drop the CHECK. Each is its own
  migration with `lock_timeout`.
- From here, `name` holds the rebuilt form for edited rows (`"Jean Luc Picard"`). That is
  intentional and is the reason `name` is the rollback bridge, not the source of truth.

**Rollback:** redeploy Release 3's code at any time inside the 14-day window (A6). It reads the
parts, or `name`, and both stay current through the trigger.

### Release 5: Stop using `name` in code (start of the rollback window for the drop)

- Remove every reference to `name` in application code: serializers, admin, search, templates,
  `values()`/`only()` calls, raw SQL. Keep the **field on the model** so Django's state matches
  the database.
- Keep the trigger. It keeps `name` populated, so redeploying Release 4 still works.
- Grep plus CI check: fail the build on new references to `User.name` / `"users"."name"`.

**Rollback:** redeploy Release 4.

### Release 6: Remove `name` from Django state only (no DDL)

```python
migrations.SeparateDatabaseAndState(
    state_operations=[migrations.RemoveField("user", "name")],
    database_operations=[],
)
```

- Django now omits `name` from INSERTs. The column is still `NOT NULL`, but the `BEFORE INSERT`
  trigger fills it from the parts before the constraint is checked. Verified.
- **Do not** let `makemigrations` generate a plain `RemoveField`. That drops the column in the
  same release, while the previous version (which still selects `name`) is in traffic, and the
  data goes with it.

**Rollback:** redeploy Release 5 (its model still has `name`, and the column still exists).

### Release 7: Cleanup (the only irreversible step; ships alone, after the gate)

Gate (all must hold, recorded in the tracking issue):

1. The rollback window after Release 6 has expired, and no rollback past Release 5 is still on
   the table.
2. No reads or writes of `users.name` from any client: zero matches in `pg_stat_statements`
   for `"users"."name"` / `users.name` since `pg_stat_statements_reset()` at the start of
   Release 6, plus code search across **all** repos, ETL and BI tools (A4).
3. §3 verification queries pass.
4. An archive of the original values exists (below) and someone has confirmed it is readable.

```sql
-- the split is lossy; keep the originals as the source of truth for compensating repairs
CREATE TABLE users_name_archive AS SELECT id, name FROM users;   -- run on a quiet period; or
-- export to S3 via aws_s3 / pg_dump -t if a 40M-row copy on the primary is unwelcome.
```

```python
# users/0NNN_drop_name.py
operations = [
    migrations.RunSQL("SET LOCAL lock_timeout = '3s';", migrations.RunSQL.noop),
    migrations.RunSQL("DROP TRIGGER IF EXISTS users_sync_name ON users;"),
    migrations.RunSQL("DROP FUNCTION IF EXISTS users_sync_name();"),
    migrations.RunSQL("ALTER TABLE users DROP COLUMN name;"),   # catalog-only; brief ACCESS EXCLUSIVE
    migrations.RunSQL("DROP FUNCTION IF EXISTS users_split_name(text);"),
]
```

No reverse migration is written on purpose: re-adding the column would not restore its values.
Recovery after this point is a compensating migration from `users_name_archive`. Drop the archive
table and the `users_read_split_name` flag on a dated follow-up (suggest +90 days, owner named in
the issue).

---

## 3. Verification queries (run on a read replica; they are full scans)

```sql
-- backfill converged (gate for Release 4, and for Release 7)
SELECT count(*) FROM users WHERE first_name IS NULL AND name IS NOT NULL;          -- expect 0

-- parts match the rule (meaningful only BEFORE Release 4; afterwards user edits diverge on purpose)
SELECT count(*) FROM users u, users_split_name(u.name) s
WHERE  (u.first_name, u.last_name) IS DISTINCT FROM (s.first_name, s.last_name);   -- expect 0

-- ambiguity report for product sign-off on A5
SELECT count(*) FILTER (WHERE last_name = '')                    AS single_token,
       count(*) FILTER (WHERE last_name ~ '\s')                  AS three_plus_tokens,
       count(*) FILTER (WHERE first_name = '' AND last_name = '') AS empty
FROM users;

-- length safety (if the part columns are ever narrowed below name's length)
SELECT max(length(first_name)), max(length(last_name)) FROM users;
```

Also check in production after every release: error rate on `users` endpoints, p99 write latency
on `users`, `ReplicaLag`, and lock waits (`pg_locks` / Performance Insights).

## 4. Recovery

| Failure | Path |
|---|---|
| Release 1 lock timeout | The deploy fails cleanly. Retry off-peak after clearing long transactions. |
| Trigger overhead hurts latency | Revert Release 1 (drop the trigger). The columns stay NULL and harmless. |
| Split rule wrong (found in Releases 2–4) | Fix `users_split_name()` (`CREATE OR REPLACE`, a forward migration), then run a compensating backfill: reset the parts for affected rows (`UPDATE ... SET first_name = NULL, last_name = NULL WHERE <predicate>`, which the trigger ignores because `name` is unchanged and the new parts are NULL) and re-run the job. `name` is intact, so this is a one-job repair. |
| New code writes bad parts (Release 4+) | Turn off the flag or redeploy the previous release. Repair from `name` (still present until Release 7) or from `users_name_archive` afterwards, row by row, as a bounded backfill. |
| Anything after Release 7 | Compensating migration from `users_name_archive` / restore-aside (restore an RDS snapshot to a **separate instance**, extract `id, name`, repair the affected rows). Never restore over production. That would discard every valid signup and update since the snapshot. |

## 5. Pre-deployment checklist, answered

1. **Can the previous version run against the new schema?** Yes at every release. The trigger
   keeps `name` correct until the drop, and the drop happens only after nothing reads it.
2. **Can old and new instances run at once?** Yes. v1 writes `name` and the trigger derives the
   parts. Newer code writes the parts and the trigger rebuilds `name`.
3. **Does it delete or transform information?** Yes. The split is heuristic, and the rebuilt
   `name` differs from the original (whitespace, token grouping). The originals live in `name`
   until Release 7, then in `users_name_archive`.
4. **Can it run more than once?** Yes. DDL is reversible through migrations, and the backfill has
   an idempotence predicate. Verified by a re-run.
5. **Can the backfill stop and resume?** Yes. A persisted `id` cursor plus a kill switch.
6. **How is correctness verified?** The §3 queries, not exit codes.
7. **Can new behavior be disabled without a schema revert?** Yes, with the
   `users_read_split_name` flag (Release 3), or by redeploying the previous release (all
   releases before 7).
8. **Recovery path if the data is wrong?** §4: a compensating backfill from `name` or the archive.
   Never an in-place restore.
9. **When is destructive cleanup, and what must be proven?** Release 7, after the window, with
   the four-point gate.
10. **Concurrent migrations?** Assumed none (A7). Freeze other `users` schema changes from
    Release 1 through Release 7.

## 6. Tracking

Open one issue with this plan in the body. Record the dates for each release, the 14-day windows,
the Release 7 gate evidence, and the archive and flag removal dates, with a named owner for the
cleanup. "Temporarily dual-columned" without a deadline is how this ends up permanent.
