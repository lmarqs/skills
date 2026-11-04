# RFC — Rate limiting for the public search API

**Status:** proposed
**Decider:** owner of the public search API (name TBD — see Assumptions) · **Reviewers:** platform/infrastructure team, security, on-call representative for the public search API (roles TBD — see Assumptions)
**Current working focus:** decision, pending ratification at the architecture meeting

## Note on this document's evidence base

This RFC was drafted without access to the company's dashboards, incident tickets, cloud console, or the `public-search-api` codebase. Every current-state claim below therefore comes from the problem statement handed to this document, not from a query or a screenshot, and is labelled *assumed* rather than *measured*. Each assumption says what would confirm it. Before this goes into the meeting, whoever owns the service should pull the four numbers flagged in Assumptions — they change which alternative wins, and confirming them is far cheaper than debating them without evidence.

## Reversibility

Mixed. The enforcement mechanism itself — which layer counts requests and rejects the excess — is a **two-way door**: rate-limit counters are ephemeral state, not a data model, so the backend can be swapped later without a migration. What is harder to reverse is the **public contract**: once external callers start writing retry logic against a specific status code, header set, and identification scheme (API key vs. IP), changing that contract needs a deprecation cycle like any other public API change. There is also a standing cost to delay — every week the service stays unprotected is a week of continued exposure to the abuse pattern that already occurred. Those two factors (a contract external parties will depend on, and live exposure today) are why this gets the full method below rather than a one-paragraph call, even though the implementation choice can be revisited later.

## Context

