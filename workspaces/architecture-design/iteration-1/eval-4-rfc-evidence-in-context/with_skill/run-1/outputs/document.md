# RFC — Splitting Reporting Queries Off the Main Database

**Status:** Draft — blocked on Phase 0 measurement (see *Open questions* and *Launch strategy*)
**Current working focus:** requirements / design (tradeoff analysis is provisional pending real measurement)

## Related documents

- Grafana board **`api-latency`** — source of the p95 latency figure quoted in this RFC. *Not
  independently reviewed while writing this document* — see "Evidence and open questions" below.
  Attach a direct link/panel screenshot here before this RFC goes to review.
- `reports/queries.py` — the application module that contains the reporting queries this RFC is about
  splitting off. *Not reviewed while writing this document* (out of reach in this working session) —
  see "Evidence and open questions."
- *(To add before review: schema diagrams / ER model for the tables `reports/queries.py` reads from;
  current DB instance sizing and configuration; any existing `pg_stat_statements` or slow-query-log
  export.)*

## Evidence and open questions

This RFC was drafted from a short problem statement, not from direct access to the dashboards, the
database, or the query code it discusses. Two numbers anchor the request, and both need to be treated
as **inputs to verify, not settled facts**, before this RFC can be finalized into an approved plan:

1. **"p95 on the dashboard endpoint was ~8s last month, per the `api-latency` Grafana board."**
   Reported by the requester from memory, not pulled fresh from Grafana while writing this document.
   Treated below as the working symptom, but the actual current p95, its trend, and whether it is
   specific to a "dashboard" endpoint or shared with other endpoints all need to be pulled from the
   dashboard before sign-off.
2. **"Reporting is maybe 40% of database load."** Explicitly called out by the requester as an
   **unmeasured guess**. This is not a minor gap — it is the single number that most changes which
   alternative in this RFC is worth building. If reporting is 5% of load, splitting it off will barely
   move the needle on the primary's headroom; if it's 70%, a read replica alone may already be
   saturated. This RFC does not treat 40% as fact anywhere in the analysis below; instead, Phase 0
   (see *Launch strategy*) makes measuring it the first deliverable, and the decision in this RFC is
   deliberately structured to be safe to start even if that number turns out to be wrong.

A third ambiguity, unresolved for the same reason (no access to the endpoint code or the query file):
**is the slow "dashboard endpoint" itself one of the reporting queries, or a separate transactional
endpoint that is being starved by reporting load competing for the same database?** These have
different fixes — the first needs the report query itself to run somewhere faster or precomputed; the
second needs *only* isolation from contention, and the report query can stay exactly as slow as it is
today without anyone being hurt by it. This RFC assumes the more common case for a "reporting
dashboard" — that the slow endpoint *is* a reporting query, and that it is *also* contending with
transactional traffic on the same instance — and calls this assumption out wherever it drives a
decision. Phase 0 resolves it with real data instead of assumption.

Everything below proceeds on these explicitly-flagged assumptions so the RFC is useful now; nothing
here should be read as a verified baseline.

## Context

The application runs report generation — including whatever powers the dashboard endpoint referenced
above — against the same primary database that serves the transactional (OLTP) workload: user actions,
writes, and the day-to-day request path. Reporting queries in this codebase live in
`reports/queries.py`; from the problem statement, this is described as the single place reporting reads
are issued from, which suggests reporting is already logically separated at the code layer even though
it is not separated at the data layer.

This shape is common and usually starts fine: reporting queries are added incrementally against the
same schema the application already has, because it's the fastest way to ship a report. It stops being
fine as the two workloads grow apart in shape — OLTP wants many short, index-friendly, low-latency
queries; reporting wants fewer, longer, scan- and aggregation-heavy queries — while both still compete
for the same CPU, I/O, connections, and lock space on one instance. The reported symptom (a
multi-second p95 on a user-facing endpoint) is consistent with that competition, though — per the open
questions above — it hasn't yet been isolated from "the report query is just inherently slow
regardless of what it runs on."

