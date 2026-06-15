# Review: `audit_event` schema & indexing

## Summary

The table is a reasonable starting point, but for a write-heavy, fast-growing, cross-service audit log it needs work in three areas: **partitioning** (to keep it manageable as it grows), **indexing** (the two stated access patterns are currently unindexed), and a few **column/modeling refinements**. Below are concrete recommendations ordered by impact.

---

## 1. Indexing — the most pressing gap

As written, the only index is the primary key on `id`. Both of your stated access patterns would do **full table scans**, which is exactly what you can't afford on a table that "will grow a lot."

### (a) Latest events for a user

```sql
SELECT * FROM audit_event WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50;
```

Add a composite index with `created_at` descending so the index satisfies both the filter and the sort:

```sql
CREATE INDEX idx_audit_event_user_created
  ON audit_event (user_id, created_at DESC);
```

This lets Postgres seek directly to the user's rows already ordered newest-first — no sort step, and it stops after `LIMIT`.

### (b) Search by event type within a time period

```sql
SELECT * FROM audit_event
WHERE type = $1 AND created_at BETWEEN $2 AND $3;
```

```sql
CREATE INDEX idx_audit_event_type_created
  ON audit_event (type, created_at);
```

Column order matters: the equality predicate (`type`) goes first, the range predicate (`created_at`) second. This is the standard "equality before range" rule and lets the index handle both.

> Note: if queries frequently combine `type` **and** `user_id`, consider `(user_id, type, created_at)` instead of, or in addition to, the user index — but don't add it speculatively. Add indexes for access patterns you can confirm.

### Index cost awareness

Every index slows down inserts and consumes space — and this is a write-heavy table written by *every* service. Keep the index count minimal and deliberate. Two well-chosen composite indexes (above) cover your two patterns. Resist adding single-column indexes on `user_id` and `type` separately, since the composite indexes already cover those prefixes.

---

## 2. Partitioning — plan for it now, not later

A perpetually-growing audit log is the textbook case for **range partitioning by `created_at`** (typically monthly). Benefits:

- **Retention is cheap.** Dropping old data becomes `DROP TABLE`/`DETACH PARTITION` (instant, no bloat) instead of a massive `DELETE` that generates dead tuples and VACUUM pressure.
- **Smaller indexes.** Per-partition indexes stay in cache and keep inserts fast.
- **Pruning.** Time-bounded queries (pattern b) only touch relevant partitions.

```sql
CREATE TABLE audit_event (
  id          bigint GENERATED ALWAYS AS IDENTITY,
  user_id     bigint      NOT NULL,
  type        text        NOT NULL,
  payload     jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
```

Important caveat: with partitioning, the PK **must include the partition key** (`created_at`), hence `PRIMARY KEY (id, created_at)`. `id` alone is no longer globally unique-enforceable by a single index, but `id` from a sequence/identity is still globally unique in practice.

Automate partition creation with `pg_partman` or a scheduled job so you never run out of "future" partitions.

If you're not ready to partition on day one, at minimum keep `created_at` as the natural retention axis and design so partitioning can be retrofitted (it's a painful migration later — strongly prefer doing it up front).

---

## 3. Column & modeling refinements

| Column | Issue | Recommendation |
|---|---|---|
| `id bigserial` | `bigserial` is fine, but `bigint GENERATED ALWAYS AS IDENTITY` is the modern, SQL-standard equivalent and avoids the implicit-sequence ownership quirks. | Use `GENERATED ALWAYS AS IDENTITY`. |
| `type varchar(50)` | The `50` is an arbitrary cap with no real benefit in Postgres (`varchar(n)` and `text` perform identically; the limit just risks a future truncation error). Audit event types are a controlled vocabulary. | Use `text`, ideally constrained by a `CHECK`/lookup table or a Postgres `enum` if the set is stable. |
| `payload jsonb` | Good choice (binary, indexable). But it's unindexed and unconstrained. | Keep `jsonb`. Only add a GIN index (`CREATE INDEX ... USING gin (payload)`) if you actually query *inside* the payload — it's expensive on writes, so don't add preemptively. Consider documenting/validating the schema per `type`. |
| `user_id bigint` | No FK and no comment on nullability semantics. For audit logs, **not** having an FK is often intentional (you must retain audit rows even after a user is deleted, and you don't want cross-service coupling). | Intentionally omit the FK, but document that choice. Consider whether system/service-originated events (no user) need `user_id` to be nullable or a sentinel. |
| — | No `service`/`source` column, despite "EVERY service writes to" it. | Add `service text NOT NULL` (or `source`) so you can attribute and filter events by origin. This is almost always needed in a shared audit log. |
| — | No correlation/trace identifier. | Consider `request_id`/`trace_id` (uuid/text) to tie audit events to a request across services. |

---

## 4. Write-path & operational considerations

- **Append-only by design.** Audit rows should be immutable. Enforce with revoked `UPDATE`/`DELETE` privileges, or a trigger that rejects mutations, so the log is trustworthy.
- **Autovacuum / fillfactor.** This is an insert-only, never-updated table, so HOT updates aren't a concern, but monitor autovacuum for visibility-map/freeze maintenance on huge partitions. Aggressive `autovacuum_freeze_max_age` tuning helps avoid wraparound surprises on cold partitions.
- **Hot-row contention on the sequence is negligible**, but if insert throughput is extreme, batching inserts from each service reduces WAL and index-maintenance overhead.
- **Time zone.** `timestamptz` is correct (not `timestamp`) — good. Keep storing UTC.

---

## Suggested revised migration

```sql
CREATE TABLE audit_event (
  id          bigint      GENERATED ALWAYS AS IDENTITY,
  user_id     bigint,                       -- nullable: system events may have no user; no FK on purpose (retain after user deletion)
  service     text        NOT NULL,         -- originating service
  type        text        NOT NULL,         -- controlled vocabulary; consider CHECK or enum
  payload     jsonb,
  request_id  text,                         -- optional cross-service correlation id
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- monthly partitions managed by pg_partman or a scheduled job, e.g.:
-- CREATE TABLE audit_event_2026_06 PARTITION OF audit_event
--   FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

-- Access pattern (a): latest events for a user
CREATE INDEX idx_audit_event_user_created
  ON audit_event (user_id, created_at DESC);

-- Access pattern (b): search by type within a time window
CREATE INDEX idx_audit_event_type_created
  ON audit_event (type, created_at);
```

## Priority checklist

1. **Add the two composite indexes** — without them, both access patterns scan the whole table. (highest impact)
2. **Decide on partitioning up front** — range-by-month; retrofitting later is costly.
3. **Add a `service` column** — a shared audit log needs to attribute origin.
4. Switch `varchar(50)` → `text`, `bigserial` → `GENERATED ALWAYS AS IDENTITY`.
5. Make the table append-only (revoke UPDATE/DELETE).
6. Defer GIN-on-`payload` and any extra indexes until a real query demands them.
