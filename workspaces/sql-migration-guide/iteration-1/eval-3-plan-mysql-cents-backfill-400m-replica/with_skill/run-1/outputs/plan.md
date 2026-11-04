# `payments.amount` (DECIMAL dollars) → `payments.amount_cents` (BIGINT cents): backfill and rollout plan

## Summary

This change alters a column's **units**, so it goes through Expand–Migrate–Contract. Nothing is
converted in place. You are part-way through already: Expand (`amount_cents BIGINT NULL`) and
dual-write (release **v2**) are done. What remains:

1. **Gate on dual-write.** Prove v2 writes both columns on *every* write path (inserts *and*
   updates) and that no other writer touches `amount`. The backfill can't repair drift that
   happens after it passes a row.
2. **Backfill** 400M rows with the job in this document. It converts in SQL, never through
   Python floats. It walks the primary key in bounded batches, keeps a compare-and-set
   checkpoint, can be paused, and **throttles on measured replica lag** so the BI replica stays
   fresh. Rows per hour has to be measured on a clone first. The arithmetic below ranges from
   about 14 hours to about 2.3 days.
3. **Verify** on the primary and on the BI replica: zero missing, zero mismatched.
4. **Move readers.** App reads go behind a flag with shadow comparison (v3), then cents-only
   reads (v4). BI and every other consumer move in parallel. That work is the long pole.
5. **Contract** in separate deploys: online rebuild to `amount_cents NOT NULL` / `amount NULL`
   (gh-ost, not native `ALTER`, because of the replica), then v5 stops writing `amount`, then
   rename `amount` as an empirical "nobody reads this" test through a month-end, then snapshot
   and drop.

The two replica-specific hazards decide most of the design:

- **Backfill binlog volume becomes replica lag** that BI sees as stale reports. The job paces
  itself on lag.
- **Any DDL on `payments` replays on the replica and waits for BI's long queries** (metadata
  lock), stalling replication. New BI queries then queue behind it. Every DDL step below has a
  replica coordination step.

## Assumptions (stated instead of asked) and blocking questions

| # | Assumption | If wrong |
|---|---|---|
| A1 | `payments.id` is a `BIGINT AUTO_INCREMENT` primary key. | The batching must walk whatever the PK is. A composite PK needs a different cursor. |
| A2 | `amount` is `NOT NULL`. | If nullable, step C1 shrinks to the optional `NOT NULL` hardening of `amount_cents`. |
| A3 | **"Cents" means hundredths for every row:** `amount_cents = amount × 100`. | **Blocking question.** If `payments` has a currency column and the target is ISO-4217 minor units (JPY has 0 decimals, KWD/BHD 3), the conversion is per-currency and the column name is misleading. Decide before the backfill bakes ×100 into 400M rows. DECIMAL(12,2) cannot hold 3-decimal amounts anyway. |
| A4 | v2 writes both columns **in the same statement or transaction**, on inserts and on every update of `amount` (captures, refunds, adjustments). | Drift on updated rows. Gate G0 detects it. Fix v2, or add a trigger (Step 0b), before backfilling. |
| A5 | Rolling deploys, rollback window **14 days** per release, BI has a **month-end close**. | Replace the windows below with yours. Gates are evidence-based. Dates are only the earliest possible. |
| A6 | Binlog is ROW format with `binlog_row_image=FULL` (needed by gh-ost and most CDC). | Check the parameter group. It changes the binlog volume estimate. |
| A7 | No CDC/ETL (DMS, Debezium, Fivetran) reads the primary's binlog. | If one does, 400M update events flow downstream. Warn the owner and check their retention and cost. |
| A8 | Engine version unknown. | Run `SELECT VERSION();`. Instant `DROP COLUMN` needs **8.0.29+**, and 8.0.29 itself was withdrawn upstream, so use 8.0.30+ (inference from memory, verify in the release notes). MySQL 8.0 reached community end of life in April 2026. Check your RDS support status: a major upgrade to 8.4 in flight would interact with this plan (checklist item 10). |

Conversion correctness (verified by arithmetic): `DECIMAL(12,2)` max is `9,999,999,999.99`, so
the maximum is `999,999,999,999` cents. That is far below BIGINT's `9.22e18`. `amount * 100` is
exact DECIMAL arithmetic with a `.00` fraction, so `CAST(... AS SIGNED)` loses nothing.
Negative amounts (refunds) convert the same way.

## Three risks