The business is multi-tenant, with roughly 300 active tenants as of today. **Assumption** (schema not
reviewed): tenants share database instances and tables, distinguished by a tenant identifier, rather
than each tenant having a dedicated database — this is the common pattern at this scale and the one
this RFC designs against; if tenants are actually isolated per-database already, several of the
alternatives below get simpler, not harder, and this should be corrected in review.

**The problem to solve:** reporting queries and transactional queries currently share one database,
and growth in reporting load and/or query complexity is producing latency that the business is calling
out as "hurting the app." We need to decide how to separate the two workloads at the data layer, in a
way that is safe to ship without a full, all-at-once migration, and that is falsifiable — steps early
in the plan can prove or disprove the assumptions above before the business commits to the expensive
part.

### Out of scope

- **Rewriting individual report queries** for correctness or business logic changes. This RFC is about
  *where* reporting queries run, not what they compute. Query-level optimization (missing indexes, bad
  query plans) is in scope only as a *contributing cause* to evaluate in Phase 0, and as a fallback
  mitigation — not as the primary recommendation.
- **A general-purpose BI / analytics platform** (e.g., ad hoc self-serve analytics for internal
  stakeholders). This RFC addresses the existing product-facing reporting/dashboard feature only. If
  the business also wants open-ended internal analytics, that is a related but separate decision that
  can reuse this RFC's replicated data, and should be scoped separately.
- **Changing the multi-tenancy model itself** (e.g., moving to database-per-tenant). Assumed fixed for
  this RFC.
- **Real-time/streaming reporting requirements.** Nothing in the problem statement asks for
  sub-second-fresh reports; this RFC assumes reporting can tolerate some replication lag (bounded and
  monitored — see Requirements) rather than requiring synchronous consistency with the primary.

## Requirements

Only the requirements that shape the architecture — the exhaustive list of every report and filter
belongs in the reporting feature's own spec, not here.

### Functional

- Reporting queries currently issued from `reports/queries.py` must continue to return **correct,
  per-tenant-isolated results** after any migration — no tenant may see another tenant's data, and no
  report's output may silently change. *(Verifying this requires the actual query inventory from
  Phase 0 — see Launch strategy; this requirement cannot be marked "met" without it.)*
- The chosen solution must support the read patterns Phase 0 finds in `reports/queries.py` (expected to
  be dominated by aggregation/scan-heavy analytical reads, based on "reports are slow," but this is
  an assumption pending the query inventory).
- Reporting reads must be able to run without holding locks that the transactional write path depends
  on, and without being blocked by transactional writes beyond a bounded, monitored replication lag.

### Non-functional

- **Isolation:** sustained or spiky reporting load must not degrade transactional (OLTP) endpoint
  latency or availability. This is the requirement most directly in service of "reports are slow and
  hurting the app" — it targets the *hurting the app* half of the problem, which is fixable by
  isolation alone, independent of whether the report queries themselves get faster.
- **Reporting latency:** a numeric target (e.g., "dashboard p95 ≤ 2s") is deliberately **not** set in
  this draft. Setting one now, off a self-reported and unverified 8s baseline, would be exactly the
  kind of unverified claim this document should not launder into a commitment. Phase 0 must produce a
  measured, current baseline; the target is set from that baseline plus explicit product input on what
  "fast enough" means for this dashboard.
- **Bounded staleness:** if reporting is served from replicated data (the direction this RFC leans),
  replication lag must be bounded and observable (e.g., an alert if lag exceeds N minutes), and product
  must sign off on what staleness is acceptable for this dashboard.
- **Reversibility:** given how much of this RFC rests on unverified numbers, the first shipped change
  must be cheap to undo — favor an approach where reporting traffic can be routed back to the primary
  with a config change, not a data-model migration, if Phase 0 or Phase 1 disproves an assumption.
