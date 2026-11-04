# AWS Infrastructure (Terraform)

AWS infrastructure as Terraform, organized as one module per region under `modules/`:

- `modules/global` — account-wide / non-regional resources (IAM, Route53, CloudFront, …)
- `modules/sa-east-1` — São Paulo region
- `modules/us-east-1` — N. Virginia region

Some workloads are deployed to **EKS**, so `kubectl` and `helm` are pinned alongside `terraform` and
`aws-cli` in `mise.toml` and available on `PATH`.

## Setup

Tooling is managed by [mise](https://mise.jdx.dev). Pinned tools (`terraform`, `aws-cli`, `kubectl`,
`helm`) install on first use:

```bash
mise install
```

Copy the env template and fill in your values (`.env.yaml` is gitignored):

```bash
cp .env.example .env.yaml
```

Authenticate to AWS before running any `tf` task (`aws sso login` or equivalent).

## Tasks

All workflows run through mise. The Terraform tasks take the **module** name — a directory under `modules/`
(`global`, `sa-east-1`, `us-east-1`).

| Task | What it does |
|------|--------------|
| `mise run tf:init <module>` | Initialize a module |
| `mise run tf:plan <module>` | Show a plan for a module (read-only) |
| `mise run tf:apply <module> [--auto-approve]` | Apply a module — **shows a plan and asks to confirm first** |
| `mise run tf:fmt` | Format all Terraform files (`-recursive`) |
| `mise run tf:check <module>` | `fmt -check` + `validate` for a module |

Example:

```bash
mise run tf:init us-east-1
mise run tf:plan us-east-1
mise run tf:apply us-east-1        # prints the plan, then waits for you to type "yes"
```

`tf:apply` writes a saved plan, prints it, and applies **exactly that plan** only after you confirm — so
what you reviewed is what gets applied. Use `--auto-approve` only from CI.

### EKS

`tf:init`/`tf:plan`/`tf:apply` source `.mise/tasks/aws-auth`, which checks you are authenticated and
provides `eks_update_kubeconfig <cluster> [region]` to wire `kubectl`/`helm` to a cluster. Cluster name and
region come from `.env.yaml`.

## Adding a task

See `.claude/skills/aws-infra-mise/SKILL.md`. In short: drop an executable bash file at
`.mise/tasks/<namespace>/<task>` with a `#MISE description`, then `chmod +x` and check `mise tasks`.
