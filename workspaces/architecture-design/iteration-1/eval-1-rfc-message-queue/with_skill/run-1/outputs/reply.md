RFC is written: `document.md`. Recommendation is **AWS SQS** (Standard + DLQ, FIFO only if
ordering is confirmed as a real need), with self-hosted RabbitMQ and Amazon MQ for RabbitMQ
analyzed and rejected — full tradeoff table with Impact/Probability/Mitigation/Contingency for
every risk is in the document. Verified the specific technical claims I made (SQS FIFO throughput
limits and high-throughput mode, RabbitMQ quorum-queue + publisher-confirm durability semantics,
Amazon MQ's cluster HA model) against current AWS/RabbitMQ docs rather than asserting them from
memory — sources are inline in the tradeoff table.

One thing I pushed back on: the framing treats "can't lose messages" and "supports complex routing
we might need later" as comparable considerations. They aren't — the first is a hard, checkable
requirement; the second is a speculative maybe with no named use case. I didn't let the maybe drive
the recommendation, and said so explicitly in the decision section, but if there's a concrete
routing need behind that phrase, it changes the answer and you should tell me.

I could not verify against your actual systems (this task explicitly has no access to them), so the
RFC is built on assumptions I've flagged both inline and in an "Open questions" section at the end.
The ones most likely to flip the recommendation if wrong:

- **"Existing cluster" = Kubernetes** — inferred from the phrasing, not confirmed. If it's ECS, VMs,
  or something else, the RabbitMQ operational-risk analysis needs redoing.
- **Order volume** — not given anywhere, so I assumed "moderate." This is the single number that
  would most sharpen this RFC (it decides SQS Standard vs. FIFO throughput ceilings and RabbitMQ
  cluster sizing).
- **Per-order ordering requirement** — I inferred you probably need order-of-emission processing
  per order (e.g. created-before-paid) but this wasn't stated; if some stages can safely process
  out of order, say so, since it changes queue configuration and throughput.
- **Team's existing RabbitMQ/Kubernetes operational experience** — unknown; this is the single
  biggest lever on how risky self-hosting actually is for this specific team versus in the
  abstract, and I couldn't weigh it either way without guessing.

I did not treat any of this as settled — the document states each as an assumption or open question
rather than a fact, per the instruction to flag rather than guess. Since I'm running unattended I
didn't stop to ask before finishing, but these are the questions I'd put to the team before this
RFC gets ratified.
