# RFC — Rate Limiting for public-search-api

**Status:** Draft — for discussion and ratification at the next architecture meeting
**Current working focus:** decision (recommendation stated, pending team ratification)

## Related documents

The following would normally be linked here but were **not accessible while drafting this
document** and should be attached before the meeting:

- Incident/postmortem records for the "abuse scares" referenced in the request (dates, request
  volumes, offending clients unknown to this draft).
- Current traffic dashboards for `public-search-api` (peak/sustained request rate, error rate,
  latency).
- The service's current ingress/networking configuration (`cloud-iac`), to confirm whether it is
  already exposed through AWS API Gateway or directly through a load balancer / Kubernetes ingress.
- Confirmation of whether callers currently present any form of client identifier (API key, token)
  or are fully anonymous.

Everything below that depends on these is explicitly marked **unverified** or **assumed**, with a
prerequisite task in *Launch strategy* to close the gap before numeric thresholds are finalized.

## Context

`public-search-api` is a public-facing search endpoint with **no request-rate controls of any
kind** today: no per-client quotas, no throttling, no circuit breaking. Any caller — authenticated
or not — can send requests at whatever rate their client allows.

That absence of controls has already produced **repeated abuse scares** (per the request that
prompted this RFC). This document could not verify the specifics — incident tickets, request
volumes, dates, or whether the traffic was scripted scraping, a retry storm, or something else —
so treat "abuse has happened and will happen again" as the operative, directionally-true premise,
and treat any specific number in this document as a placeholder until real telemetry is attached.

Two things follow from having zero controls today: first, a single misbehaving client (malicious
or just poorly written) can degrade the API for everyone else; second, every abusive request is
currently also a compute/infrastructure cost with no ceiling. Both risks compound the longer this
goes unaddressed, which is why this is being brought to the architecture meeting now rather than
folded into a future roadmap item.

**The problem to solve:** decide how `public-search-api` enforces per-client rate limits, and land
on one of the two approaches already on the table — AWS API Gateway's native throttling, or
custom rate-limiting middleware backed by Redis running on the team's Kubernetes cluster — so a
concrete mitigation can ship rather than the discussion recurring at the next incident.

### Out of scope

- **Authentication / API-key issuance redesign.** This RFC assumes today's identity model for
  callers (API key if one exists, otherwise source IP) stays as-is. If the org decides to
  introduce mandatory API keys for all public API traffic, that changes the analysis below and
  deserves its own RFC.
- **Network-layer DDoS protection** (AWS Shield, broad WAF rules unrelated to per-client rate
  limiting). Complementary to this decision, not a substitute for it, and not re-litigated here.
- **Monetization / usage-tier pricing** for external API consumers.
- **Search ranking, relevance, or result-quality changes.**

### What this document could not verify (read before acting on any number below)

- Current request volume (sustained and peak), and whether existing abuse was volumetric,
  scripted-but-low-rate, or endpoint-specific.
- Whether `public-search-api` is already fronted by AWS API Gateway, a plain ALB, or a Kubernetes
  ingress controller. **This materially changes Alternative A's switching cost** (enabling a
  feature on infra already in place vs. inserting a new hop in front of the service).
- Whether callers present any client identifier today, or are fully anonymous.
- The service's existing latency SLA/budget, against which any rate-limiter overhead should be
  measured.

## Requirements

### Functional

- Every request to `public-search-api` must be evaluated against a per-client rate limit before
  reaching business logic. "Per-client" means per API key when one is presented, falling back to
  source IP for anonymous callers.
- A request that exceeds its client's limit must be rejected with `HTTP 429` and a `Retry-After`
  header — never silently dropped, and never allowed to degrade the service for other clients
  (e.g., by exhausting a shared connection pool or queue).
- Limits must be adjustable per client/tier **without a code deploy**, so an on-call engineer can
  tighten or loosen a specific client's limit mid-incident.
- Normal client behavior (e.g., a user paging through search results in quick succession) must not
  be throttled — the mechanism needs a short burst allowance above the sustained rate, not a hard
  per-second wall.

### Non-functional

