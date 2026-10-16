# Zero-Downtime Migration Plan: Split `users.name` into `first_name` / `last_name`

**Context:** Django app, Postgres on RDS, ~40M rows, hottest table in the product, rolling deploys (old and new code run side-by-side during every deploy). Goal: introduce `first_name` / `last_name`, migrate all data, switch all reads/writes, and eventually drop `name` — with no downtime and no long locks.

**Strategy:** classic expand → backfill → dual-read cutover → contract. Every step is individually deployable, backward-compatible with the code one version behind it, and reversible until the final drop.

---

## Phase 0 — Preflight (do this before anything else)

1. **Decide the split semantics.** Splitting a full name is lossy and culturally fraught. Pick a rule and write it down, e.g.:
   - `first_name` = everything before the **last** space, `last_name` = last token (or the inverse: first token / rest — pick one).
   - Single-token names → `first_name = name`, `last_name = ''`.
   - Empty/NULL names → both `''`/NULL.
   - Record the rule in the backfill command so it is one function, unit-tested, used everywhere (Python side) and mirrored in any SQL backfill.
   - Accept that some rows will be "wrong" (e.g. "Maria da Silva", "Jan van der Berg"). Because we keep `name` intact until the very end, you can re-run a corrected backfill at any time before the drop.

2. **Inventory every write path to `name`:**
   - `Model.save()`, `objects.create()`, serializers, forms, Django admin;
   - `queryset.update()`, `bulk_create()`, `bulk_update()` (these **skip** `save()` and signals);
   - raw SQL, ETL jobs, other services writing to the same DB.
   This determines whether app-level dual-writes are sufficient or you need a DB trigger (recommended below — it covers everything, including `update()`/`bulk_*` and out-of-band writers).

3. **Set safe lock/timeout defaults for all DDL.** On RDS Postgres, any `ALTER TABLE` needs an `ACCESS EXCLUSIVE` lock; the danger is not holding it, it's **waiting** for it behind a long-running query while queuing all other traffic behind you. Every migration session should run:

   ```sql
   SET lock_timeout = '3s';
   SET statement_timeout = '10s';   -- lift for specific long-safe ops
   ```

   In Django, wrap this per-migration (example shown in Phase 1). If a DDL statement times out, it's safe to just retry — better to retry than to stall the hottest table.

4. **Confirm migration/deploy ordering.** All steps below assume: *run migrations first, then roll code*. Each code version must work against both "its" schema and the next schema. That is exactly what the phases below guarantee.

5. **Check `name` usage in indexes/constraints.** If there are indexes on `name` used for search/sort, plan equivalent indexes on `(last_name, first_name)` etc., created `CONCURRENTLY` (Phase 4), *before* switching reads.

---

## Phase 1 — Expand: add nullable columns (Deploy 1)

Add `first_name` and `last_name` as **nullable, no default enforced by a rewrite**. On Postgres 11+ even a default is metadata-only, but nullable-no-default is the most conservative and is instant regardless.

Model change (fields exist but nothing uses them yet):

```python
class User(models.Model):
    name = models.CharField(max_length=255)          # unchanged for now
    first_name = models.CharField(max_length=255, null=True, blank=True)
    last_name = models.CharField(max_length=255, null=True, blank=True)
```

Migration (with lock timeout guard):

```python
from django.db import migrations, models

class Migration(migrations.Migration):
    atomic = True
    dependencies = [("users", "00XX_previous")]

    operations = [
        migrations.RunSQL("SET lock_timeout = '3s';", migrations.RunSQL.noop),
        migrations.AddField("user", "first_name",
            models.CharField(max_length=255, null=True, blank=True)),
        migrations.AddField("user", "last_name",
            models.CharField(max_length=255, null=True, blank=True)),
    ]
```

Notes:
- `ADD COLUMN ... NULL` is a catalog-only change: milliseconds once the lock is acquired.
- Deliberately **nullable**. NULL means "not yet backfilled" — this is your progress marker. Do not add `NOT NULL` or defaults yet.
- Old code (previous release) never sees these columns and is unaffected. Django only selects columns it knows about, so adding is always rolling-deploy-safe.

Deploy 1 ships this migration plus the model fields. No behavior change.

---

## Phase 2 — Dual-write (Deploy 2)

Every write that sets `name` must now also set `first_name`/`last_name`. Two layers — do both; the trigger is the safety net, the app code is the long-term implementation:

