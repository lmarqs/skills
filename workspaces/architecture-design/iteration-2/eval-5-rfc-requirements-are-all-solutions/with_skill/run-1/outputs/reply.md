# Reply

The RFC is written, but it does not say what you asked it to say, so here is the short version before
you open it.

**None of your five items is a requirement.** All five are design choices — ways of meeting a
requirement — and I could not find the requirement underneath four of them. The two facts you gave me
that are not solutions are the whole basis of the document: checkout fails in ~2% of attempts, and when
it fails nobody can tell which step broke. The second one is the reason the first one is still open.
Every candidate fix in your list is a guess about which step is failing, and none of them can be
evaluated until the failing step is knowable.

**So the document decides one thing and defers the rest**: instrument the existing checkout path (step
boundary wrapper, a persisted attempt ledger with per-step outcomes and side-effect flags, one config
kill switch, 90-day retention), then decide the shape of checkout in a second RFC six weeks later,
against the actual failure distribution. That is a deliberate two-way door taken to avoid four one-way
doors — service boundaries, a consistency model, a published inter-service contract, and a third-party
dependency in the revenue path — none of which the current evidence can justify.

## What I reclassified

| You said | It actually is | Where it went |
| --- | --- | --- |
| Use the saga pattern | A coordination pattern | Tradeoff row `[Consistency]`. Deferred. The requirement it serves (G3, no money-without-goods) has an unverified premise — see Q1 |
| Split into microservices | A topology | Tradeoff row `[Topology]`. Deferred. It records nothing by itself, so it answers none of the requirements in this document |
| Add Redis caching | A technology | Tradeoff row `[Caching]`. **Rejected.** No latency or load problem was reported or measured, so it answers no requirement at all — and a stale price or stale stock in checkout creates failures, working against the goal |
| Use gRPC between services | A transport and a contract format | Tradeoff row `[Transport]`. Deferred, and conditional: it only exists if the split happens |
| Introduce a feature flag system | Part design choice, part delivery practice | The capability under it became requirement **F3** (revert the checkout path without a deploy), met by one config switch. The platform-sized version is tradeoff row `[Rollout]`, not adopted |

I also added one option nobody proposed on each side of the argument, so the recommendation had to beat
something real: a hosted APM with distributed tracing instead of the ledger (it loses on sampling and
because an agent cannot know whether money moved), and idempotency keys plus a reconciliation job
instead of the saga (it is strictly cheaper and does not presuppose the split).

## What I challenged

- **The framing.** "Requirements for the checkout refactor" presupposes that a refactor is the answer.
  The evidence you gave supports one conclusion — that you cannot see the flow — and does not indicate
  where the flow is wrong.
- **The 2%.** It arrived with no board, query or date, so it is labelled *assumed* throughout, with you
  as its origin. I did not upgrade it, and the first phase-0 task replaces it with a measured number.
- **The absence of a consistency problem.** The saga is the only one of your five with a plausible
  requirement behind it, and nothing in the request says inconsistent checkouts actually happen. That is
  the first blocking question.

## Two additions of mine, so you can argue with them

- **F2, the side-effect flags** (payment authorized, payment captured, stock reserved, order created,
  per step). It serves the support agent and whoever reconciles payments against orders, and it is the
  largest single piece of work in the design. It is also the reason a hosted APM does not win: an agent
  sees a call, not whether money moved.
- **N2, the guardrail** (the failure rate must not rise, p95 must not rise by more than 30 ms). It
  serves the customer. We are touching the revenue path for a diagnostic reason, so the guardrail is a
  requirement rather than a note, and F3's switch is its response.

## Questions I would have asked, and did not

You asked for the document in one go, so I stated the assumptions inline instead of stopping. These are
the checkpoints I would have used, in order, with my recommended answer attached.

**After the requirements (the one that matters most):** do you accept the reclassification, or do you
want any of the five treated as already decided? My recommendation: accept it. If you reaffirm an item,
it becomes a prior decision authored by you, the document records it as such, and its tradeoff row gets
re-run with your reason in it — that is a legitimate outcome, but it should be visible rather than
absorbed silently into the design.

**After the tradeoff table:** is driver 1 (nothing is evaluable until the failing step is knowable)
really the veto criterion, or is there a delivery deadline that makes six weeks of phase 0 impossible?
My recommendation: it is the veto. If a deadline exists, tell me the date and I will re-run the table
with time-to-market promoted, which would likely favour the hosted-APM row despite its sampling
weakness.

Three blocking questions in the document are cheap lookups that any of us could do in a day, and the
status stays *proposed* until they are answered:

- **Q1.** Do failed checkouts leave inconsistent outcomes today — money captured with no order, or
  stock reserved with no payment? Sample the last 50 failures by hand. If no: the saga loses the only
  requirement it answers. If yes: G3 is live and the compensation options stay on the table.
- **Q2.** Checkout attempt volume, terminal-outcome breakdown, and the value of a completed checkout.
  One query plus one figure from finance. Without it the 2% stays hearsay and there is no way to size
  what any of this is worth.
- **Q3.** Does checkout handle cardholder data inside the application? If yes, the payment-card standard
  governs what a step record may contain (outcome codes only, no payloads), and a constraint row appears.

## Assumptions you should know I made

- The checkout path is one synchronous request path inside the existing application. Your "split into
  microservices" only makes sense against a non-split incumbent. Reading the checkout entry point
  confirms it.
- No distributed tracing or step-level metrics exist today. If an APM agent is already deployed, the buy
  option gets much cheaper and may beat my recommendation.
- Checkout latency is fine. Nothing in the request said otherwise, and this is what removes the caching
  row's only possible requirement.
- The step list in the diagrams (validate cart, authorize payment, and so on) is generic and invented as
  a placeholder. The real list is phase 0's first task, and the diagrams are redrawn from it. Nothing in
  the decision depends on the specific steps, only on there being an enumerated set.
- The failures are concentrated in a few steps rather than spread evenly. That is the usual shape and it
  is what makes the phased approach pay. If they are spread evenly, the second RFC starts from a harder
  position and this document should be revisited.
- Team size is unknown; I assumed small, since one person is asking for a five-part refactor.

## Caveats

I had no codebase, schema, dashboard, incident record or ticket. The method behind this document expects
the numbers in Context to be looked up rather than asked for, so everything about the current state is
labelled *assumed* with the lookup that would settle it, and the Sources section says so explicitly
rather than looking respectable. The phase-0 tasks exist to convert those labels into measured numbers,
and they are the first week of work.

The document's weakest section is the requirements' derivation: N2's 30 ms tolerance and N3's 15 minutes
are commitments rather than deltas from a measured value, because there is no measured value to delta
from. Both are flagged *assumed* and both get measured before they are treated as met.

And the counter-case, since I would rather state it than have you find it: if the taxonomy comes back
showing the failures concentrated in one step whose fix is obviously a service boundary, this plan will
have cost four to six weeks that going straight at it would have saved. I took the bet anyway, because
the alternative bet is that a five-part refactor chosen blind lands on the right four to six weeks, and
that has both a worse expected value and a much worse downside.
