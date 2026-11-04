---
name: release
description: >-
  Cut a cross-platform release of the CLI with goreleaser. Use when the user wants to publish a new version,
  tag a release, or ship binaries. Destructive/remote: it creates a public GitHub release and uploads
  artifacts, so it confirms the tag and runs a dry-run snapshot before publishing.
argument-hint: "[vX.Y.Z]"
---

# Release the CLI

Cut a versioned, cross-platform release via `mise run release:publish` (goreleaser). This publishes a
GitHub release and uploads binaries, so treat it as state-changing and confirm before running.

## Usage
```bash
mise run release:check          # validate config
mise run release:snapshot       # local dry run, no publish
git tag v1.2.3 && git push origin v1.2.3
mise run release:publish        # cut the real release
```

## Instructions
1. Parse `$ARGUMENTS` for the target version (e.g. `v1.2.3`). If missing, ask for it.
2. Run `mise run release:check` to validate `.goreleaser.yaml`. Stop on failure.
3. Run `mise run release:snapshot` and surface the built artifacts for review.
4. Confirm `GITHUB_TOKEN` is set and the working tree is clean. Create and push the tag
   (`git tag <version> && git push origin <version>`) only after the user confirms.
5. Run `mise run release:publish` to build and publish for the pushed tag.
6. Report the release URL and the artifacts that were uploaded.
