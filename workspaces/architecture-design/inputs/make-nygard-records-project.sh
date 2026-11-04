#!/usr/bin/env bash
# Builds the disposable web-tier repository eval 11 runs against: decision
# records in docs/adrs/ in Nygard's format (Status, Context, Decision,
# Consequences), numbered 0001 and 0002.
# Usage: make-nygard-records-project.sh <empty-dir>
set -euo pipefail
dir="${1:?usage: make-nygard-records-project.sh <empty-dir>}"
mkdir -p "$dir/docs/adrs" && cd "$dir"
git init -q -b main
git config user.email eval@example.com
git config user.name eval
cat > docs/adrs/0001-record-architecture-decisions.md <<'MD'
# 1. Record architecture decisions

## Status

Accepted

## Context

We need to record the architectural decisions made on this project.

## Decision

We will use Architecture Decision Records, as described by Michael Nygard, kept in `docs/adrs/`.

## Consequences

Each decision is one numbered file. A new decision that replaces an old one marks the old one
"Superseded by" the new.
MD
cat > docs/adrs/0002-run-four-stateless-web-replicas.md <<'MD'
# 2. Run four stateless web replicas behind a round-robin balancer

## Status

Accepted

## Context

A single web instance went down twice in March 2026 and took the site with it.

## Decision

Run four web replicas behind the cloud load balancer with round-robin routing.

## Consequences

Any replica can receive any request. In-memory state is not shared between replicas.
MD
git add -A && git commit -q -m "chore: init"