The public search API (`public-search-api`) is a public-facing endpoint with, as of today, no rate limiting, throttling, or abuse controls of any kind: any caller can send requests at any rate (stated in the request that produced this RFC; *assumed* — not verified against the service's ingress configuration, WAF console, or API Gateway console, none of which were reachable while drafting this document). That absence has already resulted in "a few abuse scares" (stated in the request; *assumed* — the incident tickets, WAF logs, or CloudWatch alarms that would confirm frequency, source pattern, and severity were not available). Taken at face value, this reads as a live, recurring exposure rather than a one-off historical event, which is why time-to-first-mitigation is treated as a first-class concern below rather than something to optimize only after the "proper" solution ships.

Because a fix has never been built, the two people scoping this problem reached for the two enforcement mechanisms they already had in mind: AWS API Gateway's native throttling, and a custom middleware backed by Redis on the team's existing Kubernetes cluster. That framing is a hypothesis about the solution space, not the solution space itself, so this document treats both as candidates in the tradeoff analysis below, alongside at least one option neither of them named.

### Technical context

The phrasing of the request — "our own middleware ... on our Kubernetes cluster" versus "AWS API Gateway's native throttling" as if it were a change — is read here as implying two things, both *assumed* and worth confirming before the meeting: (1) `public-search-api` runs today on the team's own Kubernetes cluster, reached through a load balancer or ingress with no rate-limiting layer in front of it; and (2) the service is not currently fronted by AWS API Gateway, so adopting it would mean introducing a new component into the request path rather than flipping on a setting on something already there. If either assumption is wrong — for instance, if the service is already behind API Gateway with throttling simply switched off — the "custom middleware" alternative gets meaningfully more expensive relative to the "native throttling" one, because turning on an existing feature is cheaper than adding a new managed component. This is the single fact most worth confirming first.

A second assumption, also unconfirmed: `public-search-api` speaks plain HTTP(S) request/response (the normal shape for a search endpoint — a query in, a JSON result set out), not something like long-lived WebSocket connections or large binary payloads. AWS API Gateway handles the former well and the latter poorly, so this affects whether Option A (below) is even viable.

### Stakeholders

- **Owner of `public-search-api`** — builds, ships, and lives with whichever mechanism is chosen.
- **Platform/infrastructure team** — owns the Kubernetes cluster and (if applicable) the AWS account; would operate any new Redis instance or approve any new API Gateway deployment.
- **On-call for the public search API** — has to diagnose and respond the next time abuse recurs, with or without a fix in place.
- **External API consumers** (partners, integrators, or public callers, exact identity unconfirmed) — the audience whose contract this RFC has to avoid breaking.

### Constraints

| Constraint | Source | Cost to challenge |
| --- | --- | --- |
| Runs on AWS | Implied by the request naming AWS API Gateway as a candidate; *assumed*, not confirmed against a cloud bill or account | Low to challenge as a fact (a quick account check), high to challenge as a platform choice (a cloud migration, clearly out of scope here) |
| The team already operates a Kubernetes cluster and can deploy new components to it | Stated in the request ("our Kubernetes cluster") | N/A — this is existing capability, not something to challenge |
| The API is public, so its response contract (status codes, headers, required identification) is consumed by parties this team does not control | Nature of a "public API," stated in the request | High: any breaking change to an existing, working integration needs a deprecation cycle, not a flag flip |

No constraint here rules out any alternative outright; where one adds cost to an option, that cost is priced in the tradeoff table rather than used to disqualify it.

### Assumptions and open questions

These are the facts that would most change the recommendation below if they turned out different. None of them blocks this draft, but all four are worth five minutes each before the meeting:

- **Is `public-search-api` already behind any AWS edge (ALB, CloudFront, or API Gateway)?** If yes, an AWS WAF rate-based rule (see Design) can likely be turned on in hours, and adopting full API Gateway throttling is cheaper than assumed here. *Assumed no; confirm in the AWS console or the service's Terraform/CDK.*
- **How much traffic does the endpoint actually see, and what did the abuse spikes look like (peak rps, single-source vs. distributed, sustained vs. burst)?** This RFC cannot size the rate-limit thresholds, the Redis instance, or the API Gateway account-level quota without it. *Assumed unknown; the fastest way to get it is the load balancer's or API Gateway's access logs, or the incident tickets for the "abuse scares" themselves.*
- **Does the team already run Redis anywhere in production (sessions, caching)?** If so, the operational cost of Option B below is much lower than modelled here, because the expertise and the on-call muscle already exist. *Assumed no dedicated production Redis exists yet; confirm with the platform team.*
- **Do any callers already authenticate with an API key, or is all traffic anonymous today?** This determines how much of the tiering requirement (F2) is free versus how much needs new key issuance and a developer-facing change. *Assumed mostly anonymous, since "no controls at all" suggests no identification layer either; confirm against the service's auth code.*

### Out of scope

- **Authentication or authorization redesign.** Rate limiting is scoped to slow down excessive request volume, not to decide who is allowed to call the API at all.
- **Ranking, correctness, or feature changes to search results.** Nothing here touches what the API returns, only how often a given caller may ask.
- **Rate limiting for any API other than `public-search-api`.** A shared, cross-API quota system is a larger, separate decision; it is named as a future consideration in Residual risks, not designed here.

## Requirements

The request handed two design choices (API Gateway throttling, Redis middleware) rather than requirements. Both are treated below as candidates in the Alternatives analysis; the requirements in this section are derived instead from the problem itself — an unprotected public endpoint that has already caused abuse incidents — so that the two named options, and the others added here, can be judged against something other than each other.

### Functional

| ID | Goal (why it matters) | Requirement | Proof | Source |
| --- | --- | --- | --- | --- |
| F1 | A caller that gets throttled needs to know it was throttled, not guess whether the API is down, or support fields "is your API broken" tickets that are actually "you were rate-limited" | A request over the caller's limit returns `429 Too Many Requests` with a `Retry-After` header and remaining-quota headers, on every public endpoint | Contract test suite that drives synthetic over-limit traffic against each public endpoint in CI and asserts the status code and headers | "No controls at all" today (stated in the request; *assumed*) |
| F2 | One abusive caller must not be able to exhaust the budget shared by every other caller, which is the actual failure mode behind "a few abuse scares" | Limits are enforced per caller identity (API key where one exists, otherwise source IP), with at least an anonymous tier and a higher, identified tier | Load test that drives one identity at several times the normal rate while confirming a second, well-behaved identity keeps succeeding at its own limit | "Abuse scares," interpreted as one or a few sources driving excess volume, the common failure mode for an unprotected public search endpoint (*assumed*; confirm against the actual incident record) |
| F3 | Without this, an abuser defeats the whole exercise by spreading requests across enough parallel connections to hit a different backend replica each time, which is exactly the trivial workaround a naive, per-process counter leaves open | The configured limit for a given identity holds within a small tolerance regardless of which instance, pod, or availability zone serves the request | Test that drives traffic through the real multi-replica path and confirms the aggregate allowance observed matches the configured single-identity limit | Architectural inference: `public-search-api` runs on a multi-pod Kubernetes deployment (Technical context, *assumed*) |
| F4 | This RFC is meant to close an abuse hole, not to ship an unannounced breaking change to whichever integrations already work today | Callers using the API exactly as they do today keep working unchanged; the only new behavior any caller can observe is a 429 if they exceed a limit they were not hitting before | Shadow-mode rollout (log would-be-throttle decisions without enforcing them) reviewed for false positives against current legitimate traffic before enforcement is switched on | General expectation for a change to a *public* API's contract (stated in the request) |

### Non-functional

| ID | Goal (why it matters) | Requirement (metric, target, condition) | Proof (measurement) | Source |
| --- | --- | --- | --- | --- |
| N1 | The fix must not become the new latency complaint it was meant to prevent | Added p95 latency from the rate-limit check stays at or below 10 ms, measured against the peak load from the still-unconfirmed traffic figures in Assumptions | Load test in staging comparing p95 with the limiter on versus off, gating launch | General hot-path budget for a synchronous check; *assumed*, no specific SLA was supplied — confirm against any existing latency target for this endpoint |
| N2 | Trading a rare abuse incident for a guaranteed availability incident on every dependency blip would make things worse, not better | If the enforcement mechanism's own backing store or dependency is unreachable, the API fails open (serves the request, unprotected) rather than failing closed (returns 5xx to everyone), and an alert fires within 1 minute of the failure | Game-day drill: kill the mechanism's dependency and confirm the API keeps serving traffic while paging on-call | Architectural inference: any new component on the request's hot path is a new failure mode by construction |
| N3 | Abuse response today is presumably manual and slow, since it has recurred without a fix; a lever that needs a deploy just recreates that same slowness | An on-call engineer can change a rate limit (globally or for one identity) without a code deployment, start to finish, in under 15 minutes | Runbook drill timed from "the limit needs to change" to "the new limit is live" | "A few abuse scares" implying a recurring, presumably ad hoc response today (*assumed*; confirm with whoever handled the last incident) |
| N4 | The fix has to pay for itself in avoided incident and support cost, not become a line item nobody sized | The added monthly run cost of the chosen mechanism is modelled and reported before launch, and stays a minor fraction of the API's current hosting cost (a specific ceiling could not be set without the current cost and traffic figures — see Assumptions) | Cloud cost report one month after launch, tagged to the new component | No budget was stated in the request; *assumed* prudence, flagged for whoever owns the cloud bill to tighten into a real number |
| N5 | Every day without any control is a day of continued exposure to a pattern that has already recurred; a multi-week build with nothing shipped in the meantime does not actually solve the stated problem on any useful timeline | A first control, even a coarse one, is live in production within days of this RFC being approved, ahead of the fuller, tiered solution | Compare the deployment date of the first control against this RFC's approval date | "Already given us a few abuse scares," read as ongoing/recent rather than resolved (*assumed*; confirm recency and severity from the incident record before the meeting) |

## Design

The components below hold regardless of which enforcement mechanism wins the tradeoff in the next section; only the enforcement point itself (marked below) is the open dimension.

- **Identity resolution** (serves F2): resolve every request to an identity — an API key if one is presented, the source IP otherwise — before any limiting decision is made.
- **Enforcement point — the dimension this RFC decides** (serves F1, F2, F3): the component that counts requests per identity and rejects the excess. Candidates are analyzed in the next section.
- **Response contract** (serves F1, F4): a 429 with `Retry-After` and remaining-quota headers on rejection; unmodified behavior otherwise. This is designed once, here, and implemented identically regardless of which enforcement point is chosen, so that a future change to the mechanism never touches the contract external callers depend on.
- **Fail-open policy** (serves N2): if the enforcement point cannot reach whatever state it depends on (a cache, a counter store, a managed service's control plane), it allows the request through and raises an alert, rather than blocking all public traffic because the limiter itself is unhealthy.
- **Edge-level volumetric backstop** (serves N5, layered under any enforcement point chosen, not a competing alternative): an AWS WAF rate-based rule in front of the API, blocking a single IP that exceeds a coarse threshold over a five-minute window. This is the fastest thing that can plausibly ship — hours, not days — if any AWS edge already sits in front of the service (see Assumptions), and it is the recommended first action regardless of which mechanism wins the main decision, because it starts addressing N5 while the fuller solution is still being built. It is deliberately coarse (IP-only, five-minute granularity, defeated by IP rotation) and is not a substitute for F1–F4; it buys time.
- **Observability** (serves N3): every decision the enforcement point makes (allow, deny, fail-open) is logged and counted, tagged by identity tier, feeding a dashboard and an alert on abnormal deny-rate spikes — the same signal that would have made the original "abuse scares" visible sooner.

One option was considered and set aside without a full tradeoff-table row: buying a dedicated API-management platform (Kong, Apigee, Cloudflare, and similar). It solves the same problem and more, but it adds a new vendor relationship, a new control plane to learn, and a recurring license cost, to deliver a capability the team's existing cloud provider already offers natively (Option A below) or that fits inside infrastructure already run (Options B/C below). It stays out of the table because nothing in the requirements needs the extra surface (API composition, developer portal, monetization) such a platform brings; it would be worth revisiting only if the team's ambitions grow well past rate limiting one endpoint.

### Static diagram

```
Public clients (browsers, partner integrations)
        |
        v
[Edge: WAF rate-based rule]  <- coarse IP backstop, all options, ships first (N5)
        |
        v
[Enforcement point]  <- the dimension under decision:
        |                - A: AWS API Gateway usage plan (managed, in front of the cluster)
        |                - B: Redis-backed middleware (in-cluster, app-level)
        |                - C: Ingress/mesh rate limiting (in-cluster, infra-level)
        v
[public-search-api pods, Kubernetes]
        |
        v
[Search index / datastore]

[Shared counter store]  <- only needed by whichever enforcement point requires
                            global state across replicas (Redis for B; a
                            rate-limit service + store for C; none for A,
                            which is globally consistent by construction)
```

### Dynamic diagram — one request, enforcement point generic

1. Client sends a request to a public endpoint, with an API key if it has one.
2. The enforcement point resolves identity: API key → its tier; otherwise source IP → anonymous tier.
3. The enforcement point checks and atomically increments that identity's counter for the current window, in one round trip regardless of implementation (a Lua script against Redis for Option B; the ingress/mesh limiter's own counter for Option C; API Gateway's internal token bucket for Option A).
4. Under the limit: the request reaches `public-search-api`; the response carries the remaining-quota headers (F1).
5. Over the limit: the enforcement point returns 429 with `Retry-After` directly; `public-search-api` is never invoked (F1).
6. If the counter store or service is unreachable: the enforcement point fails open, logs the failure, and lets the request through (N2); an alert fires.
7. Every outcome (allow, deny, fail-open) is emitted as a tagged metric feeding the abuse-visibility dashboard (N3).

## Alternatives analysis (Tradeoff)

### Decision drivers, in priority order

1. **N5 — time to a first working control.** Given the recurring abuse, speed to any protection outweighs elegance.
2. **F3 and N2 together — correct, globally consistent enforcement without becoming a new single point of failure.** These are the two failure modes this RFC exists to avoid trading into each other.
3. **N3 — operability.** Whether a limit can change without a deploy.
4. **Which new dependency is cheaper for this team to own** — API Gateway (a new managed AWS component) versus Redis (a new stateful, self-run dependency) versus an ingress/mesh feature (config on infrastructure already run). Not "avoid anything new," since every option adds something; the question is which addition this team is best placed to operate.
5. **N4 — cost**, modelled, not asserted.
6. **N1 — added latency.**
7. **F2 and F4 — tiering flexibility now, and headroom for more complex rules later, without breaking today's callers.**
8. **Reversibility** — cost to swap the mechanism later, from Reversibility above.

### Alternatives

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **A — AWS API Gateway native throttling (usage plans, API keys)** | Fully managed: no new stateful component for the team to operate; globally consistent by construction, so F3 is satisfied for free; usage plans + API keys satisfy F2's two-tier requirement directly; limits changeable via console/IaC without a deploy (N3); AWS operates the availability of the mechanism itself (N2 mostly for free) | Introduces a new component into the request path if the service is not already behind an AWS edge (Assumptions); usage-plan quotas are coarse (per key/per stage), not expressive enough for hypothetical future rules like cost-aware or cross-API shared limits; tiered throttling via usage plans requires the REST API flavor of API Gateway, priced higher per request than the HTTP API flavor (AWS public pricing, general knowledge — verify against the account's actual configuration and current pricing page) | Migrating the ingress path (DNS/TLS cutover) causes an outage if mishandled | High | Medium | Canary a small percentage of traffic through the new path first; keep the old path live during cutover; rehearse the rollback | Revert DNS/routing to the direct path |
| | | | Usage-plan granularity turns out insufficient once real tiering needs are known | Medium | Medium | Pair with the WAF rule for coarse protection and a Lambda authorizer only if a specific rule truly needs it | Layer a thin custom check in front of the affected endpoints only, rather than replacing the whole mechanism |
| **B — Redis-backed custom middleware on the existing Kubernetes cluster** | No new AWS component or ingress migration; full control over the limiting algorithm and any future business rule; reusable for other services later | The team takes on operating Redis reliably for every public request (multi-AZ, upgrades, monitoring) — a genuinely new ongoing cost if no production Redis exists yet (Assumptions); Redis becomes a new dependency on the hot path of every request, so N2's fail-open behavior has to be engineered deliberately rather than inherited for free; slower to ship than flipping on a managed feature, working against N5; a hand-rolled limiting algorithm is easy to get subtly wrong (clock skew, non-atomic increments) and give a false sense of protection | Redis (or its network path) becomes unavailable and the limiter becomes a new outage cause for all public traffic | High | Medium | Managed Redis with multi-AZ replication; a strict timeout and circuit breaker on every call; fail-open is the explicit default, not an afterthought | Automatic fail-open plus a page; the WAF rule keeps providing coarse protection while Redis is down |
| | | | The custom algorithm has a bug that under-throttles (abuse continues) or over-throttles (legitimate callers blocked) | Medium | Medium | Use a well-reviewed limiting library rather than hand-rolled logic; ship in shadow mode first, enforce only after a clean review window | A kill switch that falls back to WAF-only enforcement while the bug is fixed |
| | | | Slower time-to-mitigate than flipping on a managed feature, while the abuse pattern keeps recurring | High | High | Ship the WAF rule (Design) in parallel, on its own, without waiting for this option to finish | None beyond the WAF backstop; inherent to building rather than enabling |
| **C — Ingress/service-mesh rate limiting on the existing cluster (e.g., an ingress controller's rate-limit annotation, or a mesh's native rate-limit filter)** — the credible alternative neither original option named | No application code change, configuration only; stays on infrastructure already run, without adopting AWS API Gateway or building app-level middleware | The simplest form (per-replica, in-memory counting) is only approximate globally: an abuser can get roughly as many requests as there are replicas before the aggregate limit bites, working against F3; a fully global version still needs a shared counter store behind it, which reintroduces most of Option B's operational cost under a different name | Per-replica counting under-protects once the deployment scales past a couple of replicas | Medium | High | Pair with the WAF rule as a global backstop while precision is not yet needed; add a shared store only for the endpoints where F3 genuinely matters | Escalate the specific endpoint to Option B's shared-state approach |
| **Do nothing (status quo)** | Zero engineering cost; zero migration or cutover risk | Fails the reason this RFC exists: `public-search-api` stays exposed to the pattern already observed, and every non-functional requirement above (N2 excepted, trivially) goes unmet by definition | The abuse pattern recurs or worsens while nothing changes | High | High (it has already happened, more than once) | None available without doing some version of the work above | The only lever left is the same ad hoc, manual response presumably used for the incidents so far |

Every option is weighed against F1–F4 and N1–N5 in the rows above rather than against each other in the abstract; the "do nothing" row exists so the cost of acting is compared against the cost of the status quo, not assumed.

## The decision

**Adopt AWS API Gateway native throttling (Option A) as the primary enforcement mechanism, using the REST API flavor with usage plans and API keys for the anonymous/identified tiers (F2), and ship the AWS WAF rate-based rule from Design as an immediate, parallel stopgap regardless of how long Option A's migration takes.** Option C (ingress/mesh-level limiting) is recorded as the fallback if the API Gateway migration turns out to be technically blocked — most plausibly by the unconfirmed assumption in Technical context that the service speaks plain request/response HTTP rather than something API Gateway handles poorly. Option B (Redis-backed middleware) is explicitly not chosen: nothing in F1–F4 needs a limiting rule more expressive than "two tiers, per identity," which usage plans already provide, and choosing it anyway would mean taking on a new, self-run, hot-path dependency (working against N2 and N5) to buy flexibility this document could not find a requirement for.

**The strongest objection to this call, stated plainly:** if the business need for rate limiting grows past what usage plans express — a limit that depends on how expensive a given search query is to run, or a quota shared across more than one public API — API Gateway's model cannot express that, and the migration already sunk into it becomes a component to work around rather than build on. The condition that would flip this decision: if product or the API owner confirms, before or shortly after this migration, a near-term need for cost-aware or cross-API shared limiting. In that case, Option B (or a hybrid — API Gateway for coarse global protection, a thin custom layer only for the specific advanced rule) should be built from the start rather than retrofitted later, since retrofitting means running two enforcement points at once.

**Decision style: autocratic**, pending ratification at the architecture meeting. This document proposes the call; the owner of `public-search-api` makes and owns it, having had the platform/infrastructure team's input on the migration cost and the on-call representative's input on N2/N3.

### Consequences

- The service gains a new component in its request path (API Gateway), which the platform/infrastructure team now operates and monitors alongside the cluster.
- Rate-limit thresholds become a console/IaC-level setting rather than application code, which is what makes N3 achievable, but also means they can be changed by anyone with that access — the change itself needs its own guardrail (who can edit a usage plan) that this document does not design.
- No new stateful dependency (Redis) is added to the critical path of every public request; the team keeps its current operational footprint on that axis.
- If the flexibility gap named above materializes, a second enforcement layer will eventually sit alongside API Gateway rather than replacing it, which is a real, accepted cost of this call, not a hidden one.

### Residual risks

- The four unconfirmed assumptions in Context/Assumptions (current edge topology, real traffic and abuse figures, existing Redis footprint, current auth state) were not available while drafting; if any turns out materially different, the cost comparison in the tradeoff table above should be redone before this decision is treated as final.
- The 13-percentile-style unknowns aside, the concrete open risk is the ingress migration itself (Option A's first table row): a cutover mistake is the single event most likely to cause an outage as a direct result of this RFC, more likely than the abuse this RFC is meant to stop.
- A future need for cross-API or cost-aware limiting, named above as the condition that would flip this decision, is treated here as a residual risk to watch rather than a reason to delay: it has not been confirmed as a near-term need, and building for it speculatively would violate the same discipline this document asks of every other requirement.

### Confirmation

- The WAF rate-based rule (Design) ships first; its deployment date versus this RFC's approval date is the direct measurement of N5.
- The F1 contract test (429 plus headers on synthetic over-limit traffic) runs in CI as a release gate from the first API Gateway deployment onward.
- The N2 fail-open game day and the N3 fifteen-minute runbook drill both run before the migration is called done, not after.
- One month after cutover: compare actual API Gateway cost (Cost Explorer, tagged) against the modelled figure in N4, and compare the deny-rate dashboard against whatever incident record exists for the original "abuse scares" — a drop in recurrence is the real test of whether this decision worked.
- Revisit this document if the cross-API or cost-aware limiting need named in the decision's objection materializes, or if any of the four open assumptions turns out to invalidate the cost comparison above.

## Launch strategy

Ship in two tracks rather than waiting for one to finish the other:

1. **Immediate (days):** the WAF rate-based rule, as a coarse IP-level backstop, contingent on confirming an AWS edge already exists in front of the service. This directly answers N5 without waiting on the migration below.
2. **Primary (weeks):** migrate `public-search-api`'s public path behind AWS API Gateway, in shadow mode first — logging every would-be-throttle decision without enforcing it, to catch false positives against real legitimate traffic (F4) — then switch to enforcing once a review window shows no unexpected impact on today's callers.

Anything past that (a shared, cross-API quota system; cost-aware limiting) is out of scope for this RFC and lives on the roadmap below only as a named future consideration, not a task.

## Tasks and roadmap

| Task | Description | Estimate |
| --- | --- | --- |
| Confirm the four open assumptions | Current edge topology, real traffic/abuse figures, existing Redis footprint, current auth state | 0.5d |
| WAF rate-based rule | Coarse IP backstop, contingent on an existing AWS edge | 1d |
| API Gateway migration, shadow mode | REST API in front of the cluster, usage plans and API keys defined, logging only | 5d |
| Contract tests and dashboards | F1's 429/header test suite in CI; deny-rate and latency dashboards for N1/N3 | 2d |
| Shadow-mode review and cutover | Review false-positive rate against real traffic, then switch enforcement on | 2d |
| N2/N3 drills | Fail-open game day; fifteen-minute limit-change runbook drill | 1d |
| Roadmap: cross-API / cost-aware limiting | Only if the near-term need is confirmed per the decision's stated flip condition | Not sized |

## Glossary

| Term | Meaning |
| --- | --- |
| The public search API (`public-search-api`) | The service this RFC protects; the subject throughout |
| Usage plan | An AWS API Gateway feature that attaches a throttle (rate/burst) and a quota to one or more API keys, giving distinct tiers per identity |
| REST API vs. HTTP API (API Gateway) | The two API Gateway product flavors; usage plans and API keys exist only on the REST API flavor, at a higher per-request price than the HTTP API flavor |
| Fail open / fail closed | Whether a component that cannot check a rule lets the request through (open) or blocks it (closed); this RFC requires fail-open for the rate limiter itself (N2) |
| WAF rate-based rule | An AWS WAF rule that blocks a single source IP once it crosses a request-count threshold over a rolling window (five minutes minimum) |
| Ingress / service mesh | The Kubernetes-native traffic-routing layer (an ingress controller, or a mesh like Envoy/Istio) that can host rate limiting as configuration rather than application code |
| Tier | A named class of caller (e.g., anonymous vs. identified) with its own limit |

## Sources

- The request that produced this document: the only source for every current-state claim above (no controls today, prior abuse scares, the two candidate mechanisms). No dashboard, ticket, or code access was available while drafting; see Assumptions for what would confirm each figure.
- AWS API Gateway product documentation (usage plans, API keys, REST vs. HTTP API pricing and feature differences) — general knowledge as of this document's drafting, not verified against this account's actual configuration or the current AWS pricing page; confirm both before the migration is costed for real.
- AWS WAF rate-based rules documentation — general knowledge, same caveat.

## Version history

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | 2026-09-08 | Drafted for the architecture meeting (author: requester's assistant) | Document created. |
