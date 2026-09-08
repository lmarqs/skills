# Context and requirements, in depth

Steps 1 and 2 of the method are where these documents are won or lost. Everything downstream is judged
against the requirements, so a requirement that is really a constraint, a solution, or a wish quietly
poisons the design and the tradeoff analysis. This reference gives the classification rules, the
anatomy of a well-formed requirement, what counts as evidence, and the six failures that show up over
and over, each with a before and after drawn from the search-service example in
`example-rfc.md`.

## Contents

1. [Classifying what you were handed](#classifying-what-you-were-handed)
2. [Anatomy of a requirement](#anatomy-of-a-requirement)
3. [Evidence](#evidence)
4. [The six recurring pitfalls](#the-six-recurring-pitfalls)
5. [The prose pass](#the-prose-pass)

## Classifying what you were handed

A request arrives as a flat list: "we need it fast, standardized endpoints, the platform team says
Kafka, over 90% coverage, and it'd be nice to have an ADR directory". Five items, four different kinds
of thing, none of them yet a requirement. Sort each one before you write a line of the document.

| Kind | Test that identifies it | Where it belongs | What it is *not* |
| --- | --- | --- | --- |
| **Constraint** | Imposed from outside this decision. We do not get to choose it here, though we may be able to challenge it at a stated cost | Context, in the constraints table, with source and cost to challenge | Not a requirement. It does not get proved at the end; it is true from the start |
| **Functional requirement** | A user or a calling system exercises it. Delete it and someone notices a capability is gone | Requirements, functional table | Not a description of internals. If only developers would notice, it is not functional |
| **Non-functional requirement** | A quality of *how well* the system behaves, expressed as metric, target, condition and measurement | Requirements, non-functional table | Not an adjective. "Fast" and "observable" are categories, not requirements |
| **Design choice** | A means of meeting a requirement: a technology, a library, a pattern, a topology | Design, or as an alternative in the tradeoff analysis | Not a requirement, even when someone influential named it first |
| **Wish** | Wanted, but nothing fails if it never ships | Out of the requirements: a pro for the options that deliver it, or a roadmap item | Not a requirement at any priority level |

Working the example list through the table:

- *"We need it fast"* — an unfinished non-functional requirement. Needs a metric, a target, a
  condition, and a measurement before it can enter the table.
- *"Standardized endpoints"* — a constraint (an org-wide API standard) with a document as its source.
  Cost to challenge is low for a brand-new endpoint and high for one the mobile app already consumes.
- *"The platform team says Kafka"* — a constraint if the platform team owns that call, a design choice
  if they were making a suggestion. Ask which, and record the answer with a name attached.
- *"Over 90% coverage"* — a constraint if CI enforces it (cite the workflow file), otherwise a delivery
  practice. Either way it is not a quality of the running system, so it does not belong in the
  non-functional table.
- *"Nice to have an ADR directory"* — a wish, and a team practice rather than a system quality. It
  leaves the requirements entirely and becomes a roadmap task.

Tell the reader what you moved and why. A short note under the requirements ("three items you listed
were reclassified: X and Y are constraints, Z is a design choice we evaluate in section 4") is what
turns triage from silent editing into a reviewable act.

## Anatomy of a requirement

Every row carries five fields. The order matters: the goal comes first because it is the part a reader
needs in order to argue with the requirement.

| Field | What goes in it | Why it is there |
| --- | --- | --- |
| **ID** | `F1`, `N1`, … | So Design and the tradeoff analysis can cite it instead of paraphrasing it |
| **Goal** | The outcome in the user's or business's world | A requirement with a goal can be renegotiated when the design gets hard; one without is a rule nobody can reason about. Volere calls this the *Rationale* |
| **Requirement** | What the design must achieve. For a non-functional one: metric, target, condition | The thing itself |
| **Proof** | How fulfilment gets demonstrated when implementation ends | Volere's *Fit Criterion*. Without it, "done" is a matter of opinion |
| **Source** | The Context fact it derives from, or the person who imposed it | Volere's *Originator*. It is what makes the requirement traceable and challengeable |

**The goal has to be derivable from the Context.** If you cannot write the goal from what the Context
already establishes, exactly one of two things is true, and both are worth saying out loud in the
document: the Context is missing evidence you should go get, or the requirement was invented and should
be dropped.

**Non-functional requirements need all four parts.** A quality-attribute scenario in the sense of Bass,
Clements & Kazman answers: under what condition, given what stimulus, what response, measured how.

- Not a requirement: *"Search should be fast."*
- Still not a requirement: *"Search p95 under 3 s."* No condition and no measurement, so nobody can
  fail it honestly.
- A requirement: *"p95 of `GET /search/find-all-by-term` stays at or below 3,000 ms at the peak load
  modelled in Context, measured by a k6 run in staging that reproduces that peak."*

**Every requirement is provable at the end.** The proof column is the test of whether the row is a
requirement at all. "The team should feel confident in the new service" has no proof and therefore is
not a requirement; it is a goal, and it belongs in the goal column of whatever requirement actually
serves it.

## Evidence

The Context is an argument about the current state, and an argument about the current state runs on
numbers. Each one carries where it came from, inline, next to the claim rather than in a footnote or a
linked document.

What counts, roughly in descending order of strength:

| Kind | Example of how it appears in the text |
| --- | --- |
| Query and result | "38% of searches filter by location (`SELECT count(*) … WHERE location IS NOT NULL` over 2026-03, 1.2M of 3.1M rows)" |
| Benchmark or load run | "the current endpoint sustains 180 rps before p95 crosses 3 s (k6, staging, 2026-04-11)" |
| Dashboard or monitor | "p95 of the search endpoint sat at 4.1 s over the last 30 days (Datadog `search-latency` board, read 2026-04-12)" |
| Source code | "the ranking rules live in `search/ranking.py:212-388` and are duplicated in the Rest API at `api/search.rb:96`" |
| Incident or ticket | "INC-4471: the nightly reindex saturated the database for 22 minutes" |
| Bill or cost report | "Elasticsearch ran USD 2,840 in March (AWS cost explorer, tag `service:search`)" |
| Screenshot or chart | Attach it and state what it shows in the sentence, so the argument survives without the image |

Label every fact with how you know it:

- **measured** — observed by you or a named source, with the query, run or board that produced it.
- **estimated** — derived from something measured. Show the arithmetic: "≈360 concurrent requests at
  peak (18,000 searches/hour ÷ 3,600 × 72 s median session, estimated)".
- **assumed** — nobody has checked. Say what would confirm it and roughly what confirming it costs:
  "we assume ranking parity matters to conversion; a two-week A/B on the top 500 terms would tell us".

**Get the number before asking for it.** Reading the schema, running the query, grepping the ranking
code, or opening the cost report is usually faster than a round trip with the user, and it turns the
document from hearsay into something first-hand. Ask the user for what only they know: business intent,
deadlines, who decides, what happened in a meeting.

## The six recurring pitfalls

### 1. Implementation details land in the requirements

**Problem.** A technology in the requirements list is a decision that skipped the analysis. Nobody
weighs alternatives to something already written down as non-negotiable.

**Before**

> ### Non-functional
> - Observability: structured logs with a correlation ID, OpenTelemetry tracing over requests and the
>   database, latency/error dashboards.

**After**

> | ID | Goal | Requirement (metric, target, condition) | Proof | Source |
> | --- | --- | --- | --- | --- |
> | N2 | On-call finds the cause of a failed search without reproducing it | Any failed request is traceable end to end from its correlation id within 5 minutes of the page | Game-day drill on the new service before launch | INC-4471, where the cause took 3 hours (measured) |

OpenTelemetry then appears in Design as the choice that meets N2, next to the alternatives that were
weighed against it.

### 2. Functional and non-functional get confused

**Problem.** The split is not "important vs. technical". Functional is what the system does, visible
from outside; non-functional is how well it does it, and it always carries a metric.

**Before**

> ### Non-functional
> - Standardized endpoints (resource name, pagination, parameters, responses) and consistent errors.
> - Automated test coverage > 90%, including a flow that validates ranking.

**After.** Neither is a quality of the running system. Both move to the constraints table:

> | Constraint | Source | Cost to challenge |
> | --- | --- | --- |
> | Public endpoints follow the company API standard | API guidelines doc, owned by the platform guild | Low for new endpoints; high for ones the mobile app already consumes |
> | Merges gated by the repo coverage threshold | `.github/workflows/ci.yml:38` | Low: team practice, changeable in a PR |

The ranking-validation flow is a *proof*, not a requirement: it becomes the Proof cell of the
functional requirement about ranking parity.

### 3. Wishes listed as requirements

**Problem.** A list that mixes the mandatory with the desirable makes every entry negotiable, and the
document can no longer be checked at the end.

**Before**

> - (*Nice to have*) An ADR directory versioning the architectural decisions.

**After.** Out of the requirements. If it matters, it is a roadmap task; if an alternative happens to
deliver it, that is a pro in that alternative's row. Gilb's Planguage is blunt about this: a *Wish* is
a stated value with no commitment behind it, which is precisely what a requirement cannot be.

### 4. Requirements without justification

**Problem.** The most damaging of the six, because an unjustified requirement cannot be renegotiated.
When the design gets expensive, the team either pays for a requirement nobody wanted or quietly drops
one that mattered.

**Before**

> - **Schedule search with response time ≤ 3,000ms at p95, validated under load.**

**After**

> | ID | Goal | Requirement (metric, target, condition) | Proof | Source |
> | --- | --- | --- | --- | --- |
> | N1 | Users abandon a schedule search that takes longer than about 3 s, and abandonment is the top drop-off in the funnel | p95 of schedule search stays at or below 3,000 ms at the peak load modelled in Context | k6 run in staging reproducing that peak | Funnel dashboard, 2026-03 cohort: 31% drop-off above 3 s (measured) |

Now a reader can argue with the number. Maybe 3.5 s costs almost nothing in abandonment, and the
cheaper design becomes viable. That conversation is impossible without the goal.

### 5. Context without evidence

**Problem.** Unsourced numbers get quoted for years and quietly become the basis of decisions nobody
can re-derive.

**Before**

> Search today is served two different ways and it now costs us in latency, in money, and in
> maintenance bugs from keeping two sources in sync.

**After**

> Search is served two ways today: straight from the transactional database and from Elasticsearch,
> stitched across two APIs. The cost shows up in three places. Latency: p95 of the search endpoint sat
> at 4.1 s over the last 30 days (Datadog `search-latency` board, read 2026-04-12; measured). Money:
> Elasticsearch ran USD 2,840 in March (AWS cost explorer, tag `service:search`; measured).
> Maintenance: 7 of the 19 search bugs closed in the last two quarters were sync divergences between
> the two sources (Jira filter `component=search AND label=sync`; measured).

Where you have no number, say so in the same voice: "we believe the nightly reindex is the main source
of daytime latency spikes, but nobody has correlated the two; an hour with the reindex logs and the
latency board would settle it (assumed)."

### 6. The document does not stand alone

**Problem.** A "Related documents" list at the top and cross references throughout turn reading into
tab management. The reader loses the argument between hops and stops following it.

**Before**

> ## Related documents
> - Solution diagram
> - Overview of the current search endpoints
> - Design of the new search API
> - Mapping of the new endpoints

**After.** Nothing at the top. The endpoints the reader needs are listed in the text where they matter,
the diagram is embedded, and provenance moves to a closing section:

> ## Sources
> - Datadog `search-latency` board, read 2026-04-12 (p95 figures in Context).
> - AWS cost explorer, tag `service:search`, March 2026 (Elasticsearch cost).
> - Solution diagram, Figma file `search-v2` (the version embedded above).

Two habits go with the rule. **Inline what the argument needs**: the number, the query, the log line,
the relevant clause of the standard, not a pointer to where they live. And **use one name per
concept**: pick "the search service" and never drift into "the service", "the API", "the search layer".
Drifting vocabulary is the main reason a document feels convoluted even when every individual sentence
is clear.

## The prose pass

Read the finished document once for the tells that make it tiring, then fix them:

- Bullet lists whose items are really sentences. If the items connect, they are a paragraph.
- Bold-word headers standing in for topic sentences ("**Performance.** The system is fast."). Write the
  sentence.
- Lists padded to three items because three feels complete. Two is a fine number.
- Vague attribution: "studies show", "it is well known", "best practice suggests". Name the source or
  drop the claim.
- Gap-filling: plausible detail invented where you had no evidence. Label it assumed or cut it.
- A closing paragraph that restates the summary. End on the decision and its consequences.

If the `humanizer` skill is installed, run it in embedded mode as a final pass on the prose. It is a
polish step, not a dependency: the rules above are what matter, and they apply whether or not the skill
is available.
