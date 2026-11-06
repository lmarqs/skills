# Preview environments

Every pull request gets its own running copy of the web app at `https://pr-<number>.preview.acme.dev`, for example `https://pr-1234.preview.acme.dev` for PR #1234. Use it to check your change in a real deployment and to share it with reviewers, designers and product.

You do not need to do anything to get one. Open a PR, push, and the environment appears about 6 minutes later.

## Lifecycle

| Event | What happens |
| --- | --- |
| You push to a PR | The `preview` GitHub Action builds and deploys it. The URL is live about 6 minutes after the push. |
| The PR is closed or merged | The environment is deleted. |
| The environment sees no activity for 72 hours | A scheduled job deletes it. |

## What the `preview` action does

1. Builds the Docker image from the repository's Dockerfile.
2. Pushes it to the `web-preview` repository in Amazon ECR (our container registry on AWS).
3. Installs it with Helm into the `previews` namespace of the **staging cluster**, the Kubernetes cluster that also runs our shared staging environment.
4. Restores a database for the environment (see below). This takes about 4 of the 6 minutes.

If a deploy fails, the logs are in the action's run on the PR's Checks tab, like any other workflow.

## Data

Each environment gets its own copy of the anonymized staging database snapshot. The snapshot is refreshed nightly at 02:00 UTC, so data created in staging today shows up in previews deployed after tomorrow's refresh. Changes you make in a preview stay in that preview and disappear when it is deleted.

## Payments and email are fake

- Stripe runs in mock mode (`STRIPE_MODE=mock`). No real charges are made.
- Emails are not sent. They are captured by MailHog, which you can read at `https://pr-<number>.preview.acme.dev/mailhog`.

## Secrets

Preview environments read secrets from **Vault**, our secrets store, under the path `secret/preview/web`. They do not use staging's secrets.

To add a new secret, ask the platform team to add it under `secret/preview/web`. A secret that exists only in staging is missing in previews, so an env var that works in staging and is empty in a preview usually means this step was skipped.

## Logs

Logs are in Datadog. Filter with:

```
env:preview pr:<number>
```

## Shell access

There is no SSH. If you have access to the staging cluster, open a shell with:

```sh
kubectl -n previews exec -it <pod-name> -- sh
```

Most developers do not have staging cluster access. Use the Datadog logs instead, or ask someone on the platform team.

## Troubleshooting

**The deploy fails with `another operation in progress`.** Two pushes landed within about a minute of each other, and the second Helm install started while the first was still running. Re-run the failed job from the PR's Checks tab.

**The URL does not load right after pushing.** Deploys take about 6 minutes. Check the `preview` action's status on the PR.

**The URL stopped working on an old PR.** Environments idle for over 72 hours are deleted.

## Cost

Each environment costs about $0.40 per day. The platform team monitors this; closing PRs you no longer need deletes their environments.
