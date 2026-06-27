# Scaffold notes — acme-platform (brownfield)

Ran the `scaffold` skill's brownfield/audit path. The repo already had code (pnpm monorepo + FastAPI +
compose) but **no mise setup**, so the work was: add the mise layer around the existing files without
touching them.

## Detected context

| Signal | Found | → toolchain |
|--------|-------|-------------|
| `package.json` + `pnpm-workspace.yaml` + `pnpm-lock.yaml`, `packageManager: pnpm@10.16.0` | yes | **node** (pnpm workspaces) |
| `packages/frontend/package.json` — Next.js 15, React 19, vitest | yes | node, frontend = dev server |
| `packages/api/pyproject.toml` — FastAPI + uvicorn, `requires-python >=3.13`, pytest | yes | **python** (`py`) |
| `compose.yml` — `localstack` service (s3, sqs, lambda) | yes | **docker** + **localstack** |
| Private npm deps note from user | n/a | **aws** (CodeArtifact via `aws-auth`) |
| existing `mise.toml` / `.mise/` | none | greenfield mise layer |
| existing `.env*` | none | use house default `.env.yaml` |
| existing `.agents/` tree | none | agent assets → `.claude/` |

## Drift report (audit against the standard)

Because there was no prior mise setup, every check is a clean-slate "add", not a conversion:

| Check | Status before | Action taken |
|-------|---------------|--------------|
| Lean `mise.toml` (no inline tasks) | absent | created lean `mise.toml`; all tasks are files |
| Task contract (`#!/usr/bin/env bash`, `set -e`, `#MISE description`) | absent | every task file follows it |
| Namespacing by toolchain | absent | `node:`, `py:`, `docker:`, `localstack:` |
| Pinned tools | absent | pinned major.minor (see below) |
| No leaked internals | n/a | CodeArtifact domain/owner/region parameterized via `.env.yaml` |
| House-rules skill | absent | added `.claude/skills/acme-platform-mise/SKILL.md` |
| Command-skills for destructive tasks | absent | added one for `localstack:deploy` |

## Advisory forks — chose the RECOMMENDED default at each (no user to ask)

| Fork | Recommended default | Chosen | Rationale |
|------|---------------------|--------|-----------|
| Namespacing | by toolchain | **by toolchain** | polyglot repo (node + python + infra); enables `**:` fan-out, avoids `test`-clash |
| Env file | `.env.yaml` | **`.env.yaml`** | no existing env file, so house default; mise auto-loads via `_.file` |
| Version pinning | major.minor, resolved now | **major.minor** | node `24`, pnpm `10.16` (from `packageManager`), python `3.13` (from `requires-python`), aws-cli `2` |
| Account internals | parameterize via env | **parameterized** | `CODEARTIFACT_DOMAIN/OWNER`, `NPM_REGISTRY_HOST`, `AWS_REGION` in `.env.yaml`; never hard-coded |
| Agent-asset dest | `.claude/` | **`.claude/`** | no `.agents/` tree present |

## Repo-specific adaptations

- **Monorepo working dirs.** node `setup/lint/test/build` run at the repo root and delegate to pnpm
  workspaces (`pnpm -r …` / the root scripts). `node:dev` is scoped to the frontend via `#MISE
  dir="packages/frontend"` since that's the only dev server. `py:*` tasks all carry `#MISE
  dir="packages/api"`.
- **CodeArtifact in `node:setup`.** Private npm deps come from AWS CodeArtifact. `node:setup` sources the
  `aws-auth` helper and mints a short-lived token only when `CODEARTIFACT_DOMAIN` is set, so the task still
  works for contributors without private deps configured.
- **`py:setup`** installs the editable pyproject project (`pip install -e .`) rather than a
  `requirements.txt` (the project uses pyproject), with a graceful fallback if no `[dev]` extra exists.
- **Command-skill scope.** Only `localstack:deploy` got a command-skill (it provisions shared local
  state / multi-step). `docker:up/down`, lint, test, build, dev are covered by the house-rules skill plus
  raw `mise run`.

## Left intact (verified, not modified)

`package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `packages/frontend/package.json`,
`packages/api/pyproject.toml`, `compose.yml`. The mise setup was added *around* them.

## Files created

```
mise.toml
.node-version            (24)
.python-version          (3.13)
.env.example             (copy → .env.yaml; .env.yaml is gitignored)
.gitignore
README.md                (Tasks section + local-dev quickstart)
NOTES.md                 (this file)
.mise/tasks/
  aws-auth               (sourced helper — CodeArtifact/ECR token minting)
  node/{setup,lint,test,build,dev}
  py/{setup,lint,test,build,dev}
  docker/{up,down}
  localstack/{setup,deploy}
.claude/
  skills/acme-platform-mise/SKILL.md       (house-rules skill)
  commands/localstack-deploy/SKILL.md      (command-skill for the destructive task)
```

## Verification

- All `.mise/tasks/**` files are `chmod +x` and carry the task contract.
- Did not run install/network commands (per task constraints). `mise tasks` not run here because mise may
  not be installed in this sandbox; every task header was authored to the documented `#MISE`/`#USAGE` shape.
