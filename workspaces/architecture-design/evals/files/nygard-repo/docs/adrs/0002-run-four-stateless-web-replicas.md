# 2. Run four stateless web replicas behind a round-robin balancer

## Status

Accepted

## Context

A single web instance went down twice in March 2026 and took the site with it.

## Decision

Run four web replicas behind the cloud load balancer with round-robin routing.

## Consequences

Any replica can receive any request. In-memory state is not shared between replicas.
