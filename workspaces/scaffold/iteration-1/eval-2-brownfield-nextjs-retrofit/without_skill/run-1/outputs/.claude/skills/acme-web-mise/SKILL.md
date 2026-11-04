---
name: acme-web-mise
description: >-
  acme-web task runner — all repeatable workflows (setup, lint, test, build, dev, start) run through
  mise as `mise run node:<task>`. Use whenever running, adding, or debugging a build/test/dev/lint/start
  command in this repo, or when tempted to `cd` and run `pnpm`/`npm`/`next` directly — that means a mise
  task is missing. Namespace here: node.
---

# acme-web mise tasks

All repeatable work is a mise task. Prefer `mise run <task>` over direct `pnpm`/`npm`/`next`
invocations — mise handles the toolchain (node, pnpm), arguments, flags, and environment consistently.

## Tasks
- `mise run node:setup` — install dependencies (`pnpm install --frozen-lockfile`)
- `mise run node:lint` — lint the codebase (`next lint`)
- `mise run node:test [pattern]` — run the test suite (`vitest run`), optional name/path filter
- `mise run node:build` — build for production (`next build`)
- `mise run node:dev` — start the dev server (`next dev`)
- `mise run node:start` — start the production server (`next start`)

List everything mise knows with `mise tasks`. Run a step across every namespace with the glob:
`mise run '**:setup'`, `mise run '**:lint'`.

## Adding a task
1. Create an executable bash file at `.mise/tasks/<namespace>/<task>` (use the `node` namespace here).
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `cd <dir> && <cmd>`, a task is missing — add it
instead of running it raw. The underlying `package.json` scripts stay as-is; the mise tasks wrap them so the
toolchain and environment are pinned and consistent.
