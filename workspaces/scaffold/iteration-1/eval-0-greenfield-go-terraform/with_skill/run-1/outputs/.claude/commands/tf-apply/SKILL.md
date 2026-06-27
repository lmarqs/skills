---
name: tf-apply
description: >-
  Apply Terraform changes for a module to live AWS infrastructure (S3 bucket, Lambda, etc.). Use when the
  user wants to apply, deploy, or provision infra for a module. Destructive: shows a plan and asks for
  confirmation before applying.
argument-hint: "<module> [--auto-approve]"
---

# Terraform apply

Run `mise run tf:apply <module>` to apply a module's changes to live AWS infrastructure.

## Usage
```bash
mise run tf:apply <module>
mise run tf:apply <module> --auto-approve
```

## Instructions
1. Parse `$ARGUMENTS` for the required `<module>` (a directory under `modules/`); if missing, ask which module.
2. Confirm AWS auth is in place — `tf:apply` sources `aws-auth` and will fail fast if not (`aws sso login`).
3. First run `mise run tf:plan <module>` and surface the plan to the user.
4. Wait for explicit confirmation before applying. Do NOT pass `--auto-approve` unless the user asked for it.
5. Apply with `mise run tf:apply <module>`; for multiple modules, apply one at a time and pause for review between each.
6. Report the result (resources added/changed/destroyed, any outputs).
