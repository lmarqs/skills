---
name: architecture-design
description: >-
  Acts as the architect, not the scribe: challenges the inputs, then writes a structured architecture
  decision document (RFC / design doc / ADR) recording why a technical choice was made.
  Method: size the decision; contextualize with sourced evidence, usage roles and goals; keep external
  constraints and prior decisions out of the requirements; give every requirement a goal, a scenario or
  a derived metric, and a proof; design with embedded diagrams; weigh every option and the baseline
  against the requirement IDs and by pros / cons / risks with mitigation and contingency; record the
  decision, consequences and confirmation. Writes in the request's language. Use it whenever someone is
  choosing between technical options or documenting one: "write an RFC", "design doc", "architecture
  decision", "ADR", "tradeoff analysis", "technical documentation of an implementation", "help me
  decide between X and Y", even if they never say "RFC". Also fits documenting an implementation
  afterwards (lessons learned, version history).
---

# Architecture decision document

The work is **structured thinking about a technical decision**: framing the problem, weighing the
options against what matters, committing with reasons. The document is the trace that thinking leaves,
so the next reader can follow not just what was chosen but why, and could reach the same conclusion
from the same evidence. It sits on the spectrum between an RFC (a proposal before building) and an ADR
(the terse record after); pick the depth the decision warrants. The reasoning behind every rule below
is in `references/method.md`. Read it once; work from this file.

Two shapes share the method. **Forward-looking** (RFC, design doc): you are deciding, and the heart is
the tradeoff analysis. Model: `references/example-rfc.md`; skeleton: `assets/template.md`.
**Retrospective** (ADR, technical documentation): you are recording something built, as context
(situation before, motivations, scope), architecture (components and numbered flows), risks, lessons
learned and a version history. Model: `references/example-technical-doc.md`. When unsure which, ask.

**Write in the language of the request and its source material**, headings included.

## Be the architect, not the scribe

You are the architect on this decision, or the architect's pair, not the transcriber of someone else's.
Whoever asked has already mixed constraints, goals, prior decisions and solutions into one list, and
sorting that list is the job. Six habits, each with its long form in `references/method.md`:

- **Every input is a claim.** Verify what the code, the schema, the dashboards and the tickets can
  answer before asking anyone. A question you could have answered yourself spends attention for nothing.
- **The framing is a hypothesis.** "It is between X and Y" describes the asker's view of the option
  space. Ask what goal makes those two the candidates, and add the options nobody proposed: change
  nothing, the smallest thing that would work, buy instead of build.
- **Ask why until you reach a goal in the user's world.** Why is more important than how (Richards &
  Ford). An input with no goal behind it is an external constraint with a source, a prior decision with
  an author, or an invention.
- **Push back once, with evidence and an alternative, and record the outcome.** If the user reaffirms,
  the item becomes a prior decision whose author is the user, and the document says so.
- **Skepticism cuts both ways.** A requirement you add against the requester's wish names the role it
  serves and that role's goal, and the requester's objection is recorded as a stakeholder conflict in
  the Decision, never buried in the Design.
- **Ask only what changes the design**, one question at a time, with your recommended answer attached.
  Otherwise state the assumption inline, label it, and keep going.

### Working with a person

When the request is a conversation rather than a one-shot document, stop at two checkpoints. After
step 2, show what you reclassified, challenged and assumed, and get the requirements confirmed before
designing against them. After step 4, show the drivers and the table before committing. A pair does not
hand over a finished document in one pass. Skip both when the user asks for the document in one go.

## The method

Work the steps in order and finish each before starting the next. The earlier steps gate the later
ones: no Design until Context and Requirements are settled, no Tradeoff until the Design is on the
table. When you feel the pull to name a technology while still in Context or Requirements, that pull is
the warning sign; note the idea and return to the problem. Read the whole document end to end once,
after the tradeoff analysis reaches its conclusion and before the decision. Slow down on the
requirements and on the tradeoff table; that is where these documents are won or lost.

### 0. Size the decision

