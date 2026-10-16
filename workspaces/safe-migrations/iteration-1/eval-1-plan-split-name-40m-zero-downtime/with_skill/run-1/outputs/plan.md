# Zero-downtime plan: split `users.name` into `first_name` / `last_name`

**Stack assumptions:** Django app, PostgreSQL on RDS, ~40M-row `users` table (hottest table),
rolling deploys (old and new app versions serve traffic simultaneously during every rollout).

## Classification: why this is a breaking change

Splitting a column is in the **breaking** class, for two independent reasons:

1. **Schema compatibility.** If we renamed/dropped `name` in one deployment, every still-running
   old app instance would error immediately — Django SELECTs explicit column lists, so old code
   queries `name` by name. During a rolling deploy that's guaranteed 500s.
2. **Information loss.** The split itself is a *lossy, ambiguous transformation*. `name` does not
   deterministically map to `(first_name, last_name)`: single-word names, multi-word surnames
   ("Maria da Silva Santos"), suffixes, mononyms, names in other conventions. Once `name` is
   dropped, no down migration can reconstruct it faithfully from the parts (`first_name || ' ' ||
   last_name` is not guaranteed to equal the original). **`name` is the source of truth until the
   very last step**, and that step is deliberately delayed.

Governing question for every step below: *can every application version in traffic work with
every intermediate database state?* Each numbered deployment keeps the answer "yes".

Two failure scenarios this plan is built to avoid:

- **Rolling-deploy window:** old pods write `name` only; new pods write both. Any step that
  requires `first_name`/`last_name` to be populated (NOT NULL, reads without fallback) breaks
  while old pods are still in traffic.
- **Post-rollout rollback window:** if we have to redeploy last week's release, it writes `name`
  only. So the new columns must tolerate stale/NULL values (fallback reads) until the rollback
  window has expired — not just until the rollout finishes.

---

## The plan — six independent deployments

Each step is a separate deploy with its own rollback story. Do not collapse steps.

### Deployment 1 — Expand: add the columns (schema only)

Django migration adding two **nullable** columns, no default, no index yet:

```python
migrations.AddField("User", "first_name_new", models.CharField(max_length=150, null=True)),
migrations.AddField("User", "last_name_new",  models.CharField(max_length=150, null=True)),
```

