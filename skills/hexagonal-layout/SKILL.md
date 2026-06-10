---
name: hexagonal-layout
description: >-
  Keep a system's business decisions independent of the technology it talks to, by reasoning about
  which way dependencies point across a hexagonal / ports-and-adapters / clean-architecture
  boundary — a decision-making core, the adapters that reach external systems, and a composition/run
  edge that wires them. The question is not "which folder" but "is this responsibility a business
  decision, a connection to the outside, or the choice of which concrete to use — and what may it
  therefore depend on?" Use whenever adding a feature, a new integration with an external system, or
  a new entrypoint, or whenever a dependency points the wrong way or you're unsure where a
  responsibility belongs. Language- and framework-agnostic: the roles map onto whatever names a
  project uses (app/infra/run, domain/adapters/cmd, core/infrastructure/main). Reach for it even
  when the user never says "hexagonal": "where should this go", "add the repository", "wire it up",
  "which layer owns this" are all signals.
---

# Hexagonal layout: keep decisions independent of the technology they run on

A system holds two kinds of code that change for different reasons: the **decisions it makes** — the business
logic, its reason to exist — and the **connections to the outside world** — whatever it uses to do I/O and
reach external systems. Tangle them and every change to the outside risks the logic, and the logic can't be
exercised without standing up the outside.

Keep them apart with one lever: **the direction of dependencies.** Everything points toward the decisions; the
decisions depend on nothing outward. The core then never depends on its technology — only the reverse.

So when you add code, the question isn't *"which folder?"* but *"is this a business decision, a connection to
the outside, or the choice of which concrete to use — and what may it therefore depend on?"*

This pays off three ways:

- **Technology-independent** — swap or defer an external choice without touching business logic.
- **Testable** — exercise the logic with stand-ins, no external system in the loop.
- **Reusable** — the same logic driven by more than one entrypoint.

Hold this as loosely or strictly as the project decides; real codebases sit all along that spectrum. Read it as
*"be aware of how the system is shaped,"* not *"obey these rules."*

## The three roles

Names vary — detect what's there, follow it, and honour any ADR that fixes the layout; don't impose your own.
What's universal is the *kind of responsibility*:

- **Core** — the decisions: business logic, domain types, use-cases, and the **interfaces it declares** for what
  it needs from outside. It owns those interfaces and depends on nothing outward.
- **Adapters** — implement the core's interfaces against the outside world. Where the I/O lives.
- **Composition / run** — chooses which concrete implementations to use, wires them into the core, and is the
  entrypoint. The only place that knows both sides.

## Which way dependencies point

**Dependencies point toward the core** — `run → core ← adapters`. The core declares the interfaces; adapters
depend on the core to implement them; run depends on both to wire them. The core never reaches out for a
collaborator — it is handed one.

The arrow comes in two kinds, and the kind changes what an outward dependency costs:

- A **runtime dependency** is loaded and executed when the program runs — it pulls in behaviour.
- A **build-time dependency** exists only while compiling or type-checking and is erased before the program
  runs — it carries no behaviour, only a shape.

A build-time arrow out of the core is lower-severity than a runtime one, not automatically fine: a strict
project can forbid *any* arrow out of the core and check it statically — a check that fails even on an
unexecuted import.

## Decision, connection, or choice of concrete?

Ask **"what is this code's reason to exist?"** and read the dependency, not the surface topic:

| Reason to exist | Role |
|---|---|
| A business rule, a domain concept, a use-case, or an interface the system needs | **Core** |
| Reaching an external system to fulfil an interface the core declared | **Adapter** |
| Choosing which concretes run, wiring them, and starting the process | **Run** |

When a change spans roles, split it along the seam — the interface in the core, its implementation in an
adapter, the wiring in run — if the payoff is worth the seam for that change.

## Naming

Top-level names should announce **what the system is** — its domain — not which pattern it uses. A generic
catch-all bucket becomes a junk drawer that hides intent and collects stray logic. Name buckets for intent; if
you group by role, keep the names few. The split into roles is what matters, not the labels.

## Smells to notice

Each lets a dependency point the wrong way and dulls a payoff. Notice them; fix the ones that cost a payoff
this project actually wants:

- **I/O or an external concrete in the core** — it can't run without the real system. Put it behind an
  interface the core declares.
- **Business logic in an adapter** — a second adapter can't reuse it. Move the decision to a core use-case;
  leave the adapter a thin translation.
- **An interface declared outside the core and imported inward** — inverts the arrow. Declare it in the core,
  where it's needed.
- **Wiring or config-reading in the core** — ties it to one deployment. Keep construction and selection in run.
- **An anemic core with the logic in run** — bound to one entrypoint. Push use-cases into the core; keep run
  thin.

How strict to hold the line is the project's call; enforce it with a check that fails when an arrow points the
wrong way.

## Workflow

1. **Detect the layout** — identify which bucket plays each role; use the project's vocabulary and any ADR,
   don't rename.
2. **Classify the change** — decision, connection, or choice of concrete? If it spans roles, split it along the
   seam.
3. **Place it and check the arrow** points toward the core.
4. **Flag the smells** that cost a payoff this project cares about; leave the trade-offs it made deliberately.
