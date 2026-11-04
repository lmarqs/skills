---
name: aws-infra-mise
description: >-
  AWS infrastructure task runner — all repeatable Terraform and EKS workflows run through mise as
  `mise run tf:<task> <module>`. Use whenever running, adding, or debugging an init/plan/apply/fmt/check
  command in this repo, deploying to EKS with kubectl/helm, or when tempted to run `terraform -chdir=...`,
  `kubectl`, or `helm` directly — that means a mise task is missing. Modules live under modules/ (global,
  sa-east-1, us-east-1). Namespaces here: tf.
---

# AWS infra mise tasks

All repeatable work is a mise task. Prefer `mise run <task>` over direct `terraform`/`kubectl`/`helm`
invocations — mise handles the toolchain versions, the module's working directory (`-chdir`), args, flags,
and AWS authentication consistently. Tools `terraform`, `aws-cli`, `kubectl`, and `helm` are pinned in
`mise.toml`, so the right versions are on `PATH` for every task and for ad-hoc EKS work.

## Tasks

Terraform tasks take the module name (the directory under `modules/`): `global`, `sa-east-1`, `us-east-1`.

- `mise run tf:init <module>` — initialize a module
- `mise run tf:plan <module>` — show a plan for a module
- `mise run tf:apply <module> [--auto-approve]` — apply a module; shows a plan and asks for confirmation
  first (skip the prompt only with `--auto-approve`, e.g. in CI)
- `mise run tf:fmt` — format all Terraform files (`-recursive`)
- `mise run tf:check <module>` — `fmt -check` + `validate` for a module

Fan a step across every module with the glob: `mise run 'tf:check' global` per module, or loop the names.

## AWS / EKS auth

`tf:init`, `tf:plan`, and `tf:apply` source `.mise/tasks/aws-auth`, which verifies you are authenticated
(`aws sts get-caller-identity`) and exposes `eks_update_kubeconfig <cluster> [region]` to point
`kubectl`/`helm` at an EKS cluster. Account-specific values (region, cluster name) come from `.env.yaml`,
never from task scripts.

## Adding a task
1. Create an executable bash file at `.mise/tasks/<namespace>/<task>` (e.g. `.mise/tasks/tf/output`).
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `terraform -chdir=… && …`, `kubectl`, or `helm`
raw, a task is missing — add it instead of running it raw.
