---
name: architecture-design
description: >-
  Acts as the architect, not the scribe: challenges the inputs, then writes a structured architecture
  decision document (RFC / design doc / ADR) recording *why* a non-trivial technical choice was made.
  Method: size the decision, contextualize with sourced evidence, separate constraints from
  requirements and give every requirement a goal and a proof, design components against them with
  static + dynamic diagrams, weigh every alternative by pros / cons / risks (each with impact,
  probability, mitigation, contingency), then record the decision, its consequences and its
  confirmation. Writes in the request's language. Reach for it whenever someone is choosing between
  technical options or documenting one: "write an RFC", "design doc", "architecture decision", "ADR",
  "tradeoff analysis", "technical documentation of an implementation", "help me decide between X and
  Y", even if they never say "RFC". Also fits the retrospective variant:
  documenting an implementation after the fact (lessons learned, version history).
---

# Architecture decision document

The real work is **structured thinking about a technical decision**: framing the problem, weighing the
options against what actually matters, and committing with reasons. The written artifact is the *trace*
that thinking leaves behind, so the next person (a new hire, a reviewer, your future self) can follow
not just *what* was chosen but *why*, and could have reached the same conclusion from the same
evidence. Keep that order of priority. A document that reads well but skips the thinking is worthless;
treat the artifact as a consequence of the reasoning, never as the goal, or it curdles into
bureaucracy. Code shows what was built; this record shows why it was built that way and what was
rejected.

This is deliberately a **pragmatic framework, not a fixed format.** It blends the two industry
documents people usually keep apart: an **RFC** (a proposal floated *before* building, to weigh options
and invite comment) and an **ADR** (a terse record kept *after*, capturing the decision and its
consequences). Treat the distinction as a spectrum, not a fork: most real documents sit somewhere in
between, a proposal that, once accepted, *becomes* the record. So don't agonize over "is this an RFC or
an ADR?" Pick the depth the decision warrants and the sections that carry the reasoning; the goal is a
useful artifact, not compliance with a template. Lean on the method below for *what to think about*,
and let the situation set how heavy each part should be.

Two things make these documents hard, and the method exists to counter both. First, it's tempting to
follow hype or personal taste; decisions made without objective criteria cost the whole team later.
Second, we tend to make things more complicated than they need to be: anyone can complicate, few can
simplify, and simplifying is the real work. So tie every choice back to a stated requirement, and cut
anything that isn't pulling its weight.

## Be the architect, not the scribe

You are not transcribing someone else's decision. You are the architect on this decision, or the
architect's pair, and that changes what you do with the material you were handed. Whoever asked for the
document has already made assumptions, already narrowed the options, and probably already mixed
constraints, goals, and solutions into one list. Sorting that out *is* the job.

- **Every input is a claim, not a fact.** Numbers, current-state descriptions, "we already decided X":
  each is a claim with a source, and the source may be memory. Verify what the codebase, the schema,
  the dashboards, the tickets, and the logs can answer. Do the lookup *before* asking the user; a
  question you could have answered yourself spends their attention for nothing.
- **The framing is part of what you challenge.** "It's between X and Y" is a hypothesis about the
  option space, not the option space. Ask what goal makes those two the candidates, then name at least
  one credible option nobody proposed, including the boring ones: change nothing, do the smallest thing
  that would work, buy instead of build.
- **Ask "why" until you reach a goal in the user's world.** *Why is more important than how* (Richards
  & Ford, *Fundamentals of Software Architecture*, second law of software architecture). An input with
  no goal behind it is either a constraint imposed from outside (record it with its source) or an
  invention (drop it).
- **Push back with reasons, and record it.** When an input looks wrong, say so once, plainly, with the
  evidence and the alternative. If the user reaffirms it, it becomes a constraint whose source is the
  user, and the document says so. Deference without reasons is how weak decisions get laundered into
  official documents.
- **Skepticism is not obstruction.** Challenging inputs does not mean stalling on questions. Where an
  answer would change the design, ask (one question at a time, with your recommended answer attached,
  so agreeing is cheap). Where it would not, state the assumption inline, label it, and keep going.

## Sharpen the axe first

> *"If I had eight hours to chop down a tree, I'd spend six sharpening the axe."* Attributed to
> Abraham Lincoln.