**2a. App-level dual-write.** One canonical split function:

```python
# users/name_split.py
def split_name(name: str | None) -> tuple[str, str]:
    if not name or not name.strip():
        return "", ""
    parts = name.strip().rsplit(" ", 1)   # last token = last_name (per Phase 0 decision)
    return (parts[0], parts[1]) if len(parts) == 2 else (parts[0], "")
```

Wire it into `User.save()` (and any serializer/form that writes `name`):

```python
def save(self, *args, **kwargs):
    if self.name and (self.first_name is None or self.last_name is None):
        self.first_name, self.last_name = split_name(self.name)
    super().save(*args, **kwargs)
```

Also fix every `queryset.update(name=...)` / `bulk_create` / `bulk_update` call site found in Phase 0 to set all three fields.

**2b. Database trigger (recommended safety net).** Catches `update()`, bulk ops, admin scripts, other services, and the rolling-deploy window where old pods still write only `name`:

```sql
CREATE OR REPLACE FUNCTION users_sync_name_split() RETURNS trigger AS $$
BEGIN
  IF NEW.name IS DISTINCT FROM OLD.name
     OR NEW.first_name IS NULL OR NEW.last_name IS NULL THEN
    NEW.first_name := CASE
        WHEN NEW.name IS NULL OR btrim(NEW.name) = '' THEN ''
        WHEN position(' ' IN btrim(NEW.name)) = 0 THEN btrim(NEW.name)
        ELSE left(btrim(NEW.name),
                  length(btrim(NEW.name)) - strpos(reverse(btrim(NEW.name)), ' '))
      END;
    NEW.last_name := CASE
        WHEN NEW.name IS NULL OR btrim(NEW.name) = '' THEN ''
        WHEN position(' ' IN btrim(NEW.name)) = 0 THEN ''
        ELSE reverse(split_part(reverse(btrim(NEW.name)), ' ', 1))
      END;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_sync_name_split
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION users_sync_name_split();
```

Ship as `RunSQL` in a migration (guard with `SET lock_timeout='3s'`; `CREATE TRIGGER` takes a brief lock, retry on timeout). Keep the SQL split logic byte-identical in behavior to `split_name()` — add a test that runs both against a corpus of tricky names and asserts equality.

Trigger overhead is a few µs per write on the hot path — measurable but almost always acceptable; verify on a staging load test if the table takes >10k writes/s.

**Rolling-deploy safety:** during the deploy, old pods write only `name` → trigger fills the split columns. New pods write all three → trigger sees non-NULL values and (if `name` unchanged) leaves them alone. No window produces rows that miss the new columns.

Deploy 2 ships: trigger migration + dual-write code. **Reads still use `name` only.**

---

## Phase 3 — Backfill 40M rows (management command, not a migration)

Never backfill inside a Django migration: `RunPython` runs in one transaction, holds one snapshot, bloats WAL, blocks `pg_repack`/vacuum, and a deploy pipeline timeout kills it halfway. Use a management command that is **resumable, batched, keyset-paginated, and throttled**:

```python
# users/management/commands/backfill_name_split.py
import time
from django.core.management.base import BaseCommand
from django.db import connection

BATCH = 5_000

SQL = """
WITH batch AS (
    SELECT id FROM users
    WHERE id > %(last_id)s AND (first_name IS NULL OR last_name IS NULL)
    ORDER BY id
    LIMIT %(batch)s
    FOR UPDATE SKIP LOCKED
)
UPDATE users u SET
    first_name = CASE WHEN u.name IS NULL OR btrim(u.name)='' THEN ''
        WHEN position(' ' IN btrim(u.name)) = 0 THEN btrim(u.name)
        ELSE left(btrim(u.name), length(btrim(u.name)) - strpos(reverse(btrim(u.name)), ' ')) END,
    last_name = CASE WHEN u.name IS NULL OR btrim(u.name)='' THEN ''
        WHEN position(' ' IN btrim(u.name)) = 0 THEN ''
        ELSE reverse(split_part(reverse(btrim(u.name)), ' ', 1)) END
FROM batch WHERE u.id = batch.id
RETURNING u.id;
"""

class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument("--start-id", type=int, default=0)
        parser.add_argument("--sleep", type=float, default=0.05)

    def handle(self, *args, **opts):
        last_id, sleep = opts["start_id"], opts["sleep"]
        while True:
            with connection.cursor() as cur:
                cur.execute("SET LOCAL statement_timeout = '30s';")
                cur.execute(SQL, {"last_id": last_id, "batch": BATCH})
                ids = [r[0] for r in cur.fetchall()]
            if not ids:
                self.stdout.write(f"Done at id {last_id}")
                break
            last_id = max(ids)
            self.stdout.write(f"...through id {last_id}")
            time.sleep(sleep)      # let vacuum/replication breathe
```

