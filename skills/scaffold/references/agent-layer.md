# The agent layer — generated skills

Two kinds of generated skill, for two different jobs. Generate them into the destination chosen at step 3
(`.claude/` by default, `.agents/` for teams that treat it as source of truth).

## 1. The project "mise" house-rules skill (always generate one)

**Why:** without it, future agents drift back to `cd packages/x && npm run y`, the env/working-dir handling
gets inconsistent, and the standard rots. This skill is the durable instruction that keeps a repo on-pattern
long after the scaffold runs. It auto-triggers, so its `description` must carry real trigger conditions.

Write to `<dest>/skills/<project>-mise/SKILL.md`. Fill `<project>`, the real namespace list, and the actual
generated tasks — it must describe *this* repo, not a generic one.

```markdown
---
name: <project>-mise
description: >-
  <Project> task runner — all repeatable workflows (setup, lint, test, build, dev, deploy) run through
  mise as `mise run <namespace>:<task>`. Use whenever running, adding, or debugging a build/test/dev/deploy
  command in this repo, or when tempted to `cd <dir> && <pkg-manager> run …` — that means a mise task is
  missing. Namespaces here: <list, e.g. node, tf, localstack>.
---

# <Project> mise tasks

All repeatable work is a mise task. Prefer `mise run <task>` over direct `npm`/`terraform`/`docker`
invocations — mise handles the working directory, args, flags, and environment consistently.

## Tasks
<!-- Generated from .mise/tasks. Group by namespace. Example: -->
- `mise run node:setup` — install dependencies
- `mise run node:test [pattern]` — run the test suite
- `mise run tf:apply <module> [--auto-approve]` — apply a Terraform module
Run a step across every module with the glob: `mise run '**:setup'`, `mise run '**:lint'`.

## Adding a task
1. Create an executable bash file at `.mise/tasks/<namespace>/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `cd <dir> && <cmd>`, a task is missing — add it
instead of running it raw.
```

## 2. Command-skills — only for destructive or multi-step tasks

**Why selective:** a command-skill earns its place when a task needs *guardrails* (confirm before applying,
operate one resource at a time, surface a plan first) or has non-obvious args. `tf:apply`, `tf:plan`,
`localstack:deploy`, a `release:publish` qualify. A `node:lint` or `go:fmt` does not — wrapping every task
just adds files and dilutes which skill should trigger. Default rule: **generate a command-skill only for
tasks that change remote/shared state or chain several steps.**

Write to `<dest>/commands/<task>/SKILL.md`:

```markdown
---
name: <task>
description: >-
  <What it does and the guardrail>. Use when the user wants to <intent>. <Any safety note, e.g. shows a plan
  and asks for confirmation before applying.>
argument-hint: "<args>"
---

# <Task title>

Run `mise run <namespace>:<task> <args>` to <do the thing>.

## Usage
```bash
mise run <namespace>:<task> <example>
```

## Instructions
1. Parse `$ARGUMENTS` for the required args; if missing, ask.
2. Build and run the `mise run` command.
3. For destructive tasks: surface the plan/diff, apply one unit at a time, wait for review between each.
4. Report the result.
```
