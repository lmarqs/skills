# Payments Service

## Overview

This section will discuss the payments service and how we got to the current setup. Originally
payments ran inside the monolith, but in 2023 we split it out because the monolith deploys were
too slow and the payments team wanted to own their releases. After a lot of discussion we chose
Kubernetes. The worker processes charges from the queue and writes results to the ledger.

## Architecture

The API receives charge requests and puts them on the queue. The consumer picks them up and
calls the card processor. If the processor is slow, it times out after 30 seconds and the
charge is retried. The job runner also sends receipts.

## Rollback is automatic

When a deploy goes bad you need to roll back. Run `kubectl rollout undo deployment/payments`
from the ops bastion, then check the dashboard. It should recover within a few minutes but
sometimes it doesn't.

## Configuration

Settings live in `config/payments.yaml`. For example, set the retry count in the YAML file,
not in the Helm chart:

```yaml
retries: 3
processor_timeout_seconds: 60
```

## Rolling back

Database migrations are not undone by the rollout undo. If the bad deploy ran a migration,
page the payments on-call before rolling back, because the old code might not be able to read
the new schema. Obviously you should check this first.

## Notes

Remember the processor timeout is 60 seconds. It's worth noting that the worker is the most
important part of the system.
