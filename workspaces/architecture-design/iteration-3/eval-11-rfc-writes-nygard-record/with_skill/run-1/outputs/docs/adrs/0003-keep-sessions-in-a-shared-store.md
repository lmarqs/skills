# 3. Keep sessions in a shared store

## Status

Accepted

## Context

ADR 2 runs four web replicas behind a round-robin balancer and notes that in-memory state is not
shared between them. Sessions are such state: each replica keeps the logins it created in its own
memory, so a user is logged out when the balancer sends a new connection to another replica, and every
deploy, which restarts all four replicas, logs out every user. A session holds up to 20 KB. The
security function requires that logout end the session on the very next request, whichever replica
receives it. Drivers, in order: logout ends the session at once on every replica; users stay logged in
across replicas and deploys; the fix must not bring back the single-instance outages ADR 2 removed; a
session holds up to 20 KB, while browsers are only required to keep 4,096 bytes per cookie (RFC 6265,
section 6.1).

## Decision

Sessions live in one shared store that every replica reads and writes, a managed in-memory key-value
store with a replica in another zone and automatic failover. The browser's cookie carries only a random
session identifier, each session expires after the current idle timeout, and logout deletes the
session before the logout response is sent. If the store cannot be reached, requests are treated as
logged out rather than falling back to replica memory. It is the one option that survives a deploy and
ends a session by deleting it while keeping ADR 2's round-robin routing.

Sticky sessions need no new service and add no latency, but each deploy's restart still logs out that
replica's users, and a failed replica logs out a quarter of them. Signed cookies keep no server state
and survive deploys, but a signed cookie cannot be ended before it expires, and 20 KB exceeds the
4,096 bytes a browser is required to keep per cookie. Adding a revocation list to signed cookies makes
logout work, but that list is a shared store every replica reads, with the large cookie kept on top.
Replicating sessions between replicas needs no new service, but a logout reaches the other replicas
only after the replication delay. Doing nothing keeps users being logged out on deploys and replica
changes.

The team agreed this option before it was written up; Dana, team lead, owns the decision. Full
analysis, requirements, tradeoff table and confirmation plan: the decision document *Keeping users
signed in across web replicas and deploys* (version 1.0, 2026-10-30), carried in the pull request that
adds this record.

## Consequences

Any replica serves any request, deploys and replica failures stop logging users out, and logout is one
delete in one place that a test can replay against every replica. Every logged-in request makes a
round trip to the store. The store joins the services a deploy and the site depend on: the team now
sizes it, monitors it and is paged for it, and a full store outage logs every user out until it
returns. The cutover deploy logs users out one last time.
