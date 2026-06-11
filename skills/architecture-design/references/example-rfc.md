# Worked example — forward-looking RFC

A condensed, real RFC (deciding the architecture of a new search service). Use it as a model for
*structure, depth, and tone* — especially the tradeoff table. Links and images from the original are
elided; in a real doc, keep them. (The skill writes in the language of the request — this example is
in English, but the same structure applies in any language.)

---

# RFC — Search

**Status:** In progress

## Related documents

> List here the diagrams, spreadsheets, and specs the RFC references (solution diagram, overview of
> the current search endpoints, design of the new search API, mapping of the new endpoints).

## Context

> Told as a story that lands on a problem, not as "this document describes…".

Search today is served two different ways — straight from the transactional database and from
Elasticsearch — stitched together across two APIs. That shape grew organically as features were added,
and it now costs us in latency, in money (running Elasticsearch), and in maintenance bugs from keeping
two sources in sync. Phase III layers the full purchase flow (search → cart → checkout) on top of that
search. **The problem to solve:** that fragmented shape can't carry the new flow without regressing
today's behavior or its ranking — so we need to decide how search should be served going forward.

### Out of scope

- **Checkout and purchase flow** — handled in its own document, even though it underpins the search
  requirements.
- **Ranking changes** — the ranking business rules must stay exactly as they are today.

### Technical context

Today there are two data sources for search: the transactional database and Elasticsearch, queried via
the Public Search API and/or the Rest API. [Describes each index, how it's queried, the cron jobs that
refresh it, and walks step by step through the current flow — search modal, results, slots — with the
endpoints involved and their known pain points.]

> Note how this section assumes *zero* prior knowledge: it names every index, every endpoint, every
> parameter. The obvious is stated.

## Requirements

> Before the requirements, it anchors where we want to land (link to the new-experience design) and
> lists the current pains (queries that degrade the database, Elasticsearch cost, inability to filter
> by location, lack of effective E2E tests). Only then does it enumerate the requirements — and it makes
> the focus explicit: backend.

### Functional

- Search must not break the experience that already exists (orderings and filters preserved).
- Procedure search compares the term against name, keywords, and TUSS code.
- The user must see results consistent only with the location they provided.
- Results must be ranked strictly the same as today.
- The system must sanitize user-entered terms to prevent injected commands.
- … (each requirement concrete and verifiable)

### Non-functional

- Standardized endpoints (resource name, pagination, parameters, responses) and consistent errors.
- Observability: structured logs with a correlation ID, OpenTelemetry tracing over requests and the
  database, latency/error dashboards.
- **Schedule search with response time ≤ 3,000ms at p95, validated under load.**
- Automated test coverage > 90%, including a flow that validates ranking.
- (*Nice to have*) An ADR directory versioning the architectural decisions.

## Design

> Opens by sizing the load (≈360 concurrent requests at a hypothetical peak) to ground the choices
> that follow. Then it decides dimension by dimension, always tying back to the requirements:

### Application provisioning

Lambda vs. Kubernetes cluster. Search has low traffic at night — a pattern that favors Lambda (charges
per invocation + duration, no idle pods). Combined with Go, it optimizes cost. Watch point: database
connections — up to 360 concurrent without pooling; we already use RDS Proxy, which would cover it.

### Language

JavaScript vs. Go, given the 360 concurrent-request peak. Both handle I/O well; Go pulls ahead on CPU
processing (we've had CPU problems in the past that drove the switch to Go) and, with Lambda, reduces
resource consumption and cost.

### Data stores

Elasticsearch delivers ranking and indexing out of the box, but it's expensive and part of the search
traffic already doesn't use it. Alternative: use our own Postgres for search (FTS: tsvector/tsquery,
pg_trgm, ts_rank_cd). It's sensitive given the volume of operations — so a **Postgres Text Search POC**
grounds the decision.

### Cache, API consumption, diagrams, API design

> Each sub-topic closes by tying back to the requirement it solves. The diagrams (static + dynamic) and
> the endpoint design go here, ensuring **every requirement is covered** by some endpoint.

## Alternatives analysis (Tradeoff)

> The heart of the document. Each alternative is analyzed by **Pros / Cons / Risk**, and each risk has
> **Impact, Probability, Mitigation, and Contingency**. Group by the dimension being decided.

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **[Data store] Database as the single source** | Eliminates Elasticsearch cost; single source, no sync; native Postgres FTS covers the requirements | High complexity to replicate ES (dis_max, boost, BM25); risk of impacting the transactional DB | Text-search queries compete with critical transactional operations | High | Medium | Route search reads to a dedicated read replica; GIN indexes; VACUUM ANALYZE in low-traffic windows | Provision a separate Postgres instance just for search reads |
| | | Search quality inferior to ES | ES ranking is hard to reproduce in Postgres | Medium | Medium | Comparative validation Postgres vs. ES on the most-searched terms before production | — |
| **[Data store] Improved ES + DB for specific cases** | Keeps the maturity of current search; separates responsibilities; less implementation effort | Keeps ES cost; two sources with sync; reindexing | Sensitive reindexing process | Medium | High | Blue-green indexing with index versioning, zero downtime | Roll the alias back to the previous index |
| **[Provisioning] AWS Lambda** | Cost optimized for the usage pattern; auto-scales; less operational overhead | Cold start noticeable on interactive search | Cold start adds hundreds of ms | Low | Medium | Provisioned Concurrency during low-traffic hours | — |
| | | | Saturating the RDS Proxy | High | Medium | Validate RDS Proxy limits; monitor connections | Reserved Concurrency; scale up the RDS Proxy instance |
| **[Language] Golang** | Better at CPU; lower consumption (cuts Lambda/pod cost); single binary; goroutines | Lower team familiarity; learning curve; slower dev at first | The learning curve lowers productivity early on | Medium | High | Define Go patterns up front; budget the curve on the board; use AI (Agents/Skills) | — |

> Note: additional rows without repeating the alternative accommodate **multiple risks** per option.
> Every alternative is checked against the requirements from the Requirements section.

## The decision

From the discussions, we decided: **provision on Lambda, language Go, eliminating Elasticsearch and
using a dedicated read replica of the Core DB with Postgres FTS as the search mechanism.** [Diagram of
the chosen solution.]

> An explicit, justified decision. It does not stop at "it depends."

## Launch strategy

> Phasing the delivery: lists the main search-flow endpoints to migrate, then the secondary ones,
> making clear what's out of scope for now — so there's no "eternal migration."

## Tasks and roadmap

| Task | Description | Estimate |
| --- | --- | --- |
| Initial project setup | README, folder structure (hexagonal architecture) | 2d |
| Migrations for tsvector + indexes; pg_trgm; thresholds | management.procedure, partner.partner, … (use CONCURRENTLY) | 5d |
| [Lambda search] /search/find-all-by-term | Unified search + tests + k6 | 3d |
| … | … | … |

> Breaks the work into estimable tasks; it need not mirror the board 1:1, but it gives the shape of the
> roadmap.
