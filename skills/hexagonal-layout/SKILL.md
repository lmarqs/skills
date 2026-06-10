---
name: hexagonal-layout
description: >-
  Keep a system's business logic independent of the technology it talks to, by reasoning about which
  way dependencies point across a hexagonal / ports-and-adapters / clean-architecture boundary. A
  system holds three kinds of code — its reason to exist (the business logic), its connections to the
  outside world, and how it's run (the wiring and entrypoint) — so when adding code the question is
  not "which folder" but "is this the reason, a connection, or how it's run, and what may it depend
  on?" Use whenever adding a feature, a new integration with an external system, or a new entrypoint,
  or whenever a dependency points the wrong way or you're unsure where a responsibility belongs.
  Language- and framework-agnostic: the kinds map onto whatever names a project uses (app/infra/run,
  domain/adapters/cmd, core/infrastructure/main). Reach for it even when the user never says
  "hexagonal": "where should this go", "add the repository", "wire it up", "which layer owns this"
  are all signals.
---

# Hexagonal layout: keep a system's reason independent of its technology

A system holds **three kinds of code**, told apart by why each exists:

- **The reason** — *why the system exists.* Its business logic, domain types, and use-cases, plus the
  **interfaces it declares** for what it needs from outside. It owns those interfaces and depends on nothing
  outward.
- **The connections** — *how it reaches the outside world.* The implementations of those interfaces against
  external systems. Where all the I/O lives.
- **How it's run** — *which connections to use, and how the program starts.* Picks the concrete
  implementations, wires them into the reason, and is the entrypoint. The only part that knows both sides.

Names vary — `core`/`adapters`/`run`, `app`/`infra`/`run`, `domain`/`adapters`/`cmd` are all the same three
kinds. Detect what a project uses and follow it (and any ADR that fixes the layout); the kinds are what matter,
not the labels.

## Which way dependencies point

**Every dependency points toward the reason:** the connections depend on it, the run code depends on both, and
the reason depends on neither. The reason declares the interfaces; the connections implement them; run wires
them. The reason never reaches out for a collaborator — it is handed one. (In the usual bucket names:
`run → core ← adapters`.)

The arrow comes in two kinds, and the kind changes what an outward dependency costs:

- A **runtime dependency** is loaded and executed when the program runs — it pulls in behaviour.
- A **build-time dependency** exists only while compiling or type-checking and is erased before the program
  runs — it carries no behaviour, only shapes and contracts: interfaces, constants, enums.

A build-time arrow out of the reason is lower-severity than a runtime one, not automatically fine: a strict
project can forbid *any* arrow out of the reason and check it statically — a check that fails even on an
unexecuted import.

## What this buys

Keeping the reason independent of its connections pays off three ways:

- **Technology-independent** — swap or defer an external choice without touching business logic.
- **Testable** — exercise the logic with stand-ins, no external system in the loop.
- **Reusable** — the same logic driven by more than one way of running it.

Hold this as loosely or strictly as the project decides; real codebases sit all along that spectrum. Read it as
*"be aware of how the system is shaped,"* not *"obey these rules."*

## Reason, connection, or how it's run?

Ask **what a piece of code is for**, and read its dependencies, not its surface topic:

| What it's for | Kind |
|---|---|
| A business rule, a domain concept, a use-case, or an interface the system needs | **Reason** |
| Reaching an external system to fulfil an interface the reason declared | **Connection** |
| Choosing which connections run, wiring them, and starting the process | **How it's run** |

When a change spans kinds, split it along the seam — the interface in the reason, its implementation in a
connection, the wiring in run — if the payoff is worth the seam for that change.

## Naming

Top-level names should announce **what the system is** — its domain — not which pattern it uses. A generic
catch-all bucket becomes a junk drawer that hides intent and collects stray logic. Name buckets for intent; if
you group by kind, keep the names few. The split into the three kinds is what matters, not the labels.

## Smells to notice

Each lets a dependency point the wrong way and dulls a payoff. Notice them; fix the ones that cost a payoff
this project actually wants:

- **I/O or an outside concrete in the reason** — it can't run without the real system. Put it behind an
  interface the reason declares.
- **Business logic in a connection** — a second connection can't reuse it. Move the decision into the reason;
  leave the connection a thin translation.
- **An interface declared with the connections instead of in the reason** — inverts the arrow. The reason owns
  its interfaces, where they're needed.
- **Wiring or config-reading in the reason** — ties it to one deployment. Keep construction and selection in
  run.
- **An anemic reason with the logic in run** — bound to one way of running. Push use-cases into the reason;
  keep run thin.

How strict to hold the line is the project's call; enforce it with a check that fails when an arrow points the
wrong way.

## Workflow

1. **Detect the layout** — identify which bucket holds each kind; use the project's vocabulary and any ADR,
   don't rename.
2. **Classify the change** — the reason, a connection, or how it's run? If it spans kinds, split it along the
   seam.
3. **Place it and check the arrow** points toward the reason.
4. **Flag the smells** that cost a payoff this project cares about; leave the trade-offs it made deliberately.
