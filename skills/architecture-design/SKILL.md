---
name: architecture-design
description: >-
  Write a structured architecture decision document — an RFC / design doc / technical doc that
  records *why* a non-trivial technical choice was made, not just what was built. Follows a six-part
  method: contextualize for a newcomer, state the architecturally-relevant requirements, design
  components against them with static + dynamic diagrams, weigh every alternative by pros / cons /
  risks (each risk with impact, probability, mitigation, contingency), record the decision and how it
  was made, then conclude and communicate. Writes in the
  same language as the request and its source material (Portuguese, English, …). Reach for it whenever
  someone is choosing between technical options or documenting one — "write an RFC", "design doc",
  "documento de arquitetura", "decisão arquitetural", "ADR", "tradeoff analysis", "documentação
  técnica da implementação" — even if they never say "RFC". Also
  fits the retrospective variant: documenting an implementation after the fact (lessons learned,
  version history).
---

# Architecture decision document

The real work is **structured thinking about a technical decision** — framing the problem, weighing the
options against what actually matters, and committing with reasons. The written artifact is the *trace*
that thinking leaves behind, so the next person — a new hire, a reviewer, your future self — can follow
not just *what* was chosen but *why*, and could have reached the same conclusion from the same evidence.
Keep that order of priority: a document that reads well but skips the thinking is worthless; treat the
artifact as a consequence of the reasoning, never as the goal, or it curdles into bureaucracy. Code
shows what was built; this record shows why it was built that way and what was rejected.

This is deliberately a **pragmatic framework, not a fixed format.** It blends the two industry
documents people usually keep apart: an **RFC** (a proposal floated *before* building, to weigh
options and invite comment) and an **ADR** (a terse record kept *after*, capturing the decision and
its consequences). Treat the distinction as a spectrum, not a fork — most real documents sit
somewhere in between: a proposal that, once accepted, *becomes* the record. So don't agonize over
"is this an RFC or an ADR?" Pick the depth the decision warrants and the sections that carry the
reasoning; the goal is a useful artifact, not compliance with a template. Lean on the method below
for *what to think about*, and let the situation set how heavy each part should be.

Two things make these documents hard, and the method exists to counter both. First, it's tempting to
follow hype or personal taste; decisions made without objective criteria cost the whole team later.
Second, we tend to make things more complicated than they need to be — anyone can complicate, few can
simplify, and simplifying is the real work. So: tie every choice back to a stated requirement, and
cut anything that isn't pulling its weight.

## Sharpen the axe first

> *"If I had eight hours to chop down a tree, I'd spend six sharpening the axe."* — attributed to
> Abraham Lincoln.

Architecture is the highest-leverage, hardest-to-reverse work in software. Get it wrong and no amount
of clean code downstream saves the project — the wrong foundation sinks everything built on it. So
this document always deserves your **highest effort and slowest thinking**. There is no "quick mode"
here, and a fast, thin pass is itself a failure. **Thinking time is not the bottleneck** — a rushed
plausible answer that's subtly wrong costs far more than the hours spent getting it right.

Spend the bulk of your effort *before* the conclusion — sharpening: genuinely understanding the
context, pinning down the requirements that actually constrain the choice, and exploring the
alternatives in earnest. The written document is the chips that fly; the real work is the cut you make
in your head first. Concretely:

- **Don't commit to the first design that seems to work.** Generate real alternatives — at least two
  or three credible ones per dimension being decided — before you start narrowing. If you can only
  think of one option, you haven't looked hard enough yet.
- **Grill your own recommendation.** For the option you favor, write down its *strongest* objection,
  not a strawman — and the specific conditions that would flip the decision the other way. A tradeoff
  table where every cell favors your pick is a warning sign, not a victory: you've stopped looking.
- **Steelman what you reject.** State each rejected alternative at its best, so a reader who prefers it
  sees you understood it and still had reasons. That's what makes the decision trustworthy.
- **Be precise; ambiguity is where bad decisions hide.** Concrete numbers (load, latency budgets,
  cost), named components, grounded claims with a link or a measurement. "Should be fast" hides a
  decision; "≤ 300ms at p95 under 2× peak, validated by load test" makes one.
- **Surface uncertainty honestly.** Where you're guessing, say so, and say what evidence (a spike, a
  POC, a benchmark) would resolve it — then recommend running it. A POC to de-risk an irreversible
  choice is the axe-sharpening, not a delay.

The sections below are *what to think about*, not a checklist to fill quickly. Slow down on the parts
that carry the most risk — usually the requirements and the tradeoff analysis.


**Write in the language of the request and its source material.** If the task, the codebase, and the
existing docs are in Portuguese, the document is in Portuguese; if English, English. Match what the
reader of *this* document will expect.

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

Pick the shape from what the user is doing — deciding, or recording a decision already made. When
unsure, ask. The sections below describe the forward-looking method; the retrospective variant reuses
the same building blocks (context, design/architecture, risks) with a backward-looking framing.

A fill-in template for the forward-looking shape lives in `assets/template.md` — start from it rather
than inventing structure, but treat its sections as a checklist, not a cage: drop what doesn't apply,
add what the decision needs.

## The method

### 1 — Contextualize

Start from the problem, not the document. The point of this section is to make a reader *understand the
situation*, so frame it around what's happening in the world — not around "this document describes…".

Tell the story so a newcomer follows it without prior knowledge: **things were this way → then this
happened → and because of that, we now need to decide X.** Nothing is "obvious" — the obvious is
exactly what a newcomer is missing, so say it. By the end the reader should be able to answer the two
questions that matter most: **what problem are we solving, and why does it matter now?** Then state what
is explicitly **out of scope** — naming non-goals keeps the work from sprawling.

