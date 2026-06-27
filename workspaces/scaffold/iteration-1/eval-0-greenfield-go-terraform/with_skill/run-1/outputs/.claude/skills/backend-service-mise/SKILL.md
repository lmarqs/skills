---
name: backend-service-mise
description: >-
  Backend-service task runner — all repeatable workflows (setup, lint, test, build, fmt, and the terraform
  plan/apply flow) run through mise as `mise run <namespace>:<task>`. Use whenever running, adding, or
  debugging a build/test/lint/deploy command in this repo, or when tempted to `cd <dir> && go ...` or run
  `terraform ...` by hand — that means a mise task is missing. Namespaces here: go, tf.
---

# Backend service mise tasks

All repeatable work is a mise task. Prefer `mise run <task>` over direct `go`/`terraform` invocations —
mise handles the working directory, args, flags, and environment (region/profile from `.env.yaml`)
consistently.

## Tasks

Go:
- `mise run go:setup` — download module dependencies
- `mise run go:build` — compile all packages
- `mise run go:test [--cover]` — run tests (optionally with coverage)
- `mise run go:lint` — run golangci-lint
- `mise run go:fmt` — format Go code

Terraform (`<module>` is a directory under `modules/`):
- `mise run tf:init <module>` — initialize a module
- `mise run tf:plan <module>` — show a plan
- `mise run tf:apply <module> [--auto-approve]` — apply changes
- `mise run tf:fmt` — format all `.tf` files
- `mise run tf:check` — check formatting and validate

Run a step across everything with the glob: `mise run '**:setup'`, `mise run '**:fmt'`.

## AWS auth

The `tf:*` tasks that touch AWS source `.mise/tasks/aws-auth`, which fails fast unless you are
authenticated (`aws sso login`). Region and any profile come from `.env.yaml` — never hard-code account
ids, regions, or domains in task scripts.

## Adding a task
1. Create an executable bash file at `.mise/tasks/<namespace>/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `cd <dir> && <cmd>`, a task is missing — add it
instead of running it raw.
