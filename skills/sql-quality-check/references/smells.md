# SQL smell catalog

Eleven recurring patterns that degrade relational databases under real data volume. Each entry has the
same shape, so it's usable by someone who has never hit the problem before:

- **Description** — the pattern, in plain terms.
- **Impact** — the resulting database behavior and why it degrades systems.
- **Detection** — the signal the skill or reviewer looks for.
- **Correction** — a to-avoid vs. preferred example.

Examples use generic identifiers (`table`, `main`, `child`, `column`, `created_at`) that stand in for any
schema, with no tie to a domain. The SQL is PostgreSQL dialect; the principles hold for any relational
database — adapt the syntax to the dialect under analysis.

These smells all carry **equal weight** — any one can severely degrade performance on its own. There is
no severity ranking, only context analysis (see the SKILL body). When several appear together, suspect the
data model, not the individual query.

## Table of contents

1. [Excess joins and cartesian row explosion](#1-excess-joins-and-cartesian-row-explosion)
2. [Function or cast on a filtered column disables the index](#2-function-or-cast-on-a-filtered-column-disables-the-index)
3. [The N+1 problem: one query becomes many](#3-the-n1-problem-one-query-becomes-many)
4. [Query on a transactional table with no date filter](#4-query-on-a-transactional-table-with-no-date-filter)
5. [Selecting all columns when few are used](#5-selecting-all-columns-when-few-are-used)
6. [Leading-wildcard text search disables the index](#6-leading-wildcard-text-search-disables-the-index)
7. [Count that reuses the listing query for pagination](#7-count-that-reuses-the-listing-query-for-pagination)
8. [High-OFFSET pagination](#8-high-offset-pagination)
9. [IN subquery and the NOT IN + NULL trap](#9-in-subquery-and-the-not-in--null-trap)
10. [Unindexed sort and unbounded list](#10-unindexed-sort-and-unbounded-list)
11. [Long transactions and unindexed mass writes](#11-long-transactions-and-unindexed-mass-writes)

---

## 1. Excess joins and cartesian row explosion

**Description.** A query that joins a main table to several dependent tables in one-to-many (1:N)
relationships within a single statement.

**Impact.** Each 1:N join multiplies the result rows. One main record with 10 children in one relation,
2 in another, and 3 in a third yields 10 × 2 × 3 = 60 redundant rows to fill a few fields. At real
volume the query returns thousands of duplicated rows, burns memory and CPU, and response time grows
disproportionately. When an ORM builds the query the problem is worse, because the multiplication is
hidden.

**Detection.** Three or more joins, especially across 1:N relations. In an ORM, eager loading of
collections inside a single query.

**Correction.** Fetch the main entity and load the collections in separate queries, or aggregate them in
the database itself.

```sql
-- Avoid: a single query multiplies rows at every 1:N join
SELECT *
FROM main m
LEFT JOIN child_a a ON a.main_id = m.id
LEFT JOIN child_b b ON b.main_id = m.id
LEFT JOIN child_c c ON c.main_id = m.id;

-- Prefer: separate queries, or aggregation in the database
SELECT id, column FROM main WHERE id = $1;
SELECT * FROM child_a WHERE main_id = $1;
```

---

## 2. Function or cast on a filtered column disables the index

**Description.** Applying a function, type cast, or arithmetic to the column inside the `WHERE` clause.

**Impact.** An index is built over the column's original value. Wrapping the column in an expression
forces the database to compute that expression for every row before comparing, which prevents index use
and triggers a sequential scan of the whole table. On large tables a millisecond query turns into
seconds. The same happens silently when the compared types don't match — e.g. comparing a timestamp
column to a string without a time zone — because the database inserts an implicit cast.

**Detection.** Any function, type cast, or arithmetic on the column on the left-hand side of the
comparison, plus comparisons between mismatched types.

**Correction.** Keep the column untouched and apply the transformation to the comparison value, which is
evaluated once.

```sql
-- Avoid: the cast on the column invalidates the index
SELECT *
FROM table
WHERE created_at::date > '2025-01-01';

-- Prefer: the column stays intact; the cast falls on the literal
SELECT *
FROM table
WHERE created_at > '2025-01-01 00:00:00-03:00'::timestamptz;
```

---

## 3. The N+1 problem: one query becomes many

**Description.** Fetch a list with one query, then fire an additional query per item to complete the
data.

**Impact.** One query becomes N+1. A list of 200 items whose related data is fetched individually is 201
round trips to the database. Each trip carries network and transaction cost; the operation gets slow and
the database is saturated with tiny queries. The write variant is the loop that runs one `INSERT` or
`UPDATE` per iteration.

**Detection.** A query inside a loop, or access to a lazily-loaded relation during iteration.

**Correction.** Load all related records in a single query; on writes, batch the operations.

```sql
-- Avoid: one query per item, in a loop in the application
--   for each item in list:
--     SELECT * FROM child WHERE id = item.ref_id

-- Prefer: a single query for all related rows
SELECT * FROM child WHERE id = ANY($1);
```

---

## 4. Query on a transactional table with no date filter

**Description.** A transactional table is one that grows without bound over time. Every query on it
should include an indexed date filter that bounds the window read.

**Impact.** Without a time window, the query scans the entire history, which only grows. What responds
quickly over 100k rows degrades to unusable at 50M. This is the omission that degrades performance
soonest as volume grows.

**Detection.** No date condition in a query over a continuously-growing table. Being generic, the skill
must infer or ask whether the table is transactional — watch for signals like a timestamp column and a
tendency to grow over time.

**Correction.** Every query on a transactional table should carry a date filter, and the column used must
be indexed. No exceptions.

```sql
-- Avoid: reads the whole history
SELECT * FROM table WHERE status = 'active';

-- Prefer: a time window on an indexed column
SELECT * FROM table
WHERE status = 'active'
  AND created_at >= now() - interval '30 days';
```

---

## 5. Selecting all columns when few are used

**Description.** Fetching every column when the code consumes only a few.

**Impact.** Reads and transfers needless data, including bulky `text` or `JSON` columns, wasting memory
and bandwidth. It also blocks index-only scans, where the database could answer from the index alone.
Finally it couples the code to the schema: adding a column silently changes the result.

**Detection.** Selecting all columns, or fetching the whole entity through an ORM, where only a few
fields are consumed.

**Correction.** Select the needed columns explicitly.

```sql
-- Avoid
SELECT * FROM table WHERE id = $1;

-- Prefer
SELECT id, column_a, column_b FROM table WHERE id = $1;
```

---

## 6. Leading-wildcard text search disables the index

**Description.** Text search with a wildcard at the start of the pattern, often combined with accent
normalization.

**Impact.** A conventional B-tree index works like an alphabetical index: it only helps when you know the
start of the term. With the wildcard at the start of the pattern there is no known prefix, so the
database scans the whole table, comparing every row.

**Detection.** `LIKE` or `ILIKE` operators with a wildcard at the start of the pattern.

**Correction.** Adopt a text index suited to the job: a trigram index (PostgreSQL `pg_trgm` extension
with `gin_trgm_ops`), a functional index over the normalization expression, or full-text search.

```sql
-- Avoid: the leading wildcard forces a sequential scan
SELECT * FROM table
WHERE unaccent(column) ILIKE unaccent('%term%');

-- Prefer: a trigram index that supports substring search
CREATE INDEX idx_table_column_trgm
  ON table USING gin (unaccent(column) gin_trgm_ops);
```

---

## 7. Count that reuses the listing query for pagination

**Description.** To show the total result count, the full listing SQL — with all joins and ordering — is
wrapped in a count.

**Impact.** The database runs the entire complexity of the listing just to count rows, at a cost close to
fetching the data, and does it on every page change.

**Detection.** A count query that reproduces the listing query.

**Correction.** Count over a lean version, without ordering and without joins that don't affect the total;
use an approximate count when exactness isn't essential; or use pagination that needs no total (see #8).

```sql
-- Avoid: counts over the whole query, including joins and ordering
SELECT count(*) FROM (
  SELECT m.* FROM main m
  LEFT JOIN child d ON d.main_id = m.id
  ORDER BY m.created_at DESC
) sub;

-- Prefer: lean count, without ordering or irrelevant joins
SELECT count(*) FROM main;
```

---

## 8. High-OFFSET pagination

**Description.** `LIMIT`/`OFFSET` pagination where the offset grows with each page.

**Impact.** An `OFFSET` of 100,000 forces the database to read and discard 100k rows before returning the
next ones. The further the page, the slower the query.

**Detection.** `OFFSET` proportional to the page number on large lists.

**Correction.** Use keyset/cursor pagination, which uses the index and keeps per-page cost constant.

```sql
-- Avoid: a growing offset walks and discards rows
SELECT * FROM table ORDER BY id LIMIT 20 OFFSET 100000;

-- Prefer: keyset pagination, anchored on the last id seen
SELECT * FROM table WHERE id > $1 ORDER BY id LIMIT 20;
```

---

## 9. IN subquery and the NOT IN + NULL trap

**Description.** Filtering by subquery via `IN` or `NOT IN`.

**Impact.** At large volume, `EXISTS` or a join usually produces a better plan than `IN` with a subquery.
Moreover `NOT IN` has a correctness trap: if the subquery returns a single `NULL`, the result becomes
empty, with no apparent error.

**Detection.** `IN` with a subquery on a critical path, and any `NOT IN` over a nullable column.

**Correction.** Prefer `EXISTS` for inclusion and `NOT EXISTS` for exclusion — the latter is immune to
the NULL problem.

```sql
-- Avoid: NOT IN returns empty if the subquery yields any NULL
SELECT * FROM table_a
WHERE id NOT IN (SELECT a_id FROM table_b);

-- Prefer: NOT EXISTS is immune to NULL values
SELECT * FROM table_a a
WHERE NOT EXISTS (
  SELECT 1 FROM table_b b WHERE b.a_id = a.id
);
```

---

## 10. Unindexed sort and unbounded list

**Description.** Sorting a large set with no index to cover it, or returning a list with no ceiling.

**Impact.** Sorting without an index forces the database to load the set and sort it in memory or on disk.
An unbounded list may try to return the whole table, exhausting application and database memory.

**Detection.** `ORDER BY` over a column with no suitable index, and a list with no limit or pagination.

**Correction.** Ensure an index that covers the sort, and always apply a limit or pagination.

```sql
-- Avoid: sorting without an index and without a limit
SELECT * FROM table ORDER BY created_at DESC;

-- Prefer: an index that covers the sort, with a limit
-- CREATE INDEX idx_table_created_at ON table (created_at DESC);
SELECT * FROM table ORDER BY created_at DESC LIMIT 50;
```

---

## 11. Long transactions and unindexed mass writes

**Description.** Holding a transaction open during slow operations — external calls or I/O — or running a
mass `UPDATE`/`DELETE` with no indexed filter.

**Impact.** An open transaction holds locks and connections, making other operations wait and exhausting
the connection pool. An `UPDATE`/`DELETE` with no indexed filter on a large table locks many rows at once
and generates bloat.

**Detection.** A network call or I/O inside a transactional block, and a write command whose filter
doesn't use an index or is absent.

**Correction.** Keep transactions short, doing the I/O outside them, and perform mass writes in batches
with an indexed filter.

```sql
-- Avoid: mass update without an indexed filter, in a single transaction
UPDATE table SET status = 'archived';

-- Prefer: batched write, with an indexed filter
UPDATE table SET status = 'archived'
WHERE id IN (SELECT id FROM table WHERE status = 'active' LIMIT 1000);
```
