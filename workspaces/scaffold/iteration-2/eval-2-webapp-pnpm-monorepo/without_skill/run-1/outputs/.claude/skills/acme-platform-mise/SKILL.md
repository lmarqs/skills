---
name: acme-platform-mise
description: >-
  acme-platform task runner — all repeatable workflows (setup, lint, test, build, dev, plus localstack and
  docker for local infra) run through mise as `mise run <namespace>:<task>`. Use whenever running, adding, or
  debugging a build/test/lint/dev command in this pnpm monorepo, spinning up local dev (LocalStack + docker
  compose), or when tempted to `cd packages/frontend && pnpm run …` or `cd packages/api && pytest` — that
  means a mise task is missing. Namespaces here: node (frontend), python (api), localstack, docker.
---

# acme-platform mise tasks

All repeatable work is a mise task. Prefer `mise run <task>` over direct `pnpm`/`pytest`/`docker`/`aws`
invocations — mise handles the per-module working directory, args, flags, and environment consistently.

## Tasks

**node (packages/frontend — Next.js):**
- `mise run node:setup` — install the pnpm workspace deps (authenticates to AWS CodeArtifact first when configured)
- `mise run node:lint` — lint the frontend
- `mise run node:test [pattern]` — run the frontend test suite (vitest)
- `mise run node:build` — production build
- `mise run node:dev` — start the Next.js dev server

**python (packages/api — FastAPI):**
- `mise run python:setup` — install API deps into the venv
- `mise run python:lint` — ruff lint
- `mise run python:test [pattern]` — pytest (optional `-k` filter)
- `mise run python:dev` — start uvicorn with auto-reload

**localstack / docker (local infra):**
- `mise run docker:up` / `mise run docker:down` — start/stop the full local stack
- `mise run localstack:setup` — start LocalStack only
- `mise run localstack:deploy` — provision local AWS resources into LocalStack

Fan a step across every module with the glob: `mise run '**:setup'`, `mise run '**:lint'`, `mise run '**:test'`.

## Private dependencies (AWS CodeArtifact)

Private npm packages are served from **AWS CodeArtifact**, not the public registry. `node:setup` sources
`.mise/tasks/aws-auth` and fetches a CodeArtifact token automatically when `CODEARTIFACT_DOMAIN` is set in
`.env.yaml`. Account id / domain / registry host live in `.env.yaml` (gitignored) — never hard-code them in
task scripts. Copy `.env.example` to `.env.yaml` and fill in the values.

## Adding a task
1. Create an executable bash file at `.mise/tasks/<namespace>/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#MISE dir=` / `#USAGE` as needed).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `cd packages/<x> && <cmd>`, a task is missing — add
it instead of running it raw.
