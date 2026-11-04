# Scaffold decisions

Context: **greenfield** (empty directory). Followed the `scaffold` skill. No user present, so
every advisory fork took the skill's RECOMMENDED default.

## Toolchain mapping
Requested: Cloudflare Workers, TypeScript on Node, deployed with wrangler, with an AWS-authenticated
build step. The skill's toolchain set has no "cloudflare" template, so per the skill's "adapt and still
produce contract-conforming tasks" guidance:

- **node** — built-in template, covers `setup` / `lint` / `test`. Swapped pnpm → npm (no pnpm requested;
  `npm ci` is the lockfile-respecting equivalent of `pnpm install --frozen-lockfile`).
- **cf** — new namespace adapted for the cloudflare/wrangler workflow (no built-in template). Contains
  `dev` / `build` / `deploy`, each following the task contract (`#!/usr/bin/env bash`, `set -e`,
  `#MISE description`, `#USAGE` where relevant).
- **aws-auth** — the sourced helper (not a runnable task), included because a build step reads a config
  value from AWS. `cf:build` and `cf:deploy` `source` it; it checks `aws sts get-caller-identity` and
  exposes `get_build_config_value()` (SSM `get-parameter`).

The user asked for setup, dev, lint, test, deploy. Mapping:
setup → `node:setup`, lint → `node:lint`, test → `node:test`, dev → `cf:dev`, deploy → `cf:deploy`.
Added `cf:build` as the AWS-reading build step (deploy reuses the same auth path).

## Advisory forks (all = recommended default)
- **Namespacing**: namespace by toolchain (`node:*`, `cf:*`). Repo is effectively polyglot
  (node + cloudflare tooling), so flat names would clash.
- **Env file**: `.env.yaml` (mise `_.file`). Committed `.env.example`; `.env.yaml` gitignored.
- **Version pinning**: major.minor resolved now — `node = "24"` (latest 24.x = 24.18.0 at scaffold time),
  `aws-cli = "2"`.
- **Account-specific internals**: parameterized via env — `${AWS_REGION}`, `${AWS_CONFIG_PARAMETER}`
  sourced from `.env.yaml`. Nothing internal hard-coded in scripts. Cloudflare account id / token are
  env-only too.
- **Agent assets**: `.claude/` (no existing `.agents/` tree).

## Agent layer
- House-rules skill (always): `.claude/skills/cloudflare-worker-mise/SKILL.md` — describes this repo's real
  namespaces (node, cf), the actual tasks, and the AWS-auth note.
- Command-skill (selective): `.claude/commands/cf-deploy/SKILL.md` — `cf:deploy` changes remote/shared state
  (Cloudflare) and requires AWS auth, so it qualifies for a guardrailed command-skill. `node:lint`/`node:test`
  do not get one (would just dilute triggering).

## Verification
`mise tasks` lists all 6 runnable tasks with descriptions and no parse error; `aws-auth` is correctly
excluded (it has no `#MISE description` — sourced helper, not a task).