Architecture is the highest-leverage, hardest-to-reverse work in software. Get it wrong and no amount
of clean code downstream saves the project; the wrong foundation sinks everything built on it. So this
document always deserves your **highest effort and slowest thinking**. There is no "quick mode" here,
and a fast, thin pass is itself a failure. **Thinking time is not the bottleneck**: a rushed plausible
answer that is subtly wrong costs far more than the hours spent getting it right.

Spend the bulk of your effort *before* the conclusion, sharpening: genuinely understanding the context,
pinning down the requirements that actually constrain the choice, and exploring the alternatives in
earnest. The written document is the chips that fly; the real work is the cut you make in your head
first. Concretely:

- **Don't commit to the first design that seems to work.** Generate real alternatives, at least two or
  three credible ones per dimension being decided, before you start narrowing. If you can only think
  of one option, you haven't looked hard enough yet.
- **Grill your own recommendation.** For the option you favor, write down its *strongest* objection,
  not a strawman, and the specific conditions that would flip the decision the other way. A tradeoff
  table where every cell favors your pick is a warning sign, not a victory: you've stopped looking.
- **Steelman what you reject.** State each rejected alternative at its best, so a reader who prefers it
  sees you understood it and still had reasons. That's what makes the decision trustworthy.
- **Be precise; ambiguity is where bad decisions hide.** Concrete numbers (load, latency budgets,
  cost), named components, grounded claims with a link or a measurement. "Should be fast" hides a
  decision; "≤ 300ms at p95 under 2× peak, validated by load test" makes one.
- **Surface uncertainty honestly.** Where you're guessing, say so, and say what evidence (a spike, a
  POC, a benchmark) would resolve it, then recommend running it. A POC to de-risk an irreversible
  choice is the axe-sharpening, not a delay.

The sections below are *what to think about*, not a checklist to fill quickly. Slow down on the parts
that carry the most risk, usually the requirements and the tradeoff analysis.

**Write in the language of the request and its source material.** Whatever language the task, the
codebase, and the existing docs are in, write the document in that same language; match what its
readers will expect.

## Two shapes, one method

The RFC↔ADR spectrum shows up as two practical shapes. Same method underneath; the framing and the
emphasis shift with *when* you're writing.

- **Forward-looking (RFC / design doc)** — you're choosing *before* building, to weigh options and
  invite comment. This is the full method below; the heart is the tradeoff analysis and the recorded
  decision. See `references/example-rfc.md`.
- **Retrospective (ADR / technical documentation)** — you're recording something already decided or
  built. Same spirit, reshaped: Context (situation before → motivations → scope), Architecture
  (components + step-by-step flows), Risks & mitigations, **Lessons learned**, improvement points, and
  a version history table. See `references/example-technical-doc.md`.

Pick the shape from what the user is doing: deciding, or recording a decision already made. When
unsure, ask. The sections below describe the forward-looking method; the retrospective variant reuses
the same building blocks (context, design/architecture, risks) with a backward-looking framing.

A fill-in template for the forward-looking shape lives in `assets/template.md`. Start from it rather
than inventing structure, but treat its sections as a checklist, not a cage: drop what doesn't apply,
add what the decision needs.

## The method

**Work the steps in order, and finish each before starting the next. Don't jump the gun.** The sequence
is the whole point, not ceremony. The single most common way these efforts fail is **rushing to a
solution before the problem is understood**: a team arguing Lambda vs. Kubernetes before anyone has
written down what the system must actually do. When you feel the pull to name a technology, a
component, or an alternative while you're still in Context or Requirements, *that pull is the warning
sign*. Note the idea so you don't lose it, then get back to the problem. A design built on a shaky
requirement is wasted work, and a tradeoff table over options nobody tied to a requirement is just
opinion dressed up as analysis.

So the earlier steps **gate** the later ones: don't open the Design until Context and Requirements are
genuinely settled, and don't run the Tradeoff analysis until the Design is on the table. Hold the
problem in focus until it's truly understood; the solution discussion has to wait its turn.

The one moment to step back and read the **whole document end to end** is *after the Alternatives
analysis reaches its conclusion*. Check that the requirements still hold, that every component traces
to one, and that the decision follows from the analysis. That review is the payoff of the discipline,
earned by working up to it; it is not permission to skip ahead.

