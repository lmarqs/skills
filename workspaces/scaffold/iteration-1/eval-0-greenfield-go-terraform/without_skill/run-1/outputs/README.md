# go-api-service

A Go HTTP API that also ships as an AWS Lambda, with its AWS infra (an S3
bucket and a Lambda) managed by Terraform. [mise](https://mise.jdx.dev) is the
task runner and toolchain manager.

## Getting started

```bash
mise run setup            # install toolchain (Go, golangci-lint, terraform, awscli, gh), Go deps, .env
```

## Layout

```
cmd/api/         standalone HTTP server entrypoint
cmd/lambda/      AWS Lambda entrypoint (reuses the same handler)
internal/handler optional shared HTTP handler + tests
infra/           Terraform: S3 bucket + Lambda
.mise/tasks/     mise task runner scripts
```

## Commands

All commands run through mise.

```bash
mise run setup                  # install tools + deps, seed .env, wire VS Code

mise run build:api              # build the HTTP server binary -> dist/api
mise run build:lambda           # build + zip the arm64 Lambda -> dist/lambda.zip

mise run run:server             # run the HTTP server locally
mise run run:function           # run the Lambda handler locally

mise run test:run               # go test ./... (race, no cache)
mise run lint:run               # golangci-lint
mise run lint:run --fix         # auto-fix + format
```

### Terraform (infra/)

```bash
mise run tf:init --backend      # initialize Terraform with the S3 backend
mise run tf:fmt                 # format
mise run tf:check               # fmt -check + validate
mise run tf:plan                # plan (defaults to -var-file=production.tfvars)
mise run tf:plan --target <x>   # plan a specific target
mise run tf:apply               # apply
mise run tf:apply --auto-approve
mise run tf:unlock <lock-id>    # force-unlock state
```

Typical deploy flow:

```bash
mise run build:lambda           # produce dist/lambda.zip
mise run tf:plan
mise run tf:apply
```

> Before first use, set the real state bucket in `infra/terraform.tf` and copy
> `infra/production.tfvars.example` to `infra/production.tfvars`.