- **Observability:** query-level metrics that separate reporting load from transactional load on the
  primary (by tagging/labeling queries, e.g. `application_name` in Postgres or equivalent), so the 40%
  figure — and everything downstream of it — becomes a measured number instead of a guess.

## Design

The design is intentionally staged, because two of the three numbers that would normally drive this
decision (real reporting p95, real % of DB load) are currently unmeasured. Rather than design the full
target architecture against guessed numbers, the design front-loads the measurement that removes the
guessing, and only then commits to a specific data-store choice.

### Components

- **Primary database (existing):** continues to serve transactional writes and reads. Gains query
  tagging so reporting vs. transactional load can be distinguished in metrics. *Addresses:
  Observability, Isolation.*
- **Query classifier / tagging layer:** every query issued from `reports/queries.py` is tagged (e.g., a
  Postgres `application_name` or a comment-based tag picked up by the query-performance tooling) so it
  is distinguishable from transactional queries in monitoring, without touching query logic. *Addresses:
  Observability — this is what turns the 40% guess into a measured number.*
- **Reporting read path (target state):** a data store reporting queries are redirected to once Phase 0
  confirms it's warranted — a streaming read replica of the primary at minimum; a precomputed/OLAP
  store if Phase 0 shows the primary's data shape can't serve reports fast enough even in isolation.
  *Addresses: Isolation, Reporting latency, Bounded staleness.*
- **Report routing switch:** an application-level toggle (per report, or globally) that sends
  `reports/queries.py` traffic to the reporting read path instead of the primary, with an instant
  fallback to the primary. *Addresses: Reversibility.*

### Static diagram (current → target)

```
Current:
  [App servers] ----(OLTP + reporting queries)----> [Primary DB]

Target (after Phase 1, pending Phase 0 confirmation):
  [App servers] --(OLTP queries)--------------------> [Primary DB]
        |                                                  |
        |--(reporting queries, via routing switch)--> [Reporting read path] <--(replication/ETL)--+
                                                                                                     |
                                                        (same Primary DB, above) -------------------+
```

- The routing switch lets `reports/queries.py` call sites choose their target without a data-model
  change, satisfying the Reversibility requirement.
- The reporting read path box is deliberately unresolved in this diagram — which concrete technology
  fills it is the subject of the Tradeoff analysis below, and the choice depends on Phase 0 data this
  RFC does not yet have.

### Dynamic diagram — request flow after Phase 1 ships

1. User requests the dashboard endpoint.
2. Endpoint calls into `reports/queries.py`.
3. Routing switch checks whether this report is migrated; if yes, sends the query to the reporting
   read path; if no (not yet migrated, or fallback engaged), sends it to the primary — identical to
   today's behavior.
4. Reporting read path executes the query against replicated/precomputed data (lag bounded and
   monitored per the Bounded staleness requirement) and returns results.
5. Metrics record latency and lag, tagged as reporting traffic, independent of primary DB metrics —
   this is what lets the team confirm or refute the isolation benefit with real numbers instead of
   assuming it.
6. If the reporting read path is unhealthy or lag exceeds threshold, the routing switch (manually or
   via an automated circuit-breaker, decided in implementation) falls back to step 3's "no" branch.

## Alternatives analysis (Tradeoff)