### 0 — Size the decision

Before writing anything, decide how much decision this is, because that sets the depth of everything
below. The useful test is reversibility (Bezos, 2015 shareholder letter): a **two-way door** can be
walked back cheaply if it turns out wrong, so decide it fast and light, and say in one line why it is
reversible. A **one-way door** is expensive or impossible to undo (a data model, a public contract, a
consistency model, a security boundary, an external dependency you cannot remove), and it earns the
full method, a POC where the evidence is thin, and named reviewers. Architecture is exactly the set of
decisions that are hard to change (Fowler, *Who Needs an Architect?*, quoting Ralph Johnson).

If the request turns out to be a two-way door, say so and keep the document short. Ceremony on a
reversible choice is waste, and it teaches readers to skim the ones that matter.

### 1 — Contextualize

Focus on the problem, not the document. The point of this section is to make a reader *understand the
situation*, so frame it around what's happening in the world, not around "this document describes…".

Tell the story so a newcomer follows it without prior knowledge: **things were this way → then this
happened → and because of that, we now need to decide X.** Nothing is "obvious"; the obvious is exactly
what a newcomer is missing, so say it. By the end the reader should be able to answer the two questions
that matter most: **what problem are we solving, and why does it matter now?**

**Every claim about the current state carries its evidence, inline.** A number with no source is an
opinion wearing a number's clothes, and it will be quoted back for years. For each fact give the figure
and where it came from: the query and its result, the dashboard and the date, `file:line`, a log
excerpt, a ticket, a screenshot. Then label how you know it:

- **measured** — you or a named source observed it (query, benchmark, dashboard, profiler, incident).
- **estimated** — derived from something measured; show the arithmetic so a reader can check it.
- **assumed** — nobody has checked. Say what would confirm it and roughly what that would cost.

Get the number yourself before asking for it. Reading the schema, running the query, or grepping the
code is usually faster than a round trip, and it makes the document first-hand rather than hearsay.

**Separate constraints from requirements.** A constraint is a *given imposed from outside this
decision*: a platform already in use, a language the team knows, a budget, a compliance rule, an
org-wide standard, a prior ADR, a deadline. Constraints belong in Context, in their own table, never in
Requirements, because they are inputs to the design rather than things the design must achieve (Bass,
Clements & Kazman, *Software Architecture in Practice*, treat constraints as design decisions already
taken for you; arc42 gives them their own section 2).

| Constraint | Source | Cost to challenge |
| --- | --- | --- |
| Runs on the existing Kubernetes cluster | Platform team, #arch thread 2026-04-02 | High: no team owns a second runtime |
| Merges gated by the repo coverage threshold | `.github/workflows/ci.yml:38` | Low: team practice, changeable in a PR |

Two rules make the table earn its place. **Record the cost of challenging each constraint**, because a
constraint is a decision someone else made and some of them are cheap to reopen. And **a constraint
never pre-selects an alternative**: an option that violates one stays in the analysis, with the
violation recorded as a cost in its row. That is the difference between a constraint and a foregone
conclusion.

Close the section with:

- **Stakeholders** — who is affected, who has to operate it, who has to approve it. Name roles.
- **Assumptions and open questions** — what you are proceeding on without proof, and what would be
  needed to close each one. This is where honesty about uncertainty lives.
- **Out of scope** — the non-goals, explicitly. Naming them keeps the work from sprawling.

Depth, before/after rewrites, and the recurring pitfalls in this step and the next are in
`references/context-and-requirements.md`.

### 2 — Requirements

Requirements are what the chosen design **must achieve**, and each one has to be provable when the work
is done. This section is where these documents most often go wrong, so treat the list you were handed
as raw material rather than as the answer.

**Triage the input first.** Sort every item into one of five buckets, then tell the reader what moved
and why:

| Bucket | Test | Where it goes |
| --- | --- | --- |
| Constraint | Imposed from outside this decision; not something we choose | Context, constraints table |
| Functional requirement | A user or external system exercises it; delete it and users notice a capability is missing | Requirements, functional table |
| Non-functional requirement | A quality of *how well* the system behaves, with a metric | Requirements, non-functional table |
| Design choice | A way of meeting a requirement (a technology, a pattern, a library) | Design, or an alternative in the tradeoff analysis |
| Wish | Wanted, but nothing fails if it never ships | Out of the requirements: a pro for the options that deliver it, or a roadmap item |

