# Scaffold notes — brownfield mise retrofit (acme-web)

Ran the `scaffold` skill's **brownfield/audit path** against an existing Next.js app. The skill is advisory
and normally asks the user to choose at each fork; with no user present, I took the skill's **recommended
default** at every fork. Those choices, plus the drift report, are recorded here.

## 1. Inventory (detection)

| Signal | Found |
|--------|-------|
| `package.json` | yes — `acme-web`, private, `packageManager: pnpm@10.16.0`; scripts: `dev`, `build`, `start`, `lint`, `test` (next + vitest) |
| `pnpm-lock.yaml` | yes (lockfileVersion 9.0) |
| Toolchain detected | **node** (single toolchain), package manager **pnpm** |
| `mise.toml` / `.mise/` | absent |
| Env file | none |
| `.gitignore` | none |
| `.claude/` / `.agents/` | neither present |

Single-toolchain (node-only) brownfield repo. Nothing about mise existed yet, so this is a clean retrofit
*around* the existing files — `package.json` and `pnpm-lock.yaml` are left byte-for-byte intact.

## 2. Drift report (audit against the standard)

| Check | Status | Recommended fix | Risk |
|-------|--------|-----------------|------|
| Lean `mise.toml` | DRIFT (no mise.toml at all) | Add lean `mise.toml` (`[settings]`/`[tools]`/`[env]`, no inline `[tasks]`) | low — new file |
| File tasks w/ task contract | DRIFT (no tasks) | Add `.mise/tasks/node/*` with shebang + `set -e` + `#MISE description` | low — new files, wrap existing scripts |
| Namespacing | DRIFT (no tasks) | Namespace by toolchain → `node:*` | low |
| Pinned tools | DRIFT (mise didn't manage versions) | Pin major.minor: `node=24`, `pnpm=10.16` | low |
| No leaked internals | PASS | n/a — nothing hard-coded; CodeArtifact path is env-gated | n/a |
| House-rules skill | DRIFT (none) | Generate `acme-web-mise` skill | low |
| Command-skills | PASS (none needed) | node-only, no destructive/multi-step tasks → none | n/a |

All drift items are low-risk **additions**. No higher-risk conversions were needed (no existing env file to
convert, no existing tasks to re-namespace).

## 3. Advisory forks — choices (skill's recommended default at each)

| Fork | Recommended default | Choice taken | Rationale |
|------|---------------------|--------------|-----------|
| Namespacing | namespace by toolchain | **`node:*`** | Standard's default. (Skill *offers* flat names for a single-toolchain repo, but namespacing is the recommended default, and it keeps every repo uniform + `**:` fan-out works.) |
| Env file | `.env.yaml` | **`.env.yaml`** | No existing env file to preserve, so used the house default. |
| Version pinning | major.minor, resolved now | **`node=24`, `pnpm=10.16`** | `pnpm` matches the existing `packageManager: pnpm@10.16.0`. Node pinned to current major.minor (24). |
| Account internals | parameterize via env | **env-gated, none committed** | No internals present; the `node:setup` CodeArtifact block is guarded on `CODEARTIFACT_DOMAIN` and is a no-op unless set in `.env.yaml`. |
| Agent-asset destination | `.claude/` | **`.claude/`** | No `.agents/` tree exists, so used the recommended default. |
| Command-skills | only for destructive/multi-step | **none** | All node tasks are trivial wrappers; a command-skill per task would just dilute triggering. |

## 4. Files created (nothing existing modified)

```
mise.toml                                  # lean: [settings] [tools] [env]
.node-version                              # 24 (idiomatic version file)
.env.yaml                                  # gitignored; mise auto-loads it
.env.example                               # committed template
.gitignore                                 # .env.yaml, node_modules/, .next/
.mise/tasks/node/setup                     # pnpm install --frozen-lockfile
.mise/tasks/node/lint                      # pnpm run lint
.mise/tasks/node/test                      # pnpm run test [pattern]
.mise/tasks/node/build                     # pnpm run build
.mise/tasks/node/dev                       # pnpm run dev
.mise/tasks/node/start                     # pnpm run start  (extra: Next.js prod server)
.claude/skills/acme-web-mise/SKILL.md      # house-rules skill (always)
NOTES.md                                   # this file
```

All `.mise/tasks/node/*` files were `chmod +x`'d.

`node:start` was added beyond the catalog's five core node tasks because the existing `package.json` already
has a `start` script (`next start`) — the standard production-serve step for a Next.js app, part of its
repeated loop. Tasks are thin wrappers over the existing `package.json` scripts, which remain the source of
truth.

## 5. Left intact (verified)

- `package.json` — unchanged.
- `pnpm-lock.yaml` — unchanged.

No install/network commands were run (per the task constraints), so `mise tasks` was not executed; task
files were validated structurally (shebang + `set -e` + `#MISE description` on every file).
