# Worked example — forward-looking RFC

A condensed RFC deciding the architecture of a new search service. Use it as a model for *structure,
depth, and tone*: the constraints table, the requirement tables with a goal and a proof on every row,
the sourced numbers in Context, and the tradeoff table. Figures are illustrative but written the way
real ones should be written, with a source and a label attached. (The skill writes in the language of
the request; this example is in English, and the same structure applies in any language.)

---

# RFC — Search

**Status:** proposed
**Decider:** Tech lead, Search  ·  **Reviewers:** Platform guild, DBA, Product owner for scheduling
**Current working focus:** tradeoff

## Reversibility

**One-way door on the data store.** Moving search off Elasticsearch means writing ranking logic against
Postgres and decommissioning the cluster; coming back would mean rebuilding indexes and re-tuning
ranking. The provisioning and language choices are two-way doors, cheap to revisit, so they get less
space below.

> Sizing the decision first is what justifies the depth of the rest. A document that spends equal
> effort on a reversible choice and an irreversible one has mis-sized both.

## Context

> Told as a story that lands on a problem, not as "this document describes…". Every number carries its
> source inline and a label.

Search is served two different ways today: straight from the transactional database and from
Elasticsearch, stitched together across two APIs (the Public Search API and the internal Rest API).
That shape grew organically as features were added, and it now costs us in three measurable places.

- **Latency.** p95 of the schedule-search endpoint sat at 4.1 s over the last 30 days (Datadog
  `search-latency` board, read 2026-04-12; *measured*).
- **Money.** Elasticsearch ran USD 2,840 in March (AWS Cost Explorer, tag `service:search`;
  *measured*), against USD 310 for the search share of the Core database instance (*estimated*, from
  instance cost apportioned by query time).
- **Maintenance.** 7 of the 19 search bugs closed in the last two quarters were divergences between the
  two sources (Jira filter `component=search AND label=sync`; *measured*).

Phase III layers the full purchase flow (search → cart → checkout) on top of that search. **The problem
to solve:** the fragmented shape cannot carry the new flow without regressing today's behaviour or its
ranking, so we need to decide how search should be served going forward.

### Technical context

There are two data sources. The transactional Postgres database holds `management.procedure` and
`partner.partner`, queried directly by the Rest API with `ILIKE` predicates and no text index
(`api/search.rb:96-184`). Elasticsearch holds one index per entity, refreshed by three cron jobs
(`ops/cron/reindex-*.yml`), and serves the search modal through the Public Search API. Ranking rules
live in `search/ranking.py:212-388` and are duplicated in the Rest API path, which is where most of the
sync bugs come from.

The current flow, step by step: the user types in the search modal → the web app calls
`GET /public/search?term=` → the Public Search API queries the Elasticsearch procedure index →
results are re-ranked in the API → the user picks a procedure → the app calls `GET /rest/slots` for
availability, which reads Postgres directly.

> Note how this section assumes *zero* prior knowledge: every index, endpoint, table and file is named.
> The obvious is stated, and each claim can be checked without asking anyone.

### Stakeholders

- **Search team** — builds and owns the new service.
- **Platform guild** — owns the API standard and the Kubernetes cluster; approves the runtime choice.
- **DBA** — owns Core database capacity; must approve any new read load on it.
- **Product owner, scheduling** — owns the funnel metrics the latency requirement derives from.

### Constraints

> Givens imposed from outside this decision. They are true from the start rather than proved at the
> end, and none of them pre-selects an alternative: an option that violates one stays in the tradeoff
> table with the violation recorded as a cost.

| Constraint | Source | Cost to challenge |
| --- | --- | --- |
| Public endpoints follow the company API standard (resource naming, pagination, parameters, error shape) | API guidelines doc, owned by the platform guild | Low for new endpoints; high for ones the mobile app already consumes, which would need a client release |
| Ranking business rules stay exactly as they are today | Product owner, scheduling; funnel is tuned to them | High: would require a ranking experiment and product sign-off |
| Merges are gated by the repo coverage threshold | `.github/workflows/ci.yml:38` | Low: team practice, changeable in a PR |
| No new managed service without platform-guild review | Platform guild policy, 2026-01 | Medium: a review takes about two weeks |

### Assumptions and open questions

- We assume ranking parity matters to conversion at the margin, but nobody has measured how much a
  small ranking change costs (*assumed*). A two-week A/B on the top 500 terms would tell us; until then
  we treat parity as a hard requirement because the product owner does.
- Peak concurrency is *estimated*, not measured: ≈360 concurrent requests (18,000 searches/hour at the
  observed daily peak ÷ 3,600 × 72 s median session, from the `search-latency` board). A month of
  request-level tracing would replace the estimate.

