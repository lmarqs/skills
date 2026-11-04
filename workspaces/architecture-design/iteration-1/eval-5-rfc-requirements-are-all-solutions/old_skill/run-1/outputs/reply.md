RFC drafted at `document.md`. One reclassification and several assumptions worth your attention before this goes further.

**Reclassified: your five "requirements" are solutions, not requirements.** Saga pattern, microservices, Redis, gRPC, and a feature flag system are all named technologies — none of them is a checkable constraint on the problem itself. Treating them as requirements would have made the tradeoff analysis circular (options graded against themselves) and risked bolting on infrastructure the actual problem doesn't call for. So I derived the real requirements from what you described as broken — a 2% failure rate with no step-level attribution — and evaluated all five named technologies as candidate solutions in the alternatives analysis, alongside other credible options for the same dimensions. Net result, in brief:

- **Feature flags** — kept, and recommended. It directly serves a real requirement (safe, instant-revert rollout on a revenue-critical path).
- **Saga pattern (orchestrated)** — kept, and recommended. It's the right fit for the atomicity/step-attribution requirement.
- **Microservices split** — deferred. Recommended a modular monolith first; extract a specific step later only if telemetry shows it actually needs independent scaling. A full split up front is a large, hard-to-reverse move made before any evidence exists about what's actually failing, and it can introduce new distributed-systems failure modes before you've fixed the old one.
- **Redis caching** — not recommended for this phase. Nothing in the stated problem (failure rate, unknown failing step) points at a caching gap; added unprompted, it's a new stateful component with its own staleness risks. Flagged for re-evaluation after Phase 1 telemetry, in case it turns out something is actually latency/DB-bound.
- **gRPC** — not recommended as stated. It only matters if/when services split, and even then, synchronous RPC between saga steps cuts against the compensation requirement (a downstream timeout takes the caller down with it). Recommended async messaging for saga participation instead, with gRPC reserved for synchronous read-only calls if needed later.

**The RFC leads with instrumentation, before any of the structural change.** The most direct fix for "we don't know which step broke" is a correlation ID and a step-level outcome log — that alone can ship without touching coordination logic, and it's also the evidence source every later phase (including the Redis/gRPC re-evaluation) depends on. I made this Phase 0/1, gating the rest.

**Assumptions, since I had no access to the actual checkout system, dashboards, or tickets — please correct these:**
- The 2% failure rate and "we don't know which step" are taken as you reported them; I could not verify them against a dashboard or logs.
- I assumed checkout is currently a single service/monolith (inferred from "split into microservices" implying it isn't already split).
- I assumed a generic step list — inventory reservation, payment authorization, order persistence, notification — since the real steps, and which of them actually produce the 2% failures, are unknown to me. Phase 1 of the RFC is designed specifically to replace this assumption with real data.

If any of those three are wrong, the requirements section and the decision may need revisiting — everything downstream traces back to them.
