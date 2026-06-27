---
name: acme-web-mise
description: >-
  acme-web task runner — all repeatable workflows (setup, lint, test, build, dev, start) run through
  mise as `mise run node:<task>`. Use whenever running, adding, or debugging a build/test/dev/lint/start
  command in this repo, or when tempted to `cd . && pnpm run …` — that means a mise task is missing.
  Namespaces here: node.
---

# acme-web mise tasks

All repeatable work is a mise task. Prefer `mise run node:<task>` over direct `pnpm`/`next` invocations —
mise handles the toolchain version, environment, and arguments consistently.

## Tasks
- `mise run node:setup` — install dependencies (`pnpm install --frozen-lockfile`)
- `mise run node:lint` — lint the codebase (`next lint`)
- `mise run node:test [pattern]` — run the test suite (`vitest run`, optional filter)
- `mise run node:build` — build for production (`next build`)
- `mise run node:dev` — start the dev server (`next dev`)
- `mise run node:start` — start the production server after a build (`next start`)

Run a step across every module with the glob: `mise run '**:setup'`, `mise run '**:lint'`.

## Adding a task
1. Create an executable bash file at `.mise/tasks/node/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `cd . && pnpm run <cmd>`, a task is missing — add
it instead of running it raw. Tasks wrap the existing `package.json` scripts; the scripts stay the source of
truth for what each command does.
