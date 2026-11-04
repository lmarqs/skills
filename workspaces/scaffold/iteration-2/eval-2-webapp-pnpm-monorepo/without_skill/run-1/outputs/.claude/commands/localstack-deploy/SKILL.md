---
name: localstack-deploy
description: >-
  Provision local AWS infrastructure (S3/SQS/Lambda) into LocalStack via mise. Use when the user wants to set
  up or refresh local dev infra, deploy resources to the emulator, or "spin up local AWS". Targets the local
  LocalStack endpoint only — never a real AWS account.
argument-hint: ""
---

# Deploy to LocalStack

Run `mise run localstack:deploy` to provision local AWS resources into the LocalStack emulator.

## Usage
```bash
mise run docker:up           # or: mise run localstack:setup  (start the emulator first)
mise run localstack:deploy   # provision resources
```

## Instructions
1. Ensure LocalStack is running first (`mise run localstack:setup` or `mise run docker:up`).
2. Confirm `AWS_ENDPOINT_URL` points at the local emulator (default `http://localhost:4566`) — this task must
   never touch a real AWS account. If it resolves to a real endpoint, stop and warn the user.
3. Run `mise run localstack:deploy`. It waits for LocalStack to be ready, then provisions resources idempotently.
4. Report which resources were created and any that already existed.
