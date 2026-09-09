RFC drafted at `document.md`, recommending **AWS API Gateway native throttling + a WAF rate-based
rule for anonymous traffic** as Phase 1, with the custom Redis middleware kept as an optional
Phase 3 if usage-plan granularity proves insufficient. Ready to bring to the architecture meeting,
but flagging what it's built on before you rely on it:

**I could not verify, and the recommendation is sensitive to these:**
1. **Whether `public-search-api` already sits behind AWS API Gateway** or is exposed directly
   (ALB/ingress). If it's already on API Gateway, Alternative A is a same-day config change; if
   not, it's a routing migration with its own (mitigated, but real) risk. I couldn't check
   `cloud-iac` or any infra config for this from where I'm running.
2. **Whether callers present an API key today or are anonymous.** This is the single biggest
   swing factor in the doc: usage-plan throttling only bites on identified clients, so if traffic
   is mostly anonymous, the WAF rule is doing most of the real work and API Gateway's marginal
   value is smaller than the pitch suggests. I flagged this explicitly as the "strongest
   objection" to my own recommendation in the decision section.
3. **No numbers on the actual abuse** (dates, volumes, which clients/endpoints) or on current
   traffic baseline/latency SLA. Every number in the doc (the ≤10ms overhead target, "two week"
   tuning window) is a placeholder, marked as such, meant to be replaced with real telemetry
   before limits are actually configured — I did not fabricate figures to make the doc look more
   precise than it is.

**What I pushed back on / reframed:** the request named exactly two alternatives (API Gateway vs.
Redis-on-K8s). I added a third — rate limiting at the existing ingress/mesh layer — specifically
to steelman the option space, then set it aside on its own merits (it doesn't solve the
global-counter problem any more cheaply than Redis would). It's in the doc for the meeting to see
the option was considered, not to reopen the two-way framing you asked for.

**Assumptions made to keep this unblocked** (all called out inline in the doc, not hidden):
- Caller identity is either an API key or falls back to source IP — no bigger identity/auth
  redesign is in scope.
- A conservative starting rate limit will be derived from real telemetry before Phase 1 ships,
  not from any number in this draft.
- The org already runs a Kubernetes cluster capable of hosting Redis if Alternative B is ever
  pursued (per the framing in your request).

Before the meeting, worth attaching: the incident/postmortem records for the abuse scares, current
traffic dashboards, and the service's ingress config — the doc names these as missing and the
recommendation should be re-checked once they're available, particularly point 2 above.
