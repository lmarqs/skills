# What I'd say back in chat

The RFC is in `document.md`, ready for the meeting — but with **status `proposed`**, deliberately, and
with a recommendation that rejects both options you put on the table for the first phase. Here is what
changed and why, so you can push back before the meeting rather than during it.

## The short version of the recommendation

Enforce at the edge with AWS WAF rate-based rules on whatever CloudFront distribution or Application
Load Balancer already fronts the service: count-only for seven days, then block with a 429 and a
`Retry-After`. Add an *optional* credential tier. Keep an off-the-shelf rate-limit service with Redis in
reserve for the day something needs exact per-key limits or calendar quotas. Days of work, no code, no
new datastore, no new hop, and refused traffic never reaches your pods.

## I challenged the framing, and both your options lost the first phase

**"AWS API Gateway's native throttling" does not do what the name suggests.** Stage- and method-level
throttling is a *single shared token bucket for all callers*. An abuser empties it and every legitimate
searcher gets 429 — the control converts a rate problem into an outage. Per-*client* throttling in API
Gateway exists only through usage plans plus API keys, which a public unauthenticated endpoint has none
of; and the account-level throttle (10,000 rps / 5,000 burst by default) is shared across every HTTP,
REST and WebSocket API in the account per Region, so a flood here could throttle unrelated APIs. It is
also the most expensive option per request, at USD 3.50/million for REST APIs.

**"Our own middleware with Redis" decides too late and buys precision nothing asks for.** Middleware in
the pod decides *after* the request has crossed the load balancer, taken an ingress connection, been
routed to a pod, and taken a worker and a connection from the pool — under exactly the load the control
exists to survive. And when I wrote out the requirements, none of them asked for an *exact* limit. Exact
counts matter when a limit is a billed or contracted quota; that is the whole value of shared counters,
and today it buys nothing. If you do build this eventually, buy it rather than write it: a distributed
rate limiter has well-known failure modes (window-boundary bursts, read/increment races, hot keys, a
counter-store pool that exhausts under the load it polices) and the off-the-shelf ingress version is a
solved problem.

**Five options nobody proposed are in the table**, each stated at its best: WAF rate-based rules at the
edge (the recommendation), per-replica local counters (adopted, but only as a backstop — the effective
limit is replicas × configured, so it is not a number you can publish), a mandatory API key for all
callers (rejected: it breaks every current caller, and a key in a browser bundle identifies without
authenticating), edge caching so the rate stops mattering (measure the repeated-query share first; on
high-cardinality search traffic it probably bounds nothing), and buying a managed CDN/API-management
product (out of proportion to the timeline). Plus the required baseline: do nothing.

## The bigger reframe: this is two decisions with opposite reversibility

The hard-to-undo part is the **client-visible contract** — which identity gets limited, what a refused
caller receives, and whether a credential ever becomes mandatory. Once external callers depend on being
anonymous or on a published limit, you cannot tighten either without breaking them.

The part you asked about — where the check runs, what holds the counters — is a **two-way door**. It is
a config and deploy change, invisible to a well-behaved client. So the RFC spends its requirements on
the contract and treats the enforcement point as the cheaper choice it is.

## What I reclassified

Nothing in your message was a requirement as stated:

- *"AWS API Gateway's native throttling"* and *"our own middleware with Redis"* → design choices. Both
  are rows in the tradeoff table.
- *"Rate limiting"* itself → a mechanism. The requirements underneath are: one caller cannot degrade
  the endpoint for others (N3), an operator can attribute traffic to a caller (F1) and refuse one
  without a deploy (F2), and a refused caller is told enough to back off (F4).
- *"No controls at all"* and *"a few abuse scares"* → Context.
- *"Our Kubernetes cluster"* and *"AWS"* → prior decisions, not constraints. Each has an incumbent with
  a row and an alternative beside it, so neither excludes an option. The Kubernetes prior decision is
  what makes the edge-versus-ingress comparison explicit rather than assumed.
- *"The API is public and unauthenticated"* → a prior decision somebody inside the org made. It is the
  reason source address is the only identity available, and its alternative (mandatory keys) is in the
  table.

## The uncomfortable part: the Context has no numbers in it

I had no codebase, no logs, no dashboards. So **every internal fact in the document is labelled
*assumed* with your name on it and the instrument that would confirm it** — including that the endpoint
has no controls, that the scares happened, and that it runs on the cluster. There are no invented
figures anywhere.

