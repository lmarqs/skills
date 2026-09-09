# Reply

**Short answer: of your three, Fargate + Aurora Serverless v2. But I am not recommending you build it
yet, and the RFC's status is *proposed*, not accepted.** Two findings outrank the choice you asked me
to make.

**Cost does not discriminate between your three options.** I priced all three at US East list rates
(read 2026-09-08) against an assumed 1M lookups/month: Lambda + Aurora ≈ USD 177/month, Lambda +
DynamoDB ≈ USD 4, Fargate + Aurora ≈ USD 228. Every one of them is between 0.1% and 6% of the USD 4,000
you are paying now. The saving comes from ceasing to pay per request, and all three deliver it, so
picking between them on cost is picking between USD 4 and USD 228 on a USD 4,000 problem. What actually
discriminates is query shapes, the latency floor, coverage and the licence.

**Your three options share four decisions, and none of them had been reviewed.** All three are "build
in-house, in Go, on AWS, on the public postcode dataset". The fourth is the one legal has not confirmed,
which means the shared, unreviewed decision is the load-bearing one. I added the missing options: **D**
keep the providers behind our own cache and proxy, **E** license the postal operator's own dataset,
**F** build on an openly licensed dataset with building-level geometry, **G** hold the dataset in the
process and run no database at all (≈ USD 53/month, and faster than any of yours).

Why Fargate + Aurora, among yours: Aurora because the job is three query shapes, not one — exact
postcode lookup, prefix-and-typo street matching, and nearest-point-in-a-radius. DynamoDB does the
first excellently and neither of the other two without you hand-building an inverted index and a
geohash key design, or running a search system beside it, at which point its advantage is gone. Fargate
because a ~200 MB read-only dataset wants a long-lived process that loads it once and pools database
connections in-process, where Lambda loads a copy per execution environment and needs RDS Proxy; the
USD 52 that costs is noise. Also: **do not set Aurora Serverless v2's minimum capacity to 0.** It pauses
after 300 s idle and resume takes up to 15 s, over 30 s after a day paused (AWS Aurora user guide). That
is a broken address form, and it makes the ≈ USD 175 Aurora floor unavoidable rather than optional.

## Reclassified

| Your input | Where it went, and why |
| --- | --- |
| "Replace the paid APIs with our own service" | A **prior decision** by you, not a requirement. Options D, E and F are its alternatives, and D is what I committed to first |
| "Lambda + Aurora / Lambda + DynamoDB / Fargate + Aurora" | **Design choices**, so they are rows in the tradeoff table, not requirements |
| "All in Go" | A **prior decision**, given its own row so that a choice nobody put on a table gets reviewed once |
| "p95 under 100 ms" | An unfinished **non-functional requirement** — no condition, no derivation, no measurement. Now N1, target labelled *assumed* |
| "~USD 4,000/month" | A **Context number**, labelled *assumed*: it came from you with no invoice attached |
| "Legal hasn't confirmed the dataset" | A **blocking open question** (Q1), in the Decision section with an owner and a date. It holds the status at *proposed* |
| "Recommend one" | What the document does, not something the system does |

## Challenged

1. **The framing.** "Which of these three?" assumes the build. The build is the expensive, hard-to-
   reverse part and it is the part blocked on legal, so the alternatives to building are now in the
   table beside your three.
2. **"Address and geocoding" is two capabilities, and a postcode dataset only replaces one.** Postcode
   → address, yes, outright. Free-text → coordinates and coordinates → address, no: a postcode file has
   no building-level geometry, so you get postcode-centroid accuracy, which is hundreds of metres out in
   a dense urban postcode and kilometres out in a rural one. If a meaningful share of that USD 4,000
   buys geocoding, this project replaces much less than it looks like it does.
3. **100 ms may be the wrong shape of target.** Nobody has measured today's p95, and a cross-internet
   call to a provider rarely lands under 100 ms at p95. So 100 ms is probably an improvement you are
   asking for, not a parity you are defending — which matters, because a cheaper design becomes viable
   if 150 ms costs nothing.
4. **Serverless-first.** Two of your three options were Lambda. I went the other way, on the dataset-load
   and connection-pooling argument, and the cost of arguing that exception is recorded in the row.