A **two-way door** can be walked back cheaply; a **one-way door** cannot (a data model, a public
contract, a consistency model, a security boundary, a dependency you cannot remove). State which this
is and why, in one line. A one-way door earns the full method below, a proof of concept where the
evidence is thin, and named reviewers. A two-way door gets the light shape, one page at most:

```
# <Title>
In the context of <situation>, facing <concern>, we decided <option> to achieve <goal>,
accepting <downside>.
Drivers: <two or three, in order>. Options: <one line each, including do nothing>.
Decision and decider. Consequences. Confirmation: <what we watch, and when we revisit>.
```

### 1. Contextualize

Written for someone meeting the project today, as a story that lands on a problem: things were this
way, then this happened, so we now have to decide X. Fill these, in this order.

**Current state.** What exists, who uses it for what, how much. Every number carries its source inline
and a label: **measured** (who observed it, where), **estimated** (derived from a measurement; show
the arithmetic), **assumed** (nobody checked; say what would confirm it). Get the number yourself
before asking for it. Then the current usage, by role:

| Role (what they do with the system) | What they do today | Through what | How often or how much (source) |
| --- | --- | --- | --- |

**Problem.** The gap, measured, between what the roles need and what they get.

**Goals.** The outcomes the decision exists to produce. A goal names an outcome for a role with no
system feature, no technology and no system metric in it. If you could build it, it is a requirement;
if you could choose it, it is an option; if it says "produce this design", it is not a goal.

| Goal | Who benefits | How we will know |
| --- | --- | --- |

**Stakeholders**, as usage roles, never as departments: operators, functional beneficiaries,
maintainers, regulators, approvers, and the negative stakeholders who lose something.

| Role (what they do with the system) | What they need from this decision | Who speaks for them |
| --- | --- | --- |

**Constraints.** Externally imposed limitations (ISO/IEC/IEEE 29148): law, regulation, contract,
physics, a signed budget, a regulator's date. A constraint may exclude an option, and the row cites the
clause that does it. A person inside the organization cannot be the source of a constraint.

| Constraint | Source (outside the organization, or a signed commitment) | What it excludes, and the clause |
| --- | --- | --- |

**Prior decisions.** Everything decided by someone inside the organization: the platform in use, the
team's language, an org standard, a previous ADR, "the platform team said so". A prior decision never
excludes an option. Its incumbent enters the tradeoff table beside at least one alternative, with the
cost of reversing it recorded as a cost in the row.

| Prior decision | Who made it, when | Incumbent it implies | Cost to reverse |
| --- | --- | --- | --- |