| Risk | Assessment |
|---|---|
| **Availability** | The backfill is ~400M row updates. With batches it holds row locks for milliseconds, but it generates heavy binlog (FULL images, before plus after) that turns into **replica lag**. Storage grows by at least 8 B × 400M ≈ 3.2 GB, plus page splits, plus binlog until it is purged. The contract DDL is the other availability risk: `MODIFY ... NOT NULL` / `NULL` rebuilds the table. Natively that is INPLACE on the primary, but on the replica it replays as one statement **after** the primary finishes, which means hours of replica lag. Hence gh-ost. |
| **Compatibility** | Safe through v2→v4 because `amount` stays written and correct. It breaks if v5 (stops writing `amount`) ships while anything still reads `amount`. New rows would show `NULL`, and BI reports `SUM(amount)` silently undercount. **BI is the consumer most likely to break, and silently.** The rollback target moves: after v5 only v4 is safe, because v2 and v3 read `amount`. |
| **Reversibility** | The backfill writes only `amount_cents`, so `amount` stays authoritative until v4. A wrong backfill is fixed by re-running it forward (R0/R1). Dropping `amount` is **R2**: the information survives in `amount_cents` only if convergence was verified, so the verification record and a retained snapshot are the evidence. |

## Steps

Code versions: **v1** wrote `amount` only (must be gone). **v2** is current: writes both, reads
`amount`. **v3** reads `amount_cents` behind a flag with shadow compare and writes both. **v4**
reads cents only and writes both (`amount` derived from cents). **v5** neither reads nor writes
`amount`.

| Step | What runs | Code live | Lock / duration on 400M rows | Verified by | Rollback target if wrong |
|---|---|---|---|---|---|
| **0** | Decisions and gate G0 (below). Open the cleanup ticket. | v2 | none | G0 queries = 0 | n/a |
| **0b** (only if G0 finds unknown writers) | `BEFORE INSERT/UPDATE` trigger deriving `amount_cents` from `amount` | v2 | brief exclusive MDL on primary **and replica** (coordinate as for DDL) | G0 re-run = 0 | `DROP TRIGGER` |
| **1** | Create `migration_progress`, `migration_heartbeat` | v2 | new tables, nothing on `payments` | tables exist on the replica | drop them |
| **2** | **Rehearsal** on a clone: restore a snapshot to a new instance, add a read replica, run the job and the gh-ost C1 | v2 | none in prod | numbers recorded (below) | n/a |
| **3** | **Backfill** production | v2 | row locks per batch (target ≤0.5 s), replica lag ≤ threshold; duration from step 2 | job reports `done`; dashboards | pause; v2 (nothing reads `amount_cents` yet) |
| **4** | **Verify** primary and BI replica | v2 | read-only chunked scan, run off-peak on the replica | `verify` exits 0 on both | re-run step 3 (it is idempotent) |
| **5** | Tell BI and consumers `amount_cents` is complete. They migrate. | v2 | none | consumer inventory signed off (step 8 gate) | n/a |
| **6** | Deploy **v3**, ramp the flag `payments.read_amount_cents` 1%→100% with shadow compare | v2+v3 | none | divergence metric = 0 across a weekly cycle | flag off (v2 behavior) |
| **7** | Deploy **v4**: cents-only reads, cents is the source of truth for writes, still writes `amount = cents/100`. Delete the backfill job. | v3+v4 | none | error rate, divergence metric | v3 or v2 (both still safe: `amount` is still written) |
| **8** | **Gate**: v4 at 100% for 14 days; no reader of `amount` anywhere (G8) | v4 | none | G8 evidence | n/a |
| **C1** | gh-ost: `MODIFY amount_cents BIGINT NOT NULL, MODIFY amount DECIMAL(12,2) NULL` | v4 | online row copy, throttled on replica lag; brief cutover rename (MDL on primary and replica); hours, measured in step 2 | post-cutover checks (below) | not needed: the schema works with v2–v4; keep `_payments_del` a few days |
| **C2** | Deploy **v5**: `amount` removed from the ORM model, inserts and updates (not just "unused") | v4+v5 | none | error rate; new rows have `amount IS NULL` | **v4 only**. Mark v2/v3 as non-deployable in the deploy tool. |
| **C3** | After v5's 14-day window: `RENAME COLUMN amount TO amount_deprecated_20270201` (example date) and wait through **one full month-end close** | v5 | metadata-only, MDL on primary and replica | nothing fails; no one complains | rename back (instant). Required before any rollback to v4. |
| **C4** | Manual RDS snapshot (retain ≥ 90 days), then `DROP COLUMN amount_deprecated_...`; drop helper tables, flag, shadow code | v5 | `ALGORITHM=INSTANT` on 8.0.30+, else fold into a gh-ost run | column gone; checks green | roll forward only; restore-aside from the snapshot |

**Earliest drop date** = max(v5 at 100% + 14 days, the first month-end close after C3) + the
close itself. With no waiting on BI, that is about 6–8 weeks after the backfill finishes. In
practice the BI migration (step 5) sets the date.

### Step 0: gate G0, before the backfill

- **Every instance runs v2.** Check app services, workers, cron and admin tools. A straggling
  v1 writes rows with `amount_cents NULL` (the backfill would catch those) and **updates
  `amount` without `amount_cents`** (it would not, if they happen after the backfill passed
  the row).