- **Correctness under scale-out:** the limit must be enforced *globally* across all instances of
  `public-search-api`, not per-pod. A per-pod in-memory counter that lets a client get N requests
  through per pod, times the pod count, does not satisfy this requirement — it must be treated as
  a failed design, not a lightweight approximation.
- **Explicit failure behavior:** if the rate-limiting mechanism itself becomes unavailable or slow,
  the system must have a stated fail-open or fail-closed policy — this cannot be left to whatever
  the chosen implementation happens to do by default.
- **Latency overhead:** the rate-limit check should add a small, bounded amount of latency to every
  request. *Proposed target: ≤ 10ms at p95*, added as a placeholder in the absence of the
  service's actual latency SLA (unverified — see above); this must be validated against the real
  budget before sign-off.
- **Observability:** allowed vs. throttled request counts per client, exposed as metrics/dashboards,
  with alerting on sustained throttling (a signal of either an abusive client or a limit set too
  low for a legitimate one).
- **Operability:** limits changeable within minutes during an active incident, by whoever is
  on-call, without needing a second team's sign-off in the moment.
- **Cost proportionality:** the infrastructure cost of the chosen mechanism should be visibly
  smaller than the cost of the abuse it prevents, not merely "acceptable."

## Design

Regardless of which mechanism is picked in the tradeoff below, the same logical shape has to exist
somewhere on the request path, before the request reaches `public-search-api`'s business logic:

- **Client identity resolution** — extract an API key from the request, or fall back to source IP.
- **Policy store** — per-client (or per-tier) limit: sustained rate + burst allowance.
- **Shared state** — tracks current usage per client, visible to every instance handling traffic
  (this is what makes the "global correctness" requirement possible at all).
- **Enforcement point** — compares current usage to policy; forwards the request or returns `429`.
- **Metrics emission** — every allow/deny decision tagged by client and policy, feeding the
  observability requirement.

### Static diagram (described — no rendering tool available in this session)

```
                     ┌───────────────────────────┐
                     │   Policy store (limits)    │
                     └─────────────┬───────────────┘
                                   │
[External client] ──▶ [Rate-limit enforcement point] ──▶ [public-search-api pods]
                                   │  (shared counter,               │
                                   │   e.g. AWS usage-plan            ▼
                                   │   quota, or Redis)     [Search backend / data store]
                                   ▼
                       [Metrics: allow / deny, per client]
```

### Dynamic diagram — request flow (described)

1. Client sends a request, optionally carrying an API key.
2. The enforcement point resolves the client's identity (API key, else source IP).
3. It looks up that client's policy (sustained rate + burst) in the policy store.
4. It reads/updates the *shared* usage counter for that client in the current window.
5. **Under limit:** request is forwarded to `public-search-api`; counter is incremented.
6. **Over limit:** request is rejected with `429` + `Retry-After`; it never reaches the API's
   business logic or the search backend.
7. The allow/deny decision is emitted as a metric (client id, policy, decision), independent of
   step 5/6, so dashboards and alerts work the same regardless of outcome.

Every component above maps to a requirement: identity resolution → per-client functional
requirement; shared state → the global-correctness non-functional requirement; the explicit
allow/deny branch → the fail-open/closed and 429-with-Retry-After requirements; metrics emission →
observability. Which concrete technology fills "enforcement point" and "shared state" is exactly
what the tradeoff below decides.

## Alternatives analysis (Tradeoff)