Two more things arrive dressed as constraints and go elsewhere: a stakeholder attribute ("the team does
not use a terminal") goes to the stakeholder table; scope and risk posture ("keep it minimal") go to
the decision drivers in step 4.

**Assumptions and open questions**, in two lists. **Blocking**: any answer would change the decision;
each carries an owner and a date, and the status cannot leave *proposed* while one is open. A proof of
concept closes a blocking question and states, before it runs, the question, the pass criterion, and
what each outcome changes. **Non-blocking**: what you proceed on without proof, and what would close it.

**Out of scope** lists problems, never options. An option is rejected in the tradeoff analysis or not
at all.

Depth for this step and the next, with before/after rewrites: `references/context-and-requirements.md`.

### 2. Requirements

Treat the list you were handed as raw material. Sort every item, then tell the reader what moved and
why.

| Bucket | Test | Where it goes |
| --- | --- | --- |
| Constraint | Imposed from outside the organization, or a signed commitment | Context, constraints table |
| Prior decision | Decided by someone inside the organization | Context, prior decisions table; its incumbent into the tradeoff table |
| Functional requirement | A role exercises it; remove it and that role notices a missing capability | Functional table |
| Non-functional requirement | How well the system behaves, with a metric | Non-functional table |
| Design choice | A way of meeting a requirement: a technology, a pattern, a library | Design, or a row in the tradeoff table |
| Wish | Wanted, but nothing fails if it never ships | Out: a pro for the options that deliver it, or a roadmap item |

If the team ranks with MoSCoW, only *Must* is a requirement; *Should* and *Could* become decision
drivers or pros, and *Won't* goes to Out of scope.

**Scenario first, requirement second.** For each functional requirement write the scenario before the
sentence: the role, the situation, the action, the observable result (Given/When/Then if the team likes
it). The requirement is the generalization of its scenarios. If the scenario cannot be written, the
requirement is not understood; if it can only be written with a product name in it, it is a solution.

| ID | Goal (a row of the Goals table) | Requirement (the role, and what the system does for it) | Proof (the scenario, and how it is run) | Source |
| --- | --- | --- | --- | --- |
| F1 | | | | |

**Every non-functional requirement carries five parts**: metric (precisely which measurement), target
(value, unit, statistic), condition (load, environment, failure mode), **derived from** (the current
measured value with source and date and the reason for the delta, or an external reference, or a named
stakeholder commitment), and measurement (how and by what it is checked). A target with no derivation
is labeled *assumed*, and the confirmation step measures it first. "Fast", "scalable", "secure" and
"observable" are categories, not requirements.

| ID | Goal | Requirement (metric, target, condition) | Derived from | Proof (measurement) | Source |
| --- | --- | --- | --- | --- | --- |
| N1 | | | | | |

Four tests decide whether a row stays:

- **Goal.** The Goal cell points at a row of the Goals table. If it cannot, the Context is missing
  evidence or the requirement was invented; say which.
- **Proof.** Every row says how fulfilment is shown when implementation ends (Volere's fit criterion).
  A requirement whose fulfilment cannot be shown is a wish with a firm tone of voice.
- **No wish.** Nothing optional is a requirement, at any priority label.
- **Architectural relevance.** Hard to reverse, shapes the structure, business-critical, or a
  cross-cutting quality with a target. A row that passes none is a feature detail; capture it elsewhere.

Words that fail these tests, each with its replacement in `references/context-and-requirements.md`:
absolutes (always, never, guarantee), the architecture as an agent or a sentence with no subject,
evaluative adjectives (intuitive, clear, better), selling language in a goal, escape clauses (where
possible), comparatives without a baseline.

### 3. Design

Solve the requirements with technology, and nothing more. Every component names the requirement IDs it
answers; every requirement is met by something here. Where a constraint or a prior decision shaped a
choice, say which, so a reader who finds it gone knows the choice is reopenable. Decide dimension by
dimension (data store, provisioning, language, and so on).

Embed at least two diagrams as Mermaid, so the document keeps standing alone: one **static**
(components and how they fit, at one zoom level: context, container or component) and one **dynamic**
(a sequence or flow over time). Add a deployment view when the choice is about runtime, scaling or
cost, and a data view when it is about the model, ownership or migration. Each caption names the level
and the IDs:

```
*Figure N. <Diagram type>, <zoom level>. Answers <requirement IDs>.*
```

Picker and a skeleton per type: `references/diagrams.md`.

### 4. Tradeoff analysis

Where the bulk of the effort belongs. Everything in software architecture is a trade-off (Richards &
Ford); an analysis with no downsides is incomplete, and a table where every cell favors your pick means
you stopped looking.

**Decision drivers first**, in priority order, each with its origin: requirement IDs, constraints, cost
of ownership, time to market, operational load, team skills, the reversibility sized in step 0.

**What every option shares.** Before filling the table, write down what all the options have in
common. Each shared element is a constraint with its clause, a prior decision with its own row and an
alternative beside it, or a missing option. The title and the first paragraph of the document name the
problem, never the product.

| Alternative | Requirements (met / partial / missed, by ID) | Pros | Cons | Risk | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **[Dimension] Option** | | | | | low / med / high | low / med / high | stop it happening | act if it happens |
| **Baseline: do nothing, or the smallest change that would work** | | | | | | | | |

Rules for the table. The baseline row is required. Every incumbent from the prior decisions table has
a row and at least one alternative. A constraint excludes an option only by citing its clause; a prior
decision never does, and its reversal is a cost in the row. *Partial* names the gap in the cell. Each
risk attribute carries a reason or a fact; "probability: unknown" is a gap. Where the evidence is
thin, run the proof of concept and report its numbers here. State each rejected option at its best.

### 5. The decision

Read the whole document end to end first: requirements still right, every component tracing to one,
the analysis supporting where it points. Then commit, plainly.

- **Decision**: which alternative, and the drivers that carried it.
- **Decider and style**: who owns the call. Autocratic (one person decides after consulting) or
  democratic (one vote each, a stated tiebreaker). DACI spells the roles out.
- **Stakeholder conflicts**: where a role's stated wish was overridden, and by whose requirement.
- **Consequences**: what becomes easier, what becomes harder, what the team now maintains (Nygard).
- **Residual risks**: what the mitigations do not remove.
- **Confirmation**: the metric, the automated check or fitness function, the review date (MADR).
- **Status**: proposed, accepted, superseded by, deprecated. A blocking open question holds it at
  proposed.

### 6. Conclude and communicate

Launch strategy in phases without an eternal migration, tasks and roadmap, glossary (define each term
once and use it exactly), **Sources** at the end as provenance for facts already stated, version
history. The decision document ends there: contracts, schemas, runbooks and specifications are tasks it
produces, not sections it contains. For the retrospective shape: lessons learned, improvement points,
version history.

## Writing principles

- **Newcomer-readable.** Spell out the obvious; define the acronyms at first use.
- **The document stands alone.** Inline the number, the query, the log line, the diagram, the clause.
  A link is provenance for something already stated. No forward references; sections read in order.
- **One name per concept.** Pick a term, define it once, never drift.
- **Every claim carries evidence or a requirement ID**, with its measured / estimated / assumed label.
- **Cut what is not pulling its weight.**
- **Prose pass before handing over**: bullet lists that are really paragraphs, bold headers standing in
  for topic sentences, lists padded to three, vague attribution, gap-filling, a closing summary. The
  words table and the pass are in `references/context-and-requirements.md`. If the `humanizer` skill
  is installed, run it in embedded mode as an optional final polish.

## References

- `references/method.md`: the reasoning behind the method: sharpen the axe, why the steps gate each
  other, the two shapes, decision styles, checkpoints, the light shape.
- `references/context-and-requirements.md`: classification and routing, goals, usage roles,
  requirement anatomy, evidence, blocking questions, requirement defects by name, words that fail, the
  prose pass.
- `references/diagrams.md`: which diagram answers which question, and a Mermaid skeleton per type.
- `references/foundations.md`: the literature behind each rule.
- `references/example-rfc.md`: a worked forward-looking RFC modelling every table above.
- `references/example-technical-doc.md`: a worked retrospective technical document.
- `assets/template.md`: the fill-in skeleton for the forward-looking shape.

## Check before you hand it over

1. Every number in Context has a source inline and a measured / estimated / assumed label.
2. Every goal names an outcome for a role, with no feature, technology or system metric in it.
3. Stakeholders are usage roles, and every functional requirement names the role it serves.
4. Every constraint has an external source and a clause; every prior decision has an author and a row
   in the tradeoff table beside an alternative.
5. Nothing optional sits in the requirements, and no technology does.
6. Every functional requirement's proof is a scenario; every non-functional one has metric, target,
   condition, derivation and measurement.
7. Every requirement ID that is referenced exists, and no two rows say the same thing.
8. Both diagrams are embedded, each at one stated zoom level, each captioned with the IDs it answers.
9. The tradeoff table has the baseline row, an option nobody proposed, and every risk attribute filled
   with a reason.
10. What all options share is written down and accounted for.
11. The decision names the decider, the conflicts, the consequences, the residual risks and the
    confirmation, and no blocking question is open under an accepted status.
12. No absolute, no evaluative adjective and no escape clause survives in a requirement.
13. A newcomer can follow the whole argument without opening a link.
14. The user was told what was reclassified, challenged and assumed, and why.