- **No unknown writers.** On the primary, look for statements writing `amount` without
  `amount_cents`:

  ```sql
  SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
  FROM   performance_schema.events_statements_summary_by_digest
  WHERE  DIGEST_TEXT REGEXP '(UPDATE|INSERT).*`payments`'
    AND  DIGEST_TEXT REGEXP '`amount`'
    AND  DIGEST_TEXT NOT LIKE '%`amount_cents`%';
  -- expect: no rows. The digest table is bounded and resets on restart, so sample across days.
  ```

- **Dual-write is correct on rows written since v2.** Run
  `backfill_amount_cents.py verify --from-id <first id written by v2>`. Expect 0 missing and 0
  mismatched. Mismatches here mean v2 has a write path that misses `amount_cents`. Fix v2 or
  add the trigger (0b) before step 3.
- **Trigger option (0b).** It catches every writer, including consoles and other services.
  Body: `SET NEW.amount_cents = CAST(NEW.amount * 100 AS SIGNED)`. On RDS, creating triggers
  with binary logging on usually needs `log_bin_trust_function_creators=1` in the parameter
  group (verify for your setup). The trigger must be dropped before v4, where cents becomes
  the source of truth, and before C1 unless your gh-ost version supports triggers.
- **Consumer inventory started** (needed by step 8): BI dashboards and saved queries, ETL and
  warehouse loads, exports, event payloads containing `amount`, API responses, caches holding
  serialized payments, views/procedures/triggers:

  ```sql
  SELECT TABLE_NAME FROM information_schema.VIEWS
  WHERE  VIEW_DEFINITION LIKE '%payments%' AND VIEW_DEFINITION LIKE '%amount%';
  SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_DEFINITION LIKE '%amount%';
  SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE EVENT_OBJECT_TABLE = 'payments';
  ```

- **Cleanup ticket opened now.** Include the C1–C4 statements, the step-8 gate and the
  earliest date. The expand is incomplete without it.

### Step 2: rehearsal (mandatory at this size)

On a snapshot-restored clone with its own read replica, run the backfill with production
settings and an artificial BI-like read load on the replica. Record:

| Measure | How | Used for |
|---|---|---|
| ids/s and rows/s at batch 2,000 | job log | duration estimate in this plan |
| batch p99 seconds | job log | `--target-batch-seconds` |
| replica lag profile | job log, CloudWatch `ReplicaLag` | `--max-lag` values |
| binlog bytes per 1M rows | `SHOW BINARY LOGS` before and after | storage headroom, binlog retention, CDC volume |
| table size growth | `information_schema.TABLES` (`DATA_LENGTH`) | `FreeStorageSpace` headroom |
| gh-ost C1 duration and cutover | gh-ost output | C1 window with BI |
| `verify` duration | job log | step 4 scheduling |

**Duration arithmetic (not measured).** 400M / 2,000 rows = 200,000 batches. A full cycle
(batch plus sleep) of 0.25 s gives ~13.9 h; 0.5 s gives ~27.8 h; 1 s gives ~55.6 h (2.3 days).
Lag throttling during BI hours pushes it toward the slow end. If the rehearsal shows more than
about a week, revisit the approach before starting (for example, a gh-ost run with a generated
value instead of a backfill).

### C1: why gh-ost, and its sharp edges

- Native `ALTER TABLE ... MODIFY ... NOT NULL` is `INPLACE` with a full rebuild. It allows DML
  on the primary, but the replica applies it as one statement after the primary commits. That
  means hours with **replication frozen** and BI on stale data. gh-ost copies rows as ordinary
  replicated writes and throttles on replica lag.