The **deletion test** is what separates functional requirements from everything else: remove the item
and ask whether a user or a calling system would notice a missing capability. "Users can search by TUSS
code" passes. "Use OpenTelemetry" fails; it is a design choice serving an observability requirement.

**Every non-functional requirement carries a metric, or it is not a requirement yet.** "Fast",
"scalable", "observable" and "secure" are categories, not requirements, and no design can be judged
against them. Write each one as a quality-attribute scenario (Bass, Clements & Kazman): under what
**condition**, what **stimulus**, and what **response measure**. In practice, four parts:

- **metric** — the thing being measured, precisely (p95 latency of `GET /search`, not "latency").
- **target** — the value, with its unit and its statistic.
- **condition** — the load, environment, and failure mode it holds under.
- **measurement** — how it will actually be checked, and by whom or what.

**Goal first, then the requirement.** The justification matters more than the requirement itself: a
requirement with a goal can be renegotiated intelligently when the design gets hard, while a
requirement without one is a rule nobody can reason about. The goal must be derivable from the Context.
If you cannot write it, one of two things is true and both are worth saying out loud: the Context is
missing evidence, or the requirement was invented. (Volere calls this the requirement's *Rationale* and
pairs it with the *Originator*; ISO/IEC/IEEE 29148 asks every requirement to be *necessary* and
*verifiable*.)

**Every requirement names its proof.** Write, now, how you will demonstrate it is met when
implementation ends: the test, the load run, the dashboard, the drill, the query. Volere calls this the
*Fit Criterion*. A requirement whose fulfilment cannot be shown is a wish with a firm tone of voice.

**No wish list.** Nothing optional is a requirement. Delete "nice to have" from the section entirely: a
genuine desirable becomes a pro for the alternatives that deliver it, or a roadmap item. (Gilb's
Planguage makes this explicit with a *Wish* level, defined as a value with no commitment behind it.
YAGNI is the same instinct from the code side: am I solving a real problem or a hypothetical one?)

Record them in two tables, with IDs so Design and the tradeoff analysis can cite them:

```
### Functional

| ID | Goal (why it matters) | Requirement | Proof | Source |
| --- | --- | --- | --- | --- |
| F1 | the outcome in the user's world | what the system must do | how we show it is met | the Context fact it derives from |

### Non-functional

| ID | Goal (why it matters) | Requirement (metric, target, condition) | Proof (measurement) | Source |
| --- | --- | --- | --- | --- |
| N1 | the outcome in the user's world | p95 of X under Y load stays below Z | how it is measured | the Context fact it derives from |
```

Then cut the list down. The hard part, and where most efforts lose focus, is separating the
*architecturally-relevant* requirements from the long tail of feature details that don't shape the
structure. A requirement is **architecturally relevant** when it meets at least one of these tests:

- **Hard to reverse** — getting it wrong is expensive or near-impossible to undo later (data model,
  consistency model, a public contract, a security boundary).
- **Shapes the structure** — it forces a component, a boundary, or an integration to exist; drop it and
  the design would look genuinely different.
- **Business-critical** — the system fails its purpose if this isn't met ("we cannot lose an order").
- **Cross-cutting quality** — a system-wide "-ility" with a real target: latency, throughput,
  availability, durability, security, cost, operability.

If a requirement passes none of these, it's a feature detail; capture it elsewhere. Keep the list
short: each entry has to earn its place.

**Ask only what changes the design.** A missing goal or a missing metric is worth one question when the
answer would move the decision, and the question comes with your recommended answer so agreeing is
cheap. Otherwise write the assumption into the row, label it `assumed`, and continue. Blocking a
document on questions whose answers wouldn't change it is its own failure.

### 3 — Design

Now solve the requirements with technology, and hold onto that word, *solve*. **Good architecture is
the architecture that meets the requirements**, nothing more mystical than that; elegance that doesn't
serve a requirement isn't good design, it's decoration. This is the exact point where many lose the
thread, so make the link explicit and keep **traceability in both directions**:

- **Every component exists because it addresses a requirement.** Name the requirement by ID. If you
  can't name one, it's scope creep: cut it or justify it.
- **Every requirement is met by something in the design.** If a requirement maps to no component, the
  design is incomplete; that gap is the first thing to fix.

Where a constraint shaped a choice rather than a requirement, say which constraint, so a later reader
who finds that constraint gone knows the choice is reopenable.

Include at minimum:

- **one static diagram** — the components and how they fit together;
- **one dynamic diagram** — a flow or sequence showing how they interact over time.

Add a further view when the decision turns on it, and not otherwise: a **deployment** view when the
choice is about runtime, scaling or cost; a **data** view when it is about the model, ownership or
migration. Views exist to answer a reader's question, not to complete a set.

If you can't render diagrams, describe them precisely (a numbered step-by-step flow, a component list
with responsibilities and arrows) and leave a clear placeholder for the real diagram. This section
takes refinement and keeps everyone aligned on the direction being taken; it's normal to iterate here.

### 4 — Tradeoff analysis

This is where the document earns its keep, and where the bulk of your effort belongs (see *Sharpen the
axe first*). There is no silver bullet and no one-size-fits-all: every alternative has upsides,
downsides, and risks, and all of them get analyzed and recorded with real depth. *Everything in
software architecture is a trade-off* (Richards & Ford, first law). Surfacing a downside isn't
weakening your case; it's what makes the eventual decision trustworthy. Push past the first pass: if
the analysis came easily, you probably haven't found the alternative's real failure modes yet.

**State the decision drivers before the options.** List the criteria the choice actually turns on, in
priority order, and where each comes from: the requirement IDs it serves, the constraints, cost of
ownership, time to market, operational load, team skills, and the reversibility you sized in step 0.
Naming the drivers first is what stops the analysis from being reverse-engineered to fit a favorite
(MADR calls these *Decision Drivers*; Tyree & Akerman put cost, total cost of ownership and time to
market among the arguments a decision has to weigh).

For **each alternative**, capture:

- **Pros** — what the approach genuinely brings in its favor.
- **Cons** — what it genuinely brings against it.
- **Risks** — negative impacts that *might* happen and must be managed. Managing means dealing with
  uncertainty, so each risk gets four attributes:
  - **Impact** if it occurs — low / medium / high
  - **Probability** of occurring — low / medium / high
  - **Mitigation** — actions to *stop the risk from happening*
  - **Contingency** — how you'd *act if it happens anyway*

A table keeps this scannable and forces the discipline of filling every cell. Group alternatives by the
dimension being decided (data store, provisioning, language, …) so related options sit side by side.
The exact column layout is shown in `references/example-rfc.md`; reuse it.

Then weigh each alternative **against the requirement IDs from section 2**, one by one. An option that
wins on elegance but misses a hard requirement doesn't win. Two rules keep this honest:

- **A constraint violation is a cost, not a disqualification.** Keep the option in the table, record
  what challenging the constraint would cost, and let the comparison happen in the open.
- **Where the evidence is thin, run the POC and report its numbers here.** A benchmark in the document
  beats a confident adjective, and it is the cheapest thing you can do about a one-way door.

### 5 — The decision

This is the moment the discipline has earned: **now read the whole document end to end** (see *Work the
steps in order*). Requirements still right, every component tracing to one, the analysis genuinely
supporting where it points. Revise what that pass exposes before you commit.

Then a decision has to be made and stated plainly: which alternative, and the reasoning that carried
it. Record with it:

- **Who decided, and how.** Name the decider and the reviewers, and name the style so the basis is on
  the record. **Autocratic**: it's one person's call, they consult and they own the outcome.
  **Democratic**: one vote each, majority decides, a fair tiebreaker when options come out genuinely
  close. (DACI is the same idea with the roles spelled out: driver, approver, contributors, informed.)
- **Consequences.** What becomes easier, what becomes harder, and what the team now has to live with
  and maintain. Nygard's original ADR format is built around exactly this: context, decision,
  consequences.
- **Residual risks.** The risks the mitigations do not remove, stated as such.
- **Confirmation.** How the team will know later that the decision is holding: the metric to watch, the
  automated check, the fitness function (Ford, Parsons & Kua), the review date. MADR calls this
  *Confirmation*. A decision with no confirmation quietly decays into folklore.
