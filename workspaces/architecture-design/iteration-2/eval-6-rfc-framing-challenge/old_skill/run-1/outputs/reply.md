# Reply

**Pick: Go — conditionally.** But the RFC's primary recommendation is that the rewrite is probably not the fix, and the document is structured so you find that out in two days instead of two months. Full RFC in `document.md`.

## What I reclassified

- **"Rust or Go" → "invoice PDF latency".** The request named two solutions before stating the problem. The problem is that finance waits ~12 s for a 40-page PDF. The language is one dimension of one possible fix; the RFC keeps it as an explicit dimension (R3 vs. R4 in the tradeoff table) and still commits to a pick, but it decides the problem first.
- **Per-document speed → delivery model.** Invoices are immutable once issued, so the PDF can be rendered once at issuance and served from storage. That makes finance's wait a storage read regardless of runtime. This is decision 1 and it ships before any rewrite question is settled.

## What I challenged

- **That a compiled rewrite would fix the 12 s.** Of the six usual causes of slow Python PDF generation (H1–H6 in the RFC), only one — Python-interpreter CPU in code we own — is fixed by changing the language. The others (native engine time, N+1 queries, asset fetching, serial batch, a pure-Python layout engine) are fixed faster and more reversibly in place. No profile exists, so nobody knows which case this is. The rewrite is gated on a two-day profiling spike with a stated decision rule.
- **That the two options were exhaustive.** Added "keep Python and fix the measured hot spots" and "keep Python and swap the rendering engine" as real alternatives with pros, cons, and risks — not strawmen.
- **Go over Rust.** For a 40-page document at modest concurrency, the interpreted-vs-compiled gap is what matters; Rust's headroom over Go buys nothing the requirements ask for, and Rust costs more in maintainability (NF4) for a team that runs Python today. The RFC states the conditions that flip this to Rust (team already runs Rust; org standard; embedded typesetting engine with a Rust-native API — and notes that last one is weak).

## What I assumed (all labeled inline in the document)

- **Latency target:** ≤ 2 s p95 / ≤ 5 s p99 interactive. Picked as a typical tolerance; needs finance to confirm.
- **Batch target:** ≤ 2,000 invoices in ≤ 30 min at month-end. Invented as a shape; needs real figures.
- **Rendering is on demand and in a human's path** — inferred from "complains constantly".
- **Deployment:** containers on the existing platform.
- **Team:** no existing Rust or Go production service. If either exists, that language wins the tiebreak on maintainability.
- **Ecosystem claims** (Go's PDF libraries thinner than Python's; Typst embeddable in Rust; Go's ramp shorter than Rust's from Python) are labeled as inference and routed to the spike for verification. I could not verify them in this session.
- **Estimates** in the roadmap are rough, one-engineer figures, to be re-estimated after Phase 0.

## What I would have asked

1. Which PDF library does the service use today (ReportLab, WeasyPrint, wkhtmltopdf, headless Chromium, other)? This single fact could settle most of the RFC.
2. Is there any stage-level timing or a profile of a slow render? If not, can we add spans this week?
3. How does finance consume PDFs — one download at a time from the UI, or a month-end batch? How many invoices per month, and what is the page-count distribution?
4. Are PDFs stored after generation, or re-rendered on every download?
5. Does generation run inside the HTTP request (are there timeouts), or as a job?
6. Which languages does the team already run in production, and who owns this service?
7. What latency would finance consider "fixed"? (2 s? 5 s? "just don't make me wait"?)
8. Is an issued invoice truly immutable in your billing system, or can it be edited after the fact? (Decides whether pre-rendering is safe.)
9. Is there an existing golden set of invoices finance would sign off on for visual parity?
