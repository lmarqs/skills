# Review: `audit_event` schema and indexing

## Context I'm working from

You told me three things that decide everything here:

- **This is a transactional table.** Every service writes to it and it "grows a lot." It is append-only history that grows without bound — the textbook profile of a table where a query with no time/key bound is fine at 100k rows and a fire at 50M.
- **Access pattern (a):** the latest events for a user.
- **Access pattern (b):** search by event type within a time period.

The migration as written supports *neither* read pattern with an index. The only index is the `bigserial` primary key on `id`. Both of your stated queries would fall back to a sequential scan of the entire (ever-growing) table plus an in-memory sort. That is the headline finding; everything else is secondary.

There is no severity ranking below — but ordered by what bites first under real volume, the missing indexes come first.

---

## Finding 1 — No index for "latest events for a user" (smells #4, #10)

**Impact.** Your query is something like:

```sql
SELECT ... FROM audit_event
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT 50;
```

With only the PK present, Postgres has no way to find a user's rows except by scanning the whole table, and no way to produce `created_at DESC` order except by sorting the matched rows in memory (or spilling to disk). At 100k rows you won't notice. At 50M you have a multi-second query on what should be an instant lookup, and the sort can blow past `work_mem`. This is smell #4 (query on a transactional table with no usable bound) compounded by smell #10 (unindexed sort).

**Correction.** A composite index whose leading column matches the equality filter and whose trailing column matches the sort:

```sql
CREATE INDEX idx_audit_event_user_created
  ON audit_event (user_id, created_at DESC);
```

Column order matters (see the modeling note below): `user_id` is the equality predicate so it leads; `created_at DESC` follows so the index *also* satisfies the `ORDER BY` and the `LIMIT` can stop after reading 50 index entries. This turns the query into an index range scan with no sort step.

**Tradeoff.** Every `INSERT` — and this table is write-heavy across all services — now maintains a second B-tree, costing a little write throughput and disk. That is exactly the read-vs-write trade you want here: you pay a small, fixed cost on the frequent write to make the frequent read fast. Worth it.

---

## Finding 2 — No index for "event type within a time period" (smells #4, #10)

**Impact.** Your query is something like:

```sql
SELECT ... FROM audit_event
WHERE type = $1
  AND created_at >= $2 AND created_at < $3
ORDER BY created_at DESC;
```

Same root cause: full sequential scan to find the `type`, plus a sort. As the table grows this degrades steadily, and it is the access pattern most likely to be run ad hoc (debugging, security investigations) where a multi-second scan is most painful.

**Correction.**

```sql
CREATE INDEX idx_audit_event_type_created
  ON audit_event (type, created_at DESC);
```

`type` (equality) leads, `created_at` (range + sort) follows. The index serves both the filter and the ordering, and the range on `created_at` is handled by the index's second column. **Note this query carries its own time bound (`created_at` between two values) — keep it.** A query on this table without a time window will read history that only grows; the time filter is what keeps the work proportional to the window, not the table.

**Tradeoff.** A second maintained index, same write/space cost as Finding 1. Do *not* try to serve this from `(user_id, created_at)` — a composite index is only usable on a prefix of its columns, so an index leading with `user_id` does nothing for a query that filters on `type` alone. These are two distinct access patterns and each needs its own leading column. (Resist adding *more* than the reads justify, though — see the index-restraint note.)

---

## Finding 3 — `SELECT *` will pull `payload` on every read (smell #5)

**Impact.** I don't have your SELECT lists, but `payload jsonb` is potentially large and unbounded. If the listing screens for patterns (a) and (b) fetch the whole row when they only render, say, `id, user_id, type, created_at`, every page drags the full JSON across the wire and into memory, and blocks any chance of an index-only scan. This is smell #5.

**Correction.** Select only the columns the listing consumes, and fetch `payload` lazily (on row expand / detail view):

```sql
SELECT id, user_id, type, created_at
FROM audit_event
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT 50;
```

**Tradeoff.** A second round trip when the user opens a single event's detail. Cheap compared to streaming every payload on every list page. If detail views are rare this is a clear win.

---

## Finding 4 — Listing pagination: avoid high `OFFSET` (smell #8)

**Impact.** "Latest events for a user" is an interactive list, so pagination is coming. If it's `LIMIT/OFFSET`, deep pages force Postgres to read and discard all preceding rows — `OFFSET 100000` reads 100k rows to return 20. On a high-volume audit log, deep pages get progressively slower.

**Correction.** Use keyset (cursor) pagination anchored on the same `(user_id, created_at, id)` ordering the index already provides:

