---
name: tf-plan
description: >-
  Show a Terraform plan for a module (the proposed changes to AWS infra) without applying. Use when the user
  wants to preview, diff, or dry-run infra changes for a module before deploying. Read-only — makes no changes.
argument-hint: "<module>"
---

# Terraform plan

Run `mise run tf:plan <module>` to show the proposed changes for a module without applying them.

## Usage
```bash
mise run tf:plan <module>
```

## Instructions
1. Parse `$ARGUMENTS` for the required `<module>` (a directory under `modules/`); if missing, ask which module.
2. Confirm AWS auth is in place — `tf:plan` sources `aws-auth` and will fail fast if not (`aws sso login`).
3. Run `mise run tf:plan <module>` and surface the plan output.
4. Summarize what would change (resources to add/change/destroy) so the user can decide whether to apply.
