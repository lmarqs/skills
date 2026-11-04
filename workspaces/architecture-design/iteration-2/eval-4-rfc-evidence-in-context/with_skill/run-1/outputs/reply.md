The RFC is in `document.md`, at status **proposed**. Recommendation: move every report read onto a
separate reporting database maintained by logical replication, and hold the pre-aggregation layer until
one measurement lands. Two things you should read before the document itself.

**Your framing is half a solution, and the missing half is the part that fixes the 8 seconds.** "Split
the reporting queries off the main database" fixes reporting competing with transactional work. It does
not necessarily fix the dashboard's latency: if most of those 8 seconds is the query's own execution
cost rather than time queued behind other work, the same query on a second database returns the same 8
seconds. So the document treats them as two requirements with two roles (N1 for the dashboard, N2 for
the contention) and makes the pre-aggregation decision conditional on measuring which one you have.
That measurement is about a day's work and it is the highest-value thing you can do this week.

**I could not verify anything.** No repository and no Grafana access in this pass, so all four of your
figures went in as claims with labels, not as facts:

| Your input | How it appears in the document | Why |
| --- | --- | --- |
| p95 ≈8 s, dashboard endpoint, last month, `api-latency` board | *measured, second-hand* | Instrument and window are named, so it is not an assumption — but the board was not opened, and "around 8 seconds" is not a number a target can be derived from |
| Reporting is 40% of database load | *assumed* | No instrument named, and "load" is not a metric: CPU time, total query time, IOPS, connections and lock waits give four different answers, and which one you meant changes the design |
| ~300 active tenants | *assumed* | No source, and "active" is undefined |
| All report queries are in `reports/queries.py` | *assumed* | Unverified claim about the code, and "all" is the load-bearing word: it defines the scope of the whole change |

Tasks T1 and T2 in the document close all four in roughly two hours, and they run before anything is
built. If the measured reporting share comes in under about 10% of database time, the recommendation is
the wrong shape and "optimize the queries in place" wins instead — the document says so explicitly.

## What was reclassified

- **"Split the reporting queries off the main database"** → design choice, not a requirement. It is
  evaluated as three separate rows in the tradeoff table (physical read replica, writable replicated
  database, columnar analytical store) against what it is meant to achieve.
- **"Reports are slow"** → split into two requirements with different roles and different measurements:
  N1 (dashboard p95, the one case you have a number for) and N6 (the rest of the catalogue, currently
  unmeasured).
- **"Reporting is 40% of our database load"** → not a requirement at all; it is the evidence N2 derives
  from.
- **One database serving both workloads**, **report queries running synchronously in the request**, and
  **the shared-schema multi-tenant model** → prior decisions, each with a row in the tradeoff table
  beside an alternative, rather than fixed background.

## Two requirements I added that you did not ask for

Both name the role they serve, and both are yours to strike:

- **N5** — every reporting read filtered by exactly one tenant identifier, enforced by a build-time
  check. A second copy of the data duplicates the tenant boundary, and duplicated boundaries are where
  cross-tenant leaks come from. At ~300 tenants, one unfiltered aggregate exposes the customer base.
- **F2** — the dashboard shows when its figures were computed, and flags them when stale. Any split
  introduces staleness where there is none today; not showing it changes what the numbers mean to the
  person acting on them.

## Questions I would have asked, with my recommended answers

Interactively I would have stopped twice — after the requirements, and before writing the decision.
Since this was one-shot, the assumptions are labelled in the document and the questions are here. The
first two are blocking: the status cannot leave *proposed* while either is open.

1. **(Blocking, B2) Is the dashboard's 8 seconds contention or query cost?** Recommended answer: run
   the measurement rather than guess — the document states the pass criterion and what each outcome
   changes before it runs. My expectation is that query cost dominates, because 8 seconds is a lot of
   queueing.
2. **(Blocking, B1) Which reports, if any, must show data that committed seconds ago?** Recommended
   answer: probably none of the dashboard metrics, but at least one financial or reconciliation report
   usually does, and those cannot move to any replicated copy. If any exist, the split saves less than
   40%.
3. **What p95 do you actually want on the dashboard?** Recommended answer: 1,500 ms, which is what the
   document uses, labelled *assumed*. There is no abandonment data and no SLA behind it. T1 reads the
   p95 of your other authenticated pages off the same board and sets the real number.
4. **What database engine, and what multi-tenant model?** Recommended answer: I assumed PostgreSQL with
   a shared schema and a tenant identifier column. The option set is the same on MySQL or SQL Server;
   only the mechanism names change. Both are confirmable in one minute and both are labelled in the
   document.
5. **Who operates a replication pipeline?** Recommended answer: I assumed a small application team with
   no dedicated database administrator, which is why operational load ranks third among the drivers and
   why the columnar-store and buy options are penalized. If you have a DBA, those rows improve and the
   recommendation could change.
6. **What is the budget?** Recommended answer: none was given, so N4's ceiling is expressed relative to
   your current database instance's cost line rather than as a currency figure, and the budget owner
   approves it before cutover. Note that a same-class second instance roughly doubles your database
   compute spend.
7. **Do your tenant contracts or applicable data-protection rules restrict where tenant data may be
   stored or processed?** Recommended answer: assume they do until checked. It is the only thing that
   would exclude an option outright, and it is the reason the constraints table has a row marked
   unconfirmed rather than being empty.

## Caveats

- The Design section names PostgreSQL-shaped mechanisms (logical replication, physical streaming
  replica, materialized views). If the engine is something else, the reasoning holds and the names
  change.
- Task estimates are mine, in engineer-days, with no knowledge of your team. Treat them as ranges.
- The document deliberately does not decide the pre-aggregation layer. That is not indecision; it is one
  measurement away, and deciding it now would be guessing at a one-way door.
- Nothing in the document was verified against your systems. Its argument is only as good as tasks T1
  to T3, which is why they are the first items on the roadmap.
