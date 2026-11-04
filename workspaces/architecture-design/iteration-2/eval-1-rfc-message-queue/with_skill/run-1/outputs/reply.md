The RFC is written, status **proposed**, and it does not land where the question pointed. Short version:
**the "can't lose messages" requirement is not won or lost at the broker**, so the SQS-versus-RabbitMQ
comparison is not the decision that matters. My recommendation is SQS, but the reasoning that gets
there is mostly about the handoff, and one open question could reverse it.

## What I changed about the question

You framed it as SQS versus self-hosted RabbitMQ. I treated that as your current view of the option
space rather than its boundary, and added two options:

- **Managed RabbitMQ (Amazon MQ for RabbitMQ)**, because it dissolves the tradeoff you described: full
  AMQP routing *and* someone else operating replication and failover. If routing is genuinely the
  reason RabbitMQ is attractive, this is the option to compare against, not self-hosting.
- **No broker at all** — the outbox table polled by workers. It is the baseline, and it is stronger
  than it usually looks: it meets every functional requirement in the document. Read its row before
  the meeting.

I also added a durable-log row (Kafka/Kinesis) and rejected it on scale, and a "publish directly, no
outbox" row so the reason for rejecting the most common shape is on the record.

The substantive claim: order pipelines lose orders at the **dual write** — the order is committed, the
publish fails, and nothing records what was left undone. A broker replicating to three availability
zones cannot replicate a message it never received. So durability is bought with a transactional
outbox plus idempotent consumers plus a quarantine you can replay, and you need all three under either
broker. Once you have them, and once the order database rather than the queue is the system of record,
the broker becomes a **two-way door** behind a hundred-line adapter. The genuine one-way door is the
delivery contract (at-least-once + idempotency keys + state-machine guards), because it reaches the
data model and every consumer.

That is why the recommendation is SQS: with durability equalised, what separates the brokers is
operational load, and self-hosting puts the durability-critical configuration — quorum membership,
publisher confirms, disk alarms, partition behaviour — in the hands of the team whose stated goal is to
not be doing that. And the routing you "might need later" has a cheap late-purchase path.

## Reclassified

| Your item | Became | Why |
| --- | --- | --- |
| "We can't lose messages" | N1 (a reconciliation that closes at zero, with a named Sev-1 level), plus F1 and F2 | "Never" is an absolute nothing satisfies. F2 exists because at-least-once delivery makes duplicates a certainty, so no-loss and no-double-charge are two requirements, not one |
| "Managed, dead simple" | Decision driver + N4 (≤8 unplanned engineer-hours per quarter, no Sev-1/2 with the mechanism as root cause) | "Simple" is an adjective; the thing you actually care about is measurable |
| "Supports complex routing we might need later" | **Not a requirement.** A pro for the options that deliver it, plus F6 (add a consumer without editing the producer) | Anticipation: a requirement for a problem that has not arrived. Buying it now costs N4/N5 against an unproven benefit |
| "Our existing cluster", "AWS" | Prior decisions, with their incumbents given rows in the tradeoff table | Neither is a constraint. A colleague's decision never excludes an option; it just carries a cost to reverse |

**One requirement I added that you did not ask for:** F3, quarantine and replay for the on-call
engineer and support agent. Without it every bug becomes a manual database repair. Strike it if you
disagree — I have flagged it in the document as an architect's addition rather than quietly designing
it in.

## The three questions I would have asked, in order

You asked for the document in one go, so these are in the document as blocking questions B1–B3 with
labelled assumptions in the meantime. Each carries my recommended answer.

1. **Does anyone in the organization already run RabbitMQ, with a named operator on call for it?**
   (B1) — *My assumption: no.* This is the single question most likely to reverse the recommendation.
   If the answer is yes, self-hosting's cost on N4 largely disappears, the routing comes free, and
   RabbitMQ becomes the better answer. Answer this one first.
2. **Peak accepted-order rate, messages per order, and does any stage need strict per-order
   ordering?** (B3) — *My assumption: 10,000 orders/day, 5 messages per order, no stage needing strict
   ordering.* Below roughly a million orders a day the cost arithmetic favours SQS by a wide margin
   (worked in the document); above that it inverts, and the FIFO quota needs checking.
3. **Any compliance rule or contract clause governing order data in a third-party managed queue?**
   (B2) — *My assumption: none, and the thin-message design keeps personal and payment data out of the
   queue anyway.* If an approval cannot be obtained, self-hosting becomes the only option that keeps
   the data in your cluster and the decision inverts the other way.

## Caveats you should read before circulating this

- **Every number in the document is assumed**, with you as its origin, because I had no codebase,
  dashboard, cost report or ticket queue. The document says so at the top and labels each figure. The
  first five roadmap tasks are the five measurements that would settle the argument; together they are
  about half a week.
- **Two vendor facts carry decision weight and I could not verify them today**: the per-request prices
  for standard and FIFO queues, and the per-queue FIFO throughput quota in your region. Both are stated
  from product knowledge and labelled "vendor-documented, to re-confirm". Ten minutes on the pricing
  page and in the service-quota console before anyone commits. My cost conclusion survives the price
  being off by a factor of five; it does not survive the volume being off by two orders of magnitude.
- **Also stated from product knowledge, not read today:** the 14-day SQS retention ceiling, the 256 KiB
  message size cap, FIFO's 5-minute deduplication window, and which plugins managed RabbitMQ supports.
  The last one matters if a plugin (delayed messages, priority) is part of why RabbitMQ appeals.
- **Targets I invented, and who should replace them**: N2's 5-minute alert (support lead), N3's
  60-second p95 (product owner), N4's 8 hours a quarter (engineering manager), N5's USD 250 a month
  (budget owner). Each is marked assumed in the document with the owner named.
- **I assumed** you are on AWS and that an order database already exists holding order state. The
  second one is load-bearing — the whole design puts the outbox in it — so confirm the order schema
  before the meeting.
- **The honest objection to my own recommendation**: it moves correctness for "charge once, ship once"
  from a vendor guarantee into your application code, in the idempotency check, on the payment path.
  An idempotency bug there is a double charge, not an edge case. That is in Residual risks, not buried.
- The document is **proposed, not accepted**, because B1–B3 are open. Recommending above an unresolved
  question that can invert the answer would be hoping rather than deciding. Answer B1 first; if it
  comes back "yes, the platform team has run RabbitMQ for two years", I withdraw the recommendation
  and the RabbitMQ row wins on its own merits.
