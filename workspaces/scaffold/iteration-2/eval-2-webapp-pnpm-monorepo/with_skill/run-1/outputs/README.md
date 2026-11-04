# acme-platform

pnpm monorepo: a Next.js frontend (`packages/frontend`) and a FastAPI service (`packages/api`), with
`compose.yml` for local infra (LocalStack emulates AWS).

## Tasks

Tooling and the repeatable build/test/dev loop run through [mise](https://mise.jdx.dev). Install mise, then
`mise install` to get the pinned toolchain (node 24, pnpm 10.16, python 3.13, aws-cli 2). Copy
`.env.example` → `.env.yaml` and fill it in.

| Task | What it does |
|------|--------------|
| `mise run node:setup` | Install pnpm workspace deps (authenticates to AWS CodeArtifact if configured) |
| `mise run node:lint` | Lint all workspaces (`pnpm -r lint`) |
| `mise run node:test [pattern]` | Test all workspaces (`pnpm -r test`) |
| `mise run node:build` | Build all workspaces (`pnpm -r build`) |
| `mise run node:dev` | Start the Next.js frontend dev server |
| `mise run py:setup` | Install the API into the project venv |
| `mise run py:lint` | Lint/type-check the API (`ruff`) |
| `mise run py:test [pattern]` | Run the API test suite (`pytest`) |
| `mise run py:build` | Build the API distribution |
| `mise run py:dev` | Start the API dev server (uvicorn, autoreload) |
| `mise run docker:up` / `docker:down` | Bring the full compose stack up / down |
| `mise run localstack:setup` | Start only LocalStack |
| `mise run localstack:deploy` | Provision local AWS resources into LocalStack |

Fan a step across both modules: `mise run '**:setup'`, `mise run '**:lint'`, `mise run '**:test'`,
`mise run '**:build'`.

### Local dev

```bash
mise run docker:up          # LocalStack + infra
mise run '**:setup'         # install node + python deps
mise run localstack:deploy  # provision local AWS resources
mise run node:dev           # frontend  (separate shell)
mise run py:dev             # backend API
```

### Private npm dependencies

Private npm packages come from **AWS CodeArtifact**. `node:setup` mints a short-lived CodeArtifact auth
token and points pnpm at the registry when `CODEARTIFACT_DOMAIN` is set in `.env.yaml` (requires
`aws sso login`). Account-specific values live only in `.env.yaml` (gitignored), never in task scripts.
