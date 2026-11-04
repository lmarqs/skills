# cloudflare-worker

A Cloudflare Worker (TypeScript on Node), deployed with [wrangler](https://developers.cloudflare.com/workers/wrangler/).
Tasks run through [mise](https://mise.jdx.dev).

## Prerequisites
- `mise` installed. Tools (node 24, aws-cli 2) are pinned in `mise.toml` and installed via `mise install`.
- Copy `.env.example` to `.env.yaml` and fill in values (`.env.yaml` is gitignored).
- `wrangler login` (or set `CLOUDFLARE_API_TOKEN`) for deploys.
- AWS credentials (`aws sso login`) — `cf:build` and `cf:deploy` read a build-time config value from AWS.

## Tasks

| Command | What it does |
|---|---|
| `mise run node:setup` | Install dependencies (`npm ci`) |
| `mise run node:lint` | Lint and type-check (`tsc --noEmit`) |
| `mise run node:test [pattern]` | Run the test suite, optional filter |
| `mise run cf:dev` | Start the Worker locally (`wrangler dev`) |
| `mise run cf:build` | Build the Worker bundle; reads a config value from AWS (SSM) |
| `mise run cf:deploy [--env <env>]` | Deploy the Worker to Cloudflare; also reads the AWS config value |

`mise run '**:setup'` fans the setup step across all namespaces.

### AWS-backed build steps
`cf:build` and `cf:deploy` source `.mise/tasks/aws-auth`, which verifies AWS auth and fetches the build-time
config value from SSM Parameter Store (`${AWS_CONFIG_PARAMETER}`). Account-specific values live in `.env.yaml`,
never in the task scripts.

Future agents: see the `cloudflare-worker-mise` house-rules skill in `.claude/skills/`.
