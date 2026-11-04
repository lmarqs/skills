RFC drafted at `document.md`. One pushback and several assumptions before you read it:

**Pushback — the five items you listed as "requirements" are solutions, not requirements.** Saga
pattern, microservices split, Redis, gRPC, and feature flags are all technology choices, not
constraints on the problem. The actual requirements, derived from what you described, are: (1) every
checkout failure must be attributable to a specific step, and (2) a failure in one step must not leave
stranded side effects (no double charge, no orphaned order) — plus the implicit constraint that any
change to a revenue-critical path ships incrementally and reversibly. I reclassified your five items as
candidate solutions and evaluated each one against those requirements in the tradeoff table, rather than
accepting them as given.

**Where the evaluation disagrees with the original ask:** the RFC recommends building the saga-style
step state machine (attribution + compensations) first, inside your current architecture — no service
split, no gRPC, no Redis yet. Those three carry real cost/risk (detailed in the doc) that's justified
only by an independent scaling or team-ownership need, which wasn't stated and which I have no evidence
for. The design is built so a later split, if that need is confirmed, reuses the same state machine
unchanged. Feature flags are kept, but scoped down to "whatever mechanism gates a gradual rollout,"
starting with something lighter than a full flag platform unless you already have one.

**Assumptions made (no access to your systems, flagged in the doc's Context and Assumptions section):**
- I could not see your current checkout code, architecture, or the dashboard behind the "~2%" figure —
  I have no breakdown of that 2% by cause, so I deliberately did not invent a numeric reliability target
  (NFR2 is qualitative until that breakdown exists).
- I assumed checkout is currently a single deployable (not already split), since you asked to split it.
- I assumed an illustrative step list (payment, inventory, order creation, notification) — confirm the
  real steps before building Phase 0's tracing.
- I flagged, but didn't assess, whether payment-data compliance (e.g., PCI DSS) constrains where step
  state or idempotency keys can be stored — worth checking before Phase 1.

Nothing here is a blocking question — the document lays out a phased plan (instrument → saga discipline
→ measure → revisit topology) that proceeds without those answers, but Phase 2 (the split) is explicitly
gated on confirming the scaling/ownership driver you may have in mind but didn't state.
