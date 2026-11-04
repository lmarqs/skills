---
name: tf-apply
description: >-
  Apply a Terraform module's changes to AWS. Use when the user wants to apply, deploy, or roll out
  infrastructure for a region/module. Destructive — it changes live cloud state, so it shows a plan and
  requires an explicit "yes" confirmation before applying.
argument-hint: "<module> [--auto-approve]"
---

# Apply a Terraform module

Run `mise run tf:apply <module>` to apply changes for one module. Modules are `global`, `sa-east-1`,
`us-east-1` (the directories under `modules/`).

## Usage
```bash
mise run tf:apply us-east-1
mise run tf:apply global --auto-approve   # CI only — skips the confirmation
```

## Instructions
1. Parse `$ARGUMENTS` for the module name; if missing, ask which module (`global`, `sa-east-1`, `us-east-1`).
2. Run `mise run tf:plan <module>` first and show the plan to the user.
3. Apply one module at a time. Never pass `--auto-approve` interactively — let the task's built-in
   confirmation prompt run, and only continue after the user reviews the plan and types `yes`.
4. If applying across regions, do them sequentially and pause for review between each.
5. Report the result (resources added/changed/destroyed) for each module.