(If your `User` model doesn't already have Django's stock `first_name`/`last_name`, use those
names directly; if it's a custom model where the names are free, drop the `_new` suffix. The
mechanics are identical either way — below I'll write `first_name`/`last_name`.)

Postgres details that matter on a 40M-row hot table:

- `ADD COLUMN ... NULL` with no default is **metadata-only** — O(1), no table rewrite. On
  Postgres 11+ even a constant default avoids a rewrite, but nullable-no-default is the safest.
- It still takes a brief `ACCESS EXCLUSIVE` lock. On the hottest table, that lock can queue
  behind a long-running query and then *everything* queues behind the lock request. Guard it:

```sql
SET lock_timeout = '3s';
SET statement_timeout = '10s';
-- run the ALTER; if it times out, retry — do not remove the timeout
```

  In Django, run this migration in a maintenance-friendly window and wrap it so the timeouts
  apply (e.g. a `RunSQL` that sets `lock_timeout` first, or set it in the migration's database
  connection options). A failed attempt is harmless; retry until it wins the lock quickly.
- **No index in this deployment.** If you'll later need indexes on the new columns, add them in
  their own migration using `CREATE INDEX CONCURRENTLY` (Django: `AddIndexConcurrently` from
  `django.contrib.postgres.operations`, with `atomic = False` on the migration).

*Rollback: drop the columns; nothing reads or writes them yet. Old code is untouched — it never
selects columns it doesn't know about.*

### Deployment 2 — Migrate (code): dual-write + fallback reads, behind a flag

Deploy application code that:

**Writes both representations, old one authoritative.**

```python
class User(AbstractBaseUser):
    ...
    def save(self, *args, **kwargs):
        if self.name and not (self.first_name and self.last_name):
            self.first_name, self.last_name = split_name(self.name)
        # if the UI now collects first/last directly, also keep name in sync:
        elif self.first_name is not None and not self.name:
            self.name = f"{self.first_name} {self.last_name}".strip()
        super().save(*args, **kwargs)
```

`split_name()` is the single, versioned splitting heuristic (e.g. `rsplit(" ", 1)`; one token →
`first_name=name, last_name=""` or NULL — decide and document). Keep it in one function: the
backfill must use *the same code* so live writes and backfilled rows agree.

**Two Django-specific traps to close now:**

- `QuerySet.update()`, `bulk_create()`, `bulk_update()` **bypass `save()` and signals**. Grep the
  codebase for every write path that touches `name` and make each one dual-write explicitly.
  This is the step where migrations silently rot — an audited list of write paths is a
  deliverable of this deployment.
- Celery tasks / admin / management commands count as write paths too.

**Reads: new-with-fallback.**

```python
@property
def display_first_name(self):
    return self.first_name if self.first_name is not None else split_name(self.name)[0]
```

Nothing user-facing should *require* the new columns yet. Gate any new behavior that consumes
`first_name`/`last_name` (emails addressed by first name, sorting by last name, etc.) behind a
**feature flag, default off** — deployment and release are separate moments. If the split
heuristic turns out wrong, you switch the flag off; no schema revert, no redeploy.

*Rollback: redeploy v1. It writes only `name`; fallback reads mean rows written by either version
are readable by both. Rows dual-written by v2 remain fully valid for v1.*

### Deployment 3 — Migrate (data): batched, idempotent, resumable backfill

A management command, not a Django data migration — 40M rows must never run inside one migration
transaction, and deploys must not block on it.

Contract (non-negotiable for a production backfill): **idempotent, restartable, bounded,
observable, pausable.**

```python
# manage.py backfill_split_name --batch-size 5000 --sleep 0.1
BATCH = 5_000
last_id = load_checkpoint()  # persisted: table row or cache key
while True:
    with transaction.atomic():
        rows = (User.objects
                .filter(id__gt=last_id, first_name__isnull=True, name__isnull=False)
                .order_by("id")
                .values_list("id", "name")[:BATCH])
        rows = list(rows)
        if not rows:
            break
        cases_f, cases_l = build_cases(rows, split_name)   # same split_name as live code
        (User.objects
         .filter(id__in=[r[0] for r in rows], first_name__isnull=True)  # idempotence guard
         .update(first_name=cases_f, last_name=cases_l))
    last_id = rows[-1][0]
    save_checkpoint(last_id)
    log_progress(last_id, len(rows))
    time.sleep(SLEEP)  # throttle; tune against replica lag
```

Key properties:

- **Idempotent:** the `first_name__isnull=True` predicate makes re-running a batch a no-op, and
  never clobbers rows the dual-write path already populated (live writes win over backfill).
- **Restartable:** checkpoint on `id`; crash → resume, not restart. Iterate by PK range, never
  `OFFSET`.
- **Bounded:** ~5k rows per transaction, short locks, no long transaction holding back vacuum.
- **Observable (RDS specifics):** emit processed/remaining/rate; watch `ReplicaLag`,
  `WriteIOPS`, CPU, and `pg_stat_activity` for blocked queries. At 5k rows per batch with
  throttling, 40M rows is hours-to-a-couple-of-days — that's fine; it's designed to be boring.
- **Pausable:** stopping mid-way leaves a valid state because reads still fall back to `name`.
  Pause during peak traffic if lag climbs.
- **Ambiguity ledger:** have the backfill count (or stamp) rows where the heuristic was uncertain
  (0 or 3+ tokens). That list is your review queue, and later your compensating-migration
  `WHERE` clause if the heuristic must change.

**Verification — queries, not exit codes:**

```sql
-- converged? must reach 0:
SELECT COUNT(*) FROM users WHERE first_name IS NULL AND name IS NOT NULL;

-- split is faithful? sample-check reconstruction:
SELECT COUNT(*) FROM users
WHERE name IS NOT NULL
  AND name <> TRIM(first_name || ' ' || COALESCE(last_name, ''));
-- expect only the known-ambiguous rows; review a sample by hand.

-- shape sanity:
SELECT COUNT(*) FROM users WHERE first_name = '' OR LENGTH(first_name) > 150;
```

*Rollback: none needed — it only fills NULLs from a column that remains intact.*

### Deployment 4 — Contract (code): new columns become authoritative

Only after Deployment 3's verification queries pass. Deploy code that:

- Reads `first_name`/`last_name` directly (drop the fallback), flag now on for everyone.
- Writes `first_name`/`last_name` as the primary fields — **but keeps dual-writing `name`**
  (`name = first + " " + last`). This is what keeps the rollback window open: if you must
  redeploy Deployment 2's (or even v1's) code, `name` is still current.

Define the **rollback window** now, with a date and an owner — e.g. 2–4 weeks covering at least
one full business cycle. Until it expires, treat the previous version as "in traffic".

*Rollback: redeploy Deployment 2's build any time inside the window; both columns are current, so
nothing is lost.*

### Deployment 5 — Stop writing `name`; remove it from Django state (column stays)

After the rollback window expires and you've verified nothing reads `name`:

- code search for `name` usages (ORM, raw SQL, serializers, admin, reports, BI/ETL jobs — **check
  non-Django consumers of the database explicitly**: analytics, warehouse syncs, other services);
- `pg_stat_statements` / RDS Performance Insights showing no queries referencing `users.name`
  other than your own dual-write.

Then deploy: remove the dual-write, and remove the field from the **Django model only**, keeping
the physical column:

```python
migrations.SeparateDatabaseAndState(
    state_operations=[migrations.RemoveField("User", "name")],
    database_operations=[],  # column stays in the database
)
```

This ordering exists because of the rolling deploy: if the column vanished while pods running
Deployment 4's code (which still selects and writes `name`) were alive, they'd error. After this
deployment, **no** app version in traffic references the column, so dropping it later is safe.

Optional in this deployment: tighten `first_name` to `NOT NULL` if the product requires it — as a
two-phase constraint so it never scans under an exclusive lock:

```sql
ALTER TABLE users ADD CONSTRAINT first_name_not_null
  CHECK (first_name IS NOT NULL) NOT VALID;          -- instant
ALTER TABLE users VALIDATE CONSTRAINT first_name_not_null;  -- full scan, but only SHARE UPDATE EXCLUSIVE
-- Postgres 12+: optionally follow with SET NOT NULL (uses the validated check, no rescan) and drop the check.
```

*Rollback: redeploy Deployment 4's build — the column still exists and it resumes dual-writing;
re-run the backfill direction `name := first || ' ' || last` if any rows were written in between.*

### Deployment 6 — Cleanup: drop the column (the only irreversible step)

A separate, later deployment — never bundled with Deployment 5. Preconditions, all proven:

- Deployment 5 has been fully rolled out and stable past its own rollback window.
- Verification queries from step 3 still pass; no consumer touches `users.name` (re-check
  `pg_stat_statements` since Deployment 5).
- A recent snapshot/backup exists (RDS automated backups + a manual snapshot tagged with this
  migration's name — your restore-aside source if anything surfaces later).

```python
migrations.SeparateDatabaseAndState(
    state_operations=[],
    database_operations=[migrations.RunSQL(
        "SET lock_timeout='3s'; ALTER TABLE users DROP COLUMN name;",
        reverse_sql=migrations.RunSQL.noop,  # be honest: there is no real reverse
    )],
)
```

`DROP COLUMN` is metadata-only in Postgres (space reclaimed by later rewrites/vacuum), but it
still takes `ACCESS EXCLUSIVE` — same `lock_timeout` guard as Deployment 1.

Put the cleanup date in the tracker on day one, with an owner. "Temporary" dual columns without a
deadline become permanent.

---

## Recovery plan (decided now, not during an incident)

- **Wrong split heuristic discovered before Deployment 6:** `name` is intact — fix `split_name()`,
  re-run the backfill with a predicate targeting affected rows (the ambiguity ledger / batch
  stamps turn "some rows, somewhere" into a `WHERE` clause). This is a compensating *forward*
  migration; no restore, no rollback.
- **Wrong data discovered after Deployment 6:** restore the tagged snapshot **aside** into a
  separate instance, extract `id, name` for affected rows, repair in place with a batched
  backfill. Never restore over production — that would destroy every valid write since.
- **Behavior (not data) is wrong:** feature flag off. No schema change, no redeploy.

## The ten-question checklist, answered

1. **Previous version vs. new schema?** Yes at every step — columns are only added (nullable) or
   removed after no live version references them.
2. **Old and new simultaneously?** Yes — that constraint dictated the 6-deployment split,
   fallback reads, and the state-only `RemoveField` before the physical drop.
3. **Information deleted/transformed?** Yes — the split is lossy and ambiguous. Original lives in
   `name` until Deployment 6, then in the tagged snapshot.
4. **Migration safe to run twice?** Yes — DDL steps are retry-guarded by `lock_timeout`; the
   backfill's `first_name IS NULL` predicate makes it idempotent.
5. **Backfill stop/resume?** Yes — PK checkpointing, bounded batches, pausable under load.
6. **Verification?** Convergence, reconstruction, and shape queries above — data checks, not exit
   codes.
7. **Disable without schema revert?** Yes — feature flag on all new-column-consuming behavior.
8. **Recovery path?** Compensating forward backfill from `name`; restore-aside after the drop.
9. **When is destructive cleanup?** Deployment 6, dated at project start, gated on the five
   proofs listed there.
10. **Interacting migrations?** Freeze other `users`-table migrations for the duration; anything
    touching `name` (serializers, search indexing, ETL) must land before Deployment 5's audit or
    wait.

## Condensed timeline

| # | Deploy | Rollback story |
|---|---|---|
| 1 | Add nullable `first_name`, `last_name` (lock-guarded) | Drop them; unused |
| 2 | Dual-write + fallback reads; flag off; audit `update()`/bulk paths | Redeploy v1 |
| 3 | Batched idempotent backfill + verification queries | None needed |
| 4 | Read/write new columns; keep syncing `name`; start rollback window | Redeploy step 2 |
| 5 | Stop writing `name`; state-only `RemoveField`; optional NOT NULL via `NOT VALID`+`VALIDATE` | Redeploy step 4 |
| 6 | After window + proofs + snapshot: `DROP COLUMN name` | Restore-aside only — irreversible by design |