Three alternatives were considered for the **[Rate-limiting mechanism]** dimension — the two named
in the request, plus a third considered and set aside, kept here so the option space is visibly
explored rather than assumed away.

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **[Mechanism] AWS API Gateway native throttling** | Fully managed — AWS operates the HA/scaling of the throttling layer itself; enforced at the edge, so rejected requests never consume cluster compute, network, or search-backend capacity; native usage-plan + API-key support; built-in CloudWatch metrics with minimal setup; fastest to ship given abuse is already active | Usage-plan throttling is keyed on API keys — doesn't natively cover fully anonymous callers; granularity is per-key requests/sec + burst, not cost-weighted per endpoint; introduces (or repositions) an AWS-specific hop whose fit depends on the service's current, unconfirmed exposure path; operational knobs live outside the Kubernetes-based deploy model the team otherwise uses | Anonymous (non-API-key) traffic isn't governed by usage-plan throttling, leaving exactly the gap the reported abuse may have exploited | High | Medium | Pair usage-plan throttling with an AWS WAF rate-based rule keyed on source IP for unauthenticated paths | Manually block offending IP ranges via WAF IP sets while the rate rule is tuned |
| | | | Inserting API Gateway in front of a service whose current topology is unconfirmed carries migration risk (DNS/ALB cutover, TLS, an added hop, integration bugs) | Medium | Medium (depends on unconfirmed topology) | Canary the cutover via weighted routing; keep the pre-existing path as an instant rollback target | Revert routing to the prior path within minutes if the cutover errors |
| | | | Per-key limiting is too coarse to express endpoint-specific cost (a heavy multi-field query vs. a cheap lookup) | Medium | High | Split expensive endpoints into distinct API Gateway resources/stages with tighter individual limits | Accept coarser protection short-term; revisit with a custom limiter if abuse concentrates on specific endpoints |
| **[Mechanism] Custom Redis-backed middleware on Kubernetes** | Full control of the limiting algorithm (token bucket, sliding window, cost-weighted per endpoint) and of identity resolution (API key, IP, header, JWT claim); a shared Redis counter gives genuinely global accuracy across all pods, meeting the correctness requirement precisely; stays inside the existing operational model (same cluster, deploy pipeline, on-call runbooks); reusable by other internal/public APIs later; limits changeable via config/flag without touching AWS infra | New moving part to provision, secure, monitor, and scale (or a shared Redis repurposed, with its own noisy-neighbor risk); limiting logic is built and tested in-house, so correctness bugs (races, clock skew) directly cause either outages or bypassed limits; abusive traffic still reaches cluster network and API pods before being rejected — worse containment than an edge-level reject; Redis sits in the hot path of every request, so its availability/latency now gates the API's; materially slower time-to-mitigate than flipping on a managed feature, given abuse is already active | Redis becomes unavailable or slow; middleware fails closed and takes down all of `public-search-api`, or fails open and defeats the purpose | High | Medium | Define an explicit fail-open-with-alert policy for short Redis blips, with a local in-memory fallback as degraded mode; run Redis with replication/Sentinel or a managed offering (e.g., ElastiCache) for HA | Page on-call to disable the middleware via feature flag; rely on upstream WAF/ALB protections until Redis recovers |
| | | | Distributed-counting bugs (races, clock skew, window-reset off-by-ones) let abuse through undetected, or wrongly throttle legitimate clients | Medium | Medium | Use a proven algorithm/library (e.g., Redis Cell, or a sliding-window Lua script) instead of a hand-rolled counter; load-test the limiter itself before rollout | Roll back to a permissive default limit while the bug is fixed, accepting temporarily reduced protection |
| | | | A large-enough volumetric attack saturates ingress/network capacity before Redis is ever consulted | High | Low–Medium | Keep basic edge protections (ALB/WAF connection limits) regardless of which mechanism wins this decision | Escalate to AWS Shield/WAF emergency response — this alternative was never meant to cover that layer alone |
| **[Mechanism] Ingress/service-mesh rate limiting already in-cluster** (e.g., NGINX ingress annotations, Envoy/Istio policy) — *considered and set aside* | No new external dependency (neither AWS API Gateway nor a new Redis); enforcement at the cluster edge, before the API pod; cheaper to operate than standing up Redis | Most ingress-level limiters count per-ingress-pod unless backed by a shared store — which reintroduces the same shared-counter requirement that motivates Alternative B, without clearly reducing its cost; typical feature depth (per-client policy management, usage plans) is shallower than API Gateway's | Whether the current ingress controller (and its version) even supports a shared-store rate-limiting module is unknown to this document | Medium | Medium | Confirm ingress controller, version, and module availability with the platform team | Fall back to Alternative A or B if unsupported |

Weighed against the requirements in section 2: Alternative A satisfies global correctness and
observability natively but only partially satisfies per-client enforcement (gap on anonymous
traffic) without a WAF companion rule, and its fit depends on an unconfirmed topology assumption.
Alternative B satisfies per-client enforcement and correctness fully by construction, but only if
the fail-open/closed policy is designed deliberately — left as a default, it fails the "explicit
failure behavior" requirement outright. Alternative C fails the correctness requirement as-is
(per-pod counting) unless paired with a shared store, at which point it stops being simpler than
Alternative B and was set aside for that reason, not pursued further, and not carried into the
recommendation below.

