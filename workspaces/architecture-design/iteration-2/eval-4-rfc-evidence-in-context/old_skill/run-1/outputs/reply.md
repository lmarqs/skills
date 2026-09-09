RFC drafted: `document.md`. Recommendation is a **read replica for reporting first, pre-aggregation second and only if measurement says so** — with a short measurement phase before either.

## One reclassification, and it's the important one

Your framing is one problem. The evidence describes **two**, with different fixes:

- **Reporting hurts the app** (the 40% load figure). Fix = isolation. Cheap, reversible, works.
- **The dashboard is slow** (the 8s p95). Fix = *less work per request*. Moving an 8-second query to a quieter machine gives it a quieter machine; it does not make it fast.

Splitting reporting off the main database solves the first outright. It solves the second **only if** most of those 8 seconds is time spent queueing behind a contended primary rather than time spent doing real work. Nothing you gave establishes which. So the RFC commits to the replica unconditionally (it's right either way), and gates the pre-aggregation work behind a measurement.

## Evidence status — nothing was verified

I had no dashboard, no repo, no database in this pass, so every figure in the document is attributed to you and labelled as reported. The provenance table is §"Evidence and its provenance". Two things to flag:

- **"Reporting causes the 8s p95" is my inference, not your evidence.** Both your numbers are equally consistent with the dashboard just being an expensive query. The design is built so that being wrong about this is survivable.
- **"40% of database load" has no defined metric.** 40% of CPU time, of total statement execution time, and of query count describe three different situations, and the success criterion has to be stated in whichever one it actually is.

I also did not open `reports/queries.py`, so its size, whether it uses an ORM, and whether it's the *only* place reporting queries live are all unknown — the last one matters, because anything outside that module won't get routed and will keep loading the primary.

## Assumptions I had to make (all in §Assumptions, individually flagged)

- **PostgreSQL**, managed (RDS/Cloud SQL), no read replica serving traffic today. If it's MySQL, the decision holds but Phase 2 needs summary tables instead of materialized views. If it's Aurora, replicas are cheaper and one whole risk class disappears. If it's self-managed, Phase 1's effort roughly doubles.
- **Python, `reports/queries.py` is the reporting data-access layer** — inferred from the filename.
- **Reports may lag the primary by up to 15 minutes.** This is the assumption most likely to be wrong and most consequential. Not my call to make — see Q4.
- **Targets I invented because none were given:** dashboard p95 ≤ 1.5s / p99 ≤ 3s, reporting down to ≤ 10% of primary load, extra infra spend ≤ 1× the primary instance. All marked "(assumed)"; argue with them, that's what they're for.
- **Report logic is frozen** — we're moving where queries run, not changing what they compute.

## Open questions (Q1–Q8 in the document)

Answer before Phase 1 ships:

1. **Data volume, growth rate, per-tenant skew?** The biggest gap. 300 tenants at 500k rows each and 300 tenants at 200M rows each are different architectures — the first is a replica for years, the second is already on the road to a columnar store. I could not size anything quantitatively without this.
2. **What does the 40% actually measure, and where did it come from?**
3. **Is `reports/queries.py` the only place reporting queries live?**
4. **What staleness can each report tolerate — does any of them feed invoicing, an audit trail, or a checkout/eligibility decision?** Blocking for Phase 2. This one is a product decision, not an engineering one, which is why the RFC records it as an unsigned-off assumption rather than a settled requirement.
5. **Which exact endpoint and panel gave the 8s, and was last month typical?** The before/after needs the same instrument.

Plus: confirm the engine and hosting (Q6), the budget ceiling (Q7), and who owns the replica operationally (Q8) — no new production system without a named owner.

## Caveats

- **Estimates in the roadmap are unvalidated.** They assume the environment guesses above and no surprises in a file I haven't read. Re-estimate after the measurement phase.
- **A read replica is read-only.** Easy to miss when planning: no summary tables or materialized views can live on it, so any pre-aggregation has to be written on the primary and replicated over. That constraint is what shapes the phasing.
- **There is a genuine tradeoff I couldn't design away.** Long reporting scans on a Postgres replica either get cancelled when they conflict with replay, or you set `hot_standby_feedback` and get bloat on the primary instead. Normal behaviour of the mechanism, not a misconfiguration. Both settings and both fallbacks are in the risk table (R2).
- **I rejected a columnar store (ClickHouse/BigQuery/etc.) for now, not on principle.** It's the strongest answer to the slow-dashboard half and plausibly where this ends up. It loses today because it means rewriting every query in `reports/queries.py` in another dialect plus operating a new platform — a large, slow bet placed on an inference. The explicit conditions that would flip that decision are recorded in §The decision.
- **Strongest objection to my own recommendation:** if the dashboard turns out to be almost entirely work-bound, Phase 1 costs an instance and a few days without moving the dashboard number at all. Accepted, because it still stops reporting from hurting the app, and because the measurement phase surfaces this *before* Phase 1 ships.
- Author and document links are `TBD` placeholders — fill them before circulating. The `api-latency` board needs a real URL in §Related documents.
