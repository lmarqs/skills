---
name: acme-platform-mise
description: >-
  acme-platform task runner — all repeatable workflows (setup, lint, test, build, dev) and local infra
  (docker, localstack) run through mise as `mise run <namespace>:<task>`. Use whenever running, adding, or
  debugging a build/test/lint/dev command, spinning up local dev infra, or when tempted to
  `cd packages/frontend && pnpm run …` or `cd packages/api && pytest …` — that means a mise task is missing.
  Namespaces here: node (pnpm workspaces / Next.js frontend), py (FastAPI service in packages/api),
  docker, localstack.
---

# acme-platform mise tasks

This is a pnpm monorepo: a Next.js frontend in `packages/frontend` and a FastAPI service in `packages/api`,
with `compose.yml` providing local infra (LocalStack for AWS emulation). All repeatable work is a mise task.
Prefer `mise run <task>` over direct `pnpm`/`pytest`/`docker` invocations — mise handles the working
directory, args, flags, and environment consistently.

## Tasks

Node (pnpm workspaces — run from repo root):
- `mise run node:setup` — install workspace deps (authenticates to AWS CodeArtifact first; see below)
- `mise run node:lint` — `pnpm -r lint`
- `mise run node:test [pattern]` — `pnpm -r test`
- `mise run node:build` — `pnpm -r build`
- `mise run node:dev` — start the Next.js frontend dev server (runs in `packages/frontend`)

Python API (`packages/api`):
- `mise run py:setup` — install the API into the project venv
- `mise run py:lint` — `ruff check`
- `mise run py:test [pattern]` — `pytest` (optional `-k` filter)
- `mise run py:build` — build the API distribution
- `mise run py:dev` — start uvicorn with autoreload

Local infra:
- `mise run docker:up` / `mise run docker:down` — bring the whole compose stack up/down
- `mise run localstack:setup` — start only LocalStack
- `mise run localstack:deploy` — provision local AWS resources into LocalStack

Fan a step across every module with the glob: `mise run '**:setup'`, `mise run '**:lint'`,
`mise run '**:test'`, `mise run '**:build'`.

## Local dev, start to finish
```bash
mise run docker:up          # start LocalStack + any other infra
mise run '**:setup'         # install node + python deps
mise run localstack:deploy  # provision local AWS resources
mise run node:dev           # frontend  (and, in another shell)
mise run py:dev             # backend API
```

## Private npm dependencies (AWS CodeArtifact)
Private npm packages are served from **AWS CodeArtifact**, not the public registry. `node:setup` mints a
short-lived CodeArtifact auth token (via the `aws-auth` helper) and points pnpm/npm at the registry whenever
`CODEARTIFACT_DOMAIN` is set in `.env.yaml`. Copy `.env.example` → `.env.yaml` and fill in
`CODEARTIFACT_DOMAIN`, `CODEARTIFACT_OWNER`, and `NPM_REGISTRY_HOST`; you must be authenticated to AWS
(`aws sso login`). Account-specific values live only in `.env.yaml` (gitignored) — never hard-code them in
task scripts.

## Adding a task
1. Create an executable bash file at `.mise/tasks/<namespace>/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags, `#MISE
   dir="packages/…"` to run inside a module).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `cd <dir> && <cmd>`, a task is missing — add it
instead of running it raw.
