---
name: cloudflare-worker-mise
description: >-
  Cloudflare Worker task runner — all repeatable workflows (setup, lint, test, build, dev, deploy) run
  through mise as `mise run <namespace>:<task>`. Use whenever running, adding, or debugging a
  build/test/dev/deploy command in this repo, or when tempted to `cd … && npm run …` or call `wrangler`
  directly — that means a mise task is missing. Namespaces here: node, cf (Cloudflare/wrangler). The cf:build
  and cf:deploy tasks authenticate to AWS to read a build-time config value.
---

# Cloudflare Worker mise tasks

All repeatable work is a mise task. Prefer `mise run <task>` over direct `npm`/`wrangler` invocations —
mise handles the working directory, args, flags, and environment (including AWS auth) consistently.

## Tasks
- `mise run node:setup` — install dependencies (`npm ci`)
- `mise run node:lint` — lint and type-check
- `mise run node:test [pattern]` — run the test suite, optional filter
- `mise run cf:dev` — start the Worker locally (`wrangler dev`)
- `mise run cf:build` — build the Worker bundle; reads a build-time config value from AWS (SSM)
- `mise run cf:deploy [--env <env>]` — deploy the Worker to Cloudflare (`wrangler deploy`); also reads the
  AWS config value

Run a step across every namespace with the glob: `mise run '**:setup'`.

## AWS authentication
`cf:build` and `cf:deploy` source `.mise/tasks/aws-auth`, which checks `aws sts get-caller-identity` and
fetches the build-time config value from SSM (`${AWS_CONFIG_PARAMETER}`). If a task aborts with
"You must be authenticated to AWS", run `aws sso login` first. Account-specific values come from `.env.yaml`,
never from the task scripts.

## Adding a task
1. Create an executable bash file at `.mise/tasks/<namespace>/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `cd <dir> && <cmd>` or a raw `wrangler …`, a task
is missing — add it instead of running it raw.
