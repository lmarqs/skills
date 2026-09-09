# Context and requirements, in depth

Steps 1 and 2 of the method are where these documents are won or lost. Everything downstream is judged
against the requirements, so a requirement that is really a prior decision, a solution or a wish
quietly poisons the design and the tradeoff analysis. This reference gives the classification rules,
the tests for goals and roles, the anatomy of a well-formed requirement, what counts as evidence, how
to handle open questions, a catalogue of requirement defects drawn from the literature, the words that
fail, and the prose pass. Examples are drawn from the search-service decision in `example-rfc.md` and
from documents reviewed while building this skill, with names and figures removed.

## Contents

1. [Classifying what you were handed](#classifying-what-you-were-handed)
2. [Goals](#goals)
3. [Roles: current usage and stakeholders](#roles-current-usage-and-stakeholders)
4. [Anatomy of a requirement](#anatomy-of-a-requirement)
5. [Evidence](#evidence)
6. [Assumptions, open questions and the proof-of-concept contract](#assumptions-open-questions-and-the-proof-of-concept-contract)
7. [Requirement defects, by name](#requirement-defects-by-name)
8. [Words that fail](#words-that-fail)
9. [The prose pass](#the-prose-pass)

## Classifying what you were handed

A request arrives as a flat list: "we need it fast, endpoints follow the company standard, the
platform team says we use the message broker they run, coverage above 90%, an ADR directory would be
nice, the marketing team does not use a terminal, keep it minimal, and the regulator requires seven
years of retention". Eight items, six kinds of thing, one requirement among them. Sort each item before
you write a line of the document.

| Kind | Test that identifies it | Where it belongs | What it is *not* |
| --- | --- | --- | --- |
| **Constraint** | Imposed from outside the organization, or a signed commitment: law, regulation, contract, physics, an approved budget, a regulator's date | Context, constraints table, with source and the clause that excludes what it excludes | Not a requirement, and not anything a colleague decided |
| **Prior decision** | Made by a person or team inside the organization: the platform, the language, an org standard, a previous ADR, "the platform team said so" | Context, prior decisions table, with author, incumbent and cost to reverse; the incumbent enters the tradeoff table beside an alternative | Not a constraint. It never excludes an option |
| **Functional requirement** | A role exercises it. Delete it and that role notices a capability is gone | Requirements, functional table, with the role named in the requirement | Not a description of internals. If only developers would notice, it is not functional |
| **Non-functional requirement** | A quality of *how well* the system behaves, expressed as metric, target, condition, derivation and measurement | Requirements, non-functional table | Not an adjective. "Fast" and "secure" are categories |
| **Design choice** | A means of meeting a requirement: a technology, a library, a pattern, a topology | Design, or a row in the tradeoff table | Not a requirement, even when someone influential named it first |
| **Wish** | Wanted, but nothing fails if it never ships | Out of the requirements: a pro for the options that deliver it, or a roadmap item | Not a requirement at any priority label |

Two more kinds arrive dressed as constraints and go elsewhere: a **stakeholder attribute** ("the
marketing team does not use a terminal") goes to the stakeholder table as what that role needs; a
**scope or risk posture** ("keep it minimal", "this is an MVP") goes to the decision drivers in step 4.

Working the example list through the table:

- *"We need it fast"*: an unfinished non-functional requirement. Needs metric, target, condition,
  derivation and measurement before it can enter the table.
- *"Endpoints follow the company standard"*: a prior decision (the guild that wrote the standard is
  inside the organization). Cost to reverse is low for a new endpoint and high for one the mobile app
  already consumes.
- *"The platform team says we use their broker"*: a prior decision with an author. The broker gets a
  row in the tradeoff table and so does at least one alternative.
- *"Coverage above 90%"*: a prior decision if CI enforces it (cite the workflow file), otherwise a
  delivery practice. Either way it is not a quality of the running system.
- *"An ADR directory would be nice"*: a wish, and a team practice rather than a system quality. It
  leaves the requirements and becomes a roadmap task.
- *"The marketing team does not use a terminal"*: a stakeholder attribute. It becomes what the
  "analyst publishing a page" role needs from the decision.
- *"Keep it minimal"*: a risk posture. It becomes a decision driver, with the reason stated.
- *"The regulator requires seven years of retention"*: the one constraint, with the regulation and
  its clause as the source. It may exclude a store that cannot retain for seven years, and the row says
  so.

Tell the reader what you moved and why. A short note under the requirements ("four items you listed
were reclassified: X and Y are prior decisions, Z is a design choice we evaluate in section 4, W is a
constraint") turns triage from silent editing into a reviewable act. If the team already ranks with
MoSCoW (Clegg, 1994), only *Must* is a requirement; *Should* and *Could* become drivers or pros, and
*Won't* goes to Out of scope.

## Goals

A goal is an outcome for a role, stated without a system feature, a technology or a system metric in
it. Goals are what requirements are derived from, which is why the goal is more important than the
requirement: a requirement with a goal can be renegotiated when the design gets hard, a requirement
without one is a rule nobody can reason about. In goal-oriented requirements engineering (van
Lamsweerde, 2001) goals are refined until each leaf can be assigned to an agent; the leaves assigned to
the software are the requirements, the ones assigned to people or the environment are expectations. A
"goal" that already names the software's behaviour has skipped the refinement.

Three tests, applied to every candidate:

- If you could build it, it is a requirement.
- If you could choose it, it is an option.
- If it says "produce this design" or "define the architecture", it is the document describing itself,
  and it is not a goal.

**Before**

> Objectives: (1) operational autonomy: the team uploads and removes files without a developer;
> (2) simplicity: a drag-and-drop interface like the hosting panel they know; (3) move to the corporate
> subdomain; (4) cost within the current cloud budget; (5) auditability.

Every item is a requirement or an option. (1) is a functional requirement for the "analyst publishing a
page" role, (2) names a solution, (3) is a prior decision or a requirement, (4) is a non-functional
requirement missing its number, (5) is a capability. None says what outcome the organization gets.

**After**

> | Goal | Who benefits | How we will know |
> | --- | --- | --- |
> | Analysts publish their own analysis pages the day they finish them | Growth analysts; the developers they no longer interrupt | Median time from "page ready" to "page live" drops from 4 working days (ticket queue, last quarter; measured) to under one |
> | Internal tools carry the company's name and outlive any one employee's account | Every reader of those pages | Zero pages served from a personal domain after cutover (inventory of links, checked monthly) |

The requirements then derive from these rows, and their Goal column points at them.

## Roles: current usage and stakeholders

"Marketing", "Finance" and "the CTO" are departments and titles. A role says what a person does with
the system, and it is the unit everything else attaches to: the deletion test asks *who* notices, the
scenario names *who* acts, the goal names *who* benefits. Alexander's onion model (*A Taxonomy of
Stakeholders*, 2005) places roles by how they touch the system: operators who run it, functional
beneficiaries who use what it produces, maintainers, regulators, sponsors, and the negative stakeholders
who lose something if it succeeds. Cockburn's use cases start from the same place: an actor with a goal
against the system.

Two tables carry the roles. In Context, what each role does today:

| Role (what they do with the system) | What they do today | Through what | How often or how much (source) |
| --- | --- | --- | --- |
| Patient searching for a procedure by name or code | Types a term in the search modal, picks a result, books a slot | Web app and mobile app calling the public search endpoint | 18,000 searches/hour at the daily peak (latency board, read 2026-04-12; measured) |
| Support agent resolving "the slot was not available" | Looks the booking up, refunds, rebooks by hand | Admin panel | 11% of Q1 contacts (support ticket tag `wrong-location`; measured) |

In the stakeholder table, what each role needs from this decision and who speaks for them:

| Role (what they do with the system) | What they need from this decision | Who speaks for them |
| --- | --- | --- |
| Compliance analyst answering an audit question | Every admin action on a record, found within the working day | Head of compliance |
| On-call engineer diagnosing a failed search | The failing request traceable end to end from its correlation id | Search team lead |
| Database owner protecting the booking flow | No new read load on the primary without a ceiling | DBA |

**Before**

> Stakeholders: Marketing, Tech, the CTO.

**After**

> | Role | What they need from this decision | Who speaks for them |
> | --- | --- | --- |
> | Growth analyst publishing an analysis page | Upload, replace and remove a page without a ticket | The analyst who built the current pages |
> | Colleague reading an analysis page | The page loads on the corporate domain, on any office machine | Head of growth |
> | Operator answering "who changed this file" | The change, the account and the time, for the last 90 days | The engineering lead |

Each functional requirement then names the role it serves in its Requirement cell.

## Anatomy of a requirement

Every row carries the fields below. The order matters: the goal comes first because it is the part a
reader needs in order to argue with the requirement.

| Field | What goes in it | Why it is there |
| --- | --- | --- |
| **ID** | `F1`, `N1`, and so on | So Design and the tradeoff table can cite it instead of paraphrasing it |
| **Goal** | A row of the Goals table | A requirement with a goal can be renegotiated; one without is a rule nobody can reason about. Volere calls this the *Rationale* |
| **Requirement** | Functional: the role, and what the system does for it. Non-functional: metric, target, condition | The thing itself |
| **Derived from** (non-functional only) | The current measured value with source and date, plus the reason for the delta; or an external reference; or a named stakeholder commitment | A target with no derivation is a number with no argument. Gilb's Planguage keeps the benchmark levels *Past*, *Record* and *Trend* beside the *Goal* for exactly this reason |
| **Proof** | Functional: the scenario, and how it is run. Non-functional: the measurement, and by what | Volere's *Fit Criterion*. Without it, "done" is a matter of opinion |
| **Source** | The Context fact it derives from, or the person who imposed it | Volere's *Originator*. It is what makes the requirement traceable and challengeable |

**Scenario first, requirement second.** For a functional requirement, write the scenario before the
sentence: the role, the situation, the action, the observable result. Given/When/Then (North, 2006) is
a fine shape for it. The requirement is the generalization of its scenarios, written afterwards. Two
tests fall out. If the scenario cannot be written, the requirement is not understood yet. If the
scenario can only be written with a product name in it, the requirement is a solution.

- Scenario: *Given a patient in a city with no clinic offering the procedure, when they search for it,
  then every result shown either offers telehealth or is bookable in that city.*
- Requirement (its generalization): *A patient sees only results they can book from the location they
  gave, telehealth counting as bookable anywhere.*
- Proof: the scenario, run as an end-to-end test per location tier, plus a production check on booking
  attempts rejected for location.

For teams that want a fixed sentence form, EARS (Mavin et al., 2009) gives one: *While <precondition>,
when <trigger>, the <system> shall <response>.* It forces a subject, a trigger and a response into
every sentence, which is most of what the words table below is for.

**Every non-functional requirement carries five parts.** A quality-attribute scenario in the sense of
Bass, Clements and Kazman answers: under what condition, given what stimulus, what response, measured
how. To that the derivation is added.

- Not a requirement: *"Search should be fast."*
- Still not a requirement: *"Search p95 under 3 s."* No condition, no measurement, and no argument
  for 3.
- A requirement: *"p95 of the search-by-term endpoint stays at or below 3,000 ms at the peak modelled
  in Context (≈360 concurrent requests). Derived from: today's 4,100 ms (latency board, 30 days to
  2026-04-12; measured) and the funnel's 31% drop-off above 3 s (funnel dashboard, 2026-03 cohort;
  measured). Measured by the load run in staging that reproduces the peak, in CI before each release."*

**Every requirement is provable at the end.** The Proof cell is the test of whether the row is a
requirement at all. "The team should feel confident in the new service" has no proof and is therefore
not a requirement; it is a goal, and it belongs in the Goals table.

## Evidence

The Context is an argument about the current state, and an argument about the current state runs on
numbers. Each one carries where it came from, inline, next to the claim rather than in a footnote or a
linked document. Name the instrument and the date, and name them as the reader knows them: "the p95
latency board, 12 Aug", "the July cost report", "issue 4182", "the load run of 3 Sep". Where the
instrument has a product name, use it. A reader who cannot tell which dashboard a number came from
cannot check it.

| Kind | How it appears in the text |
| --- | --- |
| Query and result | "38% of searches filter by location (`SELECT count(*) … WHERE location IS NOT NULL` over 2026-03, 1.2M of 3.1M rows)" |
| Benchmark or load run | "the current endpoint sustains 180 rps before p95 crosses 3 s (load run, staging, 2026-04-11)" |
| Dashboard or monitor | "p95 of the search endpoint sat at 4.1 s over the last 30 days (latency board, read 2026-04-12)" |
| Source code | "the ranking rules live in `search/ranking.py:212-388` and are duplicated at `api/search.rb:96`" |
| Incident or ticket | "INC-4471: the nightly reindex saturated the database for 22 minutes" |
| Bill or cost report | "the search cluster ran USD 2,840 in March (cloud cost report, tag `service:search`)" |
| Survey | "75% of respondents report the documentation is spread across tools (internal survey, n=24, 2025-06)": a percentage without its n and date is not a number |
| Screenshot or chart | Attach it and state what it shows in the sentence, so the argument survives without the image |

Label every fact with how you know it:

- **measured**: observed by you or a named source, with the query, run or board that produced it.
- **estimated**: derived from something measured. Show the arithmetic: "≈360 concurrent requests at
  peak (18,000 searches/hour ÷ 3,600 × 72 s median session; estimated)".
- **assumed**: nobody has checked. Say what would confirm it and roughly what confirming it costs. A
  figure the user states with no source is *assumed*, with the user as its origin.

**Get the number before asking for it.** Reading the schema, running the query, grepping the code, or
opening the cost report is usually faster than a round trip with the user, and it turns the document
from hearsay into something first-hand. Ask the user for what only they know: business intent,
deadlines, who decides, what happened in a meeting.

## Assumptions, open questions and the proof-of-concept contract

An open question is **blocking** when any of its answers would change the decision: whether a data
source may be used commercially, whether a regulation applies, whether the incumbent platform can meet
a target at all. Blocking questions carry an owner and a date, sit in the Decision section where the
recommendation is, and hold the status at *proposed* until closed. A blocking question filed as a
"risk" near the end of the document is a decision made by hoping.

A proof of concept or a spike is the way to close a blocking question, and it only counts as one if it
states, before it runs, three things:

| Before it runs | Example |
| --- | --- |
| The question it answers | Can the database reproduce the search engine's first-page ranking for the top 500 terms? |
| The pass criterion | At least 490 of 500 terms with zero position differences on the first page |
| What each outcome changes | Pass: the database option stays and the cluster is retired. Fail: the cluster stays for those query shapes behind a flag, and the cost target moves |

"We will build a POC with two tools" with none of the three is a deferral, not a decision.

**Non-blocking** assumptions are what you proceed on without proof: state each, its label, and what
would close it. They are the honest part of the document, not the weak part.

## Requirement defects, by name

The catalogue below is built from sources that predate this skill: Meyer's seven sins of the specifier
(*On Formalism in Specifications*, IEEE Software, 1985), the characteristics ISO/IEC/IEEE 29148 asks
of a requirement and of a set, Volere's rationale and fit criterion, Gilb's commitment and benchmark
levels, van Lamsweerde's goal refinement, Zave and Jackson's distinction between requirements (about
the environment) and specifications (about the machine), and Alexander's stakeholder taxonomy. The last
column records whether the defect was observed in the documents reviewed while building the skill. The
catalogue does not depend on that column; the column is expected to change as more documents are read.

| Defect | Source | What it looks like | Test | Fix | Seen |
| --- | --- | --- | --- | --- | --- |
| Noise | Meyer | An API specification, a log-field dictionary and test code inside a decision document; a row that repeats another; "the architecture must be robust" | Delete it: does any decision change? | Cut, or move to a task the decision produces | yes |
| Silence | Meyer; ISO *complete* | A requirement ID referenced but never defined; a role in the stakeholder table with no requirement; a failure mode nobody wrote down | Every referenced ID exists; every role has a row or an explicit "none" | Write the row or the "none" | yes |
| Overspecification | Meyer; Zave & Jackson | "Must use the broker the platform team runs"; "audit log"; "structured JSON logs"; "an interface like the hosting panel" | Can the scenario be written without the product or mechanism? | Capability for a role; the product goes to Design or to a tradeoff row | yes |
| Contradiction | Meyer; ISO *consistent* | "Minimum replication time of up to two minutes"; "volume is unknown" in one section and "a limit above legitimate use" in another; a constraint duplicating a requirement in different words | A number quoted twice agrees with itself; no two rows say the same thing | One statement, one place | yes |
| Ambiguity | Meyer; ISO *unambiguous* | "Support 20 concurrent users" (doing what?); "fast"; "intuitive" | Two readers would run the same measurement | The five-part form; the words table | yes |
| Forward reference | Meyer | "Related documents" at the top; the diagram in another tool; a score from a spreadsheet the reader cannot see; "see the section below" | The document reads in order with no second tab open | Inline the number, the diagram, the clause; Sources at the end | yes |
| Wishful thinking | Meyer | "Never lose a message"; "guarantee 100%"; "the content will be authentic" | The measurement and the level below which it fails can be named | The measured condition and its fail level | yes |
| Missing rationale | ISO *necessary*; Volere *rationale*; van Lamsweerde | A requirement row with an empty or circular Goal cell | The Goal cell points at a row of the Goals table | Write the goal from the Context, or drop the row | yes |
| No fit criterion | ISO *verifiable*; Volere *fit criterion* | "The project should be well documented"; "the team feels confident" | The Proof cell holds a runnable check | A scenario or a measurement, or the row becomes a goal | yes |
| Optional in the mandatory list | Gilb *Wish* level; MoSCoW | "(Nice to have) an ADR directory" | Nothing fails if it never ships? | A pro for the options that deliver it, or a roadmap item | yes |
| Unanchored target | Gilb *Past*, *Record*, *Trend*; INCOSE rationale | "p95 below 3 s" with no current value; a rate limit sized while volume is "unknown"; a factor of ten with no reason | The Derived-from cell is filled | Measure the current value; state the reason for the delta, or label the target assumed | yes |
| Partial recorded as met | ISO *complete*; the requirements column of the tradeoff table | "Not possible per flag, however the cache expires when a flag changes" listed as compliance | The cell says *met*, *partial* or *missed*, and *partial* names the gap | Record the gap and its consequence | yes |
| Unsourced claim | ISO traceability; Clements et al., *record rationale* | "75% of users report…", "costs about X a month", "p95 was around 5 s" with no board, query or date | Every number has a source inline and a label | Source and label, or *assumed* with the way to confirm it | yes |
| Goals stuffed with requirements and options | van Lamsweerde | An Objectives list naming a UI style, a hostname, a budget and a capability | Each goal is an outcome for a role, with no feature, technology or system metric | The Goals table; the items move to their tables | yes |
| Stakeholders as departments | Alexander; Cockburn | "Marketing, Tech, the CTO" | Each role says what it does with the system | The usage-role table | yes |
| Prior decision dressed as a constraint | ISO 29148's definition of constraint; Bass, Clements & Kazman | "Use only the tools we have today"; "the platform team standardized on X" | The source is outside the organization or a signed commitment | The prior decisions table; the incumbent and an alternative in the tradeoff table | yes |
| Hidden shared decision | Richards & Ford; *be the architect* | Three options that are all "build an internal service in language L"; a title that names the product; a compliance checklist for one tool as the whole analysis | Write down what every option shares; each element is a constraint, a prior decision with a row, or a missing option | Add the missing option or the row | yes |
| Blocking question buried | Nygard's status lifecycle; Meyer *silence* | A legal question in a data-loading appendix below the recommendation; "under analysis" in a requirement cell; "we will do a POC" with no criterion | Blocking questions in the Decision with owner and date; the proof-of-concept contract | Move it, own it, date it; hold the status at proposed | yes |
| Architect's unjustified addition | ISO *necessary*; Alexander's negative stakeholders | "The requester said they do not want audit, but we as tech think it matters" and then the design has it | The added row names a role and its goal, and the conflict is recorded | The role, the goal, the recorded conflict | yes |

### Where the original six land

This skill began from six defects one team observed in its own documents. Mapping them onto the
catalogue is a critique as much as a confirmation:

- *Implementation details treated as immutable requirements* is two defects, not one: overspecification
  (a mechanism inside a requirement) and a prior decision dressed as a constraint (a colleague's choice
  excluding options). They are fixed in different places.
- *Functional and non-functional confused* is a symptom. The distinction itself is contested in the
  literature (Glinz, *On Non-Functional Requirements*, RE 2007, shows the usual taxonomy leaks). The
  defect underneath is a quality with no measure, which is ambiguity plus no fit criterion. The label
  earns its place only because the non-functional table forces the five parts.
- *Wish-list items as requirements, with nothing saying how they will be proven* is also two: optional
  in the mandatory list, and no fit criterion. Meyer's "wishful thinking" is a third, different thing
  (a requirement nothing could meet or verify), so the name was being used for two defects at once.
- *Requirements not justified* maps onto one well-attested defect, missing rationale, and the claim
  that the justification matters more than the requirement follows from goal refinement: the
  requirement is derived, the goal is the source.
- *Context claims without evidence* and *documents that do not stand alone* are real, and they are
  document-level defects, not requirement-level ones. Meyer's forward reference is the requirement-scale
  version of the second.
- Ten defects in the table were not in the six and were present in the reviewed documents: noise,
  silence, contradiction, unanchored target, partial recorded as met, goals stuffed with requirements,
  stakeholders as departments, hidden shared decision, blocking question buried, and the architect's
  unjustified addition.

### Before and after, for the most frequent

**Overspecification**

> Before: *Observability: structured logs with a correlation ID, distributed tracing over requests and
> the database, latency and error dashboards.*

> | ID | Goal | Requirement (metric, target, condition) | Derived from | Proof | Source |
> | --- | --- | --- | --- | --- | --- |
> | N2 | On-call finds the cause of a failed search without reproducing it | Any failed request is traceable end to end from its correlation id within 5 minutes of the page | INC-4471 took 3 h 10 m to diagnose (post-mortem; measured); 5 minutes is the on-call lead's commitment | Game-day drill before launch | INC-4471 |

The tracing library then appears in Design as the choice that meets N2, beside the alternatives.

**Prior decision dressed as a constraint**

> Before: *Constraints: runs on the existing container cluster (platform team); uses the message broker
> the platform team operates.*

> | Prior decision | Who made it, when | Incumbent it implies | Cost to reverse |
> | --- | --- | --- | --- |
> | Standardize compute on the existing container cluster | Platform team, 2025-11 | Cluster deployment | Medium: a second runtime needs an owner; two services already run serverless |
> | One message broker for the company | Platform team, 2025-06 | The operated broker | High for existing consumers; low for a new producer |

Both incumbents get a row in the tradeoff table, and so does an alternative to each.

**Unanchored target**

> Before: *The schedule-search endpoint responds in at most 3,000 ms at p95, validated under load.*

> | ID | Goal | Requirement | Derived from | Proof | Source |
> | --- | --- | --- | --- | --- | --- |
> | N1 | Patients complete the search they started | p95 of schedule search at or below 3,000 ms at the modelled peak | Today 4,100 ms (latency board, 30 days to 2026-04-12; measured); 31% drop-off above 3 s (funnel dashboard, 2026-03 cohort; measured), so 3 s is where the loss begins | Load run in staging at the modelled peak, in CI | Funnel dashboard; latency board |

Now a reader can argue with the number. If 3.5 s costs almost nothing in abandonment, the target moves
and a cheaper design becomes viable.

**Unsourced claim**

> Before: *Search today is served two different ways and it now costs us in latency, in money, and in
> maintenance bugs from keeping two sources in sync.*

> After: *Search is served two ways today, from the transactional database and from the search cluster,
> stitched across two APIs. The cost shows up in three places. Latency: p95 of the search endpoint sat
> at 4.1 s over the last 30 days (latency board, read 2026-04-12; measured). Money: the cluster ran
> USD 2,840 in March (cloud cost report, tag `service:search`; measured). Maintenance: 7 of the 19
> search bugs closed in the last two quarters were sync divergences (issue tracker, component `search`,
> label `sync`; measured).*

Where you have no number, say so in the same voice: "we believe the nightly reindex is the main source
of daytime latency spikes, but nobody has correlated the two; an hour with the reindex logs and the
latency board would settle it (assumed)."

**Hidden shared decision**

> Before: *Alternatives: (A) serverless functions with a serverless relational database; (B) serverless
> functions with a key-value store; (C) containers with the serverless relational database. Language: Go
> in all three.*

Everything shared is a decision: build an internal service, in Go, on this cloud. None has a row.

> After: *What every option shares: an internal service (a prior decision by this team, 2026-07; the
> alternative is to keep the paid providers behind a proxy and a cache, added as option D), the
> language (prior decision, row added with the incumbent language beside it), and the cloud provider
> (prior decision, 2024; cost to reverse high, recorded in each row). Option E, licensing the official
> dataset, is added because the legal question in the Decision may force it.*

**Blocking question buried**

> Before, in section 8 of 11: *Legal alert: the postcode base is licensed by the postal operator; the
> legal department should assess the source before go-live.*

> After, in the Decision: *Blocking question: may the public postcode dataset be used commercially?
> Owner: head of legal. Date: 2026-09-30. If no, options A to C fall back to option E (license the
> official dataset), which changes the cost driver. Status stays proposed until answered.*

## Words that fail

Words a reviewer will strike, with the move that replaces them. The classes come from ISO/IEC/IEEE
29148's list of language to avoid (superlatives, subjective language, vague pronouns, ambiguous adverbs
and adjectives, loopholes, open-ended non-verifiable terms, comparatives, negative statements) and
from the INCOSE *Guide to Writing Requirements* (R7 vague terms, R9 escape clauses, R10 open-ended
clauses, R28 absolutes).

| Word class | Example | Why it fails | Replacement move |
| --- | --- | --- | --- |
| Absolutes | always, never, guarantee, 100%, all | Nothing is verifiable at 100%, and the architecture guarantees nothing; it enables | The measured condition, and the level below which it fails |
| Architecture as agent, or no subject | "the architecture ensures", "it must be possible to", "the responsibility falls to the architecture" | There is no architecture responsible for anything; a role does something and the system responds | The role and the system as subjects: *when X, the system shall Y for role Z* |
| Evaluative adjectives | intuitive, clear, better, quality, authentic, makes sense, robust | A value judgement cannot be measured or tested | A metric, or delete the word |
| Selling language in a goal | "will improve communication", "increases efficiency", "brings more security" | A goal states a need, it does not persuade | The need in the role's words, and the measure that shows it met |
| Escape clauses | where possible, if needed, as appropriate, when applicable | A documented excuse for not meeting the requirement | Delete, or state the condition precisely |
| Comparatives without a baseline | faster, cheaper, more reliable, scalable | Compared with what, measured when? | The number against the *Past* value |
| Vague quantities | some, several, many, about, a few, most | Two readers, two counts | The number, or the range with its source |
| Solution verbs in a requirement | "implement a cache", "use a queue", "log to" | A mechanism, not a capability | What the role can do or observe; the mechanism goes to Design |
| Anticipation | "for future integrations", "prepared for", "will eventually" | A requirement for a problem that has not arrived | Delete, or a driver with its reason |

## The prose pass

Read the finished document once for the tells that make it tiring, then fix them:

- Bullet lists whose items are really sentences. If the items connect, they are a paragraph.
- Bold-word headers standing in for topic sentences ("**Performance.** The system is fast."). Write
  the sentence.
- Lists padded to three items because three feels complete. Two is a fine number.
- Vague attribution: "studies show", "it is well known", "best practice suggests". Name the source or
  drop the claim.
- Gap-filling: plausible detail invented where you had no evidence. Label it assumed or cut it.
- A closing paragraph that restates the summary. End on the decision and its consequences.
- Any word from the table above surviving in a requirement or a goal.

If the `humanizer` skill is installed, run it in embedded mode as a final pass on the prose. It is a
polish step, not a dependency: the rules above are what matter, and they apply whether or not the
skill is available.
