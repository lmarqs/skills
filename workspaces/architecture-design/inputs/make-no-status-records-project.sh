#!/usr/bin/env bash
# Builds the disposable API repository eval 12 runs against: decision records
# in docs/adrs/ from a template with no status field (Context, Options,
# Decision, Consequences), and a README saying records are written only for
# decisions already taken.
# Usage: make-no-status-records-project.sh <empty-dir>
set -euo pipefail
dir="${1:?usage: make-no-status-records-project.sh <empty-dir>}"
mkdir -p "$dir/docs/adrs" && cd "$dir"
git init -q -b main
git config user.email eval@example.com
git config user.name eval
cat > docs/adrs/0001-ship-the-api-as-a-single-binary.md <<'MD'
# Ship the API as a single binary

## Context

Deploys copied a virtualenv and drifted between hosts.

## Options

- **Container image**: reproducible; lost because the hosts run no container runtime.
- **Single static binary**: chosen.

## Decision

Build the API as one static binary per release.

## Consequences

A deploy is one file copy. Native dependencies must link statically.
MD
cat > docs/adrs/README.md <<'MD'
# Decision records

One file per decision, `NNNN-<decision-as-slug>.md`, from `template.md`. A record is written only for
a decision that has been taken.
MD
cat > docs/adrs/template.md <<'MD'
# <Decision taken, as a sentence>

## Context

## Options

## Decision

## Consequences
MD
git add -A && git commit -q -m "chore: init"