The external facts *are* verified against AWS documentation, read 2026-09-08, and cited inline: WAF's
attachable resource types, evaluation windows (60/120/300/600 s), minimum rate limit of 10, the
detection-lag caveat, custom-response status codes including 429, WAF pricing (USD 5/web ACL + USD
1/rule + USD 0.60/million), API Gateway's throttling levels and quotas, and both pricing models.

Consequently **Phase 0 is two days of reading logs, not building anything**, and requirement F1
(attribution) comes before enforcement. A threshold guessed from no data refuses real users, which is a
worse incident than the one you are preventing, because you cause it deliberately and at scale.

## Three blocking questions — the status cannot move to accepted until they close

I would have asked these one at a time with my recommended answer attached. Since this was one-shot,
they are in the document with owners and dates:

1. **B1 — What sits directly in front of `public-search-api`: CloudFront, an ALB, an existing API
   Gateway, or a Network Load Balancer?** *This is a five-minute check and it changes the plan.* A WAF
   web ACL attaches to CloudFront, ALB, API Gateway REST API, AppSync, Cognito, App Runner, Bedrock
   AgentCore Gateway, Verified Access and Amplify — and to nothing else, NLB included. If it is an NLB
   or a bare Service, Phase 1 stops being a two-day config change and roughly triples in effort.
   *My guess: an ALB-backed ingress, so the recommendation holds. Please confirm before the meeting.*
2. **B2 — Is legitimate traffic separable by source address?** Contracted as a proof of concept: over
   one week of logs, does a threshold *T* exist where under 0.1% of first-party-marked requests would
   be refused and at least 80% of the three largest bursts would be? If it fails (legitimate traffic
   concentrated behind carrier NAT or a corporate proxy), per-address limiting cannot be the primary
   control and the credential work moves ahead of enforcement.
3. **B3 — Does any signed third-party agreement promise a caller a rate, an availability level, or
   continued unauthenticated access?** If yes, that clause is a real external constraint, F5 becomes
   urgent rather than preparatory, and API Gateway usage plans become a genuine contender for that one
   dimension — they are the only option in the table with real calendar quotas. *My guess: no such
   agreement exists, which is why the RFC recommends what it does.*

## Assumptions you should read and correct

- The abuse episodes have not yet caused a user-facing outage (your word "scares"). **If they have, two
  drivers swap priority** and a cruder control shipped faster becomes the right answer. This is the
  assumption most likely to change the recommendation.
- Redis is already something the team runs and knows.
- AWS Shield Standard's baseline network/transport-layer protection is in place, so this decision is
  about application-layer per-caller volume only.
- No managed CDN or API-management product is already in use elsewhere in the org. If one is, the "buy"
  option gets much cheaper and deserves a second look.
- Volumes in the cost table (10M / 100M / 1,000M requests per month) are illustrative, labelled as
  such, and exist so the cost driver can be settled before Phase 0 delivers the real number.
- **B4, non-blocking:** which data-protection instrument governs this traffic and what retention it
  allows for IP-keyed counters and logs. Both GDPR and LGPD treat an IP address as personal data. This
  changes how logs are stored (raw address or salted hash, 30 days or 90), not which option wins — so
  it does not hold the status.

## Two caveats about the recommendation itself

- **The edge control is approximate by design.** A burst can run for up to several minutes before WAF
  reacts (usually under 30 seconds), and changing a rule's settings resets its counters, pausing
  limiting for up to a minute. Inside those windows abuse is *recorded*, not prevented. That is the
  trade for shipping in days with nothing new on your request path.
- **429 headers from the edge are static.** WAF custom response headers carry fixed values, so
  `Retry-After: 60` works but a per-request remaining-count header does not. F4 is scored *partial* for
  that reason rather than talked around. A caller that needs live remaining counts needs the decision
  made where the request is served — which is the deferred Redis phase.

## One deliberate deviation from the method

Requirement F4 names HTTP 429 and `Retry-After` explicitly, which normally would be a mechanism leaking
into a requirement. I left it there on purpose: the refusal contract is the one-way door in this
decision, and a requirement phrased as "the caller learns it should back off" would let the design pick
something non-standard that we could then never change. If you disagree, the fix is to move the status
code into Design and keep the behaviour in F4.

## Where your Redis idea ended up

Not discarded — **deferred to Phase 3 and changed from bespoke to off-the-shelf at the ingress**, to be
started only when a requirement names a caller that needs an exact limit or a calendar quota. If B3
turns up contracted partners, that phase may arrive sooner than the RFC assumes.
