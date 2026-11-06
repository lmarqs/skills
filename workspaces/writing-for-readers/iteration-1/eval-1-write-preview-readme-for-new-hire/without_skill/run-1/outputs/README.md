# Preview environments

Every pull request gets its own running copy of the web app, called a preview environment. Open it to check your
change in a real deployment before merging.

## Open your preview

After you push to a PR, wait about 6 minutes, then open:

```
https://pr-<number>.preview.acme.dev
```

`<number>` is the PR number. For PR 1234, the URL is `https://pr-1234.preview.acme.dev`.

Each push rebuilds and redeploys the preview, so the URL always shows the latest commit after the build finishes.

## What happens when you push

The `preview` GitHub Actions workflow runs on every push to a PR:

1. Builds the Docker image from the repository's Dockerfile.
2. Pushes the image to the `web-preview` repository in Amazon ECR (our container registry).
3. Installs the image with Helm into the `previews` namespace on the staging cluster.

The staging cluster is the Kubernetes cluster that also runs our staging environment. Helm is the tool that deploys the
app's Kubernetes resources; a namespace is a partition of the cluster, and all previews share the `previews` one.

Of the roughly 6 minutes, about 4 go to restoring the database (see [Data](#data)).

## Data

Each preview starts with its own copy of the anonymized staging database snapshot. The snapshot is refreshed nightly
at 02:00 UTC, so a preview holds staging data as of the most recent refresh. Changes you make in one preview do not
affect other previews or staging.

## Payments and email

Third-party services are stubbed so testing never charges a card or emails a real person:

- Payments: Stripe runs in mock mode (`STRIPE_MODE=mock`).
- Email: every outgoing email lands in MailHog, an inbox you read in the browser at
  `https://pr-<number>.preview.acme.dev/mailhog`.

## Secrets

Previews read secrets from Vault, the service that stores our credentials and API keys. They use the `preview` path,
`secret/preview/web`, and never the staging secrets. If your change needs a new secret, ask the platform team to add it
under `secret/preview/web`.

## Logs

Logs go to Datadog. Filter by:

```
env:preview pr:<number>
```

## Lifetime

A preview is deleted when its PR is closed or merged. A scheduled job also deletes any preview that has been idle for
more than 72 hours. Each preview costs about $0.40 a day, and the platform team monitors the total.

## Troubleshooting

**The `preview` job fails with "another operation in progress".** Two pushes landed within about a minute of each
other, and the second Helm install collided with the first. Re-run the failed job.

**You need a shell inside the running app.** There is no SSH access. If you have staging cluster access, run
`kubectl -n previews exec`. Most developers do not have that access; use the Datadog logs instead.
