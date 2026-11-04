# Backend service

A Go API plus Terraform for its AWS infrastructure (an S3 bucket and a Lambda).

## Getting started

This repo uses [mise](https://mise.jdx.dev) as its task runner and toolchain manager.

```bash
mise install          # install pinned toolchains (go, terraform, aws-cli, golangci-lint)
cp .env.example .env.yaml   # then fill in AWS_REGION / profile
mise run go:setup     # download Go module dependencies
```

## Tasks

All repeatable work runs through mise as `mise run <namespace>:<task>`. List everything with `mise tasks`.

### Go (`go:*`)
| Task | Description |
|------|-------------|
| `mise run go:setup` | Download Go module dependencies |
| `mise run go:build` | Compile all packages |
| `mise run go:test [--cover]` | Run tests (optionally with coverage) |
| `mise run go:lint` | Run golangci-lint |
| `mise run go:fmt` | Format Go code |

### Terraform (`tf:*`)
`<module>` is a directory under `modules/` (e.g. the S3 bucket / Lambda module).

| Task | Description |
|------|-------------|
| `mise run tf:init <module>` | Initialize a module |
| `mise run tf:plan <module>` | Show a plan (preview changes) |
| `mise run tf:apply <module> [--auto-approve]` | Apply changes to AWS |
| `mise run tf:fmt` | Format all `.tf` files |
| `mise run tf:check` | Check formatting and validate config |

Run a step across everything: `mise run '**:fmt'`.

## AWS authentication

The `tf:*` tasks that touch AWS source `.mise/tasks/aws-auth`, which fails fast unless you are
authenticated (`aws sso login`). Region (and any profile) come from `.env.yaml` — account-specific values
never live in task scripts.