Operational notes:

- **Throughput:** 5k rows/batch at ~15–20 batches/s ceiling; realistically with `sleep 0.05` you'll do 40M rows in a few hours. Tune `BATCH`/`--sleep` against p99 latency on the table.
- **Each batch is its own short transaction** — no long snapshot, no lock pileups; `SKIP LOCKED` avoids fighting concurrent user updates (the trigger keeps those rows correct anyway).
- **Resumable:** it logs the high-water `id`; on crash, restart with `--start-id`. The `first_name IS NULL` predicate makes it idempotent regardless.
- **Watch while it runs (pause = stop the loop, nothing breaks):**
  - RDS `ReplicaLag` (if read replicas), `WriteIOPS`, `CPUUtilization`;
  - `pg_stat_progress_vacuum` / dead tuple count on `users` — a 40M-row full-table UPDATE pass creates ~40M dead tuples. Consider temporarily lowering `autovacuum_vacuum_scale_factor` for this table:
    ```sql
    ALTER TABLE users SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_cost_delay = 1);
    ```
    (Reset after the migration.) Expect table bloat; if the table is storage-sensitive, plan a `pg_repack` after everything settles.
  - Run during low-traffic hours if possible; it's fine to spread over multiple nights.
- **Optional partial index to accelerate the scan** if the NULL-scan gets slow near the end:
  ```sql
  CREATE INDEX CONCURRENTLY users_split_pending_idx
      ON users (id) WHERE first_name IS NULL OR last_name IS NULL;
  ```
  Drop it (`DROP INDEX CONCURRENTLY`) when the backfill finishes.

**Verification after backfill:**

```sql
SELECT count(*) FROM users WHERE first_name IS NULL OR last_name IS NULL;  -- must be 0
-- spot-check consistency between name and the split columns:
SELECT id, name, first_name, last_name FROM users
WHERE btrim(concat_ws(' ', first_name, NULLIF(last_name,''))) IS DISTINCT FROM btrim(coalesce(name,''))
LIMIT 100;
```

Triage the mismatch sample (multiple spaces, weird whitespace, etc.) — fix the split function and re-run the backfill for affected rows if needed. `name` is still the source of truth, so this is cheap to iterate.

---

## Phase 4 — Switch reads to the new columns (Deploy 3)

1. **Create any needed indexes first**, outside a transaction, concurrently:

   ```python
   from django.contrib.postgres.operations import AddIndexConcurrently

   class Migration(migrations.Migration):
       atomic = False   # required for CONCURRENTLY
       operations = [
           AddIndexConcurrently("user",
               models.Index(fields=["last_name", "first_name"], name="users_last_first_idx")),
       ]
   ```

   If a `CREATE INDEX CONCURRENTLY` fails midway it leaves an `INVALID` index — drop and retry.

2. Change all read paths (templates, serializers, search, sorting, `full_name` display) to use `first_name`/`last_name`. Add a compatibility property so display code has one source:

   ```python
   @property
   def full_name(self):
       return f"{self.first_name} {self.last_name}".strip()
   ```

3. **Keep writing `name`** in this deploy (`name = full_name` on save, or a reverse-direction trigger clause). This keeps `name` fresh so you can roll back Deploy 3 instantly if the new read paths misbehave.

Bake for a few days. Watch error rates and any user-facing name rendering.

---

## Phase 5 — Stop writing `name` (Deploy 4)

Once Deploy 3 is trusted:

1. Remove all writes to `name`; new writes set only `first_name`/`last_name`.
2. Make `name` DB-nullable so inserts that omit it don't violate NOT NULL (this must land **before** or with the code change; `DROP NOT NULL` is catalog-only, instant with the lock-timeout guard):

   ```sql
   ALTER TABLE users ALTER COLUMN name DROP NOT NULL;
   ```