## The decision

**Recommendation: Alternative A — AWS API Gateway native throttling, paired with an AWS WAF
rate-based rule to cover anonymous/IP traffic** — as the mechanism to ship first, given abuse is
already active and zero controls exist today. This is proposed to the architecture meeting as a
recommendation, not a unilateral decision: **decision style is democratic** — the meeting is asked
to ratify, amend, or reject it, informed by the analysis above.

**Why this, and not Alternative B:** the deciding factor is time-to-mitigate against an active,
recurring problem. A fully managed edge control ships faster and with less new operational surface
than building and hardening a Redis-backed limiter from scratch, and it rejects abusive requests
before they touch cluster compute or the search backend — which a Redis-in-the-path approach
cannot do. The genuine strength of Alternative B — full control over cost-weighted, per-endpoint
limiting — is not something this RFC found evidence is currently needed; if usage-plan throttling
proves too coarse once real telemetry comes in (see *What this document could not verify*), that is
the trigger to revisit Alternative B as a second phase, not a reason to delay Phase 1.

**Strongest objection to this recommendation, stated plainly:** if callers today are largely
anonymous (unconfirmed) and the abuse pattern is IP-rotating rather than a small set of
identifiable clients, usage-plan throttling contributes little and the WAF rate rule becomes the
entire mitigation — in which case Alternative A's "native throttling" pitch is weaker than it
looks, and the real ask is closer to "configure WAF," with API Gateway offering less marginal
value. The team should be prepared to weight the decision toward B if the confirmed traffic
pattern (task 1 below) shows this.

## Launch strategy

**Phase 1 — stop the bleeding (ship first):**
1. Confirm current exposure topology and traffic baseline (see *Tasks*, item 1) — this determines
   whether Alternative A is a same-day config change or a routing migration.
2. Enable AWS API Gateway usage-plan throttling in front of `public-search-api` with a
   provisional, conservative limit derived from the real baseline (not the placeholder numbers in
   this draft).
3. Add an AWS WAF rate-based rule for unauthenticated/IP-identified traffic to close the anonymous
   gap called out in the tradeoff table.
4. Stand up per-client allow/deny dashboards and an alert on sustained throttling before declaring
   Phase 1 done — without this, there is no way to tell if the limits are protecting the service or
   quietly breaking legitimate clients.

**Phase 2 — validate and tune:** watch the dashboards from Phase 1 against real traffic for a
defined window (proposed: two weeks) and adjust limits; confirm whether abuse recurs and whether
it's now contained at the edge.

**Phase 3 — optional, not scheduled:** revisit whether a Redis-backed, cost-weighted limiter
(Alternative B) is needed for specific expensive endpoints, only if Phase 2 data shows usage-plan
granularity is insufficient. This is explicitly not part of the initial rollout, to avoid the
"eternal migration" trap of trying to solve both mechanisms at once.

## Tasks and roadmap

| Task | Description | Estimate |
| --- | --- | --- |
| Confirm current topology & traffic baseline | Determine whether `public-search-api` sits behind API Gateway, ALB, or ingress today; pull sustained/peak request-rate and existing latency figures | 0.5–1d |
| Confirm caller identity model | Determine whether callers present an API key today or are anonymous; needed to size the WAF-vs-usage-plan split | 0.5d |
| Configure API Gateway usage plan(s) | Per-client (or default) limit + burst, tied to API keys where present | 1–2d |
| Configure WAF rate-based rule | IP-keyed rate rule for anonymous traffic | 1d |
| Observability | Per-client allow/deny metrics, dashboard, sustained-throttling alert | 1–2d |
| Canary + cutover (if topology requires inserting API Gateway) | Weighted routing, rollback path kept live | 1–3d (only if applicable) |
| Phase 2 tuning window | Monitor real traffic against configured limits, adjust | 2 weeks (calendar, not effort) |

## Version history

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | 2026-09-08 | Lucas Marques | Document created for architecture-meeting review. |
