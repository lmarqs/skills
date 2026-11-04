---
name: cli-mise
description: >-
  This Go CLI's task runner — all repeatable workflows (build, test, lint, fmt, release, docs) run through
  mise as `mise run <task>`. Day-to-day Go tasks use flat names (build, test, lint, fmt); the release flow
  (goreleaser) lives under release:* and docs (mkdocs) under docs:*. Use whenever running, adding, or
  debugging a build/test/lint/fmt/release/docs command in this repo, or when tempted to call `go build`,
  `go test`, `golangci-lint`, `goreleaser`, or `mkdocs` directly — that means a mise task should be used
  or is missing.
---

# CLI mise tasks

All repeatable work is a mise task. Prefer `mise run <task>` over direct `go`/`golangci-lint`/`goreleaser`/
`mkdocs` invocations — mise handles tool versions, working directory, args, flags, and environment
consistently.

This is a single Go module, so the day-to-day tasks are **flat** (no `go:` prefix). Multi-step groups keep a
namespace: `release:*` and `docs:*`.

## Tasks

Day-to-day (Go):
- `mise run build` — compile the CLI binary (`go build ./...`)
- `mise run test [--cover]` — run tests, optionally with coverage
- `mise run lint` — run golangci-lint
- `mise run fmt` — format Go code (`go fmt ./...`)

Release (goreleaser):
- `mise run release:check` — validate `.goreleaser.yaml`
- `mise run release:snapshot` — build a local cross-platform snapshot, no tag/publish
- `mise run release:publish` — cut a real release for the current git tag (needs `GITHUB_TOKEN`)

Docs (mkdocs):
- `mise run docs:build` — build the docs site
- `mise run docs:serve` — serve docs locally with live reload

## Adding a task
1. Create an executable bash file at `.mise/tasks/<task>` (flat) or `.mise/tasks/<namespace>/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for `go build`, `go test`, `goreleaser`, or `mkdocs`
directly, use the matching `mise run` task — and if none exists, add it instead of running it raw.
