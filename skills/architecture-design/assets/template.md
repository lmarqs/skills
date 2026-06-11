<!--
  Skeleton for a forward-looking architecture decision document (RFC / design doc).
  Write the document in the language of the request and source material — translate these headings
  into that language if it isn't English.
  Treat sections as a checklist, not a cage: drop what doesn't apply, add what the decision needs.
-->

# <Title>

**Status:** <draft | in review | approved>
**Current working focus:** <context | requirements | design | tradeoff | decision | concluded>

## Related documents

- <diagrams, spreadsheets, specs, dashboards referenced below>

## Context

<Written for someone meeting the project now. What exists today, why we're looking at this, with no
ambiguity — state the obvious.>

### Out of scope

- <non-goals: what is explicitly excluded, and why>

## Requirements

<Only the architecturally-relevant ones: business-critical, or expensive/irreversible to undo.>

### Functional

- <what the system must do — concrete and verifiable>

### Non-functional

- <how well: latency (e.g. p95 ≤ Xms validated under load), observability, test coverage, security,
  standardization>

## Design

<Solve the requirements with technology. Components and how each requirement is met. Decide dimension
by dimension, always tying back to the requirement it solves.>

- **Static diagram:** <components and how they fit together — or link/placeholder>
- **Dynamic diagram:** <flow/sequence over time — or link/placeholder>

## Alternatives analysis (Tradeoff)

<For each alternative: Pros, Cons, Risk. Each risk with Impact, Probability, Mitigation, and
Contingency. Group by the dimension being decided. Check each alternative against the requirements.>

| Alternative | Pros | Cons | Risk (description) | Impact | Probability | Mitigation | Contingency |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <option A> | <pros> | <cons> | <risk> | low/med/high | low/med/high | <stop it happening> | <act if it happens> |
| <option B> | | | | | | | |

## The decision

<Which alternative was chosen and why. Decision style: autocratic (yours to make the final call) or
democratic (majority). Commit — don't stop at "it depends".>

## Launch strategy

<How to deliver in phases, without an eternal migration. What ships now, what comes later.>

## Tasks and roadmap

| Task | Description | Estimate |
| --- | --- | --- |
| <task> | <description> | <Xd> |

## Version history

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | <yyyy-mm-dd> | <author> | Document created. |