- Sketch (check flags against your gh-ost version's docs):

  ```
  gh-ost --host=<primary> --database=<db> --table=payments \
    --alter="MODIFY amount_cents BIGINT NOT NULL, MODIFY amount DECIMAL(12,2) NULL" \
    --allow-on-master --assume-rbr \
    --throttle-control-replicas=<bi-replica> --max-lag-millis=2000 \
    --max-load=Threads_running=40 --critical-load=Threads_running=200 \
    --chunk-size=1000 --postpone-cut-over-flag-file=/tmp/ghost.postpone \
    --execute
  ```

- **gh-ost refuses tables with foreign keys.** If `payments` has FKs in either direction, the
  options are `pt-online-schema-change` (its FK handling has its own risks; rehearse it) or a
  native rebuild in an agreed BI downtime window for the replica.
- **NULL into NOT NULL under the copier's `INSERT IGNORE` semantics can silently become `0`.**
  Inference from how gh-ost copies rows; confirm on the clone. Make **zero NULL
  `amount_cents`** a hard precondition, checked immediately before starting (G0 plus v2+ always
  writing it keep it at zero). Afterwards check
  `SELECT COUNT(*) FROM payments WHERE amount_cents = 0 AND amount <> 0;` → expect 0.
- Cut over only inside the replica coordination window (below). Keep `_payments_del` for a few
  days as a pre-image, then drop it off-peak. Dropping a huge table can stall the server
  briefly.
- If `amount` is already nullable (A2) and you decide `NOT NULL` isn't worth one rebuild, skip
  C1. Then keep a scheduled `amount_cents IS NULL` invariant check instead.

### Replica coordination for every DDL on `payments` (0b, C1 cutover, C3, C4)

A DDL needs an exclusive metadata lock on the replica too. A BI query running for 40 minutes
holds the applier for 40 minutes, and every new BI query on `payments` queues behind it.

1. Agree a 15-minute window with BI and pause their scheduled jobs on `payments`.
2. On the replica, kill long queries on `payments` just before the DDL:
   `SELECT ID, TIME, INFO FROM information_schema.PROCESSLIST WHERE COMMAND = 'Query' AND TIME > 60;`
   then `CALL mysql.rds_kill(<id>);`.
3. On the primary, run DDL with `SET SESSION lock_wait_timeout = 10;` so it fails fast instead
   of queueing behind a long transaction. Retry with backoff.
4. Watch the replica for `Waiting for table metadata lock` and kill its blocker if it appears.

## Backfill job

### Helper tables (step 1, via your normal migration runner)

```sql
CREATE TABLE IF NOT EXISTS migration_progress (
  migration_id VARCHAR(64)  NOT NULL PRIMARY KEY,
  last_id      BIGINT       NOT NULL DEFAULT 0,
  max_id       BIGINT       NOT NULL,
  rows_updated BIGINT       NOT NULL DEFAULT 0,
  batches      BIGINT       NOT NULL DEFAULT 0,
  state        ENUM('running','paused','done') NOT NULL DEFAULT 'running',
  updated_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS migration_heartbeat (
  id TINYINT     NOT NULL PRIMARY KEY,
  ts DATETIME(6) NOT NULL
) ENGINE=InnoDB;
```

### Design choices

- **The conversion is done by MySQL**, in the same statement that writes it. No
  read-modify-write from Python, so there is no race with concurrent app updates and no float.
- **Guard predicate** `NOT (amount_cents <=> CAST(amount * 100 AS SIGNED)) AND amount IS NOT
  NULL`. It is idempotent: a re-run matches 0 rows. It also repairs drift, not just NULLs. It
  can never write NULL into `amount_cents`. It is valid only while `amount` is the source of
  truth, which is why the job is deleted in step 7.
- **Keyset batches on the PK.** The next upper bound is the id N rows ahead, so gaps don't
  produce empty or oversized batches. No `OFFSET` scans from the table start.
- **`READ COMMITTED` session.** No gap locks, so the batch near the table tail does not block
  the app's inserts. Short `innodb_lock_wait_timeout` means the job yields to the app, not the
  other way round.
- **Checkpoint committed in the same transaction as the batch, compare-and-set on `last_id`.**
  A crash resumes exactly. A second worker started by mistake fails on its first batch.
- **Lag measured, not inferred.** A timestamp is written to the primary and the job times how
  long the replica takes to show it. This is independent of `Seconds_Behind_Source` quirks and
  clock skew, and needs no replication privileges.
- **No per-row failure table.** The transform is DECIMAL arithmetic that cannot fail or
  overflow. Failures are per batch (lock wait, deadlock, lost connection): retried with
  backoff, then the batch is halved, then the job exits non-zero with its checkpoint intact
  (park and page).
- **Upper bound = `MAX(id)` at first start.** Later rows are written by v2 with both columns.
  `verify` covers the whole table regardless.

### `backfill_amount_cents.py`

```python
#!/usr/bin/env python3
"""Backfill payments.amount_cents from payments.amount.

Bounded, idempotent, restartable, pausable, and throttled on measured replica lag.
Credentials come from the environment: PRIMARY_HOST, PRIMARY_USER, PRIMARY_PASSWORD,
REPLICA_HOST, REPLICA_USER, REPLICA_PASSWORD, DB_NAME, optional *_PORT and DB_SSL_CA.

    backfill_amount_cents.py run    [--batch-size 2000] [--max-lag 2] [--peak-max-lag 1]
    backfill_amount_cents.py verify [--target replica] [--from-id N]

Pause:  UPDATE migration_progress SET state='paused'  WHERE migration_id='2026_11_payments_amount_cents';
Resume: UPDATE migration_progress SET state='running' WHERE migration_id='2026_11_payments_amount_cents';
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import logging
import os
import signal
import sys
import time

import pymysql

MIGRATION_ID = "2026_11_payments_amount_cents"
RETRYABLE = {1205, 1213, 2006, 2013}  # lock wait timeout, deadlock, server gone, lost connection
RECONNECT = {2006, 2013}

NEXT_UPPER = """
    SELECT id FROM payments
    WHERE id > %s AND id <= %s
    ORDER BY id
    LIMIT 1 OFFSET %s
"""

BACKFILL = """
    UPDATE payments
    SET    amount_cents = CAST(amount * 100 AS SIGNED)
    WHERE  id > %s AND id <= %s
      AND  amount IS NOT NULL
      AND  NOT (amount_cents <=> CAST(amount * 100 AS SIGNED))
"""

ADVANCE = """
    UPDATE migration_progress
    SET    last_id = %s, rows_updated = rows_updated + %s, batches = batches + 1
    WHERE  migration_id = %s AND last_id = %s
"""

VERIFY_CHUNK = """
    SELECT COUNT(*),
           COALESCE(SUM(amount IS NOT NULL AND amount_cents IS NULL), 0),
           COALESCE(SUM(NOT (amount_cents <=> CAST(amount * 100 AS SIGNED))), 0),
           COALESCE(SUM(amount IS NULL), 0)
    FROM   payments
    WHERE  id > %s AND id <= %s
"""

VERIFY_SAMPLE = """
    SELECT id FROM payments
    WHERE  id > %s AND id <= %s
      AND  NOT (amount_cents <=> CAST(amount * 100 AS SIGNED))
    LIMIT  20
"""

log = logging.getLogger("backfill_amount_cents")


def connect(prefix: str, *, autocommit: bool) -> pymysql.connections.Connection:
    ca = os.environ.get("DB_SSL_CA")
    return pymysql.connect(
        host=os.environ[f"{prefix}_HOST"],
        port=int(os.environ.get(f"{prefix}_PORT", "3306")),
        user=os.environ[f"{prefix}_USER"],
        password=os.environ[f"{prefix}_PASSWORD"],
        database=os.environ["DB_NAME"],
        autocommit=autocommit,
        connect_timeout=10,
        read_timeout=120,
        write_timeout=120,
        ssl={"ca": ca} if ca else None,
    )


def connect_primary() -> pymysql.connections.Connection:
    conn = connect("PRIMARY", autocommit=False)
    with conn.cursor() as c:
        c.execute("SET SESSION transaction_isolation = 'READ-COMMITTED'")
        c.execute("SET SESSION innodb_lock_wait_timeout = 3")
        c.execute("SET SESSION lock_wait_timeout = 5")
    conn.commit()
    return conn


def emit(event: str, **fields) -> None:
    log.info(json.dumps({"event": event, "migration_id": MIGRATION_ID, **fields}, default=str))


class Backfill:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.primary = connect_primary()
        # autocommit: every SELECT sees a fresh snapshot; under REPEATABLE READ the heartbeat would freeze.
        self.replica = connect("REPLICA", autocommit=True)
        self.batch_size = args.batch_size
        self.sleep = args.min_sleep
        self.stopping = False
        signal.signal(signal.SIGTERM, self._request_stop)
        signal.signal(signal.SIGINT, self._request_stop)

    def _request_stop(self, *_: object) -> None:
        self.stopping = True

    def initialise(self) -> None:
        with self.primary.cursor() as c:
            c.execute("SELECT COALESCE(MAX(id), 0) FROM payments")
            (max_id,) = c.fetchone()
            c.execute(
                "INSERT IGNORE INTO migration_progress (migration_id, last_id, max_id) VALUES (%s, 0, %s)",
                (MIGRATION_ID, max_id),
            )
        self.primary.commit()

    def progress(self) -> tuple[str, int, int, int]:
        with self.primary.cursor() as c:
            c.execute(
                "SELECT state, last_id, max_id, rows_updated FROM migration_progress WHERE migration_id = %s",
                (MIGRATION_ID,),
            )
            row = c.fetchone()
        self.primary.commit()
        return row

    def replica_lag(self, ceiling: float) -> float:
        """Seconds until the replica shows a write committed now; returns >= ceiling if slower."""
        with self.primary.cursor() as c:
            c.execute("SELECT NOW(6)")
            (beat,) = c.fetchone()
            c.execute(
                "INSERT INTO migration_heartbeat (id, ts) VALUES (1, %s) ON DUPLICATE KEY UPDATE ts = %s",
                (beat, beat),
            )
        self.primary.commit()
        started = time.monotonic()
        while True:
            with self.replica.cursor() as c:
                c.execute("SELECT ts FROM migration_heartbeat WHERE id = 1")
                row = c.fetchone()
            elapsed = time.monotonic() - started
            if row and row[0] >= beat:
                return elapsed
            if elapsed >= ceiling:
                return elapsed
            time.sleep(0.05)

    def threads_running(self) -> int:
        with self.primary.cursor() as c:
            c.execute("SHOW GLOBAL STATUS LIKE 'Threads_running'")
            value = int(c.fetchone()[1])
        self.primary.commit()
        return value

    def max_lag(self) -> float:
        start, end = self.args.peak_hours_utc
        hour = dt.datetime.now(dt.timezone.utc).hour
        in_peak = start <= hour < end if start <= end else (hour >= start or hour < end)
        return self.args.peak_max_lag if in_peak else self.args.max_lag

    def run_batch(self, last_id: int, max_id: int) -> int:
        size = self.batch_size
        attempt = 0
        while True:
            try:
                started = time.monotonic()
                with self.primary.cursor() as c:
                    c.execute(NEXT_UPPER, (last_id, max_id, size - 1))
                    row = c.fetchone()
                    upper = row[0] if row else max_id
                    c.execute(BACKFILL, (last_id, upper))
                    changed = c.rowcount
                    c.execute(ADVANCE, (upper, changed, MIGRATION_ID, last_id))
                    if c.rowcount != 1:
                        self.primary.rollback()
                        raise RuntimeError("checkpoint moved underneath this worker: is a second worker running?")
                self.primary.commit()
                self._tune(time.monotonic() - started)
                return changed
            except pymysql.err.MySQLError as error:
                code = error.args[0] if error.args else None
                try:
                    self.primary.rollback()
                except pymysql.err.MySQLError:
                    pass
                if code not in RETRYABLE:
                    raise
                if code in RECONNECT:
                    self.primary = connect_primary()
                attempt += 1
                emit("batch_retry", last_id=last_id, size=size, attempt=attempt, error=str(error))
                if attempt >= self.args.max_attempts:
                    if size <= self.args.min_batch:
                        raise RuntimeError(f"batch after id {last_id} keeps failing; parked for a human") from error
                    size = max(self.args.min_batch, size // 2)
                    attempt = 0
                time.sleep(min(30, 2 ** attempt))

    def _tune(self, seconds: float) -> None:
        target = self.args.target_batch_seconds
        if seconds > 2 * target:
            self.batch_size = max(self.args.min_batch, self.batch_size // 2)
        elif seconds < target / 2:
            self.batch_size = min(self.args.max_batch, int(self.batch_size * 1.25) + 1)

    def run(self) -> int:
        self.initialise()
        started = time.monotonic()
        _, first_id, _, _ = self.progress()
        last_report = 0.0
        while not self.stopping:
            state, last_id, max_id, rows_updated = self.progress()
            if state == "done":
                emit("already_done", last_id=last_id, max_id=max_id)
                return 0
            if state == "paused":
                emit("paused", last_id=last_id)
                time.sleep(self.args.pause_poll)
                continue
            if last_id >= max_id:
                with self.primary.cursor() as c:
                    c.execute("UPDATE migration_progress SET state = 'done' WHERE migration_id = %s", (MIGRATION_ID,))
                self.primary.commit()
                emit("done", rows_updated=rows_updated, hint="run `verify` on primary and replica")
                return 0

            ceiling = self.max_lag()
            lag = self.replica_lag(ceiling)
            threads = self.threads_running()
            if lag >= ceiling or threads > self.args.max_threads_running:
                self.sleep = min(self.args.max_sleep, max(self.args.min_sleep, self.sleep * 2))
                emit("throttled", lag_s=round(lag, 3), threads_running=threads, sleep_s=self.sleep)
                time.sleep(self.sleep)
                continue
            self.sleep = max(self.args.min_sleep, self.sleep * 0.8)

            self.run_batch(last_id, max_id)

            now = time.monotonic()
            if now - last_report >= self.args.report_every:
                _, current, _, rows_updated = self.progress()
                id_rate = (current - first_id) / max(now - started, 1e-9)
                eta_h = (max_id - current) / id_rate / 3600 if id_rate > 0 else None
                emit("progress", last_id=current, max_id=max_id,
                     pct=round(100 * current / max(max_id, 1), 3), rows_updated=rows_updated,
                     ids_per_s=round(id_rate), eta_h=round(eta_h, 2) if eta_h else None,
                     batch_size=self.batch_size, sleep_s=round(self.sleep, 3), lag_s=round(lag, 3))
                last_report = now
            time.sleep(self.sleep)
        emit("stopped_by_signal")
        return 0


def verify(args: argparse.Namespace) -> int:
    conn = connect("REPLICA" if args.target == "replica" else "PRIMARY", autocommit=True)
    with conn.cursor() as c:
        c.execute("SELECT COALESCE(MAX(id), 0) FROM payments")
        (max_id,) = c.fetchone()
    last_id, totals, samples = args.from_id, [0, 0, 0, 0], []
    while last_id < max_id:
        with conn.cursor() as c:
            c.execute(NEXT_UPPER, (last_id, max_id, args.chunk - 1))
            row = c.fetchone()
            upper = row[0] if row else max_id
            c.execute(VERIFY_CHUNK, (last_id, upper))
            chunk = [int(v) for v in c.fetchone()]
            if chunk[2] and len(samples) < 100:
                c.execute(VERIFY_SAMPLE, (last_id, upper))
                samples.extend(r[0] for r in c.fetchall())
        totals = [t + v for t, v in zip(totals, chunk)]
        last_id = upper
        time.sleep(args.chunk_sleep)
    rows, missing, mismatched, null_amount = totals
    emit("verify", target=args.target, from_id=args.from_id, max_id=max_id, rows=rows,
         missing=missing, mismatched=mismatched, null_amount=null_amount, sample_ids=samples[:100])
    return 0 if missing == 0 and mismatched == 0 else 1


def parse_hours(value: str) -> tuple[int, int]:
    start, end = (int(x) for x in value.split("-"))
    return start, end


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", stream=sys.stdout)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run")
    run.add_argument("--batch-size", type=int, default=2000)
    run.add_argument("--min-batch", type=int, default=200)
    run.add_argument("--max-batch", type=int, default=5000)
    run.add_argument("--target-batch-seconds", type=float, default=0.5)
    run.add_argument("--max-lag", type=float, default=2.0, help="replica lag ceiling off-peak, seconds")
    run.add_argument("--peak-max-lag", type=float, default=1.0, help="replica lag ceiling during BI hours")
    run.add_argument("--peak-hours-utc", type=parse_hours, default=(11, 23), help="e.g. 11-23")
    run.add_argument("--max-threads-running", type=int, default=40)
    run.add_argument("--min-sleep", type=float, default=0.05)
    run.add_argument("--max-sleep", type=float, default=30.0)
    run.add_argument("--max-attempts", type=int, default=5)
    run.add_argument("--pause-poll", type=float, default=10.0)
    run.add_argument("--report-every", type=float, default=30.0)

    ver = sub.add_parser("verify")
    ver.add_argument("--target", choices=["primary", "replica"], default="primary")
    ver.add_argument("--from-id", type=int, default=0)
    ver.add_argument("--chunk", type=int, default=50000)
    ver.add_argument("--chunk-sleep", type=float, default=0.05)

    args = parser.parse_args()
    return Backfill(args).run() if args.command == "run" else verify(args)


if __name__ == "__main__":
    sys.exit(main())
```

The script has not been executed: there was no database to run it against. Run it on the step-2
clone before production. Include the edge rows `0.00`, `0.01`, negative amounts and
`9999999999.99`, and a kill -9 mid-run followed by a restart.

### Operating it

- Run it as **one** long-lived process (a Kubernetes Job or ECS task with restart on failure)
  on a host near the database, not a laptop. It is safe to kill at any time.
- Run with full defaults nights and weekends. Use the stricter `--peak-max-lag` during BI
  hours, set `--peak-hours-utc` to BI's working hours, and agree the ceilings with BI before
  starting.
- **Dashboard and alerts:** `progress` events (pct, ids/s, ETA, batch size, sleep, lag) into
  your log metrics, plus CloudWatch `ReplicaLag`, `CPUUtilization`, `WriteIOPS`,
  `BinLogDiskUsage`, `FreeStorageSpace` and app p99/error rate. **Staleness alert:** no
  `progress` event for 10 minutes while state = `running`. Mark start and end on the
  dashboards.
- **Pause** by setting `state = 'paused'` (above). The job stops between batches, leaving a
  valid state.
- **Tell BI** that `amount_cents` is partially filled while this runs. They should not switch
  to it before step 4 passes. If they must, `COALESCE(amount_cents, amount * 100)` is correct
  throughout.

## Verification

| When | Check | Expect |
|---|---|---|
| G0 | `verify --from-id <first v2 id>`; digest query in step 0 | 0 missing, 0 mismatched; no unknown writers |
| Step 4 | `verify --target primary`, then `verify --target replica` (off-peak) | 0 missing, 0 mismatched, `null_amount` = 0 (A2) |
| Step 4 | Recheck `sample_ids` from any non-zero run | still mismatched means real drift (fix the writer, re-run step 3); converged means it was an in-flight write |
| Step 6 | v3 shadow divergence metric | 0 across a full weekly cycle |
| Before C1 | `SELECT COUNT(*) FROM payments WHERE amount_cents IS NULL;` | 0 |
| After C1 | `SHOW CREATE TABLE payments`; `SELECT COUNT(*) FROM payments WHERE amount_cents = 0 AND amount <> 0;`; `verify --target replica` | new definition; 0; 0/0 |
| Step 8 (G8) | `events_statements_summary_by_digest` on **primary and replica** for `` `amount` `` (excluding `amount_cents`), sampled across days and through a month-end; BI inventory signed off by its owner; repo search across every deployed service and version | no readers |
| C3 | Nothing fails through one month-end close | silence |

Keep a cheap scheduled invariant after step 4, until C4: the `verify` mismatched count over the
last day's id range. It stays a useful alarm for unknown writers.

## Recovery

| Step | What "wrong" looks like | Detection | Response |
|---|---|---|---|
| 3 backfill | BI replica stale; app p99 up | `ReplicaLag`, throttle events, p99 | pause; lower the ceilings; resume. No data risk. |
| 3 backfill | wrong values (e.g. A3 decided otherwise) | step-4 verify, spot checks | pause; fix the transform; re-run forward. `amount` is intact and authoritative. Never "reverse" a backfill. |
| 3 | job hangs | staleness alert | kill it. The checkpoint is per batch; restart resumes. |
| 6 v3 | divergence, wrong amounts shown | shadow metric | flag off |
| 7 v4 | bad cents-first write path | errors, divergence | roll back to v3 or v2. `amount` is still written. Rows v4 wrote wrongly need a compensating fix computed from audit/request logs. |
| C1 | gh-ost overloads or stalls | its throttle status, lag | gh-ost pauses itself, or interrupt it (the original table is untouched until cutover) |
| C1 | replica stuck on MDL at cutover | `Waiting for table metadata lock` on the replica | `CALL mysql.rds_kill(<blocking BI query>)` |
| C2 v5 | something still read `amount` | error, or a wrong BI report | roll back to **v4 only**; backfill `amount` for v5-written rows from cents (`amount = amount_cents / 100` where `amount IS NULL`, batched with this job's pattern) |
| C3 | a hidden reader breaks | loud error | rename back (instant). Find the reader and move it. |
| C4 | data needed after drop | request | restore the retained snapshot **aside**, extract `(id, amount)`, load as a staging table, scoped repair. Never restore over production. |

**Evidence sources:** until C4, `amount` itself. After C4, the manual snapshot (≥ 90 days) and
the step-4/C1 verification records. RDS binlog retention is typically hours to days (check
`CALL mysql.rds_show_configuration;`), so binlog is not part of the evidence plan.

## Cleanup (C4) preconditions

All must hold, and are recorded on the cleanup ticket with evidence links:

1. No application version reads `amount`: v5 at 100%, v2–v4 marked non-deployable.
2. No application version writes it: rows since v5 have `amount IS NULL`.
3. The backfill completed and was verified independently on primary and replica (step 4).
4. `amount_cents` is valid: C1 checks passed, and the invariant check has stayed green.
5. The rollback windows expired, and C3 survived a full month-end close with no failures.
6. A manual RDS snapshot was taken immediately before, with retention ≥ 90 days.

Then, inside the replica coordination window:

```sql
SET SESSION lock_wait_timeout = 10;
ALTER TABLE payments DROP COLUMN amount_deprecated_20270201, ALGORITHM=INSTANT;  -- 8.0.30+; errors instead of rebuilding otherwise
DROP TABLE migration_progress, migration_heartbeat;
```

Also remove the `payments.read_amount_cents` flag, the shadow-compare code and any 0b trigger.
On engines below 8.0.29, `ALGORITHM=INSTANT` errors: fold the drop into a gh-ost run instead.
`INSTANT` add/drop is limited to 64 row versions per table, so check
`information_schema.INNODB_TABLES.TOTAL_ROW_VERSIONS` (8.0.29+; verify the column name on your
version).

## Checklist status

| # | Question | Answer / finding |
|---|---|---|
| 1 | Previous version on new schema? | Yes at every step. Rollback targets are listed per step. After C2 only v4. |
| 2 | Old and new side by side? | Yes. Every pair (v2/v3, v3/v4, v4/v5) shares a schema both handle. |
| 3 | Deletes or transforms information? | The backfill writes only the new column. The drop (C4) destroys `amount`, which is R2 given verified convergence plus the snapshot. |
| 4 | Safe to run twice? | Yes: guard predicate plus compare-and-set checkpoint. |
| 5 | Stop and resume? | Yes: per-batch checkpoint and pause state. |
| 6 | Verify the data? | `verify` on primary and replica, shadow metric, C1 checks. |
| 7 | Disable without schema revert? | v3 flag. v4/v5 roll back by redeploy. |
| 8 | Recovery if data is wrong? | Table above. |
| 9 | Cleanup date and proof? | Cleanup preconditions above. Earliest date in Steps. |
| 10 | Interacting migrations? | **Open:** any planned 8.0→8.4 upgrade, other `payments` DDL, BI batch windows. Freeze other `payments` DDL until C1. |
| 11 | Locks, durations, abort? | Per step. **Durations need the step-2 rehearsal numbers. Missing until then.** |
| 12 | Pre-image and retention? | `amount` itself until C4, `_payments_del` after C1 for a few days, snapshot ≥ 90 days after C4. |
| 13 | Shape held elsewhere? | **Open:** inventory of BI, ETL/CDC, events, API, caches (step 0). This is the long pole. |
| 14 | Previous release's tests on new schema? | Run v4's suite after C1 and v4's suite after C2's schema. Add a CI job running the previous release's suite against the migrated schema. |
