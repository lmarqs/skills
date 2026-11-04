Draft RFC is in `document.md`. Notes on how I handled your list, since I reshaped it rather than transcribing it:

**Reclassified:**
- The line you put last — "every action in the admin panel has to end up queryable by compliance, they currently grep prod logs by hand" — is the actual reason this project exists. I promoted it to the primary functional requirement (FR-1/FR-2) and treated Kafka, AWS, the API standard, and the UI as constraints/details sitting underneath it, not peers on the same list.
- Kafka and AWS are treated as **given constraints**, not alternatives to weigh — per your note that the platform team already decided Kafka. The tradeoff analysis only covers what's actually open: the ingestion pattern into Kafka, the downstream store, and schema management.
- "Test coverage above 90%" is a testing target, not an architectural requirement on its own — it doesn't shape a component. I kept it as a stated NFR but derived the requirement it was actually gesturing at (no admin action ever goes unaudited) and designed a reconciliation job + contract tests for that, since a coverage percentage doesn't guarantee completeness.
- The UI stays a strict "nice to have": phase 3, not gating phase 1, so compliance gets a working query API without waiting on it.

**Pushed back on:**
- "It should be fast" isn't a requirement as written — fast for what, measured how? I split it into an ingestion-latency budget (≤10ms added to the admin request, assumed) and a query-latency budget (p95 ≤ 2s, assumed) and flagged both as placeholders pending real SLA input, since no traffic or latency numbers were given.
- I added one thing you didn't ask for: an **outbox + CDC ingestion pattern** instead of a direct Kafka producer call from the admin action handler. A direct call risks the dual-write problem — the action commits but the Kafka publish silently fails, which directly violates "every action must end up queryable." Given that's your stated purpose, I treated this as worth the added CDC infrastructure rather than optimizing for simplicity. This is the single highest-risk call in the doc — flag it if your team has no CDC experience, since it's real added complexity, not a rounding error.

**Assumptions I made (unverifiable to me, stated as such in the doc):**
- Retention period for the audit trail — no number given, I placeholder'd 5 years hot+cold and flagged it as needing legal/compliance sign-off, not a researched figure.
- Traffic volume — assumed moderate (low thousands of admin actions/day); if real volume is much higher, revisit the store choice.
- The actual company API standard document wasn't available to me, so the endpoint shapes in the doc follow generic REST convention and are flagged as needing a check against the real standard.
- Whether "action" includes read-only/sensitive-view actions, and whether historical backfill is needed — both left as open questions for compliance to answer, not decided by me.

I did not invent details for the platform team's Kafka decision doc or the admin panel's internals since I don't have access to either — both are named in the doc as gaps, not filled in.

No blocking questions from me — this is a full draft ready for platform/compliance review; the five items under "Open questions requiring sign-off" in the doc are the ones that need an owner before implementation starts.
