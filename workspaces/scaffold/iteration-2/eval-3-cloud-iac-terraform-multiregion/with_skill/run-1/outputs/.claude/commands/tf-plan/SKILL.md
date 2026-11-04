---
name: tf-plan
description: >-
  Show a Terraform plan for a module — the read-only preview of what an apply would change in AWS. Use when
  the user wants to plan, preview, or diff infrastructure changes for a region/module before applying.
argument-hint: "<module>"
---

# Plan a Terraform module

Run `mise run tf:plan <module>` to preview changes for one module. Modules are `global`, `sa-east-1`,
`us-east-1` (the directories under `modules/`).

## Usage
```bash
mise run tf:plan sa-east-1
```

## Instructions
1. Parse `$ARGUMENTS` for the module name; if missing, ask which module (`global`, `sa-east-1`, `us-east-1`).
2. Ensure the module is initialized — if `plan` complains, run `mise run tf:init <module>` first.
3. Run `mise run tf:plan <module>` and surface the plan output.
4. Summarize what would change (added/changed/destroyed). This is read-only; nothing is applied.
