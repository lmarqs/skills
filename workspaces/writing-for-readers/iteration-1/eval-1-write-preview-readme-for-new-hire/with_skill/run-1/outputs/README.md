---
description: What a preview environment is, how to reach and debug yours, and what to do when one fails.
audience: Frontend engineers new to the team. Know Docker and GitHub Actions well; have not used our staging cluster, Vault or the preview setup.
---

# Preview environments

Every pull request gets its own running copy of the web app at
`https://pr-<number>.preview.acme.dev`, about six minutes after each push. You do not have to
create it: the `preview` GitHub Action builds and deploys it, and it is deleted when the pull
request closes. This page covers how a preview is built, what data and services it has, how
long it lives, where its secrets and logs are, and the one known deploy failure.

## A push to a pull request deploys its preview in about six minutes

The `preview` GitHub Action runs on every push to a pull request and does three things:

1. Builds the Docker image and pushes it to ECR, AWS's container registry, in the
   `web-preview` repository.
2. Restores a copy of the staging database into the preview. This step takes about four of
   the six minutes.
3. Installs the image with Helm, a Kubernetes deployment tool, into the `previews` namespace
   of the staging cluster. The staging cluster is the Kubernetes cluster that also runs our
   staging environment; a namespace is a partition of it that keeps previews apart from
   staging.

The preview is ready at `https://pr-<number>.preview.acme.dev`, where `<number>` is the pull
request number.

## Previews hold anonymized staging data, with payments and email stubbed

Each preview starts from the anonymized staging database snapshot, which is refreshed every
night at 02:00 UTC. A preview built today therefore shows staging data as of last night.

Payments and email never reach real services:

- Payments run against a mock: `STRIPE_MODE=mock`.
- Email goes to MailHog, a mail catcher with a web inbox, at
  `https://pr-<number>.preview.acme.dev/mailhog`. Open it to read any email the app sent.

## Previews are deleted when the pull request closes or after 72 idle hours

A preview is deleted when its pull request is merged or closed. A scheduled job also deletes
any preview that has been idle for more than 72 hours. Each preview costs about $0.40 a day,
and the platform team monitors that spend.

## Preview secrets live in Vault under `secret/preview/web`

The app in a preview reads its secrets from Vault, our secrets store, under
`secret/preview/web`. These are separate from staging secrets, so a secret that exists in
staging is not automatically available in a preview. To add a secret, ask the platform team
to add it under `secret/preview/web`.

## Debug a preview through Datadog logs

Logs for a preview are in Datadog. Filter with `env:preview pr:<number>`.

You cannot SSH into a preview. If you have staging cluster access, you can open a shell with
`kubectl -n previews exec`; most developers do not have that access, so start with the logs.

## If the deploy fails with "another operation in progress", re-run the job

Two pushes within about a minute of each other can make the second Helm install fail with
`another operation in progress`, because the first install is still running. Re-run the
failed job in GitHub Actions.