```sql
SELECT id, user_id, type, created_at
FROM audit_event
WHERE user_id = $1
  AND (created_at, id) < ($2, $3)   -- last (created_at, id) seen
ORDER BY created_at DESC, id DESC
LIMIT 50;
```

Including `id` as a tiebreaker makes the order total (two events can share a `created_at`). For this to be fully index-backed, extend the index to `(user_id, created_at DESC, id DESC)`.

**Tradeoff.** Keyset can't jump to "page 47" — only next/previous. For an audit feed that's almost always acceptable, and per-page cost stays constant instead of growing with depth.

---

## Modeling-level observations (the root cause, not the symptoms)

Findings 1, 2, and 4 are not three separate bugs — they're one modeling gap: **the table was defined without indexing for its declared read patterns.** A few model-level points:

- **`type varchar(50)`.** A free-form string for event type invites typos and drift (`"login"` vs `"LOGIN"` vs `"user.login"`) across the many services writing here, and it bloats every index entry on `type`. Consider a Postgres `enum`, or a `lookup` table referenced by a small FK, or at minimum a `CHECK` constraint and a naming convention. **Tradeoff:** an `enum` requires a migration (`ALTER TYPE ... ADD VALUE`) to introduce new event types — friction that a `varchar` doesn't have. For a value set that changes rarely and is shared org-wide, the consistency and smaller indexes are usually worth it; if new event types appear constantly, a lookup table is the more flexible middle ground.

- **`user_id` has no FK and no `NOT NULL` story for system events.** It's `NOT NULL`, which is good, but audit logs often need to record events not tied to a user (system/cron/anonymous). Confirm every event truly has a user; if not, you'll be inserting sentinel values, which corrupts the `(user_id, created_at)` index's usefulness. Whether to add a real FK to `users` is a judgment call: a FK guarantees integrity but adds a per-insert check on the hot write path and can complicate user deletion (audit rows usually must outlive the user). For an audit log that must survive user deletion, many teams deliberately omit the FK — that's defensible here.

- **Growth strategy: partitioning.** You said it "will grow a lot." The single most effective structural move for an unbounded, time-ordered, write-heavy log is **range partitioning by `created_at`** (e.g. monthly). It keeps indexes small per partition, lets pattern (b)'s time filter prune whole partitions, and — critically for an audit table — makes retention a `DROP TABLE` of an old partition instead of a massive `DELETE` (which would be smell #11: an unindexed mass delete that locks rows and generates bloat). **Tradeoff:** partitioning adds operational machinery (partition creation, a default partition, the partition key must be part of the PK → PK becomes `(id, created_at)`), so don't reach for it on day one for a low-volume table. But given your explicit "grows a lot," design for it now rather than retrofitting at 50M rows.

- **Index restraint.** Add the two indexes above (Findings 1 and 2) because they map directly to your two stated reads. Don't speculatively index `payload`, `id`-other-than-PK, etc. Every index taxes the write path, and this is a write-heavy table — each one matters.

---

## Validate with the plan, don't trust the prose

Before considering this settled, capture `EXPLAIN (ANALYZE, BUFFERS)` for both access patterns, against a table loaded to realistic volume, after creating the indexes:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, user_id, type, created_at FROM audit_event
WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, user_id, type, created_at FROM audit_event
WHERE type = $1 AND created_at >= $2 AND created_at < $3
ORDER BY created_at DESC;
```

What confirms the fix:

- **`Index Scan` / `Index Only Scan`** using the new indexes — not `Seq Scan`. A `Seq Scan` here on a big table means the index isn't being picked (check for a type mismatch on `created_at` — compare against a `timestamptz` literal, never a bare string, per smell #2).
- **No separate `Sort` node** — the `(…, created_at DESC)` index should supply the order. A `Sort Method: external merge  Disk:` line means the sort spilled and the index isn't covering the order.
- **`Rows Removed by Filter` near zero** — confirms the filter is index-backed rather than scanning and discarding.

---

## Suggested revised migration

```sql
CREATE TABLE audit_event (
  id         bigserial PRIMARY KEY,
  user_id    bigint      NOT NULL,
  type       varchar(50) NOT NULL,   -- consider enum / lookup table + naming convention
  payload    jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Pattern (a): latest events for a user
CREATE INDEX idx_audit_event_user_created
  ON audit_event (user_id, created_at DESC, id DESC);

-- Pattern (b): event type within a time period
CREATE INDEX idx_audit_event_type_created
  ON audit_event (type, created_at DESC);
```

Plus, as a deliberate near-term decision given the stated growth: plan **monthly range partitioning on `created_at`** and a retention policy that drops old partitions. Defer it only if you're confident volume will stay modest — but you told me it won't.
