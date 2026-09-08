<!--
  Skeleton for a forward-looking architecture decision document (RFC / design doc).
  Write the document in the language of the request and source material — translate these headings
  into that language if it isn't English.
  Treat sections as a checklist, not a cage: drop what doesn't apply, add what the decision needs.
  Nothing links out of this document to carry its argument: inline the number, the query, the excerpt,
  the diagram. Links go in Sources at the end, as provenance for what is already stated.
-->

# <Title>

**Status:** <proposed | accepted | superseded by X | deprecated>
**Decider:** <name / role>  ·  **Reviewers:** <names / roles>
**Current working focus:** <context | requirements | design | tradeoff | decision | concluded>

## Reversibility

<One-way door (expensive or impossible to undo) or two-way door (walkable back cheaply), and why. A
two-way door keeps this document short.>

## Context

<Written for someone meeting the project now: what exists today, why we're looking at this, with no
ambiguity. State the obvious. Every number carries its source inline and a label:
`(Datadog board X, read yyyy-mm-dd; measured)`, `(18,000/h ÷ 3,600 × 72 s; estimated)`,
`(nobody has checked; assumed — an hour with the reindex logs would settle it)`.>

### Stakeholders

- <who is affected, who operates it, who approves it — by role>

### Constraints

<Givens imposed from outside this decision. Not requirements: they are true from the start rather than
proved at the end, and none of them pre-selects an alternative.>

| Constraint | Source | Cost to challenge |
| --- | --- | --- |
| <the given> | <doc, person, file:line, prior ADR> | <low / high, and why> |

### Assumptions and open questions

- <what we're proceeding on without proof, and what would close it>

### Out of scope

- <non-goals: what is explicitly excluded, and why>

## Requirements

<Only the architecturally-relevant ones: hard to reverse, structure-shaping, business-critical, or a
cross-cutting quality with a target. Nothing optional belongs here. If items from the request were
reclassified, say which and why in a line under the tables.>

### Functional

<Each one passes the deletion test: remove it and a user or calling system notices a missing
capability.>

| ID | Goal (why it matters) | Requirement | Proof | Source |
| --- | --- | --- | --- | --- |
| F1 | <the outcome in the user's world> | <what the system must do> | <how we show it is met at the end> | <the Context fact it derives from> |

### Non-functional

<Each one carries metric, target and condition in the requirement, and the measurement method in the
proof. No metric means it is not a requirement yet.>

| ID | Goal (why it matters) | Requirement (metric, target, condition) | Proof (measurement) | Source |
| --- | --- | --- | --- | --- |
| N1 | <the outcome in the user's world> | <p95 of X stays ≤ Y ms at Z load> | <k6 run / drill / dashboard> | <the Context fact it derives from> |

## Design

<Solve the requirements with technology. Each component names the requirement IDs it answers; each
requirement maps to something here. Where a constraint shaped a choice rather than a requirement, say
which constraint. Decide dimension by dimension.>

- **Static diagram:** <components and how they fit together — embedded, or a precise description>
- **Dynamic diagram:** <flow/sequence over time — embedded, or a numbered step-by-step flow>
- <a deployment view if the choice is about runtime, scaling or cost; a data view if it is about the
  model, ownership or migration>

## Alternatives analysis (Tradeoff)

### Decision drivers

<The criteria this choice turns on, in priority order, each with where it comes from: requirement IDs,
constraints, cost of ownership, time to market, operational load, team skills, reversibility.>

<For each alternative: Pros, Cons, Risk. Each risk with Impact, Probability, Mitigation, and
Contingency. Group by the dimension being decided. Weigh each alternative against the requirement IDs.
Include at least one credible option nobody proposed. An option that violates a constraint stays in the
table with the violation recorded as a cost.>

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <option A> | <pros> | <cons> | <risk> | low/med/high | low/med/high | <stop it happening> | <act if it happens> |
| <option B> | | | | | | | |

## The decision

<Which alternative was chosen and why, referring to the drivers above. Decision style: autocratic
(one person's call, they own it) or democratic (majority). Commit — don't stop at "it depends".>

### Consequences

- <what becomes easier, what becomes harder, what the team now has to maintain>

### Residual risks

- <the risks the mitigations don't remove>

### Confirmation

<How we'll know later that this is holding: the metric to watch, the automated check or fitness
function, the review date.>

## Launch strategy

<How to deliver in phases, without an eternal migration. What ships now, what comes later.>

## Tasks and roadmap

| Task | Description | Estimate |
| --- | --- | --- |
| <task> | <description> | <Xd> |

## Glossary

| Term | Meaning |
| --- | --- |
| <domain term, system name, acronym> | <definition, used consistently everywhere above> |

## Sources

- <provenance for facts already stated above: dashboards with dates, queries, files, tickets, bills>

## Version history

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | <yyyy-mm-dd> | <author> | Document created. |
