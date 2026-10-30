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
