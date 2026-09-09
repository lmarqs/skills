# Reply

**Recommendation: Fargate + Aurora Serverless v2 (Postgres with PostGIS + pg_trgm), in Go** — but do not
start building until legal answers, and ask the vendor for a better price this week while you wait.

RFC is in `document.md`. The reasoning in one pass:

- **DynamoDB is out on capability, not cost.** Fuzzy free-text address matching and nearest-neighbour
  reverse geocoding are the two requirements that shape this system, and DynamoDB does neither as a
  query engine. The workarounds are hand-rolled geohash fan-out plus, realistically, an OpenSearch
  cluster — which costs more than the whole Aurora option and adds a second store to sync. That kills
  both Lambda + DynamoDB and the fourth combination you didn't list (Fargate + DynamoDB).
- **Lambda is out on the tail, and the argument is the inverse of the intuitive one.** Serverless is
  usually justified by low spiky traffic, which is what you appear to have. But at low average volume
  nothing keeps a warm pool alive, while autocomplete fires bursts of *concurrent* requests that each
  need their own execution environment — so cold starts land inside p95, not out in p99. Lambda's
  unstable execution environment also neuters the in-process cache, which is the biggest latency lever
  available. Provisioned Concurrency fixes it by paying for always-warm capacity, at which point you
  have Fargate's cost with Lambda's constraints.
- **Cost doesn't discriminate — and that reframes the project.** All three options land in the low
  hundreds of dollars a month against a $4k bill. The real cost of building is ~6–8 engineer-weeks plus
  a permanent maintenance tax (dataset refreshes, quality, normalization) that the vendor currently
  absorbs. So I optimised for *least novel code*, not cheapest stack — and PostGIS KNN + pg_trgm are
  mature answers to your two hard requirements that you don't have to write, test, or debug.

## Two reclassifications

1. **Go isn't a decision — all three of your options were "in Go", so it was already settled.** I moved
   it out of the tradeoff table into a "Constraints already settled" section, with the reasoning for
   why it's a good fit recorded anyway so it doesn't become a mystery later. Nothing in the analysis
   pushes back on it. Tell me if it's actually still open; it wouldn't change the recommendation, but
   it would add a dimension to analyse.
2. **The legal caveat is not a caveat — it's the gate.** A geocoding service with no data it's allowed
   to serve has no reason to exist, and it's the only failure mode here that writes off the whole
   project. So I promoted it to a hard requirement (N6: nothing serves production traffic from a
   dataset without written commercial-use clearance) and a blocking Phase 0. It's also cheap to close:
   a written opinion on a *specific named dataset release and licence version*, not "postcode data" in
   general. "Public" and "licensed for commercial use" are different things — some national postcode
   products are licensed precisely to prevent this substitution, and share-alike or attribution terms
   can carry obligations of their own.

## Things I added that you didn't ask for

- **Data sourcing as a third decision dimension** (open dataset / licensed bulk dataset / stay with the
  vendor). Your three options only covered compute and storage, but the sourcing question can
  invalidate both. Good news: the architecture is dataset-agnostic, so if legal says no, only the
  loader and the cost model change — not the service.
- **Ask the vendor for a revised quote in Phase 0.** It's free, it's parallel, and a costed in-house
  plan is the strongest negotiating leverage you'll ever have. If they discount enough, the right
  outcome of this RFC is *don't build* — and the document says so explicitly.
- **A 2–3 day latency spike before any build work**, as a go/no-go on the 100 ms target. Load the real
  dataset, replay the real query mix, measure p95 per endpoint. It de-risks the one requirement that
  could invalidate the design, and it also measures whether the dataset fits in memory (which keeps the
  faster fallback alive).
- **p99 ≤ 250 ms alongside your p95 ≤ 100 ms.** A p95-only target is gameable by an architecture with a
  bad tail — which is exactly the failure mode Lambda has here.
- **A quality-parity requirement.** Public data can be staler and sparser than what you're paying for.
  The failure mode is silent and customer-facing (a slightly wrong address), so the rollout runs in
  shadow mode against the vendor and diffs the answers before any traffic moves.

## Open questions

The first two can change the answer:

1. **Which capabilities are actually in scope?** Postcode lookup only, or also free-text autocomplete
   and reverse geocoding? **If it's exact postcode lookup only, my recommendation flips** — DynamoDB (or
   no database at all) becomes the right answer, because the two requirements that eliminate it
   disappear. This is the single most valuable thing you can tell me.
2. **What's the real request volume and endpoint mix?** I inferred ~1M requests/month by dividing $4,000
   by assumed commodity geocoding list rates of $4–5 per 1,000. That's unverified and it's wrong
   entirely if the $4k is a flat enterprise licence. It drives both the cost model and the cold-start
   analysis.
3. **Is the 100 ms p95 server-side or client-observed?** I assumed server-side at the service boundary.
   If it's client-observed, none of the three options is sufficient on its own and the answer becomes
   edge caching in front of whichever compute you pick.
4. **One country or several?** Multi-country multiplies the licensing surface (one clearance per
   dataset) and roughly doubles the effort estimate.
5. **Who owns the legal question and when does the written opinion land?** Which publisher, which
   dataset, which licence version?
6. **What quality-parity threshold makes the cutover acceptable?** That's a product-owner call, not an
   engineering one, and I left it as a blocking input rather than picking a number.
7. **Has the vendor been asked for a better price yet?**

## Assumptions and caveats

- **All cost figures are unverified order-of-magnitude estimates** from AWS us-east-1 list prices as I
  recall them (≈$170/month for the recommended stack). I had no pricing calculator access and no
  invoice. The *conclusion* they support — that infra cost is two orders of magnitude below the $4k
  bill and therefore doesn't discriminate between the options — survives being wrong by several
  multiples, which is the only reason I used them. Re-run them properly before approval; it's a task in
  the roadmap.
- **The 6–8 engineer-week estimate is a guess** made with no sight of your codebase, the dataset, or
  the team's Go and PostGIS experience. Treat it as a shape, not a commitment. It is, however, the
  number the business case actually turns on — not the infrastructure bill.
- **I assumed the dataset is read-only, refreshed monthly or quarterly, and small enough to fit in a
  container's memory.** The last one is unverified and is what keeps the faster in-process-index option
  viable as a fallback.
- **I recorded but did not resolve the strongest objection to my own pick:** for a read-only dataset
  this small, keeping a database in the request path isn't obviously necessary. An in-process index
  would be faster, cheaper, and would remove the store from the availability chain. I still chose
  Aurora first because it buys mature PostGIS ranking instead of spatial-index code we'd own, and
  because it doesn't stake the design on the unverified memory assumption. The in-process index is
  written up as the documented Phase 2 escape hatch, and the design's in-process cache is deliberately
  the first step toward it — moving further costs no interface change.
- **Nothing in the document is legal advice**, and it doesn't attempt to guess how the licence question
  resolves.
- I also flagged, but didn't act on, one oddity: **Aurora Serverless v2's headline feature is largely
  wasted here.** Scale-to-zero has a resume latency in seconds, incompatible with 100 ms p95, so the
  cluster sits at minimum capacity 24/7 — you're paying for a small provisioned instance with an
  autoscaling feature you can't use. A right-sized provisioned Postgres may be cheaper and more
  predictable. It's in the tradeoff table as an unoffered alternative; it's a billing-model choice, not
  an architecture change, so it can be settled after the volume numbers land.
