# RFC — Rewriting the PDF Generation Service: Rust vs. Go

**Status:** Draft — recommendation made, pending sign-off from the service owner and a pre-work profiling spike (see *Open verification items*)

## Related documents

- Current PDF generation service source repository — **not available to this document's author**; not linked.
- Profiling / APM trace for the 40-page invoice generation path — **not available**; not linked.
- Finance team complaint tickets — **not available**; not linked.
- No dashboard, benchmark, or ticket referenced above was accessible while writing this RFC. Every quantitative claim below is either the input given for this RFC (flagged as **reported, not independently verified**) or a general, publicly-known property of the languages/runtimes discussed (flagged inline). Treat this document as directionally sound but re-validate the flagged numbers before treating them as commitments.

## Context

The company generates PDF invoices as part of its billing flow. The generator is a Python service. For a representative case — a 40-page invoice — it takes **~12 seconds** to produce the document (reported input to this RFC; not independently profiled here). The finance team, who wait on this output to close billing cycles and hand documents to customers/auditors, complain about it regularly (reported input; the underlying tickets were not available to review).

Twelve seconds for a single document is slow enough to be felt by a human waiting on it, and it gets worse if invoices are generated in a batch (e.g., a month-end run across many customers) rather than one at a time — batch behavior is not confirmed here (see *Open verification items*), but it is the scenario where a fixed per-document cost compounds fastest and would most justify urgency.

**The problem to solve:** the current implementation is too slow for the finance team's needs, and the organization wants to rewrite the service in a faster, compiled language. This RFC evaluates **Rust vs. Go** as the implementation language for that rewrite and makes a recommendation.

### A framing risk this RFC flags before going further

A rewrite in a faster language only fixes the problem if the 12 seconds is actually dominated by CPU-bound PDF rendering (layout, text shaping, drawing) rather than by I/O — e.g., fetching invoice line items from a database or another service, sequential network calls, or disk/image I/O. **No profiling data for the current service was available to this RFC's author**, so this is stated as an assumption, not a verified fact:

> **Assumption A1:** the majority of the 12 seconds is CPU-bound work inside the PDF rendering path, not waiting on external I/O.

If A1 is false — e.g., if the 12 seconds is mostly spent waiting on a slow database query per line item — neither Rust nor Go will meaningfully help, and the right fix is pipeline/query optimization or parallel fetching, not a language rewrite. This RFC proceeds under A1 because that is the premise implied by the request, but **recommends confirming it with a short profiling spike before committing engineering time to a full rewrite** (see *Launch strategy*). This is the single largest risk to the value of this entire effort, and it is called out again in the decision section.

### Out of scope

- Whether to rewrite at all vs. optimize the existing Python service (the request already decided on a rewrite; this RFC only picks the language).
- Changes to invoice content, layout, or visual design — the output must remain equivalent to what finance and customers see today.
- The document/data pipeline that supplies invoice line items to the generator (assumed to stay as-is, behind whatever interface the new service exposes).
- Deployment platform (assumed to be whatever container/orchestration substrate already hosts other backend services).
- Other document types the same service might generate beyond invoices, if any — not confirmed either way.

## Requirements

Only the requirements that actually shape the language/architecture choice are listed; feature-level detail (exact invoice fields, tax rules, etc.) is out of scope for this document.

### Functional

- The rewritten service must produce PDFs that are visually and structurally equivalent to today's output (same pagination behavior, fonts, tables, totals) for documents ranging from short invoices to at least the 40-page case cited above.
- The service must accept the same invoice data contract the current Python service consumes (assumed stable; not confirmed — flag if the data contract is also changing).
- Output must remain a standards-valid PDF suitable for a financial/billing record. **Whether PDF/A or another archival profile is a hard compliance requirement was not confirmed** — flagged as an open question, since it affects library choice in both languages.

### Non-functional

