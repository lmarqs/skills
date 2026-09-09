# Reply (what I would have said in chat alongside the document)

Draft RFC is in `document.md`. Read the decision first (**A2 + B1 + C3 + D1**), then the *Strongest
objection* and *Assumptions and open questions* sections — that is where the document is weakest and
where your input changes it.

## Shape of the document

Forward-looking RFC, not a retrospective ADR: you are choosing before building, so the weight sits in
the tradeoff analysis and the recorded decision. If it turns out a pipeline already exists and you are
documenting it after the fact, tell me — the shape changes (context becomes prior situation →
motivations → scope, and it gains a lessons-learned section instead of a launch strategy).

Four dimensions were decided, each with 3–4 credible alternatives:

- **A. Response mode** → accept-then-process (validate + persist synchronously, `202`, fan out after).
- **B. Deduplication** → unique constraint on `(partner_id, event_id)` with on-conflict-do-nothing,
  plus a payload hash to catch `event_id` reuse.
- **C. Fan-out** → transactional outbox + relay → one topic → three independent durable subscriptions.
- **D. Partner auth** → per-partner HMAC signature over timestamp + body, two live keys for rotation;
  mTLS offered additively.

## Diagrams

Three diagrams, all embedded in the page as Mermaid code blocks — no external links, nothing to open:
a static component diagram, a happy-path/duplicate sequence, and a consumer-failure/recovery sequence.

**Caveat you need to check:** this assumes your wiki renders Mermaid. Many do; some do not, and some
render only in the newer syntax. As insurance, the static diagram is followed by an ASCII box drawing
and each sequence diagram by a numbered step list, so the page carries its full meaning even with no
rendering at all. If your wiki renders neither, tell me which format it does accept (PlantUML,
Graphviz, an image upload) and I will convert. I could not verify how your wiki renders anything.

## Vendor neutrality — a reclassification you should know about

You did not name a cloud, a database, or a broker, so I deliberately did **not** pick products.
Components are specified as capabilities, with a *Vendor mapping* table listing implementations that
satisfy each one. Product selection is recorded as a smaller, more reversible follow-up decision rather
than being smuggled into this document.

One hard constraint survives that neutrality: **the outbox must be able to commit in the same
transaction as the event store.** If your platform cannot do that, the no-loss guarantee is unavailable
and Dimension C has to be re-decided — it is listed under *What would flip this decision*.

## The 200 events/s figure

I used your number and derived everything from it, showing the arithmetic so you can recheck it:
17.28M events/day, a 400 events/s design target at 2× headroom, 800 writes/s including the outbox,
1,200 fan-out deliveries/s. I could not verify the measurement itself or its averaging window, so it is
recorded as Assumption **A1**.

Worth saying plainly: **200 events/s justifies none of this design.** A single modest database node
handles the write rate. The outbox, the topic and the three subscriptions are buying failure isolation
and a no-loss guarantee, not throughput. If those are not what you want, the design should be much
smaller — see the objection section, which argues for the simpler consumers-poll-the-store option and
names the conditions under which I would switch to it.

## Questions I would have asked (recorded as Q1–Q6 in the document)

1. **Q2 — who are the three consumers, and what does each actually need?** Full payload or a
   notification? Freshness? Ordering? Replay depth? This is the biggest gap; the answers could collapse
   the fan-out design or complicate it materially.
2. **Q1 — does an ingestion path already exist for any partner?** If yes, the document needs a migration
   and decommissioning section, and its *Out of scope* is wrong.
3. **Q6 — do we already run an internal event bus, or change-data-capture off the store?** Either would
   pre-decide most of Dimension C, and CDC would let me delete the outbox and the relay entirely.
4. **Q4 — do payloads contain personal or regulated data?** If so, retention, the replay tool, the
   dead-letter queues and logging all pick up requirements this draft does not cover.
5. **Q3 — how many partners, and how skewed is their traffic?** Drives per-partner rate limits and
   whether one partner can starve the others.
6. **Q5 — must a partner be able to look up the status of an event they sent?** The `202` contract
   implies a receipt lookup that I have not designed.

## Assumptions I had to make (A1–A10 in the document, with who confirms each)

The ones that would actually change the design, in order of risk:

- **A8 — no consumer needs strict per-key or global ordering.** Highest-risk assumption in the document.
  If any consumer needs ordering, the relay must publish with a partition key, the subscriptions must
  preserve per-key order, and dead-lettering can no longer skip a failing message.
- **A2 — average payload ≈4 KB.** Pure guess, and it drives all storage sizing: ≈69 GB/day and ≈2.07 TB
  over 30 days at 4 KB; ≈20.7 TB at 40 KB. Replace this with a measurement before anyone starts.
- **A5 — a relational-class store with transactional unique constraints, and a broker with independent
  per-consumer cursors, are both available to us.**
- **A3 / A4 / A6 / A7** — ingest p95 ≤ 150 ms, 99.9% availability, 30-day replayable retention, ≤ 5 s
  fan-out freshness. All invented targets. Each is checkable and each is attributed in the document.
- **A9 — this is your call to make** (recorded as an autocratic decision), with the consumer teams
  holding a veto on exactly one clause: the at-least-once delivery contract, because it obliges them to
  be idempotent. Correct that if your approval process differs.

## Before implementation starts

Three cheap measurements, any of which can invalidate part of the design — all of them worth doing
before code, not during:

1. Re-derive the load numbers from the source of the 200 events/s measurement, and get **real payload
   sizes** (≈1 day against existing logs; highest value per hour of anything in the document).
2. Measure the **actual duplicate rate**, and specifically whether any partner reuses an `event_id` for
   a different event — that is the one failure mode in this design that loses data silently.
3. Load test at 2× peak (400 events/s, 800 writes/s) plus a 24 h soak with one consumer stopped, to
   prove isolation and replay.

## Other caveats

- Task estimates are engineering-days for one engineer, judgement not measurement, and they assume the
  platform capabilities in A5 already exist. Add lines if anything must be provisioned from scratch.
- I invented no facts about your organisation: team names, existing services, partner names and any
  prior pipeline are all absent by design rather than guessed. Fill them in as you review.