3. Drop the sync trigger (its job is done):

   ```sql
   DROP TRIGGER trg_users_sync_name_split ON users;
   DROP FUNCTION users_sync_name_split();
   ```

4. Optional hardening now that backfill is verified — add NOT NULL to the new columns **without a long lock** (PG 12+ pattern):

   ```sql
   ALTER TABLE users ADD CONSTRAINT users_first_name_nn
       CHECK (first_name IS NOT NULL) NOT VALID;          -- instant
   ALTER TABLE users VALIDATE CONSTRAINT users_first_name_nn;  -- share lock only, scans without blocking writes
   ALTER TABLE users ALTER COLUMN first_name SET NOT NULL;      -- instant: PG proves it from the validated CHECK
   ALTER TABLE users DROP CONSTRAINT users_first_name_nn;
   ```
   (Repeat for `last_name`; mirror in Django with `AlterField(null=False)` wrapped in `SeparateDatabaseAndState` or `migrations.RunSQL` pairs so model state matches.)

---

## Phase 6 — Contract: drop `name` (two deploys — this ordering matters)

Django reads **every field on the model** in its default `SELECT`, so if you drop the column while any running pod still has `name` on the model, that pod starts throwing `ProgrammingError: column users.name does not exist` on every query. Split it:

**Deploy 5 — remove the field from Django state only (column stays in DB):**

```python
class Migration(migrations.Migration):
    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[migrations.RemoveField("user", "name")],
            database_operations=[],   # column physically remains
        ),
    ]
```

After this deploy, **no code version in existence selects or writes `name`.** Grep the codebase (and any raw SQL / analytics jobs / other services) for `users.name` to be sure — this is the last checkpoint.

**Deploy 6 — physically drop the column** (a separate release, after Deploy 5 is fully rolled out everywhere):

```python
class Migration(migrations.Migration):
    operations = [
        migrations.RunSQL(
            ["SET lock_timeout = '3s';", "ALTER TABLE users DROP COLUMN name;"],
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
```

- `DROP COLUMN` is metadata-only (instant), but still needs `ACCESS EXCLUSIVE` — the lock timeout + retry-on-failure rule applies one last time.
- The disk space is not reclaimed immediately; it comes back gradually via updates/vacuum, or all at once if you `pg_repack` the table afterwards (recommended anyway given the backfill bloat).
- **Point of no return.** Before running it: take/verify a snapshot, and confirm the mismatch audit from Phase 3 is empty or accepted. Consider archiving `id, name` to S3/another table first if product/legal might ever want the original strings (the split is lossy).

---

## Rollback matrix

| After | Rollback |
| --- | --- |
| Deploy 1 (add columns) | Nothing to do; unused nullable columns are harmless. |
| Deploy 2 (dual-write + trigger) | Revert code; trigger keeps columns in sync either way. |
| Phase 3 (backfill) | No rollback needed — `name` untouched; re-run backfill anytime. |
| Deploy 3 (reads switched) | Revert code; `name` is still being written, so old reads are correct. |
| Deploy 4 (stopped writing `name`) | Re-enable `name` writes + re-run a mini-backfill of `name` from the split columns for rows touched in the window. |
| Deploy 5 (field removed from model) | Revert code (column still exists). |
| Deploy 6 (column dropped) | **None** except restore from snapshot/archive. Hence the checkpoint above. |

## Timeline sketch

- Day 1: Deploy 1 (add columns) + Deploy 2 (dual-write/trigger) — can be same day.
- Days 2–3: backfill (nights), verify, iterate on split edge cases.
- Day 4: Deploy 3 (switch reads). Bake 3–7 days.
- Day ~10: Deploy 4 (stop writing `name`, NOT NULL hardening).
- Day ~17: Deploy 5 (remove from model). Bake one full release cycle.
- Day ~20+: Deploy 6 (drop column), then `pg_repack` during a quiet window.

## Key invariants (the whole plan in four lines)

1. Never let any live code version reference a column that doesn't exist — add columns before code that uses them, remove code before dropping columns.
2. Never hold `ACCESS EXCLUSIVE` on `users` for more than milliseconds — `lock_timeout + retry` on every DDL; no rewriting DDL at all.
3. Never mutate 40M rows in one transaction — batched, idempotent, resumable backfill outside migrations.
4. Keep `name` authoritative and synced until the split columns are verified — every phase before Deploy 6 is cheaply reversible.
