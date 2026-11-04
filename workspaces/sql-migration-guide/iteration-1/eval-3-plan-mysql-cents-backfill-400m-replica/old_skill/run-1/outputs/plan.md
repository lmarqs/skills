# payments.amount → payments.amount_cents: backfill and rollout plan

**Verdict.** This is a *units change* — the most dangerous compatibility class, because a value
read in the wrong unit doesn't error, it is silently off by 100×. You've already done the right
first two moves (new column, dual-write). What remains is five more deployments, and only the
last one is irreversible. `amount` stays in the table, written by every release, until the
backfill is verified, the app and the BI team both read `amount_cents`, and a rollback window has
expired. It is the source of truth for every repair until then.

The conversion itself is lossless: `DECIMAL(12,2)` holds exactly two decimal places, so
`amount * 100` is an exact integer, and the largest value (`9999999999.99` → `999999999999`) is far
inside `BIGINT`. Nothing is truncated or rounded — provided it's computed in SQL decimal
arithmetic, never through a float.

## Assumptions (check these — several change the plan)

| # | Assumption | If wrong |
|---|---|---|
| A1 | `payments.id` is a `BIGINT AUTO_INCREMENT` primary key | Batch on whatever unique, indexed, monotonic key exists; the script's range walk depends on it |
| A2 | The current release (call it **R2**) dual-writes `amount_cents` on **every** write path — inserts *and* every `UPDATE` that changes `amount` (refunds, captures, adjustments, admin tools) | Any path that updates only `amount` makes `amount_cents` drift after it's backfilled. Find them before the backfill; the `verify` mode below detects drift but doesn't prevent it |
| A3 | Nothing else writes `payments.amount`: no other service, cron, stored procedure, trigger, or manual SQL runbook | Same drift problem; each writer must dual-write or be retired first |
| A4 | R2 computes cents with integer/`Decimal` math (`Decimal(amount) * 100`), not `float` | `float(19.99) * 100 = 1998.9999…` → `int()` gives `1998`. The verify pass catches it, but fix the code before backfilling |
| A5 | `amount` is `NOT NULL` | If already nullable, skip step 5's `MODIFY amount … NULL` |
| A6 | Rolling deploys; the previous release (**R1**, writes `amount` only) is still in the rollback set | If R1 comes back, its writes leave `amount_cents` NULL/stale — re-run backfill, then `repair` |
| A7 | `binlog_format = ROW` and the BI replica is the only replica; no CDC/ETL (DMS, Debezium, Fivetran) reads the binlog | A CDC consumer sees ~400M update events and later a schema change; tell its owners and check its throughput |
| A8 | MySQL engine version is 8.0.30 or later (`SELECT VERSION();`) | Determines whether the final drop can be `ALGORITHM=INSTANT` (see step 6) |
| A9 | Money is read in one place in the app (a model/accessor) you can put behind a flag | If reads are scattered, finding them all is part of step 3 |

## The sequence

Each row is a separate deployment. "Rollback set" = versions that must still work against the
schema/data *during and after* that step.

| Step | What | Schema / data state after | Rollback |
|---|---|---|---|
| 1 ✅ | Expand: `amount_cents BIGINT NULL` | both columns, cents NULL | drop column (nothing reads it) |
| 2 ✅ | R2: dual-write, read `amount` | new rows have both | redeploy R1 → then re-run backfill + repair |
| **3** | **Backfill** + verify | every row has both, equal | none needed: it only fills NULLs from `amount` |
| **4** | R3: read `amount_cents` behind a flag; keep writing both. BI migrates | both columns maintained | flag off (instant); or redeploy R2 — safe, both columns written |
| **5** | After the rollback window: online rebuild (`amount` nullable, `amount_cents NOT NULL`); then R4 stops writing `amount` | `amount` frozen, nothing reads it | redeploy R3 (writes both again). R2 is **no longer** rollback-safe after R4 |
| **6** | After a second window + proof of no readers: drop `amount` | gone | **irreversible** — only via the pre-drop snapshot |

### Step 3 — Backfill (the job below)

**Before starting:**

1. Confirm A2–A4 by code search for every write to `amount` (`amount =`, `amount=`, ORM field
   assignments, raw SQL, `UPDATE payments`). This is the single most important pre-check.
2. Confirm R2 is fully rolled out and R1 is not running anywhere (old pods, workers, queue
   consumers).
