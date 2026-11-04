---
name: cf-deploy
description: >-
  Deploy the Cloudflare Worker via `mise run cf:deploy`. Use when the user wants to ship/release the Worker to
  Cloudflare. This changes remote state and requires AWS auth (it reads a build-time config value), so confirm
  the target environment and that the user intends to deploy before running.
argument-hint: "[--env <env>]"
---

# Deploy the Cloudflare Worker

Run `mise run cf:deploy [--env <env>]` to build and deploy the Worker to Cloudflare. The task sources
`.mise/tasks/aws-auth` first, so the caller must be authenticated to AWS (it reads a build-time config value
from SSM).

## Usage
```bash
mise run cf:deploy                 # deploy the default environment
mise run cf:deploy --env staging   # deploy a named wrangler environment
mise run cf:deploy --env production
```

## Instructions
1. Parse `$ARGUMENTS` for an optional `--env <env>`. If the user did not name an environment, confirm whether
   they mean the default (often production) before proceeding.
2. Confirm the user actually wants to deploy — this changes remote, shared state on Cloudflare.
3. Ensure AWS auth is in place; if the task aborts with "You must be authenticated to AWS", run
   `aws sso login` and retry.
4. Run the `mise run cf:deploy …` command.
5. Report the deployed version/URL and any wrangler output.
