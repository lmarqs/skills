# Cloudflare Worker

TypeScript Cloudflare Worker, run on Node tooling and deployed with
[wrangler](https://developers.cloudflare.com/workers/wrangler/). Tasks are
driven by [mise](https://mise.jdx.dev/).

## Prerequisites

- [mise](https://mise.jdx.dev/) (manages the Node toolchain)
- A Cloudflare account; authenticate wrangler with `npx wrangler login`
- AWS CLI configured with credentials (used by the build/deploy config step)

## Tasks

| Task                    | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| `mise run setup`        | Install dependencies and prepare the environment.                 |
| `mise run dev`          | Run the Worker locally with wrangler.                             |
| `mise run lint`         | Lint and type-check the project.                                  |
| `mise run test`         | Run the test suite (Vitest + workers pool).                       |
| `mise run deploy`       | Authenticate to AWS, read config, then deploy to Cloudflare.      |
| `mise run aws-auth`     | Verify AWS authentication (dependency of the config build step).  |
| `mise run build-config` | Read the build config value from AWS SSM Parameter Store.         |

## AWS config build step

One build step reads a config value from AWS. The `deploy` task depends on
`build-config`, which depends on `aws-auth`:

```
deploy -> build-config -> aws-auth
```

- `aws-auth` runs `aws sts get-caller-identity` and fails fast with a clear
  message if you are not authenticated (run `aws sso login` first).
- `build-config` reads `$APP_CONFIG_PARAM` from AWS SSM Parameter Store in
  `$AWS_REGION` and writes it to `.build-config.env` (gitignored).

Adjust `AWS_REGION` and `APP_CONFIG_PARAM` in `mise.toml` for your setup.

## Quick start

```sh
mise run setup
mise run dev      # local development
mise run lint
mise run test
mise run deploy   # production deploy (requires AWS + Cloudflare auth)
```
