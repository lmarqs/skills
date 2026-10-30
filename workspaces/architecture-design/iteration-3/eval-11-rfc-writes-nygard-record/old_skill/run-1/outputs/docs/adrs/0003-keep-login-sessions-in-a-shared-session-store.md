# 3. Keep login sessions in a shared session store

## Status

Accepted, 2026-10-30. Decider: Dana, team lead, after consulting the web team. Reviewer: the security
team. Relates to ADR-0002 (completes it; does not supersede it).

## Context

ADR-0002 runs four web replicas behind round-robin routing and noted that in-memory state is not shared
between replicas. Login sessions are such state: each replica keeps the sessions it created in its own
memory. A signed-in user is signed out when the balancer sends a request to another replica, and every
user is signed out on every deploy, because a deploy replaces every replica.

Sessions hold up to 20 KB each (stated by the team; not yet measured). The security team requires that
signing out ends the session; this record reads "immediately" as: from the moment the sign-out response
is sent, every replica refuses that session's cookie, including a copied one. Browsers are only required
to accept cookies of 4,096 bytes each (RFC 6265, section 6.1), so a 20 KB session needs five or more
cookies if the browser holds it. No traffic figures are recorded; live sessions, peak request rate and
deploy frequency are unknown and are measured before the store is sized.

Options considered:

- **Do nothing.** Sign-out already ends the session, but users keep being signed out between requests
  and on every deploy.
- **Sticky sessions** (balancer affinity). The smallest change, but a deploy or a failed replica still
  discards the sessions pinned to it, so deploys keep signing users out.
- **Signed cookies** (session data held by the browser). No server state, but a copied cookie stays
  valid after sign-out, and 20 KB of cookies would ride on every request.
- **Small signed cookie plus a shared revocation list.** Meets the sign-out rule only by adding a shared
  store, plus key management and a session trimmed under 4 KB.
- **Hosted identity or session service.** Rewrites sign-in and still needs a server-side home for the
  application data in the session.
- **Shared server-side session store.** Meets all of the above at the cost of a new stateful component
  on every signed-in request.

## Decision

Keep login sessions in one session store shared by all four replicas. The browser's session cookie
carries only an opaque random ID (`HttpOnly`, `Secure`, `SameSite=Lax`). The sign-out rule removed
signed cookies; surviving deploys removed sticky sessions.

Recommended store: a managed Redis-compatible key-value service with a primary and a replica in a second
availability zone, automatic failover, TLS and authentication, on the private network. Dana confirms the
product at implementation; any store meeting the checks below satisfies this decision.

How the web tier uses it: key `session:<id>` with a time-to-live equal to the idle timeout, refreshed on
use; write the session back only when it changed; read from the primary only; on sign-out, delete the key
and wait for one store replica to acknowledge (`WAIT 1`) before responding, so a failover cannot bring
the session back; if the store is unreachable, treat the request as signed out (fail closed) and alert;
version the session format so old and new code read it during a rolling deploy.

Cutover is one deploy behind a configuration flag. That deploy discards in-memory sessions as every
deploy does today and is the last one that signs users out. The flag is the rollback for two weeks, then
the in-memory path is removed.

## Consequences

Deploys and replica replacements no longer sign users out, and the replicas become stateless, as
ADR-0002's title already claimed. Sign-out is a delete in one place.

Every signed-in request now depends on the session store. During a store outage users are signed out
and cannot sign in: the security requirement was put ahead of staying signed in. The team now runs,
sizes, patches, pays for and pages on the store, and keeps the session format compatible across
versions.

Confirmation: a CI test signs out on one replica and replays the cookie against all four (blocks the
release on failure); a rolling-deploy test with synthetic signed-in users runs on each release
candidate; a failover drill before go-live and quarterly, with a 30-second target for refused signed-in
requests (assumed); session load p99 at or below 5 ms (assumed); a dashboard count of unexpired session
cookies the store does not recognise. Review on 2027-01-30, or earlier if the store causes a
user-visible incident or sessions grow past 20 KB.
