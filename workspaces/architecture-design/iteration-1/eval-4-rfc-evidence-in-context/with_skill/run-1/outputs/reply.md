RFC drafted: staged plan (measure → tune → read replica → conditional materialized views → conditional OLAP), not a single-shot migration. Two things I did not do that you should know about:

**I did not verify your numbers, and neither should you treat them as verified yet.**
- The 8s p95 figure: I have no access to your Grafana, so it's carried in the doc as "reported by you, unverified," not as a measured baseline. Pull the real current p95 from `api-latency` before this RFC goes to review — it's the first line item in Phase 0.
- The 40% DB-load figure: you flagged it yourself as an unmeasured guess, and I treated it that way — it does not drive the recommended alternative anywhere in the tradeoff analysis. It's exactly the number that decides whether a plain read replica is enough or whether you need a real OLAP/CDC pipeline, so I made measuring it a blocking prerequisite (Phase 0) rather than picking an architecture to fit a guess.
- `reports/queries.py`: not accessible from this session (your app repo isn't in this working directory). I couldn't inventory actual query shapes, so the design section is explicit that "reporting queries are analytical/aggregation-heavy" is an assumption pending a real audit, not a finding.

**One ambiguity I resolved by assumption, flagged in the doc:** whether the slow "dashboard endpoint" is itself a reporting query, or a separate transactional endpoint being starved by reporting load contending for the same DB. I assumed the former (plus contention) because that's the common shape for a reporting dashboard, but the two failure modes call for different fixes, and Phase 0's query-cost profiling step is designed to tell them apart.

**Recommendation, in short:** don't jump straight to a dedicated analytics warehouse — it's the most expensive, least reversible option and its justification rests entirely on the unmeasured 40%. Start with query tagging + load measurement (days, not weeks), then a streaming read replica with a reversible routing switch. Escalate to materialized views or a full OLAP/CDC pipeline only if the measured data says the replica alone isn't enough.

Assumption I made without a way to check it: your tenants share database tables (a `tenant_id`-style model) rather than being isolated per-database. If that's wrong, flag it — it changes the isolation requirement and simplifies (not complicates) a couple of the alternatives.

No further questions blocking — the doc names what to go measure next (Phase 0) rather than asking you for numbers I could instead have you go pull.