- **Latency:** reduce the 40-page invoice case from ~12s to a materially better target. This RFC proposes **p95 ≤ 2s for a 40-page invoice** as a working target — this number is **not validated against finance's actual tolerance** and should be confirmed with them before being treated as an SLO.
- **Throughput / concurrency:** the service must handle whatever concurrent/batch load exists today (e.g., a month-end run) without linear degradation. Actual peak volume is **unknown to this RFC** — flagged as an input needed before capacity planning can be finalized.
- **Correctness under load:** no partial/corrupted PDFs, no silent failures — financial documents that go to customers and auditors cannot be wrong.
- **Operability:** structured logs, metrics, and tracing consistent with however the rest of the backend is instrumented, so the new service isn't a blind spot.
- **Maintainability:** the language chosen must be one the team can realistically staff, review, and support for years, not just build once. This is a cross-cutting, hard-to-reverse requirement — a rewrite in a language nobody can maintain trades one bad outcome (slow) for another (unmaintained).
- **Migration safety:** since this is a financial document generator, the cutover must be verifiable (e.g., byte-for-byte or visual diffing against the old service's output for a sample set) before the Python service is retired.

## Design

Both candidate languages solve the requirements with the same shape of service; the language is the variable under decision, not the architecture. The components below are language-agnostic.

### Components

- **API/ingress layer** — receives a request to generate an invoice (invoice ID or inline data), validates it. *Answers: correctness, operability.*
- **Data assembly layer** — fetches/normalizes the line items, totals, and metadata needed to render the invoice, from whatever upstream source supplies them today. *Answers: functional data-contract requirement; this is also where Assumption A1 would be falsified if this layer turns out to dominate the 12s.*
- **Template/layout engine** — lays out pages, tables, headers/footers, pagination logic. *Answers: functional equivalence and the 40-page scaling requirement.*
- **Render/assembly engine** — draws primitives (text, lines, embedded fonts/logos) and assembles the final PDF bytes. *Answers: the latency requirement — this is the component Assumption A1 says is the bottleneck.*
- **Output sink** — returns/stores the generated PDF (object storage, response stream, etc., assumed unchanged from today).
- **Observability** — structured logging, metrics (generation duration, error rate, queue depth if batched), tracing correlated across the above. *Answers: operability requirement.*

### Static diagram

```
                    ┌─────────────────────────────────────────┐
                    │           PDF Generation Service          │
                    │                                            │
 Request ─────────▶ │  API/ingress  →  Data assembly  →         │
 (invoice ID)       │                                    │       │
                    │                                    ▼       │
                    │                          Template/layout   │
                    │                                    │       │
                    │                                    ▼       │
                    │                          Render/assembly   │
                    │                                    │       │
                    │                                    ▼       │
                    │                             Output sink ───┼──▶ PDF bytes /
                    │                                            │   object storage
                    │  Observability (logs/metrics/tracing) ─────┤   (all stages)
                    └─────────────────────────────────────────┘
Upstream data source (DB / service) ◀── queried by Data assembly
```

### Dynamic diagram — request flow

1. Caller (finance workflow / billing job) requests generation for invoice `N`.
2. API/ingress validates the request and hands off to Data assembly.
3. Data assembly fetches invoice header + line items from the upstream source (single call or paginated, depending on what exists today — unconfirmed).
4. Template/layout engine computes pagination given the line-item count (this is where a 40-page document diverges in cost from a 1-page one).
5. Render/assembly engine draws each page's content and serializes the PDF.
6. Output sink persists/streams the result; success/failure and duration are emitted to observability.
7. Caller receives the PDF (or a pointer to it) and a completion signal.

Step 3 vs. steps 4–5 is exactly the split that determines whether Assumption A1 holds — instrumenting the boundary between them in whichever language is chosen (or better, in the *current* Python service first) is the cheapest way to de-risk this whole RFC.

## Alternatives analysis (Tradeoff)

Only one dimension is actually open in this RFC — the implementation language — since the rewrite itself and the general architecture above are treated as given by the request. Each alternative is checked against the requirements above.

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **[Language] Go** | Compiled, no interpreter overhead — large, well-known speedup over CPython for CPU-bound formatting/rendering loops (general property of compiled vs. interpreted languages; not a measured number for this specific workload). Mature PDF-generation libraries for structured, tabular documents (e.g., `gofpdf`, `maroto`, commercial options like `unipdf`) — this shape of library fits an itemized invoice well. Simple concurrency model (goroutines) for batch generation. Fast compile/iteration cycle keeps rewrite risk down. If the existing backend already leans on Go elsewhere (repository naming conventions suggest this may be the case, but this RFC could not confirm the org's language inventory directly), hiring, code review, shared tooling, and observability integration are cheaper. | Garbage-collected — GC pauses are a real (if usually small) tail-latency risk under sustained concurrent load, which matters if a batch run generates many invoices at once. Less raw control over memory layout than Rust, so extremely tight per-document allocation budgets are harder to hit. | GC pause spikes tail latency during a large batch run | Medium | Low–Medium | Tune GOGC / use a pooled-object pattern for hot render buffers; load-test the batch scenario before rollout | Fall back to bounded worker-pool concurrency (cap parallel generations) to reduce GC pressure until tuned |
| | | Go's PDF ecosystem, while workable, is less feature-complete for advanced typography/embedding than some Rust or native alternatives | A layout edge case (rare font, complex table span) that the current Python library handles isn't supported out of the box | Medium | Medium | Diff-test against a representative sample of real invoices (including edge cases) before cutover | Patch/extend the chosen library, or shell out to a secondary renderer for that edge case only |
| **[Language] Rust** | No GC — the most predictable tail latency and the lowest memory footprint of the two; strongest ceiling on raw CPU-bound rendering throughput. Memory safety without a runtime, which matters if the render path processes untrusted/variable invoice data at volume. | Smaller, less mature ecosystem specifically for structured document/PDF generation (`printpdf`, `genpdf` exist but are less battle-tested for complex tabular layout than Go's invoice-oriented libraries); more building-from-primitives likely needed. Steeper learning curve (ownership/borrowing, lifetimes) — slower initial development, higher review burden, smaller hiring pool. No evidence surfaced that the team currently has production Rust experience; this would be a first production use of the language for this org as far as this RFC could determine. | The learning curve slows delivery and increases defect risk in a financial-document generator during the team's first production Rust project | High | High (absent confirmed prior Rust experience) | Timebox a spike using the actual invoice template before committing; pair the rewrite with an engineer who has prior Rust exposure if one exists; budget real ramp-up time in the roadmap, not just ideal-case estimates | Fall back to Go mid-project if the spike or early implementation shows the ramp cost is unacceptable — cheaper to abandon early than after a partial rewrite |
| | | | PDF library gaps force hand-rolling parts of the layout/rendering engine | Medium | Medium | Evaluate `printpdf`/`genpdf`/`typst`-as-a-library against the real invoice template in the same spike above | Wrap a mature non-Rust renderer (e.g., invoke a battle-tested CLI/service) for the parts Rust libraries don't cover well — partially defeats the point of the rewrite, but is a working fallback |

**Both alternatives satisfy Assumption A1's premise equally well** — if the bottleneck truly is CPU-bound rendering, either compiled language would likely deliver a large improvement over Python; the difference between them is second-order (tail latency ceiling, ecosystem fit, delivery risk) rather than "one works and one doesn't."

## The decision

**Decision: rewrite the PDF generation service in Go.**

Reasoning, tied back to the requirements:

- **Latency requirement:** both Go and Rust comfortably clear the jump from an interpreted Python implementation; Rust's edge is in tail-latency ceiling and memory footprint, which matters more at very high concurrency than for a single 40-page document. Nothing in the stated problem (a per-document latency complaint) demands that ceiling today.
- **Maintainability requirement (the tie-breaker):** this is where the decision actually turns. A financial-document generator needs to be reviewable and staffable for years. Go's simpler learning curve, larger hiring pool, and (plausible, not confirmed) alignment with the rest of the backend's language make it the lower-risk long-term owner of this service. Rust's steeper ramp is a real, high-probability risk (see table) with no evidence of existing team experience to offset it.
- **Functional requirement (equivalent invoice output):** Go's PDF ecosystem includes libraries built specifically for tabular, itemized documents like invoices, which maps more directly onto this use case than Rust's currently thinner PDF-specific ecosystem.
- **The strongest objection to this pick, stated plainly:** if the org anticipates needing the lowest possible tail latency and memory footprint at very high concurrent batch volumes (e.g., generating thousands of invoices in a tight window), Rust's no-GC model is the better long-term bet, and this decision should be revisited if that scenario turns out to be the actual driver of the complaints rather than single-document latency. That volume/concurrency figure was not available to this RFC (see *Open verification items*) — it is the one input most likely to flip this recommendation.

**Decision style:** this RFC makes an explicit recommendation (Go) as requested, but it is written as input to the accountable engineer/tech lead who owns this service, not as a democratic vote — no team consultation was available in producing this document. Treat this as a recommendation to ratify or override, not a final autocratic ruling already exercised.

## Open verification items (must close before/soon after rollout)

These are the inputs this RFC could not verify directly and that materially affect the decision or its rollout; the recommendation above stands under the stated assumptions, but should be revisited if any of these come back differently:

1. **Profile the current Python service** on the 40-page case to confirm Assumption A1 (CPU-bound rendering vs. I/O-bound data fetch). If I/O-bound, the rewrite's expected payoff drops and the fix may lie elsewhere entirely.
2. **Confirm actual peak concurrency/batch volume** (e.g., month-end run size) — this is the input most likely to push the decision toward Rust if volumes are very high.
3. **Confirm the finance team's actual latency tolerance** — the ≤2s p95 target above is proposed, not agreed.
4. **Confirm whether PDF/A or another archival/compliance profile is required** for these documents — affects library choice in either language.
5. **Confirm whether the existing backend is predominantly Go** — this RFC treated it as a plausible, unconfirmed factor in Go's favor; if the backend is actually polyglot or Rust-adjacent, re-weigh the maintainability argument.

## Launch strategy

1. **Spike (pre-commitment, days not weeks):** instrument the current Python service (or a minimal harness) to split data-fetch time from render time on the 40-page case, closing verification item 1. If this contradicts Assumption A1, pause and re-scope before writing Go code.
2. **Parallel-run POC:** build a thin Go prototype covering one representative invoice template end-to-end, benchmark it against the ≤2s target, and diff its output against the current Python service's output for a sample set (closes the functional-equivalence requirement).
3. **Full rewrite:** once the POC validates both latency and output-equivalence, build out the remaining templates/edge cases behind a feature flag, running Go and Python side by side.
4. **Cutover:** switch finance-facing traffic to the Go service once a diffing pass across a broad invoice sample (not just the 40-page case) passes, keeping the Python service available as a fallback for a defined window.
5. **Retire Python service** once the fallback window passes with no regressions.

## Version history

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | 2026-09-08 | Claude (agent, on request) | Initial draft: recommends Go over Rust for the PDF generation service rewrite, with explicit flags on unverified inputs and a pre-rollout profiling spike. |
