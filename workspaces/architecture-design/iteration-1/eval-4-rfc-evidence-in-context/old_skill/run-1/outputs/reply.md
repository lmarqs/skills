RFC drafted at `document.md`: split reporting off the primary via a dedicated read replica, gated by a
Phase 0 measurement spike, with the ETL/warehouse alternative deliberately deferred.

**What I reclassified:**
- Your "maybe 40%" DB-load figure — by your own account, unmeasured. I did not use it as a sizing
  input or a requirement. Instead it became a gate: Phase 0 (native query-stats capture, ~2 days) has
  to produce a real number before any infrastructure spend, and the heaviest alternative (ETL to a data
  warehouse) is explicitly not authorized to start until that number exists. If it comes back low
  (under ~10%), the RFC's own "condition that would flip the decision" section says to fall back to
  query/index tuning instead of a replica.
- The 8s p95 on the `api-latency` board — I treated this as *reported, not verified*: I couldn't open
  that dashboard from this session, it's a single data point from last month with no trend and no
  stated healthy baseline or SLO target, and it's not yet established that reporting contention (rather
  than something else) is the actual cause. Phase 0 also includes correlating reporting query
  concurrency against that same latency window, to test that assumption before committing.
- I couldn't read `reports/queries.py` (not reachable from this session), so the design deliberately
  doesn't assume anything about what's inside it — the reporting service sits in front of it unchanged,
  and a query/index audit of that file is called out as cheap, parallel work regardless of what else
  happens.

**Assumptions I made explicit in the doc (flag and confirm before Phase 1):**
- Database engine: assumed a mainstream relational engine with native async replication (not stated in
  the request).
- Report staleness tolerance: assumed "minutes are fine," not real-time.
- Dashboard p95 target: no target was given; assumed ≤1s as a working default.
- Budget for a data-warehouse-class build: assumed constrained, hence deferring Alternative B.

**Questions worth getting answered before Phase 1, if you want to tighten the doc further:** the actual
DB engine, the acceptable staleness for each report (some may need this, some may not), and who owns
the dashboard p95 SLO. None of these blocked producing the RFC — they're recorded as open items with
an owner to confirm them, per the document's *Assumptions and unresolved inputs* table.
