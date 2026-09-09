# Reply

RFC drafted at `document.md`. Read §3 first — I reclassified most of what you sent, and if you
disagree with that table the rest of the document changes.

## The requirement was the sentence you didn't number

"Every action in the admin panel has to end up queryable by the compliance team, they currently grep
production logs by hand" is the whole problem. Items 1–6 are a mix of constraints, one real
requirement, one vague target, and one non-goal. I built the design around the closing sentence and
demoted the rest accordingly.

## Reclassifications

| You said | I recorded it as | Why |
| --- | --- | --- |
| (1) Must use Kafka — platform team decided | **Constraint C1**, not a requirement | Kafka is a mechanism. The requirement under it is "the event reaches the store without loss" — and in this design that guarantee comes from the transactional outbox and the idempotent write, not from the broker. I honoured the constraint, but §7 records what it costs on this specific problem and what would justify reopening it with the platform team. |
| (2) Endpoints follow the company API standard | **Requirement N5** | A public contract is expensive to change once compliance and a future UI depend on it. Genuinely architecturally relevant. |
| (3) It should be fast | **Rejected as written**; split into N1–N4 | "Fast" conflates four budgets that pull in different directions: write-path overhead (≤ 10 ms p95), ingest freshness (≤ 60 s p95), interactive query (≤ 2 s p95), and export (1M rows ≤ 15 min). **All four numbers are mine, not yours** — they are proposals for you and compliance to confirm or replace. |
| (4) Test coverage above 90% | **Not an architectural driver** — moved to the delivery gates in §9 | The design is identical at 90% and at 70%; coverage forces no component, boundary, or integration to exist. I kept it as a CI gate and added the thing that actually matters more: integration tests for the completeness path against a real Postgres and a real broker, because a mocked broker cannot demonstrate no-loss. |
| (5) Must run on AWS | **Constraint C2** | Correctly a given. It does shape which managed services are on the table, so it stays recorded. |
| (6) Nice to have: a UI | **Non-goal for v1**, Phase 4 | Deferred as you asked, with one obligation left on the design: the query API is shaped for a UI (filters, stable cursors) so it is additive later, not a rewrite. |

## Requirements I added that you didn't ask for

Three, and I'd defend all three:

- **Tamper evidence (F5).** An audit log that engineers can edit is not evidence, and the people being
  audited include people with production access. S3 Object Lock in compliance mode plus a per-event
  hash chain, verified nightly.
- **Provable completeness (N6).** "Every action is captured" is worthless as a promise. A nightly
  reconciliation of outbox against store, alarmed on any gap, turns it into a number you watch. This
  is the requirement that most shaped the design.
- **Durability over availability on the write path (N7).** The audit row is inserted inside the
  business transaction, so if the audit write fails, the admin action fails. **This is the most
  arguable choice in the document** and I want you to push on it: it means an audit-path problem can
  block legitimate admin work. I took it because an unrecorded privileged action is unrecoverable
  while a retried one is not, but it is a real cost to a production transactional database.

## Assumptions I had to invent (A1–A9 in §3)

No codebase, no metrics, no API standard document, so every number in the RFC is a labelled guess.
The four that would actually change the design:

- **A1 — ~500k actions/day, ~2 KB each.** Order-of-magnitude guess. If it's 50× higher, the store
  decision flips from Aurora to OpenSearch.
- **A3 — the admin panel is on PostgreSQL and controls its own transactions.** The entire capture
  design depends on this. If false, the whole of dimension A is reopened and the fallback loses
  events. This is a 30-minute check and it should be the first thing anyone does.
- **A5 — 7-year retention, 13 months needing interactive query.** Pure guess, and it is the single
  biggest cost lever in the system.
- **A4 — the latency budgets above.** Mine, not agreed with anyone.

## Open questions (§11) — worth more than more analysis from me

1. **Q1** — What is the real volume of audited admin actions, average and peak? (Could flip the store
   choice.)
2. **Q2** — Where is the company API standard document? I designed endpoints against a plausible REST
   shape; N5 is unverifiable without it.
3. **Q3** — What does compliance actually ask for today, in their own words: structured filters, or
   free-text search across payloads? If it's free-text, Aurora is the wrong store and OpenSearch is
   right. I'd talk to them before Phase 2.
4. **Q4** — Which actions must be audited? State changes only, or also sensitive reads (bulk exports,
   viewing full documents)? Is there a regulatory list?
5. **Q5** — Does the admin panel control its own DB transactions, and is it Postgres? (A3.)
6. **Q6** — Is there a corporate standard for immutable/WORM audit storage we should conform to?
7. **Q7** — Retention obligation, and how it interacts with data-deletion requests (an immutable
   7-year store and a deletion request are in direct conflict — worth resolving with legal early).
8. **Q8** — Is a second consumer of the audit topic actually planned (SIEM, warehouse)? This is the
   question that decides whether the Kafka hop earns its keep.

## Caveats

- **Sequencing matters more than usual here.** Capture is the only part whose delay destroys value
  permanently — every day without it is evidence lost forever. Query and export can be added later
  over data you already hold. So Phase 1 ships capture *without* a query API, and deliberately
  doesn't depend on Kafka topic onboarding, so a platform-team delay can't stop the clock.
- **Scope gap to communicate explicitly.** This service captures admin panel actions only. Actions via
  the public API, background jobs, or direct SQL are not covered in v1. Compliance will hear
  "queryable audit log" and assume everything, so say this out loud to them rather than letting them
  discover it during an audit.
- **One claim I could not verify:** I noted in §5.4 that a purpose-built immutable ledger database
  (Amazon QLDB) appears to be on an end-of-support path, which would rule it out for a 7-year
  obligation. That is **inference from memory, not verified** — flagged as Q6. It doesn't change the
  recommendation (Object Lock + hash chain reaches the same property with services you already use),
  but check it before the RFC is approved.
- **No pricing numbers anywhere.** I deliberately left dollar figures out rather than state
  unverified ones. The MSK Serverless per-cluster-hour charge in dimension D2 is flagged as needing a
  pricing check; it's not load-bearing for the recommendation.
- **Everything about compliance's workflow is second-hand.** The strongest single improvement to this
  RFC is a 30-minute conversation with them (Q3, Q4, Q7) before Phase 2 starts.
