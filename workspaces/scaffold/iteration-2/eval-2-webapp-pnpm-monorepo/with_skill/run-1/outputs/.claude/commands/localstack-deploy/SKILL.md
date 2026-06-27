---
name: localstack-deploy
description: >-
  Provision local AWS resources (s3, sqs, lambda) into LocalStack via `mise run localstack:deploy`. Use when
  the user wants to set up or refresh local infrastructure for development. Ensure LocalStack is running
  first and surface what will be created before provisioning.
argument-hint: ""
---

# Deploy local infrastructure to LocalStack

Run `mise run localstack:deploy` to provision the app's local AWS resources into LocalStack.

## Usage
```bash
mise run localstack:setup   # ensure LocalStack is up (or: mise run docker:up)
mise run localstack:deploy
```

## Instructions
1. Confirm LocalStack is running (`mise run localstack:setup` or `mise run docker:up`); start it if not.
2. Confirm `AWS_ENDPOINT_URL` resolves to the LocalStack endpoint (default `http://localhost:4566`) — this
   task must never touch real AWS.
3. Surface the resources the task will create (buckets, queues, functions) before running it.
4. Run `mise run localstack:deploy`.
5. Report the resources created and any failures.