### Out of scope

- **Checkout and purchase flow** — its own document, even though it underpins the search requirements.
- **Ranking changes** — the rules must stay as they are today; see the constraint above.

## Requirements

> Four items from the original request were reclassified. "Standardized endpoints" and "coverage above
> 90%" are constraints, not qualities of the running system, and moved to the table above.
> "OpenTelemetry tracing" is a design choice serving N2, and moved to Design. A "nice to have ADR
> directory" left the document entirely and became a roadmap task: nothing optional is a requirement.

### Functional

| ID | Goal (why it matters) | Requirement | Proof | Source |
| --- | --- | --- | --- | --- |
| F1 | Existing users must not lose the search they already rely on, or the migration will be rolled back | Every ordering and filter available today keeps working, including filter-by-location | Contract test suite replaying the 500 most-frequent query shapes from the last 90 days against old and new, comparing result sets | Technical context: current endpoints and their parameters |
| F2 | Clinicians search by the code on the form in front of them as often as by name | Procedure search matches the term against name, keywords and TUSS code | Test set of 200 real terms sampled from query logs, each returning the expected procedure in the first page | Query logs: 41% of terms are numeric TUSS codes (*measured*) |
| F3 | A result the user cannot actually book is worse than no result, and drives support contacts | Results only include partners serving the location the user provided | E2E test per location tier, plus a production check that flags any booking attempt rejected for location | 11% of support contacts in Q1 were "the slot was not available" (*measured*, Zendesk tag `wrong-location`) |
| F4 | The funnel is tuned to today's ranking; a change is a product decision, not a side effect of a migration | Results are ranked identically to today for the top 500 terms | Side-by-side ranking comparison on those terms, zero position differences in the first page | Constraint: ranking rules stay as they are |
| F5 | A single injected term must not be able to read or damage partner data | User-entered terms are parameterised or escaped on every path into the data store | Static analysis rule on the query builders, plus a suite of injection payloads in CI | Rest API builds `ILIKE` predicates by string interpolation today (`api/search.rb:118`) |

### Non-functional

| ID | Goal (why it matters) | Requirement (metric, target, condition) | Proof (measurement) | Source |
| --- | --- | --- | --- | --- |
| N1 | Users abandon a schedule search that takes longer than about 3 s, and that drop-off is the largest single loss in the funnel | p95 of `GET /search/find-all-by-term` stays at or below 3,000 ms at the estimated peak of ≈360 concurrent requests | k6 run in staging reproducing that peak against production-sized data, in CI before each release | Funnel dashboard, 2026-03 cohort: 31% drop-off above 3 s (*measured*); peak from Assumptions (*estimated*) |
| N2 | On-call has to find the cause of a failed search without reproducing it, or incidents run for hours | Any failed search request is traceable end to end from its correlation id within 5 minutes of the alert | Game-day drill before launch: inject a failure, time the diagnosis | INC-4471, where the cause of a search outage took 3 h 10 m to find (*measured*) |
| N3 | Search must not be able to take the booking flow down with it, which is what makes the current shape risky | Search query load adds no more than 10% to Core database CPU at the estimated peak | Load test with search traffic on, CPU read from the RDS dashboard | Nightly reindex saturated Core for 22 minutes in INC-4471 (*measured*) |
| N4 | The migration has to pay for itself, or the cheaper option is to leave things alone | Monthly run cost of search at or below USD 1,500 at current volume | Cost Explorer, tagged, one month after cutover | Today's USD 3,150 combined (*measured* + *estimated*, see Context) |

> Every row states the goal before the requirement, because the goal is what makes the requirement
> negotiable. If 3.5 s turns out to cost almost nothing in abandonment, N1's target can move and a
> cheaper design becomes viable. That conversation is impossible without the goal column.

## Design

> Decides dimension by dimension, always naming the requirement each choice answers.

### Data access and ranking

A **search service** owns all search reads (F1, F2, F3, F4). It exposes the endpoints the web app and
the mobile app call, so ranking logic exists in exactly one place, which is what removes the class of
bug behind 7 of 19 search defects. Terms are parameterised at the query-builder boundary (F5).

### Application provisioning

Lambda vs. the existing Kubernetes cluster. Search traffic drops to near zero overnight (the
`search-latency` board shows under 40 requests/hour between 01:00 and 05:00; *measured*), a pattern that
favours per-invocation billing (N4). The watch point is database connections: ≈360 concurrent
invocations without pooling would exhaust Core's connection limit, and we already run RDS Proxy, which
covers it (N3). Choosing Lambda challenges the "no new managed service without review" constraint only
if the guild counts it as new; it does not, since two other services already run on it.

