---
name: sql-quality-check
description: >-
  Audit and improve SQL quality systematically — catch performance smells in raw SQL, ORM-generated
  queries, schema/modeling decisions, migrations, or PR diffs, explain the database-level impact, give
  a corrected version, and make the tradeoff explicit. Generic by design: no project, domain, ORM, or
  language config — any context it needs (is this table transactional? is the scan intentional? what
  volume is expected?) is raised during analysis, never assumed. Reach for it whenever someone writes,
  reviews, or optimizes a query or data-access code — "review this query", "why is this slow", "check
  my migration", "is this index right", or when you see N+1, SELECT *, a cartesian/row explosion,
  three-plus joins, a missing date filter on a growing table, OFFSET pagination, LIKE '%term%', NOT IN
  with nullable columns, an unindexed ORDER BY, an unbounded list, or a long transaction — even when
  they never say the word "SQL". Use it both to validate new code and designs and to audit existing
  ones.
---

# SQL quality check

The real work here is **judging tradeoffs, not applying rules blindly.** Anyone can memorize "don't use
`SELECT *`"; the skill is knowing *why* it costs you, *when* it actually matters, and what you give up
by changing it. Every recommendation has a price, and naming that price is what makes the advice
trustworthy — a finding that only lists the downside of the current code, without the cost of the fix,
is half an analysis. So for each thing you flag, you owe three things: the database-level **impact**, a
**corrected** version, and the **tradeoff** the fix carries.

Three premises sit underneath every recommendation. Keep them in view:

- **There is no universally correct answer in SQL — every decision is a tradeoff.** An index speeds up
  reads but slows writes and costs space. State the cost alongside the benefit, every time.
- **Data is written once and read many times.** Because reads dominate, reads are what you optimize for.
  That's what justifies denormalizing frequently-read data and indexing the columns used in filters and
  ordering — you pay a little on the rare write to save a lot on the common read.
- **The root cause is usually the data model.** The smells below are *symptoms*. When several show up
  together, the real problem is generally the schema or the API contract, not the individual query —
  say so, rather than patching each symptom in isolation.

All the smells carry equal weight: any one of them, on its own, can degrade performance severely under
real data volume. There is no severity ranking — there is context analysis. A sequential scan on a tiny
lookup table is fine; the same scan on a 50-million-row transactional table is a fire. Which is why you
never judge from the SQL text alone.

## How to work

You may receive a SQL snippet, an ORM-generated query, a schema/modeling design, or a PR diff. Work it
in this order:

1. **Gather the context you need — don't assume it.** The same query can be perfect or catastrophic
   depending on facts that aren't in the SQL: Is this table *transactional* (grows without bound over
   time)? Is a full scan *intentional* (a one-off admin job) or an accident? What volume is expected?
   Infer what you can from signals — a timestamp column and an ever-growing shape suggest a transactional
   table; a `LIMIT` suggests an interactive list. When a finding hinges on something you can't infer,
   **ask** rather than guessing. A confident recommendation built on a wrong assumption is worse than a
   question.
2. **Scan for the smells.** Read `references/smells.md` — the catalog of 11 recurring patterns, each with
   how to detect it, why it degrades systems, and the corrected form. Match against what you're given.
3. **For each smell found, deliver the three things:** the cause/impact in plain terms, the corrected
   version, and the tradeoff the correction carries. Tie symptoms back to the model when they cluster.
4. **Validate with the execution plan.** Don't stop at reading the SQL — the plan is the evidence.
   `references/modeling-and-plans.md` covers `EXPLAIN`/`EXPLAIN ANALYZE`, what to look for (sequential
   scans on big tables, sorts spilling to disk, whether an index is actually used), plus the
   modeling and indexing guidance the recommendations draw on. Request or suggest the plan for any
   query you're unsure about.

## The smell catalog (index)

Full detail — impact, detection, and a to-avoid/preferred example for each — is in
`references/smells.md`. The eleven patterns:

1. **Excess joins / cartesian row explosion** — 3+ joins, especially 1:N, multiplying result rows.
2. **Function or cast on a filtered column** — wrapping the column in an expression disables its index.
3. **N+1** — one query per item in a loop instead of one query for all (read *and* write variants).
4. **Query on a transactional table with no date filter** — scans an ever-growing history.
5. **Selecting all columns when few are used** — `SELECT *` wastes I/O and blocks index-only scans.
6. **Leading-wildcard text search** — `LIKE '%term%'` can't use a B-tree index.
7. **Count that reuses the listing query for pagination** — runs the whole listing just to count.
8. **High-OFFSET pagination** — reads and discards N rows before returning the page.
9. **`IN` subquery and the `NOT IN` + NULL trap** — `EXISTS`/`NOT EXISTS` is usually safer and faster.
10. **Unindexed sort / unbounded list** — `ORDER BY` with no covering index, or no `LIMIT`.
11. **Long transactions / unindexed mass writes** — held locks, connection-pool exhaustion, bloat.

## Output

Match the situation. A quick review might be a checklist; a PR review wants inline comments anchored to
the offending lines; a design audit wants a short report. Whatever the shape, each finding carries the
same three parts — **impact**, **corrected version**, **tradeoff** — and clusters of symptoms get a note
pointing at the likely modeling root cause. Lead with the findings that matter under the actual expected
volume; don't bury a row-explosion behind a stylistic nit.

**Write your findings in English**, regardless of the language of the code, comments, or PR under
review. Keep table, column, and identifier names verbatim from the source — translate the analysis, not
the schema.

## References

- `references/smells.md` — the full catalog of 11 smells: description, impact, detection, and a
  to-avoid/preferred example for each. Read it when scanning any query or diff.
- `references/modeling-and-plans.md` — modeling and indexing guidance (read-optimization, denormalization,
  composite-index column order, partial indexes, index restraint, data types) and how to validate with
  the execution plan (`EXPLAIN`). Read it for schema/design audits and to confirm a query's behavior.
