# Reply

RFC drafted — but I pushed back on the framing, and you should read §2.1 first.

## The main thing I changed

Four of your five "requirements" are solutions, not requirements. Saga, microservices, Redis, and gRPC
are candidate designs; they can't be evaluated until we know what problem they solve. The one real
requirement hiding in the list is behind "feature flag system": *any change to checkout must be
reversible in minutes without a deploy*. I kept that as NFR2 and then weighed a minimal kill switch
against a full flag platform on its merits.

The actual requirement is in the last sentence of your message, not the list: **checkout fails ~2% of
the time and we can't tell which step broke.** That's a diagnosability problem. The RFC derives its
requirements from it (per-step attribution, a failure taxonomy, no inconsistent money/order state,
idempotent retry, 30-day retrospective diagnosis) and designs against those.

I did not reject your five items. They're all in the tradeoff analysis — steelmanned, with the
condition that would bring each back:

| Item | Status | Returns when |
| --- | --- | --- |
| Saga | Deferred, partially adopted | Compensations adopted for cross-system steps now, inside the current process. Full saga becomes mandatory if checkout already spans services |
| Microservices | Deferred | If the real driver is deploy contention or team ownership — then it's its own RFC with those as requirements, not a fix for the 2% |
| Redis | Deferred | If measurement shows failures are dominated by dependency timeouts or slow reads |
| gRPC | Deferred | Only meaningful if the split happens; it's a transport choice inside that decision |
| Feature flags | Adopted as minimal kill switches | Full platform if there's an org-level mandate and owner |

## Recommendation, in one line

Instrument checkout's steps first (durable step ledger + tracing spans + failure classifier +
reconciliation job), measure for two weeks, then decide the restructuring with a failure profile in
hand. No new service, no new transport, no new datastore — one table, one scheduled job, and a
dashboard.

The reason isn't caution. Without a baseline, a post-refactor 2% is uninterpretable: you can't tell
whether the refactor fixed the old causes and added equally costly new ones. Instrumenting first is
what makes any later refactor verifiable.

## Strongest objection to my own recommendation

"Instrumentation is a delay dressed up as diligence — 2% is bleeding revenue now." It's in the document
(§4.5) with my answer. The concession: nothing in the plan forbids fixing an obvious bug found in week 1
by reading the code. What it forbids is committing to a large structural change before there's a failure
profile.

## The one thing I'd most want answered

**Is checkout one process against one database today, or does it already span services?** This is
assumption `A-8`, and it's the hinge. If it already spans services with separate databases, saga
compensations move from "deferred" to "mandatory now", and the step ledger has to be designed as a
distributed saga log with an outbox instead of a local table. My design assumes the simpler case.

## Open questions (full list is §9)

Decision-changing:

1. Single process/single DB, or already distributed? (`A-8`)
2. Any evidence the 2% includes charged-but-no-order cases? Refunds, chargebacks, support tickets that
   look like this?
3. Is there an independent mandate to decompose the monolith?

Refining:

4. What are the actual checkout steps, and which providers does each call?
5. What observability stack exists — retention, budget?
6. Current checkout p95, and any latency target or SLO?
7. Current deploy-to-revert time? (If it's under 5 minutes, the kill switches may be unnecessary.)
8. Is checkout in PCI scope, and who owns that review?
9. Does any feature-flag tooling already exist?
10. Traffic volume and seasonality, for the cost estimates and the measurement window?

## Caveats you should know about

- **I had no codebase, no dashboard, and no failure data.** Everything factual is an assumption, listed
  with IDs in §8 and cross-referenced where it's used. Phase 0 of the launch plan exists specifically to
  confirm or kill them.
- **The step names in the design are invented placeholders** (`validate_cart`, `reserve_inventory`,
  `authorize_payment`, `persist_order`, `capture_payment`, `notify`). The real list comes from reading
  the code.
- **The estimates are unvalidated** — one engineer familiar with the codebase, no existing
  instrumentation. Re-estimate after Phase 0.
- **The ~2% figure is yours, not verified by me.** I've asked for the query and window behind it, because
  the baseline matters for judging whether anything worked.
- **Diagrams are Mermaid, described precisely enough to redraw.** Replace with real images before
  approval if your RFC process expects them.
- **The decision is recorded as autocratic and pending review** — deliberately, since the proposals
  arrived without requirements attached. §5.2 lists exactly what would overturn it. If any of those
  conditions holds and you already know it, tell me and I'll revise rather than defend.