### Language

JavaScript vs. Go at the estimated peak. Both handle I/O well; Go pulls ahead on CPU-bound ranking work
and cuts memory per invocation, which reduces Lambda cost (N4). Prior CPU problems in the Node services
are what drove the team's earlier move to Go.

### Data store

Elasticsearch delivers ranking and indexing out of the box but costs USD 2,840/month (N4), and part of
search traffic already bypasses it. The alternative is Postgres full-text search (`tsvector`/`tsquery`,
`pg_trgm`, `ts_rank_cd`) against a dedicated read replica, which keeps search load off the primary
(N3). Reproducing ES ranking exactly (F4) is the risk, so a **Postgres text-search POC** on the top 500
terms grounds the decision; its results are in the tradeoff table below rather than asserted here.

### Observability

Structured logs with a correlation id propagated from the edge, OpenTelemetry tracing across the
service and its database calls, and a latency/error dashboard per endpoint. This is the design choice
that meets **N2**; the requirement is the 5-minute diagnosis, not the tool.

### Diagrams

- **Static:** web app and mobile app → API gateway → search service → read replica; the cron reindex
  jobs and the Elasticsearch cluster shown as the components being removed.
- **Dynamic:** numbered sequence for a term search — client sends term → service normalises and
  parameterises it → replica executes the `tsquery` with `ts_rank_cd` → service applies the ranking
  rules → response with pagination per the API standard.

> Both diagrams are embedded in the real document. Every component above names the requirement it
> serves, and every requirement ID appears at least once in this section: that two-way check is what
> catches both scope creep and gaps.

## Alternatives analysis (Tradeoff)

### Decision drivers

In priority order: **N3** (cannot endanger the booking flow) and **F4** (ranking parity), both
effectively veto criteria; then **N1** (latency), **N4** (cost), then operational load on a team of
four, then reversibility (the data store is a one-way door, so evidence matters more here than
elsewhere).

> Naming the drivers before the options is what stops the table from being reverse-engineered to fit a
> favourite. Note that "the platform team prefers Kubernetes" is not a driver: it is a constraint with
> a cost, and it appears as a cost in the rows below.

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **[Data store] Postgres FTS on a dedicated read replica** | Removes USD 2,840/month (N4); single source, no sync (F1); POC reproduced first-page ranking on 487 of the top 500 terms | High effort to replicate ES scoring (`dis_max`, boost, BM25); 13 terms still diverge | Text-search queries compete with transactional load | High | Medium | Dedicated read replica; GIN indexes; `VACUUM ANALYZE` in low-traffic windows; N3 load test gates the cutover | Provision a separate Postgres instance for search reads only |
| | | | The 13 divergent terms need per-term tuning and may not converge | Medium | Medium | Tune with `ts_rank_cd` weights before cutover; product sign-off on the residual list | Keep ES for those query shapes behind a flag |
| **[Data store] Keep ES, improve it, DB for specific cases** | Keeps mature ranking (F4 for free); less implementation effort; separates responsibilities | Keeps the USD 2,840 (fails N4); two sources, so sync bugs persist (works against F1) | Reindexing remains a sensitive operation | Medium | High | Blue-green indexing with index versioning, zero downtime | Roll the alias back to the previous index |
| **[Data store] Managed search service (OpenSearch Serverless)** | No cluster to operate; scales to the overnight trough | Violates the no-new-managed-service constraint (two-week guild review, medium cost); pricing at our volume estimated USD 1,900/month, so N4 passes only marginally | Cost model is usage-based and hard to predict at peak | Medium | Medium | Run a two-week metered trial before committing | Fall back to the read-replica option |
| **[Provisioning] AWS Lambda** | Cost matches the traffic shape (N4); auto-scales to the peak; no cluster to operate | Cold start is visible on an interactive search | Cold start adds hundreds of ms to p95 (N1) | Low | Medium | Provisioned concurrency during business hours | Move the hot endpoint to the cluster |
| | | | Saturating RDS Proxy at ≈360 concurrent invocations (N3) | High | Medium | Validate proxy limits in the N1 load test; monitor connection count | Reserved concurrency; scale the proxy instance |
| **[Provisioning] Existing Kubernetes cluster** | Satisfies the platform guild's preference at no challenge cost; no cold start (N1) | Pays for idle capacity overnight, when traffic is under 40 req/h (works against N4) | Idle cost erodes the migration's payback | Medium | High | Scale to zero with KEDA | Accept the cost and drop N4's target |
| **[Language] Go** | Better CPU profile for ranking; lower memory per invocation (N4); single binary | Lower team familiarity; slower delivery at first | The learning curve lowers early productivity | Medium | High | Define Go patterns up front; budget the curve on the board | Ship the first endpoint in Node and port it |
| **[Do nothing]** | Zero effort and zero migration risk | Leaves p95 at 4.1 s (fails N1), the cost at USD 3,150 (fails N4) and the sync bugs in place (works against F1); Phase III would ship on the fragmented shape | Phase III inherits the coupling and search takes the booking flow down | High | Medium | None available without the work this RFC proposes | — |

