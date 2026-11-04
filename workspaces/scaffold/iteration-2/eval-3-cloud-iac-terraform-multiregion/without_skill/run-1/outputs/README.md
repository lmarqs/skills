# AWS Infrastructure (Terraform)

Infrastructure-as-code for our AWS account, organised as one Terraform module
per scope under `modules/`:

| Module                | Scope                                                          |
| --------------------- | -------------------------------------------------------------- |
| `modules/global`      | Account-wide / global services (IAM, Route 53, CloudFront).    |
| `modules/us-east-1`   | Resources in the `us-east-1` (N. Virginia) region.             |
| `modules/sa-east-1`   | Resources in the `sa-east-1` (São Paulo) region.               |

Each module is self-contained: its own backend, providers, variables, and
state. You always act on **one module at a time**.

## Prerequisites

These tools must be on your `PATH`:

- [`terraform`](https://developer.hashicorp.com/terraform/install) `>= 1.5.0`
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) — some modules deploy to EKS
- [`helm`](https://helm.sh/docs/intro/install/) — Helm releases are deployed to EKS
- AWS credentials configured (e.g. `aws configure` or environment variables)

`kubectl` and `helm` are required because several modules provision EKS
clusters and then deploy Kubernetes / Helm workloads onto them.

## Workflow

All operations go through `scripts/tf.sh`, which takes the module to act on and
the command to run:

```
scripts/tf.sh <module> <command>
```

| Command | What it does                                                                      |
| ------- | --------------------------------------------------------------------------------- |
| `init`  | Initialise the module (providers + backend).                                      |
| `plan`  | Show a plan for the module.                                                        |
| `fmt`   | Format the module's `.tf` files in place (`terraform fmt -recursive`).            |
| `check` | Non-mutating validation: `terraform fmt -check` + `terraform validate` (for CI).  |
| `apply` | **Generate a plan, show it, ask for confirmation, then apply that exact plan.**   |

### Examples

```sh
# First-time setup for a region
scripts/tf.sh us-east-1 init

# See what would change
scripts/tf.sh us-east-1 plan

# Apply — shows the plan and waits for you to type "yes"
scripts/tf.sh us-east-1 apply

# Tidy up formatting
scripts/tf.sh global fmt

# CI check
scripts/tf.sh sa-east-1 check
```

A `Makefile` is provided as a shortcut (`make plan MODULE=us-east-1`, etc.).

## Safe applies

`apply` never changes anything without showing you first. It runs
`terraform plan -out=tfplan.binary`, prints the resulting plan, and then prompts
for confirmation. Only when you type `yes` does it apply that saved plan — so
what you reviewed is exactly what runs. Anything else aborts with no changes.

## Remote state

Each module's `versions.tf` has a commented-out `backend "s3"` block. Fill it in
(or pass `-backend-config=...` to `init`) before running `init` so state is
stored remotely rather than locally.
