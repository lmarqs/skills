---
name: hexagonal-layout
description: >-
  Place new code in the right layer of a hexagonal / ports-and-adapters / "screaming"
  architecture — a business-logic core, infrastructure adapters, and a composition/run layer —
  and keep dependencies pointing the right way between them. Use whenever adding a feature, a new
  integration or provider (database, HTTP client, vendor SDK, queue, filesystem, clock), or a new
  entrypoint (CLI, web handler, Lambda) to a project split into those roles, or whenever you are
  unsure which directory a module belongs in or a dependency seems to point the wrong way.
  Language-agnostic: the three roles map onto whatever names a project already uses — app/infra/run,
  application/infra/runtime, domain/adapters/cmd, core/infrastructure/main, internal/<domain> + cmd.
  Reach for it even when the user never says "hexagonal": "where should this go", "add the Postgres
  repository", "wire it up", "which layer owns this" are all signals.
---

# Hexagonal layout: three roles and which way dependencies point

Strip hexagonal architecture (ports & adapters, the clean-architecture core) down and two ideas are left:
**three roles a piece of code can play**, and **which direction dependencies run between them.** That is all
this skill is — a thin map for placing a change and keeping the arrows straight. Read it as *"be aware of how
this is shaped,"* not *"obey these rules."* How strict to be is the project's call.

Landing a change in the right role buys two things worth wanting:

- **A core you can test** — exercise the business logic with plain inputs and stand-in collaborators, with no
  database, network, or live SDK in the loop.
- **A core you can reuse** — the same use-cases driven from a web handler, a CLI, and a Lambda at once,
  because none of them is baked into the logic.

How close a codebase gets to those is a spectrum, and real ones sit all along it — a NestJS or Spring layout
keeps framework decorators and concrete repositories right beside the domain and ships fine. The roles and
the arrows are the knowledge; how far to push them is judgement.

## The three roles

Names vary — detect what's already there, don't impose your own. The *purpose* is what's universal:

- **Core** (`app` / `application` / `domain` / `core`) — *what the system does.* Business logic, domain
  types, use-cases, and the contracts (interfaces/ports) it declares about what it needs from the world. It
  names the work and the shape of its dependencies, not the concrete systems behind them.
- **Infrastructure** (`infra` / `adapters`) — *how the world is reached.* Concrete implementations of the
  core's contracts against real systems: the database, HTTP clients, vendor SDKs, the filesystem, queues,
  the clock.
- **Composition / run** (`run` / `runtime` / `main` / `cmd`) — *which concretes, and how it's driven.*
  Selects the implementations, wires them into the core, and exposes an entrypoint (CLI, web handler,
  Lambda, bot). The runtime is pluggable; this is the layer that knows which concretes exist.

## Which way dependencies point

Keep one thing straight: **dependencies point inward, at runtime** — `run → core ← infra`. The core declares
the contracts, infra implements them, run wires them; the core doesn't reach out for its collaborators, they
are handed to it.

"At runtime" matters, because dependencies come in two kinds:

- A **runtime dependency** is loaded and executed when the program runs — an ordinary `import` of a value,
  class, or function. These are the arrows that "point inward" governs.
- A **build-time dependency** exists only while compiling or type-checking and is erased before the program
  runs — a TS `import type`, a Python `TYPE_CHECKING` import, a bare annotation. It carries no behaviour: a
  core importing a *type* from its own contract (a GraphQL resolver importing its schema's `QueryResolvers`)
  hasn't reached outward at runtime at all.

So when an arrow leaves the core, the useful question is *which kind* — a runtime arrow (the core now leans on
a concrete or on I/O) or a build-time one (a type that vanishes).

## Where does this code go?

Ask **"what is this code's reason to exist?"** and read the *runtime* arrow, not the surface topic:

| Reason to exist | Layer | Tell |
|---|---|---|
| A business rule, domain concept, use-case, or a contract the system needs | **Core** | At runtime it touches only its arguments, its injected collaborators, and the system's own types. A GraphQL resolver that validates args and calls an injected datasource is core — even though it names GraphQL. |
| Reaching a specific outside system to fulfil a contract the core declared | **Infra** | It implements a core-declared contract with the concrete that does the I/O. Naming a vendor/protocol (Postgres, S3, Stripe, gRPC) is a hint, not the test: the GraphQL *server* and a Postgres *repo* are infra; the *resolver* is core. |
| Choosing *which* concretes run and starting the process | **Run** | It selects implementations, builds the context, and boots / exposes the handler. |

The classic split is a use-case that "needs to call an API": the *call* is infra, the *decision to call and
what to do with the result* is core. The core declares a contract (`RateProvider`), infra implements it, run
injects it. When a change spans roles, splitting it along that seam is the move — if the two payoffs are worth
the seam for that change.

## Naming: let it scream

Top-level names should announce **what the system is** (its domain), not which pattern it uses. A generic
`adapters/` or `utils/` directory becomes a junk drawer that hides intent and accumulates stray logic. Prefer
intent-named buckets; if you group by role, keep the role names few and meaningful. There's no single right
trio — `app/infra/run`, `application/infra/runtime`, `domain/adapters/cmd` are all fine. The split into the
three *roles* is what matters, not the labels.

## Things to be aware of

A few patterns dull the two payoffs. Notice them, then decide whether they matter for this project:

- **I/O or a concrete vendor in the core** — that code can't run in a test without the real system. If
  isolating it matters, push the I/O behind a contract the core declares; if the project is content
  committing to that vendor, the seam may not be worth it.
- **Business logic inside an adapter** — a decision a second adapter can't reuse. Move it to a core use-case;
  leave the adapter a thin translation.
- **A contract declared in infra and imported *up* into the core** — that inverts the arrow. Declare it in
  the core, where it's needed.
- **Wiring or config-reading in the core** — ties it to one deployment. Keep construction and selection in
  run.

Want to *hold* the core to a strict line — no I/O, no vendor imports? That's a worthwhile call, but it's
yours to make and enforce: record it in an ADR and wire up a linter (import-linter, dependency-cruiser /
ESLint boundaries, ArchUnit, go-arch-lint). This skill maps the territory; it doesn't police it.

See `references/anti-patterns.md` for these smells with fixes and a cross-ecosystem naming table.

## Workflow

1. **Detect the layout.** List the top-level packages; identify which plays each role. Use the project's
   vocabulary — don't rename.
2. **Classify the change** with the table above, reading the runtime arrow. If it spans roles, consider the
   split: contract in the core, implementation in infra, wiring in run.
3. **Place it**, and notice which way its dependencies point at runtime.
4. **Flag the smells** that cost a payoff this project actually cares about; leave the trade-offs it has
   deliberately made.
