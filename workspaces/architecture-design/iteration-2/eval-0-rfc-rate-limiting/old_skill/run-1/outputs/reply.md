RFC drafted at `document.md`. **Recommendation: AWS WAF rate-based rules on the API Gateway stage as
the per-caller control, API Gateway stage/method throttling as the aggregate backstop, API keys +
usage plans for named integrators. Do not build the Redis middleware.**

## One reclassification you should know before the meeting

**The A-vs-B framing is mis-specified, and that reframes the discussion.** API Gateway's native
throttling has exactly four scopes — AWS Regional, per-account, per-API/stage/method, and per-client
*where the client is identified by an API key in a usage plan*. There is **no per-IP scope**. For a
mostly-anonymous public API that means "API Gateway native throttling" is not per-caller rate limiting
at all; it is an aggregate circuit breaker. Adopted on its own it would convert one abuser's burst into
a `429` for every legitimate user, while leaving us believing we were protected.

So the real comparison is not two options but at least five enforcement points. I added three the
framing omitted:

- **AWS WAF rate-based rules** — the managed option that actually does per-IP limiting, in front of the
  cluster, with a native count-only mode and an IP-set kill switch. This is the recommendation, and it
  was not on the table.
- **Ingress-local limiting** (NGINX `limit-req` / Envoy local) — cheap, but its effective limit is
  `limit × replicas` and moves with the HPA.
- **Envoy + the upstream `ratelimit` service** — the steelman of "our own middleware with Redis": same
  capabilities, proven implementation, none of the bespoke code. If we ever need exact per-caller
  semantics, this is the target, not something we write.

The deciding requirement turned out to be **where enforcement sits**: every in-cluster option (the
proposed Redis middleware included) rejects a request only after it has crossed the edge, the load
balancer and landed on a pod. It spares the database but not the system — we still pay for the attack.

## Questions I would have asked (they change the analysis, not just the wording)

1. **Is `public-search-api` behind an API Gateway REST API or an HTTP API (v2)?** This is the biggest
   one. **WAF cannot attach to an HTTP API.** If it is v2, the recommendation still stands but has to be
   enforced at a CloudFront distribution or an ALB in front, which adds a hop and a migration.
2. **What did the abuse scares actually look like — a handful of IPs, or thousands?** If it was already
   distributed, per-IP limiting of any flavour is the wrong tool and the answer is bot detection or
   identity. This is flip condition #1 in the doc.
3. **Real traffic numbers:** aggregate peak rps, and the per-source-IP distribution (p50/p99/p99.9).
   Every threshold in the document is deliberately left as a formula because of this gap.
4. **Who are the non-first-party consumers?** Any named integrators we can hand an API key to, and does
   any of them legitimately need high sustained throughput?
5. **Have we published or contractually promised anything about rate limits?** Affects whether Phase 1
   needs a notice period.
6. **Is there already an HA Redis someone owns?** It lowers option B's cost, though not its
   architectural problem.
7. **Where should the limit live long term — edge or CloudFront?** Moving the web ACL to CloudFront
   rejects further out and pairs with caching; I deferred it to Phase 3 rather than couple it to this
   decision.
8. **Who owns this control on-call, and what is the acceptable `429` rate on legitimate traffic?**
   Phase 1's exit criterion needs a number from a human.

## Assumptions I had to make (all labelled A1–A7 in the doc)

A1 mostly-anonymous public traffic · **A2 API Gateway REST API in `sa-east-1` routing to EKS** ·
**A3 low-hundreds rps peak, no legitimate client needing more than a few rps sustained** ·
**A4 concentrated rather than distributed abuse** · A5 no published rate-limit commitment · A6 no Redis
available today · A7 no need for exact per-caller accounting. A2, A3 and A4 are the ones that would
change the analysis if wrong; the doc says so in place.

## Caveats

- **Verified against AWS docs today** (links in the doc): the four API Gateway throttle scopes; the
  10,000 rps / 5,000-burst account default (2,500/1,250 in a listed set of Regions that excludes
  `sa-east-1`); WAF's supported targets (REST API yes, HTTP API no); rate-based rule windows
  60/120/300/600 s and minimum limit 10; AWS's own caveats that limiting is *"not intended for precise
  request-rate limiting"* and can lag *"up to several minutes"*; the aggregation-key list; WAF pricing
  ($5/web ACL, $1/rule, $0.60/M requests) and the 2 + 30-per-custom-key WCU cost.
- **Not verified, flagged in the doc:** whether `429` is on WAF's allowed custom-response status-code
  list (I could not load that page — if it is not, the fallback is `403` with a documented body, which
  weakens F4); whether an API-Gateway-attached WAF block still incurs the API Gateway request charge;
  ElastiCache pricing for the Redis crossover calculation.
- **WAF inspection latency is deliberately left unquantified.** AWS publishes no figure and I refused to
  invent one — instead Phase 0's Count mode is set up to *measure* it, since count mode pays the full
  inspection cost at zero enforcement risk. N1 is written as a gate on that measurement.
- **No codebase or traffic data was inspected.** Every threshold is a formula plus a rule for deriving
  it from the Phase 0 baseline, not a number. If someone wants numbers in the doc before the meeting,
  point me at the traffic dashboard and I will fill them in.
- **The honest weakness of the recommendation is in the doc, not buried:** per-IP limiting punishes
  CGNAT users and is defeated by proxy rotation. I wrote the strongest version of that objection into
  §The decision along with five explicit conditions that would flip us to Envoy + global rate-limit
  service, so a reversal later is a planned move rather than a rewrite.