Grouped by the dimension being decided: **where reporting queries in `reports/queries.py` execute.**
Every alternative is evaluated against the requirements above; all four remain viable answers until
Phase 0 data arrives, which is exactly why Phase 0 is a gate rather than a footnote.

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **[A] Query/index tuning only, stay on primary** | No new infrastructure; fastest to try; fixes root cause if queries are simply unindexed/badly planned rather than inherently heavy; fully reversible | Doesn't address Isolation if the real cause is resource contention, not query inefficiency (unverified which it is); ceiling is the primary's total capacity — doesn't scale with tenant growth | Root cause turns out to be contention, not query shape — tuning ships and 8s p95 barely moves | High | Medium (unverified) | Do this analysis in Phase 0 via `EXPLAIN ANALYZE` on real report queries before committing further | If ineffective, fall through to alternative B/C without having wasted more than the Phase 0 investigation |
| **[B] Streaming read replica for reporting** | Directly addresses Isolation (separate compute/IO from primary); relatively mature/managed (e.g., cloud-managed read replica); reversible via the routing switch; keeps a single schema/query dialect, so `reports/queries.py` needs little rewriting | Doesn't inherently make an individual report query *faster* — if a query takes 8s from data-shape/aggregation cost alone, it still takes ~8s on a replica; replica lag adds a staleness tradeoff; still Postgres-shaped, so heavy ad hoc aggregations remain expensive | If Phase 0 shows reporting queries are inherently slow (not contention-bound), this alternative ships and doesn't fix the user-facing symptom | High | Medium (unverified — this is exactly what Phase 0 resolves) | Phase 0 profiles whether current 8s is dominated by contention (waits/locks) or by query cost (rows scanned, plan cost) before betting on B alone | Layer alternative C (materialized/precomputed views) on top of the replica for the specific reports that are slow on their own merits |
| | | | Replication lag exceeds tolerance during high-write periods, producing visibly stale dashboards | Medium | Low–Medium | Monitor lag, alert on threshold, and get explicit product sign-off on acceptable staleness before launch | Route affected reports back to the primary via the routing switch until lag recovers |
| **[C] Precomputed/materialized aggregates (on primary or on a replica)** | Can make the *specific slow report* fast regardless of root cause, since the expensive aggregation is done once on a schedule, not per-request; works even if the query is inherently a heavy scan | Refresh scheduling adds operational complexity; every new/changed report needs its own materialization work — doesn't generalize across `reports/queries.py` for free; staleness is coarser and less continuously tunable than replica lag | A report's business logic changes and the materialized view silently goes stale/wrong without anyone noticing | Medium | Medium | Add data-freshness checks/tests to the refresh job; treat view definitions as reviewed code, same as `reports/queries.py` | Roll back to computing that report live (on replica or primary) until the view is fixed |
| **[D] Dedicated analytical/OLAP store fed by CDC or ETL** | Best long-term ceiling — purpose-built for scan/aggregation workloads at scale; fully isolates reporting compute from the primary; scales independently of the 300-tenant OLTP footprint | Highest cost and operational overhead of all four (new system to run, new pipeline to keep healthy, a second query dialect for whoever maintains `reports/queries.py`); slowest to ship; hardest to justify without confirmed data on load/volume | Overbuilt relative to actual need if reporting turns out to be, e.g., 10% of load rather than the guessed 40% — sunk engineering cost for a problem that alternative B would have solved | Medium | Medium (directly tied to the unmeasured 40% figure) | Do not start D until Phase 0's measured load and Phase 1's replica-based results say B/C have hit their ceiling | Descope to B/C, keeping the CDC pipeline (if partially built) as a future option rather than finishing it under pressure |

**Where this leaves the decision:** A is nearly free and worth doing regardless of the outcome of the
rest, so it happens inside Phase 0, not instead of a real fix. B is the smallest structural change that
directly answers "reports are hurting the app" (the isolation half of the problem) and is cheap to
reverse. C is a targeted addition once specific reports are proven slow on their own merits, not a
replacement for B. D is the right answer only if Phase 0's measured load turns out to validate — or
exceed — the guessed 40%, and should not be started on the strength of a guess.

## The decision

**Decision:** Ship in the staged order Phase 0 (measure) → A (tune, in parallel) → B (read replica with
a reversible routing switch) → evaluate C for any report still slow on the replica → revisit D only if
Phase 0/B's real numbers warrant it. This is not "pick B and build it"; it's "commit to the cheapest
structural fix that plausibly solves the stated problem, instrumented so the team knows within weeks,
not quarters, whether it worked or whether to escalate to C/D."