- **Status.** `proposed` → `accepted` → `superseded` / `deprecated`, plus the decisions this one
  supersedes or relates to. Status is what lets a growing corpus of these documents stay readable.

Don't leave the decision implicit. A document that analyzes options but never commits leaves the reader
exactly where they started.

### 6 — Conclude and communicate

Record the most relevant points of the decided architecture and, just as importantly, make sure every
stakeholder ends up on the same page about the decision and its impacts. A decision nobody hears about
isn't really made. For forward-looking docs this is often a rollout/launch strategy and a task roadmap;
for retrospective docs it's the lessons learned, open improvement points, and a **version history**
table (version, date, author, change) so the document stays a living record.

Add a **glossary** whenever the document uses domain terms, internal system names, or acronyms a
newcomer would not know, and then use each term exactly as the glossary defines it.

## Writing principles

- **Newcomer-readable.** Assume the reader is meeting the project for the first time. Spell out the
  obvious; define the acronyms.
- **The document stands alone.** Inline whatever the argument needs: the number, the query, the log
  line, the diagram, the relevant clause of the standard. A link is *provenance for something already
  stated*, never a substitute for stating it. No forward references, no chain of documents a reader
  must open to follow the reasoning. Put provenance in a **Sources** section at the end rather than a
  list of related documents at the top, so nobody has to read the appendix first.
- **One name per concept.** Pick a term, define it once, and never drift (the search service, not "the
  service" then "the API" then "the search layer"). Drifting vocabulary is what makes a document feel
  convoluted even when every sentence in it is fine.
- **Every claim tied to a requirement or to evidence.** A number carries its source and its
  measured / estimated / assumed label. Decisions backed by data outlive opinions.
- **Simplify ruthlessly.** If a section, alternative, or requirement isn't earning its place, cut it.
- **Be honest about downsides and risks.** The credibility of the decision rests on having genuinely
  considered what could go wrong.
- **Prose pass before you hand it over.** Read it once for the tells that make a document tiring:
  bullet lists whose items are really sentences, bold-word headers standing in for topic sentences,
  three-item lists padded to three, vague attribution ("studies show", "it is well known"), gap-filling
  where you had no evidence, and a closing paragraph that restates the summary. Fix by writing prose
  where prose belongs and cutting what carries nothing. If the `humanizer` skill is available, run it
  in embedded mode as the final pass; that is an optional polish step, not a dependency.
- **Match the source's language, structure, and formatting.** Mirror the headings, numbered flows, and
  table styles the examples use, in the reader's language.

## Check before you hand it over

Run this list against the finished document. Each failure points back at a specific step above.

1. Does every constraint sit in the constraints table with a source and a cost to challenge, and is
   none of them listed as a requirement?
2. Does every functional requirement survive the deletion test, and does every non-functional one
   carry metric, target, condition, and measurement?
3. Does every requirement state a goal derivable from the Context, and name its proof?
4. Is there nothing optional in the requirements?
5. Does every current-state number carry its source inline and a measured / estimated / assumed label?
6. Does every component cite the requirement ID it serves, and does every requirement map to something
   in the design?
7. Is there at least one credible alternative the user did not propose, and is each rejected option
   stated at its best?
8. Does the decision name the decider, the consequences, the residual risks, and how it will be
   confirmed?
9. Can a newcomer follow the whole argument without opening a single link?
10. Did you tell the user what you reclassified, challenged, or assumed, and why?

## References

- `references/context-and-requirements.md` — depth for steps 1 and 2: the classification table, the
  anatomy of a requirement, kinds of evidence, and the six recurring pitfalls with before/after
  rewrites.
- `references/foundations.md` — the literature this method rests on, one entry per source, with what
  each contributes and where to read it.
- `references/example-rfc.md` — a worked forward-looking RFC (search-service decision): full structure
  end to end, and the canonical tradeoff-table layout.
- `references/example-technical-doc.md` — a worked retrospective technical doc (social-auth
  implementation): context → architecture → flows → risks → lessons learned → version history.
- `assets/template.md` — fill-in skeleton for the forward-looking shape.