> Rows are added without repeating the alternative to carry **multiple risks** per option. Every option
> is scored against the requirement IDs, the "do nothing" baseline is on the table so the cost of
> acting is compared against the cost of not acting, and the option that violates a constraint stays in
> the analysis with the violation priced rather than being dropped on sight.

## The decision

**Provision on Lambda, in Go, retiring Elasticsearch and serving search from a dedicated Core read
replica with Postgres FTS.** The drivers decided it: the read-replica option is the only one that meets
N4 without a marginal cost model, and the POC brought F4 within 13 terms of parity, which the product
owner accepted with the residual list attached. N3 is handled by the replica plus the load-test gate.

**Decision style: autocratic.** The tech lead for Search owns the call, having consulted the platform
guild (provisioning), the DBA (N3) and the product owner (F4). Recorded here so the basis is visible.

### Consequences

- Search ranking lives in SQL and Postgres scoring functions from now on: cheaper to run, harder to
  change, and it needs someone on the team who understands `ts_rank_cd`.
- The Elasticsearch cluster and its three cron jobs are decommissioned, removing the sync bug class.
- Core gains a replica to operate and monitor, and search failures now correlate with database health.
- Two runtimes remain in play for the team (Lambda and the cluster), so the on-call runbook grows.

### Residual risks

- The 13 divergent terms may not converge; product accepted the list, but a ranking complaint after
  cutover is plausible.
- Peak concurrency is an estimate. If the real peak is materially higher, N1 and N3 both need re-testing
  before the second phase.

### Confirmation

- The N1 k6 run stays in CI as a release gate: if p95 crosses 3,000 ms at the modelled peak, the build
  fails. That is the fitness function for this decision.
- Weekly review of Core CPU attributable to search against N3's 10% ceiling for the first quarter.
- Cost Explorer check one month after cutover against N4's USD 1,500.
- Revisit this document if peak concurrency doubles or if the ranking constraint is lifted.

## Launch strategy

Phase the delivery so there is no eternal migration: the main search-flow endpoints first behind a
flag, with the contract test suite (F1) comparing old and new on live traffic shapes; then the
secondary endpoints; then decommission Elasticsearch and delete the cron jobs. Anything not on that
list is explicitly out of scope for now.

## Tasks and roadmap

| Task | Description | Estimate |
| --- | --- | --- |
| Initial project setup | README, folder structure (hexagonal), CI with the coverage gate | 2d |
| Migrations for `tsvector` + indexes; `pg_trgm`; thresholds | `management.procedure`, `partner.partner` (use `CONCURRENTLY`) | 5d |
| Read replica provisioning and monitoring | Replica, RDS Proxy config, CPU dashboard for N3 | 2d |
| `/search/find-all-by-term` | Unified search endpoint + contract tests + k6 for N1 | 3d |
| Correlation id and tracing | Edge propagation, OpenTelemetry, dashboards for N2 | 2d |
| ADR directory | Roadmap item carried over from the original wish list | 1d |

## Glossary

| Term | Meaning |
| --- | --- |
| Search service | The new service that owns all search reads; the single home for ranking logic |
| TUSS code | The national procedure code printed on the forms clinicians work from |
| Core | The transactional Postgres database behind booking |
| FTS | Postgres full-text search (`tsvector`, `tsquery`, `ts_rank_cd`) |

## Sources

- Datadog `search-latency` board, read 2026-04-12 (p95, overnight volume, daily peak).
- AWS Cost Explorer, tag `service:search`, March 2026 (Elasticsearch cost).
- Jira filter `component=search AND label=sync`, closed Q4 2025 to Q1 2026 (sync bug count).
- Zendesk tag `wrong-location`, Q1 2026 (support contact share).
- Funnel dashboard, 2026-03 cohort (abandonment above 3 s).
- INC-4471 post-mortem (reindex saturation, diagnosis time).
- Postgres text-search POC, branch `poc/pg-fts`, run 2026-04-09 (ranking parity on the top 500 terms).

> Provenance sits at the end, as backing for facts the document already stated. Nothing above requires
> opening one of these to follow the argument, which is the test of a self-contained document.
