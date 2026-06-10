# Anti-patterns and the cross-ecosystem naming table

Every smell below is a violation of the one rule — *dependencies point inward, the core is pure*. The fix
always restores it.

## Smells and fixes

### 1. Business logic in an adapter
An infra adapter does more than translate — it decides, validates, or computes a domain rule.
**Why it hurts:** the rule is now untestable without the real integration, and a second adapter would
duplicate or contradict it.
**Fix:** move the decision into a core use-case; leave the adapter a thin translation to/from the outside
system.

### 2. I/O or a vendor import in the core
`import requests` / `boto3` / `psycopg2`, `open(...)`, or `datetime.now()` inside the core.
**Why it hurts:** the core can no longer be unit-tested in isolation, and it is welded to one vendor.
**Fix:** declare a port in the core for what you need (`Clock`, `RateProvider`, `OrderRepo`); implement it
in infra; inject it. The clock and randomness are I/O too — pass them in rather than calling them.

### 3. The junk-drawer `adapters/` or `utils/`
A generic bucket named for the pattern (or for nothing) that collects unrelated code.
**Why it hurts:** intent disappears; business logic hides among helpers; the layout stops screaming.
**Fix:** name buckets for intent/domain. True cross-cutting *pure* helpers belong in the core; integrations
belong under names that say which system they adapt.

### 4. The interface defined in the wrong layer
The port is declared in infra (next to its implementation) and the core imports *up* to reach it.
**Why it hurts:** it inverts the dependency — the core now depends on infra, and the whole benefit is lost.
**Fix:** the **core owns the interface**; infra imports the core to implement it. An interface lives where
it is *needed*, not where it is *implemented*.

### 5. Wiring/orchestration leaking into the core
The core reads env vars, constructs concrete adapters, or chooses which implementation to use.
**Why it hurts:** the core now knows about concretes and config — it can't be reused or tested cleanly.
**Fix:** all construction and selection lives in composition/run; the core receives its dependencies
ready-made (constructor or argument injection).

### 6. Anemic core / logic in run
All the real behavior sits in the entrypoint (the CLI/handler) and the core is just data classes.
**Why it hurts:** the behavior is bound to one runtime; a second entrypoint (web + CLI) duplicates it.
**Fix:** push use-cases into the core; run stays thin — parse input, call a use-case, render output.

## Role → common directory names by ecosystem

Detect and reuse what the project already has; this table is for recognition, not prescription.

| Role | Python | TypeScript / Nest | Java / Spring | Go |
|---|---|---|---|---|
| Core (pure) | `app`, `domain`, `core` | `domain`, `core` | `domain` | `internal/<domain>`, `core` |
| Infrastructure | `infra`, `adapters` | `infrastructure`, `adapters` | `infrastructure`, `adapter` | `internal/adapters`, `infra` |
| Composition/run | `run`, `main`, `cmd` | `main.ts`, `app.module.ts` | `Application`, `config` | `cmd/<app>` |

If a project mixes conventions, follow the one its core already uses and note the inconsistency rather than
churning a rename.