3. Agree with the BI team on an acceptable replica lag (the script defaults to throttle at 5 s,
   resume at 2 s) and a time window. Consider running faster overnight with a higher
   `--max-lag`, and conservatively during business hours.
4. Check headroom: `FreeStorageSpace` on both instances (the backfill materializes 8 bytes per row
   for an instant-added column and generates binlog for 400M row updates — with
   `binlog_row_image=FULL` that's before+after images of every row), and the RDS binlog retention
   setting (`CALL mysql.rds_show_configuration;`).
5. No other DDL or online schema change on `payments` while the backfill runs (checklist #10).
6. Dry-run in a staging copy with realistic size to measure batch time and rate. **I haven't
   measured anything; any duration estimate for 400M rows is a guess until you do.** The script
   prints ids/s and an ETA from real throughput.

**Design (why the job looks the way it does):**

- **The write is one statement per batch, computed in SQL** —
  `SET amount_cents = amount * 100 WHERE id >= ? AND id < ? AND amount_cents IS NULL AND amount IS NOT NULL`.
  Reading rows into Python and writing cents back would race with a concurrent app `UPDATE` of
  `amount` between the read and the write and store a stale value. In a single `UPDATE`, InnoDB
  locks the row and computes from its current value.
- **Idempotent**: the `amount_cents IS NULL` predicate makes re-running any range a no-op, and it
  never overwrites a value R2 already wrote.
- **Bounded, by primary-key range, not `LIMIT`.** `WHERE amount_cents IS NULL LIMIT 1000` has no
  index to use, so each batch re-scans from the start of the table — it gets slower as it
  progresses, quadratically on 400M rows. PK ranges are a cheap range scan each time. Batch size
  adapts to keep each transaction near 0.5 s.
- **`READ COMMITTED` session, `innodb_lock_wait_timeout = 5`**: no gap locks blocking app inserts;
  a contended batch fails fast and is retried with backoff instead of stalling payments.
- **Restartable**: the checkpoint (`backfill_progress.next_id`) is advanced in the *same
  transaction* as the batch, so a crash can never skip or double-count a range. Re-run the same
  command to resume.
- **Single worker**: `GET_LOCK` refuses a second concurrent worker. (Overlap would be harmless
  anyway because of the idempotence predicate.)
- **Pausable**: `SIGTERM`/`Ctrl-C` stops after the current batch; or
  `UPDATE backfill_progress SET paused = 1 WHERE job = 'payments.amount_cents.backfill.v1';`
  to pause without killing it.
- **Replica-aware**: checks `Seconds_Behind_Source` on the BI replica before every batch and
  waits when it's over the limit. CloudWatch `ReplicaLag` is 1-minute granularity — too coarse to
  throttle on, but alarm on it.
- **Observable**: `backfill_progress` holds rows changed, batches, retries, failed batches,
  position, and timestamps; the log prints range, rows changed, batch time, %, ids/s, ETA. Total
  rows = `end_id − start` in ids; remaining = `end_id − next_id`.
- **Upper bound**: `MAX(id)` when the job starts. Rows above it are written by R2 with both
  columns; the verify pass over the full table catches any exception.
- **No row stamp needed**: the conversion is a pure function of `amount`, which is kept. Any
  wrong value is found and fixed with `amount_cents <> amount * 100` — that predicate is the
  compensating migration's `WHERE` clause.

**Privileges**: primary user needs `SELECT, UPDATE` on `payments` and `CREATE, SELECT, INSERT,
UPDATE` on `backfill_progress`; replica user needs `SELECT` and `REPLICATION CLIENT`. On
MySQL < 8.0.22 replace `SHOW REPLICA STATUS` / `Seconds_Behind_Source` with `SHOW SLAVE STATUS` /
`Seconds_Behind_Master`.

**Run:**

```bash
pip install pymysql
export MYSQL_USER=... MYSQL_PASSWORD=... MYSQL_DATABASE=...
export MYSQL_PRIMARY_HOST=<writer endpoint> MYSQL_REPLICA_HOST=<BI replica endpoint>

python3 backfill_amount_cents.py backfill      # resumable; re-run the same command after any stop
python3 backfill_amount_cents.py verify        # read-only, against the replica; exit 1 on any finding
python3 backfill_amount_cents.py repair        # only if verify reports mismatched rows
```

**Verification (step 3 is done only when all of these hold — not when the job exits 0):**

The `verify` mode runs these per id range on the replica (wait until lag is ~0 first) so no single
query scans 400M rows:

```sql
-- converged: must be 0
SELECT COUNT(*) FROM payments WHERE amount_cents IS NULL AND amount IS NOT NULL;
-- correct: must be 0
SELECT COUNT(*) FROM payments WHERE amount IS NOT NULL AND amount_cents <> amount * 100;
-- no cents-only rows while amount is still written: must be 0
SELECT COUNT(*) FROM payments WHERE amount IS NULL AND amount_cents IS NOT NULL;
```

Plus an aggregate the BI team can reproduce — it's also the reconciliation they'll trust:

```sql
SELECT DATE(created_at) AS d, SUM(amount) * 100 AS dollars_as_cents, SUM(amount_cents) AS cents
FROM payments
WHERE created_at >= '2025-01-01' AND created_at < '2025-02-01'   -- per month, on the replica
GROUP BY d
HAVING dollars_as_cents <> cents;                                 -- expect no rows
```

(`created_at` is assumed; use the table's timestamp column.)

**Keep running `verify` on a schedule (e.g. daily) until step 5.** Drift after the backfill means
a write path from A2/A3 was missed: find and fix it, then `repair`.

### Step 4 — R3: switch reads to `amount_cents` (deploy dark, then release)

- R3 keeps writing both columns, exactly like R2. Reads come from `amount_cents` when the flag
  `payments_read_amount_cents` is on, from `amount` when it's off.
- While the flag is on, compare: if `amount_cents != amount * 100` for a row read, log a metric
  and serve `amount` (or alert, your choice). That turns every read into a live verification.
- Release: deploy with the flag off → canary a small slice → watch the mismatch metric, payment
  error rates, and totals → widen to 100%.
- Rollback: flag off (no deploy, no schema change). Redeploying R2 is also safe — both columns are
  still maintained.
- The flag changes *who reads which column*, never what gets written, so it can't produce rows a
  version in the rollback set can't read.

**BI team (a second consumer of this schema, on its own schedule):**

- Inventory their use of `amount` on the replica:
  ```sql
  SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
  FROM performance_schema.events_statements_summary_by_digest
  WHERE DIGEST_TEXT LIKE '%payments%' AND DIGEST_TEXT LIKE '%amount%'
  ORDER BY LAST_SEEN DESC;
  ```
  Digest tables are bounded and reset on restart, so pair this with their own query/dashboard
  repository and any saved queries in the BI tool.
- They switch to `amount_cents / 100` (or keep integer cents end-to-end) **after step 3 is
  verified** — before that, `amount_cents` is partially NULL and their sums would be silently low.
  If they want to switch early: `COALESCE(amount_cents, amount * 100)`.
- Optionally give them a stable view (`CREATE VIEW payments_bi AS SELECT …, amount_cents,
  amount_cents / 100 AS amount_dollars …`) so the next physical change doesn't break them again.
- Their sign-off ("no query reads `payments.amount`") is a prerequisite for step 6.

### Rollback window

Agree on it now and write the dates down, with an owner:

- **Window 1** — from R3 at 100% until you're confident R3's reads are right (suggestion: two
  weeks including a month-end close, since money bugs often surface in reconciliation).
  Until it expires, R2 must stay deployable, so `amount` must stay written.
- **Window 2** — from R4 until the drop. `amount` is frozen but intact, so it's still the repair
  source for any row created before R4.

Flag `payments_read_amount_cents` gets the same deadline as the drop of `amount`: remove both
together.

### Step 5 — stop writing `amount`

Prerequisites: window 1 expired, verify clean, BI reading `amount_cents`, R2 out of the rollback
set (after R4, R2 would read `NULL`/stale `amount` for new rows).

1. **Online rebuild** (assuming A5): R4 can't omit `amount` from inserts while it's `NOT NULL`, and
   making it nullable rebuilds the table in MySQL. Do both tightenings in one pass:
   ```sql
   ALTER TABLE payments
     MODIFY amount       DECIMAL(12,2) NULL,
     MODIFY amount_cents BIGINT        NOT NULL;
   ```
   Don't run this as plain `ALTER TABLE` on 400M rows: even with `ALGORITHM=INPLACE` the replica
   replays it as one long statement *after* it finishes on the primary, so the BI replica stops
   applying changes for the whole rebuild. Use **gh-ost** (binlog-based, throttles on replica
   lag; on RDS run it with `--allow-on-master --assume-rbr` against the writer) or
   **pt-online-schema-change** (trigger-based). Both throttle and can be paused. Verify
   `amount_cents` has zero NULLs immediately before cutover, or the `NOT NULL` copy fails.
   R2 and R3 are both fine with this schema: they always write both columns.
2. **R4**: remove `amount` from the model/ORM mapping entirely (many ORMs include every mapped
   column in `INSERT`/`UPDATE`), read and write only `amount_cents`. Rollback: redeploy R3, which
   writes both again; rows written by R4 in the meantime have `amount = NULL` — R3 reads cents,
   so it doesn't care, and `repair`-style backfill can refill `amount` from `amount_cents / 100`
   if you ever need it.

### Step 6 — drop `amount` (the only irreversible step)

Run it alone, as its own change, only after proving:

- [ ] Window 2 expired.
- [ ] No application version reads or writes `amount`: code search across all repos/services,
      plus `performance_schema.events_statements_summary_by_digest` on **both** the primary and
      the replica shows no statement touching `payments.amount` since R4.
- [ ] BI sign-off; no dashboards, saved queries or extracts reference it.
- [ ] Last `verify` clean for rows before R4 (`amount_cents = amount * 100`).
- [ ] A recovery source exists: take a manual RDS snapshot right before the drop and keep it
      for a defined period (and/or export `(id, amount)` with RDS snapshot export to S3). After
      the drop this is the only place the original values live.

```sql
ALTER TABLE payments DROP COLUMN amount, ALGORITHM=INSTANT;
```

- `ALGORITHM=INSTANT` for `DROP COLUMN` needs MySQL 8.0.29+; I'd require 8.0.30+ (8.0.29 had
  instant-DDL defects — verify against the MySQL release notes for your RDS minor version). With
  `ALGORITHM=INSTANT` stated explicitly, MySQL errors instead of silently falling back to a
  rebuild. InnoDB caps instant changes per table (`TOTAL_ROW_VERSIONS` in
  `information_schema.INNODB_TABLES`, limit 64); if it refuses, use gh-ost instead.
- Even an instant DDL takes an exclusive metadata lock. On the replica, the applier waits behind
  any long-running BI `SELECT` on `payments`, and every BI query after it queues behind the
  pending lock — replication *and* BI stall together. Run it in a window agreed with BI, check
  for long queries on the replica first (`SELECT * FROM information_schema.PROCESSLIST WHERE
  TIME > 60`), and be ready to kill them. On the primary, set `SET SESSION lock_wait_timeout = 5`
  before the `ALTER` so it gives up rather than blocking payment writes.

## Recovery plan (decided before deploying)

| What went wrong | Repair | Source of truth |
|---|---|---|
| Backfill wrote wrong cents | `repair` mode: batched, idempotent `SET amount_cents = amount * 100 WHERE NOT (amount_cents <=> amount * 100)` | `amount` (still present) |
| A write path updates only `amount` (drift) | Fix the path, then `repair` | `amount` |
| R1 redeployed during step 3–4 | Re-run `backfill` with a new `--job` name, then `verify` | `amount` |
| R3 reads look wrong | Flag off; investigate; no schema change | both columns |
| Wrong cents after step 5 (R4 writes cents only) | Fix code; compensating update from app logs / payment provider records for rows since R4 | rows before R4: `amount`; after: external records |
| Problem found after the drop | Restore the pre-drop snapshot **to a separate instance**, extract `(id, amount)`, repair only the affected rows in production | snapshot |

A point-in-time restore of the production instance is not on the table at any step: it would
discard every valid payment written since the restore point to fix a column that has an exact,
still-present source (`amount`) until step 6, and a snapshot after it.

**While the backfill runs, watch:** replica lag (script + CloudWatch alarm), primary
`Threads_running` and p99 payment write latency, lock waits/deadlocks (the job's `retries`
counter), `FreeStorageSpace` on both instances, binlog disk usage, and InnoDB history list length
(`SHOW ENGINE INNODB STATUS`). Pause (`paused = 1`) if any degrade.

## Pre-deployment checklist

1. **Previous version vs new schema?** Yes at every step through 5; R1 after step 2 needs a
   re-backfill; R2 after R4 is unsafe (by design — window 1 must have expired).
2. **Old and new at once?** Yes: every release up to R3 writes both columns; R4 runs alongside R3
   safely because R3 reads cents.
3. **Deletes/transforms information?** The backfill adds a derived copy, losslessly. Only step 6
   deletes; the original lives in the pre-drop snapshot.
4. **Safe to re-run?** Yes: `amount_cents IS NULL` predicate (backfill) / mismatch predicate
   (repair).
5. **Stop and resume?** Yes: transactional checkpoint, `SIGTERM`, `paused` flag.
6. **Verify correctness?** `verify` mode + per-day aggregate reconciliation + R3's read-time
   comparison.
7. **Disable without schema revert?** Flag `payments_read_amount_cents`.
8. **Recovery path?** Table above.
9. **Destructive cleanup when, and proven how?** Step 6 checklist; dates and owner to fill in:
   window 1 ends `____`, window 2 ends `____`, owner `____`.
10. **Concurrent migrations?** No other DDL/online schema change on `payments` during steps 3, 5
    and 6; check the release calendar for anything touching payments or the BI replica.

## Backfill job — `backfill_amount_cents.py`

Syntax-checked with `py_compile`; not executed against a database. Run it against a staging copy
first.

```python
#!/usr/bin/env python3
"""Backfill, verify, and repair payments.amount_cents from payments.amount.

Walks the primary key in bounded ranges. Every write is a single UPDATE that derives
amount_cents from amount in the same row, so the value can never be computed from a stale read.
Progress is committed in the same transaction as each batch: a crash resumes from the last
committed range. The idempotence predicate makes re-running or overlapping any range a no-op.
Throttles on replica lag so the BI replica stays fresh.

Modes:
  backfill  fill rows where amount_cents IS NULL
  verify    count unconverted and mismatched rows, read-only (point it at the replica)
  repair    rewrite rows where amount_cents disagrees with amount (compensating migration)
"""
from __future__ import annotations

import argparse
import logging
import os
import signal
import time

import pymysql

ER_LOCK_WAIT_TIMEOUT = 1205
ER_LOCK_DEADLOCK = 1213
RETRYABLE_ERRORS = {ER_LOCK_WAIT_TIMEOUT, ER_LOCK_DEADLOCK}

log = logging.getLogger("amount_cents")

BACKFILL_SQL = """
UPDATE payments
SET    amount_cents = amount * 100
WHERE  id >= %s AND id < %s
  AND  amount_cents IS NULL
  AND  amount IS NOT NULL
"""

REPAIR_SQL = """
UPDATE payments
SET    amount_cents = amount * 100
WHERE  id >= %s AND id < %s
  AND  amount IS NOT NULL
  AND  NOT (amount_cents <=> amount * 100)
"""

VERIFY_SQL = """
SELECT
  SUM(amount_cents IS NULL AND amount IS NOT NULL)              AS unconverted,
  SUM(amount IS NOT NULL AND amount_cents <> amount * 100)      AS mismatched,
  SUM(amount IS NULL AND amount_cents IS NOT NULL)              AS cents_without_amount
FROM payments
WHERE id >= %s AND id < %s
"""

PROGRESS_DDL = """
CREATE TABLE IF NOT EXISTS backfill_progress (
  job            VARCHAR(64) NOT NULL PRIMARY KEY,
  next_id        BIGINT      NOT NULL,
  end_id         BIGINT      NOT NULL,
  rows_changed   BIGINT      NOT NULL DEFAULT 0,
  batches        BIGINT      NOT NULL DEFAULT 0,
  retries        BIGINT      NOT NULL DEFAULT 0,
  failed_batches BIGINT      NOT NULL DEFAULT 0,
  paused         TINYINT     NOT NULL DEFAULT 0,
  started_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)
"""


class Stop(Exception):
    """Raised between batches when a shutdown signal arrived."""


stop_requested = False


def request_stop(signum, _frame):
    global stop_requested
    log.warning("signal %s received; stopping after the current batch", signum)
    stop_requested = True


def connect(host: str, autocommit: bool) -> pymysql.connections.Connection:
    conn = pymysql.connect(
        host=host,
        port=int(os.environ.get("MYSQL_PORT", "3306")),
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        database=os.environ["MYSQL_DATABASE"],
        autocommit=autocommit,
        connect_timeout=10,
        read_timeout=120,
        write_timeout=120,
    )
    with conn.cursor() as cur:
        # READ COMMITTED releases locks on scanned rows that don't match the predicate and
        # avoids gap locks, so app inserts/updates near the batch range aren't blocked.
        cur.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED")
        cur.execute("SET SESSION innodb_lock_wait_timeout = 5")
    return conn


def replica_lag_seconds(replica: pymysql.connections.Connection) -> float | None:
    """Seconds_Behind_Source from the replica; None means replication is not running."""
    with replica.cursor(pymysql.cursors.DictCursor) as cur:
        cur.execute("SHOW REPLICA STATUS")
        row = cur.fetchone()
    if not row:
        return None
    lag = row.get("Seconds_Behind_Source")
    return None if lag is None else float(lag)


def wait_for_replica(replica, max_lag: float, resume_lag: float) -> None:
    lag = replica_lag_seconds(replica)
    if lag is not None and lag <= max_lag:
        return
    log.info("replica lag %s s > %s s; throttling", lag, max_lag)
    while not stop_requested:
        time.sleep(5)
        lag = replica_lag_seconds(replica)
        if lag is not None and lag <= resume_lag:
            log.info("replica lag %s s; resuming", lag)
            return
    raise Stop


def load_or_init_progress(primary, job: str, start_id: int | None, end_id: int | None) -> dict:
    with primary.cursor(pymysql.cursors.DictCursor) as cur:
        cur.execute(PROGRESS_DDL)
        cur.execute("SELECT * FROM backfill_progress WHERE job = %s", (job,))
        row = cur.fetchone()
        if row:
            log.info("resuming %s at id %s of %s", job, row["next_id"], row["end_id"])
            return row
        cur.execute("SELECT MIN(id) AS lo, MAX(id) AS hi FROM payments")
        bounds = cur.fetchone()
        next_id = start_id if start_id is not None else bounds["lo"]
        # Rows above the starting MAX(id) are written by the dual-writing release; the final
        # verify pass over the whole table catches any exception.
        last_id = end_id if end_id is not None else bounds["hi"] + 1
        cur.execute(
            "INSERT INTO backfill_progress (job, next_id, end_id) VALUES (%s, %s, %s)",
            (job, next_id, last_id),
        )
    primary.commit()
    return {"job": job, "next_id": next_id, "end_id": last_id, "paused": 0}


def is_paused(primary, job: str) -> bool:
    with primary.cursor() as cur:
        cur.execute("SELECT paused FROM backfill_progress WHERE job = %s", (job,))
        (paused,) = cur.fetchone()
    primary.commit()
    return bool(paused)


def run_batch(primary, sql: str, job: str, lo: int, hi: int) -> int:
    """Apply one range and advance the checkpoint atomically. Returns rows changed."""
    with primary.cursor() as cur:
        changed = cur.execute(sql, (lo, hi))
        cur.execute(
            "UPDATE backfill_progress "
            "SET next_id = %s, rows_changed = rows_changed + %s, batches = batches + 1 "
            "WHERE job = %s AND next_id = %s",
            (hi, changed, job, lo),
        )
        if cur.rowcount != 1:
            # Another worker advanced the checkpoint; our write was still idempotent.
            primary.rollback()
            raise RuntimeError(f"checkpoint for {job} moved underneath us at id {lo}")
    primary.commit()
    return changed


def bump(primary, job: str, column: str) -> None:
    with primary.cursor() as cur:
        cur.execute(f"UPDATE backfill_progress SET {column} = {column} + 1 WHERE job = %s", (job,))
    primary.commit()


def write_loop(args, sql: str) -> None:
    primary = connect(args.primary, autocommit=False)
    replica = connect(args.replica, autocommit=True)

    with primary.cursor() as cur:
        cur.execute("SELECT GET_LOCK(%s, 0)", (f"backfill:{args.job}",))
        (got_lock,) = cur.fetchone()
    if got_lock != 1:
        raise SystemExit(f"another worker holds the lock for {args.job}")

    progress = load_or_init_progress(primary, args.job, args.start_id, args.end_id)
    lo, end = progress["next_id"], progress["end_id"]
    chunk = args.chunk
    started = time.monotonic()
    first_lo = lo

    while lo < end:
        if stop_requested:
            raise Stop
        while is_paused(primary, args.job):
            log.info("job paused via backfill_progress.paused; sleeping")
            time.sleep(30)
            if stop_requested:
                raise Stop
        wait_for_replica(replica, args.max_lag, args.resume_lag)

        hi = min(lo + chunk, end)
        for attempt in range(1, args.max_retries + 1):
            t0 = time.monotonic()
            try:
                changed = run_batch(primary, sql, args.job, lo, hi)
                break
            except pymysql.err.OperationalError as exc:
                primary.rollback()
                if exc.args[0] not in RETRYABLE_ERRORS or attempt == args.max_retries:
                    bump(primary, args.job, "failed_batches")
                    raise
                bump(primary, args.job, "retries")
                log.warning("batch [%s,%s) attempt %s failed: %s", lo, hi, attempt, exc)
                time.sleep(min(2 ** attempt, 30))
        elapsed = time.monotonic() - t0

        # Keep each transaction short: grow the range when batches are fast, shrink when slow.
        if elapsed < args.target_seconds / 2:
            chunk = min(chunk * 2, args.max_chunk)
        elif elapsed > args.target_seconds:
            chunk = max(chunk // 2, args.min_chunk)

        done, total = hi - first_lo, end - first_lo
        rate = done / max(time.monotonic() - started, 1e-6)
        log.info(
            "range [%s,%s) changed=%s took=%.3fs chunk=%s progress=%.2f%% ids/s=%.0f eta=%.1fh",
            lo, hi, changed, elapsed, chunk, 100 * done / total, rate,
            (end - hi) / max(rate, 1e-6) / 3600,
        )
        lo = hi
        time.sleep(args.sleep)

    log.info("%s reached end_id %s", args.job, end)


def verify(args) -> None:
    conn = connect(args.replica, autocommit=True)
    with conn.cursor() as cur:
        cur.execute("SELECT MIN(id), MAX(id) FROM payments")
        lo, hi = cur.fetchone()
    lo = args.start_id if args.start_id is not None else lo
    end = args.end_id if args.end_id is not None else hi + 1
    totals = {"unconverted": 0, "mismatched": 0, "cents_without_amount": 0}
    while lo < end:
        if stop_requested:
            raise Stop
        top = min(lo + args.max_chunk, end)
        with conn.cursor(pymysql.cursors.DictCursor) as cur:
            cur.execute(VERIFY_SQL, (lo, top))
            row = cur.fetchone()
        for key in totals:
            count = int(row[key] or 0)
            if count:
                log.warning("range [%s,%s) %s=%s", lo, top, key, count)
            totals[key] += count
        lo = top
    log.info("verify totals: %s", totals)
    if any(totals.values()):
        raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("mode", choices=["backfill", "verify", "repair"])
    parser.add_argument("--primary", default=os.environ.get("MYSQL_PRIMARY_HOST"))
    parser.add_argument("--replica", default=os.environ.get("MYSQL_REPLICA_HOST"))
    parser.add_argument("--job", help="checkpoint key; defaults per mode")
    parser.add_argument("--start-id", type=int)
    parser.add_argument("--end-id", type=int, help="exclusive upper bound")
    parser.add_argument("--chunk", type=int, default=2_000, help="initial id-range size")
    parser.add_argument("--min-chunk", type=int, default=200)
    parser.add_argument("--max-chunk", type=int, default=20_000)
    parser.add_argument("--target-seconds", type=float, default=0.5, help="target batch duration")
    parser.add_argument("--sleep", type=float, default=0.05, help="pause between batches")
    parser.add_argument("--max-lag", type=float, default=5, help="throttle above this replica lag")
    parser.add_argument("--resume-lag", type=float, default=2, help="resume below this replica lag")
    parser.add_argument("--max-retries", type=int, default=5)
    args = parser.parse_args()
    args.job = args.job or f"payments.amount_cents.{args.mode}.v1"

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)

    try:
        if args.mode == "verify":
            verify(args)
        else:
            write_loop(args, BACKFILL_SQL if args.mode == "backfill" else REPAIR_SQL)
    except Stop:
        log.info("stopped cleanly; rerun the same command to resume")


if __name__ == "__main__":
    main()
```
