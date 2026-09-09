# Reply

Draft RFC is in `document.md`. Read the Assumptions and Open questions sections first — the document is only as good as the ten assumptions I had to make on your behalf.

## What I changed about your framing

**Your four stakeholders are departments, not roles — I reclassified them.** Marketing, Finance, the CTO and Support tell me whom to invite to the review; they are useless as a permission model, because it breaks on the first reorg, the first time someone in Finance fixes a typo, and the first contractor who is in no department. The design is built against six usage roles instead: **Author, Requester, Reviewer/Approver, Viewer, Administrator/Operator, Auditor/Cost owner**. The mapping back to departments is in the Context section. Concretely this changed two things: Author became a role that must have ≥ 2 holders (R-F3), and Requester became a first-class role with its own surface (R-F4) instead of a chat habit — which is the actual fix for the bottleneck you described.

**"It must be intuitive, secure and fast, and nothing is ever lost" is four adjectives, not four requirements.** I translated each into something a reviewer can accept or reject, and you should push back on any of these numbers, because I invented them:

- *intuitive* → two Marketing colleagues who are **not** the current analyst each publish a new page and correct an existing one, unaided, first try, in ≤ 10 min. This is the exit criterion for phase 2. It is the only requirement the fast phase-1 plan does not meet, and I say so in the doc.
- *secure* → six separate requirements. The one you probably have not considered: hand-written HTML nobody reviews is **untrusted code**, so it must not share a cookie or storage origin with any company application. That constraint alone kills "put it on a path of the main site" and "publish it through the marketing CMS".
- *fast* → p95 TTFB ≤ 200 ms, LCP ≤ 2.5 s, publish-to-live ≤ 60 s. Measured, not asserted.
- *nothing is ever lost* → every version that was ever live retained 5 years, Authors cannot delete, soft delete with 30-day undo, RPO 0 / RTO ≤ 4 h.

**I added a requirement you did not ask for.** The chat-bottleneck detail in your last sentence is not a nice-to-have — it is a single point of failure on live, possibly public content. R-F3 and R-F4 exist because of it. Moving the domain without fixing this just relocates the problem.

## The decision, and the honest caveat

Chosen: object storage + CDN (S3 + CloudFront) on a dedicated cookie-free subdomain, object versioning as the durability guarantee, internal pages gated by OIDC at the edge, and a Git+CI bridge for two weeks replaced by a small internal Publisher app.

**The strongest objection is in the doc, and I mean it:** for 30 pages and one author this may be more machinery than you need. A managed static host (Cloudflare Pages / Netlify / Vercel with their access product) plausibly gets you a company subdomain, TLS, CDN, per-deploy history and SSO gating in about a day, with no edge code and no app to own. I rejected it on 5-year retention and on procurement — both of which are guesses of mine, not findings. **If your procurement is fast and the vendor's export/retention story holds, take that instead and skip roughly two thirds of the roadmap.** The flip conditions are listed explicitly under "The decision".

## Open questions — Q1 and Q2 are blocking

I answered these with labelled assumptions so the document holds together. Two of them can invalidate the design, not just a detail:

1. **Q1 — Are these pages public, internal-only, or both?** I assumed both (A1). If everything is internal-only, the public-CDN and approval layers disappear and the system gets materially smaller.
2. **Q2 — Can a page ever contain personal, customer or health data?** I assumed a hard no, enforced at review (A2). Given the industry you are in, this is the one I am least comfortable assuming. If the answer is yes, **stop and re-run the decision** — data-protection requirements would be first-class inputs and "public" is probably off the table. Nothing in the current design is built for regulated data.

Non-blocking, but each one is currently a guess of mine (A3–A10 in the doc): which domain and who controls its DNS; which identity provider and whether everyone is in it; whether pages need live data or are fully self-contained; expected pages/authors/traffic in a year; who approves a public page and whether Legal or Brand is in that path; which cloud you are on and the budget ceiling; how long versions must be kept and whether legal-hold immutability applies; whether an external deadline exists; whether the analyst will hand over registrar access so the old links can redirect; and whether you already license a CMS or static host that I should have evaluated first (that last one could change the decision outright).

## Caveats on what is in the document

- **Numbers I did not verify.** The cost line ("single-digit to low-tens of USD/month") is an order-of-magnitude read of list pricing, not a calculator output — producing the real estimate is a roadmap task and Finance should see it before sign-off. The day estimates in the roadmap are one-person engineering days with no review latency, order-of-magnitude only. The LCP ≤ 2.5 s figure is the standard "good" threshold for that metric; the 200 ms TTFB and 60 s publish budgets are mine and negotiable.
- **I named AWS services** (S3, CloudFront, Lambda@Edge, Terraform) on the assumption that you are already on AWS (A8). If not, the same primitives exist elsewhere and the reasoning carries over unchanged; only the names move.
- **The residual security risk is stated, not hidden.** A sibling subdomain still shares the parent domain's cookie scope and carries a subdomain-takeover vector. A separate registrable domain removes both — but it defeats the entire point of your request, so I chose the subdomain and wrote down the mitigations (host-scoped `__Host-` cookies in your apps, DNS records only via IaC, dangling-record audits).
- **The bridge is the plan's biggest process risk.** Phase 1 hands publishing to Git+CI, which the analyst can use and Marketing cannot. If phase 2 never starts, you have solved domain ownership and durability and left the bottleneck exactly where it is. The doc sets an escalation date for that reason; hold it.
- **I did not build a page inventory** because I had no access to the pages. Phase 0 exists for that, and I expect a meaningful fraction of the 30 to be retired rather than migrated.
