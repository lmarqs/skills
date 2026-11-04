RFC written to `document.md`. Recommendation: transactional outbox + CDC from the admin panel's DB
into Kafka → Lambda consumer → Aurora (hot, immutable, partitioned) with an S3/Object-Lock cold
archive → Lambda query API. Kafka and AWS taken as given, not re-decided.

**Reclassified / pushed back on:**

- **"Must be fast" is not a requirement, it's a placeholder.** Split into two concrete, checkable
  budgets: ingestion lag ≤30s p95 (freshness) and query latency ≤2s p95 hot / ≤10s p95 cold. Numbers
  are assumed, not confirmed — check with compliance before treating them as final.
- **"UI for browsing logs" moved out of core requirements into Phase 3.** You already flagged it as
  nice-to-have; the actual requirement ("queryable by compliance") is satisfied by the API. Building
  the API to support the UI later costs nothing extra now.
- **"Test coverage above 90%" kept, but flagged as insufficient alone.** A coverage number doesn't
  prove no action is ever silently dropped, which is the actual risk in this system. Added contract,
  fault-injection, and reconciliation tests as required supplements.
- **Two requirements added that you didn't state:** immutability of records (FR-5) and restricted
  query access (FR-4). Both are implied by "compliance" and "audit," and both are hard to retrofit —
  flagged clearly in the doc as additions, not attributed to you.
- **Retention period is an open question I did not resolve.** No number was given and I have no
  access to a legal/compliance retention policy. Design assumes a placeholder (13mo hot + indefinite
  cold) that can be dropped in without a redesign — get the real number before Phase 1 ships.
- **Kafka's delivery guarantee has a consequence you should know about:** at-least-once, so the
  consumer needs a dedup key. Not a pushback on the decision itself, just made the implication
  explicit since "the platform team already decided" doesn't mean the consequences were spelled out.

**Unavailable references, handled as assumptions, not fabrications:** the company API standard
document, the platform team's Kafka decision record, and the admin panel's action inventory were all
named but not accessible in this environment. Each is called out in "Related documents" with the
specific assumption I made in its place — verify all three before merging.

**Scope call worth confirming:** I included the admin-panel-side outbox/CDC work in this RFC's scope,
because nothing today emits a structured event at all (that's the whole problem). If the admin-panel
team owns their own backlog separately, that piece may need to move to a different ticket — flagged
in the doc's "strongest objection" paragraph as the main practical risk to this recommendation.
