# acme-web

A Next.js application. Tooling is managed with [mise](https://mise.jdx.dev): it pins the
toolchain (node, pnpm) and exposes the repeatable workflows as namespaced tasks.

## Getting started

```bash
mise install        # install the pinned node + pnpm
mise run node:setup # install dependencies
mise run node:dev   # start the dev server
```

## Tasks

All repeatable work runs through mise as `mise run node:<task>`. Run `mise tasks` to list them.

| Task | What it does | Wraps |
|------|--------------|-------|
| `mise run node:setup` | Install dependencies (frozen lockfile) | `pnpm install --frozen-lockfile` |
| `mise run node:lint` | Lint the codebase | `pnpm run lint` (`next lint`) |
| `mise run node:test [pattern]` | Run the test suite (optional filter) | `pnpm run test` (`vitest run`) |
| `mise run node:build` | Build for production | `pnpm run build` (`next build`) |
| `mise run node:dev` | Start the dev server | `pnpm run dev` (`next dev`) |
| `mise run node:start` | Start the production server | `pnpm run start` (`next start`) |

The existing `package.json` scripts still work directly; the mise tasks wrap them so the toolchain
and environment stay pinned and consistent across machines and CI.

## Configuration

- `mise.toml` — pinned tools (`node`, `pnpm`), settings, and env wiring.
- `.node-version` — node version, read by mise (and other tools).
- `.env.yaml` — local environment, auto-loaded by mise. Gitignored; copy from `.env.example`.
- `.mise/tasks/node/*` — the task scripts.
