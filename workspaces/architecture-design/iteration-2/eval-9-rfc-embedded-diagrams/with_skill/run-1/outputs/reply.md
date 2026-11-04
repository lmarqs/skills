Written as a forward-looking RFC, status *proposed*, with four Mermaid diagrams embedded in the page —
nothing in the argument requires opening a link, and the *Sources* section is provenance only. If your
wiki does not render Mermaid, export each figure as an image into the page and keep the Mermaid source
in the document as the editable original.

**Sizing:** mixed reversibility, and it changes where the effort went. The partner-facing contract
(response classes, whether an event identifier is mandatory, what "accepted" promises) and the retained
payload are one-way doors, so they carry most of the evidence and the alternatives. The fan-out
mechanism and where semantic validation runs are two-way doors and are argued more briefly.

## What I reclassified

- **"Partners post events to us"** → a prior decision about the integration model, not a requirement.
  Its incumbent (HTTP push) has a row in the tradeoff table, and the pull inversion sits beside it.
- **"Validate, deduplicate, persist, fan out"** → mechanisms. The requirements underneath are what a
  role can observe: a definitive answer (F1), one persisted event and one delivery per consumer however
  many times it is sent (F2), catch-up without a partner resend (F3), consumer isolation (F4).
- **"Three internal consumers"** → a count in Context, not a requirement. The requirement is
  independent progress per consumer, which is what keeps the number three out of the design; a fourth
  consumer is a fourth read position.
- **"Include the diagrams; the team will not open external links"** → an attribute of this document's
  readers. It is in the stakeholder table and it is why every figure is embedded.
- **"About 200 events/s at peak, measured last month"** → Context evidence, and the load condition in
  N1, N4 and N6 after doubling.
- **"Keep it in this order"** (implicit in the phrasing) → treated as a hypothesis and argued with; see
  below.

## What I challenged

**The pipeline order.** Deduplicating before persisting is a check-then-write: two operations with a
gap, and two copies of the same event arriving inside that gap both pass the check. I made
deduplication a property of the persistence write instead — a uniqueness constraint on
(partner, event identity) in the same insert — so a conflicting insert *is* the duplicate. An expiring
cache check survives only in front of that constraint, as a cost optimization, never as the authority.
This is recorded as a stakeholder conflict in the Decision, since the order was yours.

**The option space.** Push-and-build was the only shape in the request. I added a managed
ingestion/relay product for the edge and inverting the transport (we pull from partner APIs, which
removes duplicate delivery at the root rather than mitigating it), plus a baseline row for leaving the
current path alone. The relay row is not a throwaway: if the owning team is smaller than about three
engineers, it wins the edge on operational load, and the document says so under *What would flip the
recommendation*.

**The 200 events/s figure.** Recorded as *measured by report*, not *measured*: the instrument and the
averaging window were not named, and whether it is a one-second peak or a five-minute average changes
the burst the edge must absorb by a factor I cannot state. Reading the instrument closes this in
minutes and is the first item under *Confirmation*.

## What I added that you did not ask for

**F7, partner attribution** — a partner cannot create an event attributed to another partner. It is a
security boundary, therefore a one-way door, therefore a requirement rather than a design detail. It
serves the partners whose data could be forged and the security function, under goal G5. No objection
of yours is on record because the question was never put; if you decline it, that refusal belongs in
the Decision's stakeholder conflicts next to the roles that lose by it.

## Questions I would have asked, with my recommended answers

Three are blocking: any answer changes the decision, so the status stays *proposed* until they close.

1. **Does any of the three consumers need events in a strict order, and ordered by which key?** My
   recommendation: assume at least one needs per-entity order and verify it first, because the ordering
   key has to be extractable from the envelope at the edge, which makes it part of the contract you
   cannot change unilaterally later. If none does, the store-polling option gets cheaper than the log
   and removes a component class.
2. **Do partner payloads carry personal data, and what retention, erasure and encryption obligations
   follow?** My recommendation: assume yes until security says otherwise, since the design retains raw
   bodies for 7 days and replays from them; an erasure obligation inside the replay window is the one
   answer that reopens the store-of-record section.
3. **Is there an ingest path in production today carrying these 200 events/s, and is this replacing
   it?** My recommendation: assume yes, because the measurement implies traffic exists. If yes, phase 3
   of the launch strategy dual-runs and you get the latency baseline N1 is missing; if no, the 200/s
   figure needs a different provenance because it cannot have come from a path that does not exist.

## Assumptions I proceeded on

Every one is labelled in the document, with what would close it.

- **2× headroom** (design condition 400 events/s) because the measurement is a month old and no growth
  rate was given. Three months of monthly peaks replaces the factor with a trend.
- **2 KB average payload**, unmeasured. It drives every storage figure: 35.4 GB/day at the reported
  peak, 248 GB over a 7-day window, 496 GB at the doubled condition, and ≈7.7 GB of identity index for
  121 million identifiers. An hour of sampling at the edge closes it.
- **All three latency and lag targets are assumed**, not derived: N1's 250 ms p99 acceptance, N4's 60 s
  consumer lag, N7's 5 s status lookup. There is no measured baseline behind any of them, they are
  numbers to argue with, and they are what *Confirmation* measures first. The consumer teams have not
  agreed the 60 s.
- **7 days** for both replay retention and the deduplication window, one number governing both so
  anything a consumer can still replay is also still recognized as a duplicate. Derived from a
  three-day weekend plus two working days, not from any outage history.
- **At least one partner cannot supply a stable event identifier**, which is why identity is hybrid
  (partner identifier where there is one, canonical body hash where there is not). Confirming it per
  partner does not change the design, only which branch each partner is in — so this one is
  non-blocking. The hash branch has a real cost: two legitimately distinct identical bodies from one
  partner collapse into one event, invisibly. That is a named, published, shrinking list rather than a
  global property, and it is in the residual risks.
- **Partners drop their own copy once we answer "accepted"**, which is what makes N2's fail level one
  event rather than a percentage.
- **Team size and on-call coverage unknown**, so every operational-load comparison in the table is
  qualitative and none is decisive alone.

## Caveats

- **No codebase, dashboard, cost report, ticket or incident record was available.** Normally I would
  have read the instrument before quoting it. Every number in the document is either arithmetic on your
  one figure or labelled *assumed*, and the *Sources* section says exactly that rather than implying
  provenance it does not have.
- **No product is named.** The tradeoff table compares capability classes (durable intake buffer, store
  of record with a uniqueness constraint, ordered log with per-consumer positions) because I do not know
  what broker, store or runtime you already run and own. Choosing the product inside the chosen class is
  a task in the roadmap and a much cheaper decision than the class.
- **No external constraint is established.** Two candidates (a partner-contract response-time clause,
  data-protection obligations) are carried as candidates that exclude nothing until someone produces
  the clause — which is what blocking question 2 is for.
- **Placeholders where the request had no names:** the consumers are A, B and C; the decider is "owner
  of the partner-integration service" as a role; the blocking-question dates are one and two weeks out
  from today. Replace all of them before this goes on the wiki.
