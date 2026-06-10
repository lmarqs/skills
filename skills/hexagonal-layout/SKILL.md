---
name: hexagonal-layout
description: >-
  Place new code in the correct layer of a hexagonal / ports-and-adapters / "screaming"
  architecture and keep the domain core pure. Use whenever adding a feature, a new integration
  or provider (database, HTTP client, vendor SDK, queue, filesystem, clock, randomness), or a
  new entrypoint (CLI, web handler, Lambda) to a project that separates a pure core from
  infrastructure and wiring — and whenever you are unsure which directory a module belongs in,
  a change might leak I/O or a third-party import into the domain, or you are reviewing whether
  a core/domain package is actually pure. Works for any language; tuned for Python projects with
  core/domain + infra/adapters + run/composition layers (e.g. app/infra/run). Reach for it even
  when the user never says "hexagonal" — "where should this go", "add the Postgres repository",
  "wire it up", "keep the domain clean", or "is my core pure" are all signals.
---

# Hexagonal layout: place code right, keep the core pure

Hexagonal architecture (ports & adapters, the clean-architecture core) splits a codebase into three roles.
Get a change into the right one and two things follow for free: the domain stays unit-testable without
mocking the world, and adding or swapping an integration is *additive* — it touches one layer, not all of
them.

There is exactly **one rule**, and everything else is a consequence of it:

> **Source dependencies point inward. The core depends on nothing outside itself.**

## The three roles

Directory names vary by project (see `references/anti-patterns.md` for the cross-ecosystem table) — detect
the names the project already uses rather than imposing your own. The *roles* are universal:

- **Core** (`app` / `domain` / `core`) — **pure business logic**: domain types, use-cases, and the
  **contracts the system declares** (interfaces/ports, enums, constants). It names *what* must happen and
  *what* it needs from the world, never *how* the world provides it. No I/O, no SDK, no concrete vendor.
- **Infrastructure** (`infra` / `adapters`) — **implements the core's contracts** against the real world:
  the database, HTTP clients, vendor SDKs, the filesystem, the clock, queues. One adapter per port.
- **Composition / run** (`run` / `main` / `cmd`) — **chooses which adapters to use and starts the
  program**: reads config/env, constructs the adapters, injects them into the core, exposes an entrypoint
  (CLI, web handler, Lambda). The runtime form is pluggable; this is the only layer that knows *which*
  concretes exist.

The dependency direction is therefore `run → core ← infra`: the core declares the interfaces, infra
implements them, run wires them — and nothing ever points back into the core.

## Where does this code go?

Ask **"what is this code's reason to exist?"** and apply the litmus test — it cuts through cases where the
surface topic misleads:

| Reason to exist | Layer | Litmus test |
|---|---|---|
| A business rule, domain concept, use-case, or a contract (interface/enum/constant) the system needs | **Core** | *Can I unit-test it with no network, filesystem, clock, or fake SDK?* If yes → core. |
| Talking to a specific outside system to fulfil a contract the core declared | **Infra** | *Does it name a vendor or protocol (Postgres, S3, Stripe, gRPC, the OS clock)?* If yes → infra. |
| Deciding *which* concretes are used and booting the process | **Run** | *Does it read config or construct-and-inject adapters?* If yes → run. |

The classic trap is a use-case that "needs to call an API." The call is infra; the *decision to call and
what to do with the result* is core. Split it: the core declares a port (e.g. `RateProvider`), infra
implements it with the HTTP client, run injects the implementation. **The core never imports the HTTP
library.** When a change spans roles, this split is the move — don't put it all in one place to avoid the
seam; the seam is the point.

## Keep the core pure (the invariant worth enforcing)

"Pure" is two checks, and the second is the one people forget:

1. The core imports **nothing from infra/run** (the dependency direction).
2. The core imports **no I/O-capable module at all** — `subprocess`, `os`, `pathlib`, sockets, `http`,
   `urllib`, DB drivers, vendor SDKs. This is what makes "pure" mean *pure* rather than "import-clean."

Enforce it with a **static** check (parse the source, don't run it) so it fails even on an import that is
never executed — an unexecuted `import os` in the core is still a breach. `scripts/check_core_purity.py`
does exactly this and needs no dependencies:

```bash
python scripts/check_core_purity.py path/to/core --layer infra --layer run
# add vendor clients the core must never import:
python scripts/check_core_purity.py src/domain -l infrastructure --io-module requests --io-module boto3
```

Wire it into the test suite / CI. Without an automated guard the invariant rots silently — the next
contributor adds one import and nothing complains. **The purity check is load-bearing; treat deleting or
weakening it as a smell, not a cleanup.**

## Naming: let it scream

Top-level names should announce **what the system is** (its domain), not which pattern it uses. A generic
`adapters/` or `utils/` directory becomes a junk drawer that hides intent and quietly accumulates business
logic. Prefer intent-named buckets; if you group by role, keep the role names few and meaningful. There is
no single "right" three words — `app/infra/run`, `domain/adapters/cmd`, `core/infra/main` are all fine. The
split into the three *roles* above is what matters, not the labels.

## Workflow

1. **Detect the existing layout.** List the top-level packages; identify which one plays each role (core /
   infra / composition). Match the project's vocabulary — don't rename.
2. **Classify the change** with the table above. If it spans roles, split it: declare the port in the core,
   implement in infra, wire in run.
3. **Place it**, keeping every new core import inward-only and I/O-free.
4. **Verify** with `scripts/check_core_purity.py` and the project's own tests. If the project has no purity
   guard yet, offer to add one — it is the cheapest insurance the layout has.

See `references/anti-patterns.md` for the smells that violate the one rule and how to fix each.