### 2 — Requirements

Requirements are what is **non-negotiable**. The hard part — and where most efforts lose focus — is
separating the *architecturally-relevant* requirements from the long tail of feature details that don't
shape the structure. Be explicit about the cut, because everything downstream is judged against this
list. A requirement is **architecturally relevant** when it meets at least one of these tests:

- **Hard to reverse** — getting it wrong is expensive or near-impossible to undo later (data model,
  consistency model, a public contract, a security boundary).
- **Shapes the structure** — it forces a component, a boundary, or an integration to exist; drop it and
  the design would look genuinely different.
- **Business-critical** — the system fails its purpose if this isn't met ("we cannot lose an order").
- **Cross-cutting quality** — a system-wide "-ility" with a real target: latency, throughput,
  availability, durability, security, cost, operability.

If a requirement passes none of these, it's a feature detail — capture it elsewhere; it doesn't belong
in the analysis that drives the architecture. Keep the list short: each entry has to earn its place.

Split them into **functional** (what the system must do) and **non-functional** (how well — latency
budgets, observability, test coverage, security, standardization). State them concretely enough to be
checkable: "search response ≤ 3000ms at p95, validated under load" beats "search should be fast."

### 3 — Design

Now solve the requirements with technology — and hold onto that word, *solve*. **Good architecture is
the architecture that meets the requirements**, nothing more mystical than that; elegance that doesn't
serve a requirement isn't good design, it's decoration. This is the exact point where many lose the
thread, so make the link explicit and keep **traceability in both directions**:

- **Every component exists because it addresses a requirement.** If you can't name the requirement a
  component serves, it's scope creep — cut it or justify it.
- **Every requirement is met by something in the design.** If a requirement maps to no component, the
  design is incomplete; that gap is the first thing to fix.

So specify the **components** and, for each, name the requirement(s) it answers. The test of a good
design stays simple: *does it meet the requirements?* Don't get lost solving dilemmas nobody asked for.

Include at minimum:

- **one static diagram** — the components and how they fit together;
- **one dynamic diagram** — a flow or sequence showing how they interact over time.

If you can't render diagrams, describe them precisely (a numbered step-by-step flow, a component list
with responsibilities and arrows) and leave a clear placeholder for the real diagram. This section
takes refinement and keeps everyone aligned on the direction being taken; it's normal to iterate here.

### 4 — Tradeoff analysis

This is where the document earns its keep, and where the bulk of your effort belongs (see *Sharpen
the axe first*). There is no silver bullet and no one-size-fits-all — every alternative has upsides,
downsides, and risks, and all of them get analyzed and recorded with real depth. Surfacing a downside
isn't weakening your case; it's what makes the eventual decision trustworthy. Push past the first pass:
if the analysis came easily, you probably haven't found the alternative's real failure modes yet.

For **each alternative**, capture:

- **Pros** — what the approach genuinely brings in its favor.
- **Cons** — what it genuinely brings against it.
- **Risks** — negative impacts that *might* happen and must be managed. Managing means dealing with
  uncertainty, so each risk gets four attributes:
  - **Impact** if it occurs — low / medium / high
  - **Probability** of occurring — low / medium / high
  - **Mitigation** — actions to *stop the risk from happening*
  - **Contingency** — how you'd *act if it happens anyway*

A table keeps this scannable and forces the discipline of filling every cell. Group alternatives by
the dimension being decided (data store, provisioning, language, …) so related options sit
side by side. The exact column layout is shown in `references/example-rfc.md` — reuse it.

Crucially, **weigh each alternative against the requirements from section 2**, one by one. An option
that wins on elegance but misses a hard requirement doesn't win.

### 5 — The decision itself

In the end a decision has to be made and stated plainly — which alternative, and the reasoning that
carried it. Name the decision style so the basis is on the record:

- **Autocratic** — if it's your call to make, make it; consult others, but you own the outcome.
- **Democratic** — one vote each, the majority decides. Not always applicable, but a fair tiebreaker
  when alternatives come out genuinely close.

Don't leave this implicit. A document that analyzes options but never commits leaves the reader
exactly where they started.

### 6 — Conclude and communicate

Record the most relevant points of the decided architecture, and — just as importantly — make sure
every stakeholder ends up on the same page about the decision and its impacts. A decision nobody hears
about isn't really made. For forward-looking docs this is often a rollout/launch strategy and a task
roadmap; for retrospective docs it's the lessons learned, open improvement points, and a **version
history** table (version, date, author, change) so the document stays a living record.

## Writing principles

- **Newcomer-readable.** Assume the reader is meeting the project for the first time. Spell out the
  obvious; define the acronyms.
- **Every claim tied to a requirement or to evidence.** Link to the dashboard, the benchmark, the
  PostHog report, the schema. Decisions backed by data outlive opinions.
- **Simplify ruthlessly.** If a section, alternative, or requirement isn't earning its place, cut it.
- **Be honest about downsides and risks.** The credibility of the decision rests on having genuinely
  considered what could go wrong.
- **Match the source's language, structure, and formatting.** Mirror the headings, numbered flows, and
  table styles the examples use, in the reader's language.

## References

- `references/example-rfc.md` — a worked forward-looking RFC (search-service decision): full structure
  end to end, and the canonical tradeoff-table layout.
- `references/example-technical-doc.md` — a worked retrospective technical doc (social-auth
  implementation): context → architecture → flows → risks → lessons learned → version history.
- `assets/template.md` — fill-in skeleton for the forward-looking shape.