**Why not commit straight to D (the OLAP warehouse)**, which is the most future-proof-looking option:
it is the most expensive and slowest to reverse of the four, and its justification rests entirely on
the 40%-DB-load figure that the requester explicitly flagged as an unmeasured guess. Committing to it
now would be exactly the kind of decision this document's own discipline warns against — locking in an
expensive, hard-to-reverse architecture on a number nobody has checked.

**Why not stop at A (tuning) alone:** it's the right first move but is not a structural fix — if the
real cause is contention for shared resources (not inefficient queries), no amount of query tuning
changes that, and the "hurting the app" half of the complaint would remain unaddressed after the
cheapest option has already been tried.

**Decision style:** Autocratic recommendation by the author of this RFC, offered for review — this
should not be treated as final until: (a) Phase 0's real numbers are in, and (b) whoever owns the
primary database's operational risk (capacity, on-call load) has signed off on adding a replica and a
routing layer.

## Launch strategy

**Phase 0 — Measure (before any infrastructure change ships):**
- Pull the real, current p95/p99 for the dashboard endpoint from the `api-latency` Grafana board
  (replacing the self-reported "~8s last month" figure used in this draft).
- Tag reporting queries (via `application_name` or equivalent) and measure their actual share of
  primary DB load over a representative period — replacing the guessed 40%.
- Run `EXPLAIN ANALYZE` (or equivalent) on the actual queries in `reports/queries.py` against
  production-like data volume, to separate "slow because of contention" from "slow because of query
  cost" — this is the fork in the road for whether B alone will work or C is needed sooner.
- Confirm the multi-tenancy assumption (shared tables with a tenant column vs. per-tenant isolation) by
  reading the schema, since several requirements above depend on it.

**Phase 1 — Isolate (alternative B):** stand up a streaming read replica; add the routing switch;
migrate the highest-impact report(s) first (starting with whichever query Phase 0 shows is both
high-frequency and high-cost); keep fallback to primary live throughout.

**Phase 2 — Target the stragglers (alternative C):** for any report still slow on the replica after
Phase 1, add a scheduled materialized/precomputed aggregate specifically for that report.

**Phase 3 — Re-evaluate D:** only opened as a phase if Phase 0's measured load and Phase 1/2's results
show the replica+materialization approach has hit a ceiling the business still needs to clear.

This is deliberately not an "eventual full migration to an OLAP warehouse" plan — later phases are
conditional on evidence from earlier ones, and the project can stop after Phase 1 or Phase 2 if that's
where the evidence says to stop.

## Tasks and roadmap

| Task | Description | Estimate |
| --- | --- | --- |
| Query tagging | Tag `reports/queries.py` call sites for observability (e.g., `application_name`) | 1–2d |
| Load measurement | Capture reporting vs. transactional DB load share over ≥1 representative week | 1d setup + 1wk wait |
| Endpoint baseline | Pull real p95/p99 history for the dashboard endpoint from `api-latency` | 0.5d |
| Query cost profiling | `EXPLAIN ANALYZE` on the report queries against realistic data volume | 2–3d |
| Schema/tenancy confirmation | Verify shared-table multi-tenancy assumption | 0.5d |
| Quick-win tuning (alt. A) | Add any indexes/rewrites the profiling surfaces | 2–5d (depends on findings) |
| Read replica provisioning (alt. B) | Stand up streaming replica; connection routing | 3–5d |
| Routing switch | Per-report toggle with fallback to primary | 2–3d |
| Migrate top report(s) | Move highest-impact report(s) from Phase 0 findings to replica | 3–5d |
| Lag monitoring & alerting | Bounded-staleness requirement | 1–2d |
| *(Conditional)* Materialized views (alt. C) | Per straggling report, after Phase 1 results | 2–4d each |
| *(Conditional)* OLAP/CDC evaluation (alt. D) | Only if Phase 0/1 data warrants; separate RFC | Not estimated here |

## Version history

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | 2026-09-08 | Lucas Marques (drafted from a verbal problem statement; dashboard, DB, and query-code access unavailable in this session) | Initial draft: staged, measurement-first plan to isolate reporting queries from the primary database. |
