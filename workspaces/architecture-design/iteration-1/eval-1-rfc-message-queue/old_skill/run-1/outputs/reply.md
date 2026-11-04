RFC drafted: `document.md`. Recommendation is **AWS SQS + SNS fan-out**, not RabbitMQ — but it's a
conditional recommendation, and I want to be upfront about why and what could flip it, since none of
the numbers that would normally settle this were given.

**What I pushed back on / reclassified**

- "Supports complex routing we might need later" is a *maybe*, not a requirement. I didn't let it
  drive the architecture as if it were committed — the skill's requirements test explicitly excludes
  speculative future needs from the architecturally-relevant list. I recorded it as an **open
  question** instead: if you (or product) can turn it into a concrete, scheduled routing need in the
  next couple of quarters, the recommendation should flip toward Amazon MQ or self-hosted RabbitMQ.
  As stated, SNS→SQS fan-out already covers the most common shape of "route one event to several
  consumer types" — it's genuine broker-level content/topic routing (AMQP exchanges) that it doesn't
  cover.
- I added a third alternative you didn't ask about: **Amazon MQ (managed RabbitMQ)**. It gets you the
  same routing power as self-hosting without your team operating a stateful Raft-replicated cluster
  for the first time on a business-critical path. It's in the tradeoff table as a real contender, not
  a footnote.
- I also briefly considered and screened out **Kafka/MSK** — mentioned in the doc's "Also considered"
  section, since it's the answer if "complex routing" actually meant "many independent teams need a
  replayable stream of every order event," which is a different problem than what was described.

**Assumptions I made (none of these were in the request, and each is flagged inline in the doc as
`[ASSUMPTION-...]`)**

1. **Traffic volume** — assumed tens to low-hundreds of orders/sec at peak. This is the single
   biggest gap: I have no real number, and it's the input most likely to change the analysis at
   meaningfully higher scale. Flagged as the top open question.
2. **"Existing cluster"** — assumed it means a Kubernetes cluster already running other production
   workloads (not one dedicated to messaging). If it's actually spare/dedicated capacity, the
   self-hosted RabbitMQ operational-risk story is less severe than I wrote it.
3. **Team's RabbitMQ experience** — assumed the team has not run RabbitMQ (or a comparable stateful
   broker) in production before. This assumption carries a lot of weight in the recommendation; if
   it's wrong (the team already operates RabbitMQ elsewhere), the operability argument for SQS
   weakens substantially and self-hosting becomes much more competitive.
4. **Cloud provider** — assumed the org runs primarily on AWS already, since SQS was on the table.

I did not fabricate any AWS/RabbitMQ facts — the concrete numbers cited in the doc (SQS FIFO
throughput caps, message retention, pricing, RabbitMQ quorum queues replacing classic mirrored queues
in 4.0) were verified against current AWS and RabbitMQ documentation before being written down, with
sources checked via web search this session.

**What I'd actually want from you before this RFC gets ratified:** answers to the four open questions
at the end of the document — real traffic numbers and a concrete yes/no on routing needs matter most;
they're both capable of flipping the recommendation, and I'd rather you confirm them than have the
team build against a guess.