## Questions I would have asked, with my recommended answer

Blocking — I would not have written past step 2 without the first two:

1. **May we use the public postcode dataset commercially?** *(Owner: legal. My recommendation: ask for a
   yes/no in writing, and in the same pass ask them to rule on the ODbL option F, so one legal cycle
   answers both.)* If no, options A, B, C and G are all excluded and the decision becomes E, F or D.
2. **What is the monthly request volume, and how does it split between postcode lookup, forward
   geocoding and reverse geocoding — and what coordinate accuracy does each consumer need?** *(Owner:
   you. My recommendation: get it from the provider invoice this week, and instrument it anyway in phase
   1.)* A lookup-dominated mix makes this project worth doing; a geocoding-dominated mix does not.
3. **Does the incumbent contract let us cut spend before renewal, and when is renewal?** *(Owner:
   finance. My recommendation: read the contract before anyone writes code.)* If there is an unexpired
   minimum commitment, the saving starts at renewal and the right move is to run phase 1 and defer the
   build.
4. **Who is the decider, and who reviews?** *(My recommendation: the engineering lead who owns the
   address entry path decides, autocratically, after consulting legal, finance, the product owner for
   address entry, and the on-call lead.)* The document names that role and flags it as assumed.

Non-blocking, but cheap and I would ask them in the same message: which provider(s) and which endpoints
are on the bill; do the clients call the provider directly or through our backend (it changes the
migration cost); and what is the published dataset's actual record count and file size (it decides
whether option G removes the database entirely, and it is minutes of work).

## Assumptions in the document, labelled there and repeated here

- **No number in the document is measured.** I had no bill, no dashboard, no log and no code. Everything
  is *assumed* (with the check that would settle it) or *estimated* (arithmetic shown). The exception is
  cloud list prices and Aurora's pause/resume behaviour, read from vendor and public pricing material on
  2026-09-08 — and the pricing summaries came from public guides rather than the vendor page itself, so
  confirm them before planning against them.
- USD 4,000/month is all address and geocoding, from one provider.
- The dataset is of the order of 10^6 records, so ~200 MB in memory. The whole option-G argument rests
  on this.
- Jurisdiction is Brazil, so the dataset in question is the Correios CEP base and the licensed product
  is the DNE, which Correios licenses commercially with no published price list. If that is wrong, Q1's
  subject changes but its shape does not.
- Callers can tolerate a fallback to a paid provider on a lookup we cannot answer. If any caller
  cannot, N1 needs a per-endpoint target.
- The whole current-usage table is assumed. It is the most valuable thing to replace with measurement,
  and phase 1 does exactly that.

## Requirements I added that you did not ask for

Recorded as stakeholder conflicts in the Decision, so you can strike them on the record:

- **F5 and N5** (versioned dataset with rollback; a staleness alert and a readable licence position).
  They serve two roles that were not in your request: legal counsel, who has to answer for the data in
  production, and the dataset-refresh maintainer — a role this decision creates and nobody has
  volunteered for.
- **N4** (coordinate accuracy per consumer). Left deliberately unset, because the number has to come
  from the consumers of coordinates, and none has been asked. Committing to centroid accuracy without
  asking them would be deciding on their behalf.

## Caveats

- **I committed one thing and only recommended the other.** Phase 1 — our own cache and proxy in front
  of the incumbents, with per-endpoint counters — is decided now, in the light one-page shape, because
  it is a two-way door, it is independent of the legal question, it captures the repeat-lookup share of
  the spend within weeks, and it produces the measurements every requirement above is missing. The build
  sits at *proposed* until Q1, Q2 and Q3 close. I put 2026-09-22 on all three; move the dates, they are
  placeholders.
- **Recommending a build over an open legal question would have been hoping, not deciding.** The RFC
  says what each answer changes, so the decision is pre-made against every outcome rather than
  postponed.
- **The three blocking questions are two weeks of other people's time, not months.** Phase 1 closes Q2
  by itself while legal and finance work on Q1 and Q3.
- **Re-read the tradeoff table once phase 1 lands.** The 1M-lookup volume, the USD 4,000, the 100 ms and
  the dataset size are all assumptions, and three of the four will move.
