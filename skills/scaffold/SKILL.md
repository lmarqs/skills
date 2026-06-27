---
name: scaffold
disable-model-invocation: true
description: >-
  Scaffold or audit a project's mise task-runner setup the house-standard way — generates a lean
  mise.toml, directory-namespaced .mise/tasks/* scripts (tf:apply, node:setup), a project "mise"
  house-rules skill, and command-skills for destructive tasks; greenfield or brownfield (detect what's
  there, report drift, fix on approval). Advisory: recommends the standard, explains the tradeoffs, and
  lets you decide. A deliberate, roughly once-per-project setup action — invoke it explicitly with
  /scaffold when starting or standardizing a repo (terraform, python, node, go, localstack,
  docker-compose, aws, arduino/platformio). Not for everyday build/test/lint runs.
---

# Scaffold a mise project

This skill stands up a project's [mise](https://mise.jdx.dev) setup — or upgrades an existing one — so it
matches a consistent house pattern and people start shipping immediately instead of reinventing a task
runner per repo.

**The governing idea: this is advisory, not enforcing.** A standard is a strong *recommendation*, a pattern
to adapt to context — not a rule to impose. At every decision point, state the recommended default, explain
the **pros, cons, and risk of deviating**, default to the recommendation, and let the user choose. You are
flexible about *what* gets built (which toolchains, which modules) and opinionated about *how* it's built
(the task contract, the file layout). That combination is what makes a scaffold both fast and consistent.

The goal is to cover the **repeated** work — the handful of commands a human runs weekly and CI runs on every
push (setup, lint, test, build, dev, deploy) — not every conceivable operation. A lean scaffold that nails
the common loop beats an exhaustive one nobody reads.

## The model in one breath

- `mise.toml` stays **lean**: `[settings]`, `[tools]` (pinned), `[env]`. No inline `[tasks]`.
- Every repeatable workflow is a **file task** at `.mise/tasks/<namespace>/<task>`. The directory path becomes
  the task name with `:` as the separator — `.mise/tasks/tf/apply` → `mise run tf:apply`,
  `.mise/tasks/node/setup` → `mise run node:setup`. Run a step across all modules with the glob:
  `mise run '**:setup'`.
- Future agents get a generated **"mise" house-rules skill** so they reach for `mise run <task>` instead of
  ad-hoc `cd packages/x && npm run y`.

## How to work

Work through these in order. Lean on the reference files for the actual templates — keep this file in mind
for the *flow and the why*, and open a reference when you reach its step.

1. **Detect the context.** Scan the target directory for signals: `go.mod`, `package.json`,
   `*.tf`/`*.tofu`, `platformio.ini`, `*.ino`/`sketch.yaml`, `compose.y*ml`/`docker-compose.y*ml`,
   `requirements.txt`/`pyproject.toml`, and any existing `mise.toml` or `.mise/`. An empty (or
   nearly-empty) directory is **greenfield**; anything with code already is **brownfield** → read
   `references/audit.md` and follow the audit path instead of generating blindly.

2. **Pick the toolchains.** Greenfield: ask which of {terraform, python, node, go, localstack, docker,
   arduino, pio, aws-auth} apply. Brownfield: pre-select what you detected and recommend the rest. The
   namespaces fall out of this choice — picking `node` + `terraform` gives you `node:*` + `tf:*`.

3. **Talk through the advisory forks.** For namespacing, env-file format, version pinning, how to handle
   account-specific internals, and where the generated agent assets live, read
   `references/standard.md` — it has the recommended default and the tradeoffs for each. Present them,
   recommend, let the user decide. Capture their choices; they drive every template below.

4. **Resolve tool versions.** Recommended: pin **major.minor** resolved at scaffold time (e.g. `node = "24"`,
   `terraform = "1.13"`). It balances reproducibility against staying current. Offer exact-patch (max
   reproducibility) or major-only (loosest) as alternatives.

5. **Materialize the files** (show the tree and diffs first; on brownfield, never overwrite — propose
   patches and apply on approval):
   - `mise.toml` — skeleton in `references/standard.md`.
   - The selected `.mise/tasks/**` scripts — templates in `references/catalog.md`. Substitute the user's
     parameters, then `chmod +x` each file.
   - `.env.yaml` (or `.env`), `.node-version`/`.python-version`, `.gitignore` entries.
   - The agent layer — `references/agent-layer.md`.
   - A short "Tasks" section in the README (or CONTEXT.md) listing what was generated and how to run it.

6. **Verify.** Run `mise tasks` — every generated task must list without a parse error. Then confirm a
   representative task resolves (e.g. `mise run --help` or a dry `mise run <ns>:lint` where safe).

## The task-file contract (and why it matters)

Every `.mise/tasks/<ns>/<task>` file follows the same shape. This isn't ceremony — mise parses these headers
to *list* and *document* tasks, so a missing `description` means an undiscoverable task, and missing
`set -e` means a failing step can silently pass CI.

```bash
#!/usr/bin/env bash
#MISE description="One-line, human-readable — shows up in `mise tasks`"
#MISE dir="packages/frontend"          # optional: working directory, relative to repo root
#USAGE arg "<module>" help="…"         # optional: positional args  → $usage_module
#USAGE flag "--auto-approve"           # optional: flags            → $usage_auto_approve
set -e

# … the actual work …
```

Full per-toolchain templates (already parameterized) live in `references/catalog.md`.

## The agent layer

Two kinds of generated skill, for two different reasons:

- **Always: one project "mise" house-rules skill.** Regenerated with *this* project's actual namespaces, it
  teaches future agents the local convention — use `mise run`, where tasks live, how to add one. Without it,
  agents drift back to `cd x && npm run y` and the standard rots. Template in `references/agent-layer.md`.
- **Selectively: per-task command-skills, only for destructive or multi-step tasks** (`tf:apply`, `tf:plan`,
  `localstack:deploy`). These carry guardrails — confirm before applying, one resource at a time. A trivial
  `node:lint` doesn't need its own skill; the house-rules skill plus raw `mise run` covers it. Adding a skill
  per task just dilutes triggering and adds files nobody reads.

## Keep account-specific internals out of the repo

Tasks frequently need an AWS account id, a private-registry domain, a region. **Never hard-code these** —
they leak internal identifiers (especially bad for a public repo) and make the task only work in one account.
Parameterize them through env (`${AWS_ACCOUNT_ID}`, `${CODEARTIFACT_DOMAIN}`, `${AWS_REGION}`) sourced from
`.env.yaml`, and treat `aws-auth` as a *sourced helper* other tasks pull in — see `references/catalog.md`.

## Reference files

- `references/standard.md` — the conventions with their tradeoffs (namespacing, env format, pinning,
  internals, agent-asset destination) + the `mise.toml` skeleton. Read at step 3–4.
- `references/catalog.md` — the per-toolchain core task templates (parameterized bash). Read at step 5.
- `references/agent-layer.md` — the house-rules skill template + the command-skill template + the rule for
  which tasks qualify. Read at step 5.
- `references/audit.md` — brownfield drift detection and the report-then-fix-on-approval procedure. Read at
  step 1 whenever the directory already has code.
