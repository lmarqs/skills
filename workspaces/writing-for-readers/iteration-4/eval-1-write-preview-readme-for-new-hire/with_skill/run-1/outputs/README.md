---
description: How to find, use and debug the preview environment that every web pull request gets.
audience: Frontend engineers new to the team. Know Docker and GitHub Actions well; have never seen the staging cluster, Vault or the preview setup.
---

# Preview environments

Every pull request gets its own running copy of the web app at
`https://pr-<number>.preview.acme.dev`, about 6 minutes after each push. You do not set
anything up: the `preview` GitHub Action builds and deploys it, and it is removed when the pull
request closes or merges.

This README covers how a preview is built, what is real and what is fake inside it, how to read
its logs, how to add a secret, and the one known failure. It does not cover the staging cluster
itself or how to get access to it.

## The `preview` action deploys each push in about 6 minutes

On every push to a pull request, the `preview` GitHub Action does three things:

1. Builds the Docker image from the repository.
2. Pushes the image to ECR, AWS's container registry, in the `web-preview` repository.
3. Installs the image with Helm, a Kubernetes package installer, into the `previews` namespace
   of the staging cluster. The staging cluster is the Kubernetes cluster that also runs our
   staging environment; the `previews` namespace keeps the preview environments apart from it.

The preview is ready at `https://pr-<number>.preview.acme.dev`, where `<number>` is the pull
request number. Most of the 6 minutes is the database restore described in the next section.

## Each preview runs on a copy of anonymized staging data

Each deploy restores a copy of the anonymized staging database snapshot into the preview. The
snapshot is refreshed every night at 02:00 UTC, so the data is at most a day old. The restore
takes about 4 of the 6 minutes a deploy takes.

## Payments and email are stubbed

A preview never charges a card or sends a real email:

- **Payments:** Stripe runs in mock mode (`STRIPE_MODE=mock`).
- **Email:** every email the app sends goes to MailHog, a mail catcher. Read it at
  `https://pr-<number>.preview.acme.dev/mailhog`.

## Secrets come from Vault's preview path

Vault is where the platform team stores secrets. Previews read theirs from the `preview` path in
Vault and never from the staging secrets. If your change needs a new secret, ask the platform
team to add it under `secret/preview/web`.

## Logs are in Datadog

Filter Datadog by `env:preview pr:<number>` to see one preview's logs.

You cannot SSH into a preview. If you have access to the staging cluster, you can open a shell
with `kubectl -n previews exec`; most developers do not have that access, so Datadog is the
usual way in.

## A preview is removed on close, merge or 72 idle hours

A preview is torn down when its pull request closes or merges. A scheduled job also removes any
preview that has been idle for more than 72 hours.

## Two pushes within a minute fail the second deploy

If two pushes land within about a minute of each other, the second Helm install fails with
`another operation in progress`. Re-run the failed `preview` job in GitHub Actions.

## Your first preview

Open a pull request, wait about 6 minutes, and open `https://pr-<number>.preview.acme.dev`. If
the page does not load, check the `preview` job in the pull request's Actions tab, then the
Datadog logs.
