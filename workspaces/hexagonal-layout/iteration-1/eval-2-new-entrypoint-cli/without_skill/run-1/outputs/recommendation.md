# Adding a CLI reindex entrypoint without duplicating logic

## Short answer

Add a new entrypoint file `src/run/reindex-cli.ts` that sits alongside
`src/run/server.ts`. It does exactly what the HTTP route does — wire up the
adapters and call the existing `reindexCatalog` use-case — but is triggered from
a `main()` invoked at module load instead of from an Express handler. No reindex
logic moves; nothing in `src/core` or `src/adapters` changes. The cron job runs
that file.

## Why this is the right seam

The repo is already laid out as a hexagonal / ports-and-adapters app, and the
boundaries it draws tell you exactly where a second trigger belongs:

- **`src/core/reindexCatalog.ts`** is the use-case. It takes a `ProductStore`
  and a `SearchIndex` and orchestrates the work (`clear()`, then `all()`, then
  `put()` each product). It depends on nothing but the ports — no Express, no
  Postgres, no Elastic. That is the logic you don't want to duplicate, and
  because it already takes its dependencies as parameters, you don't have to:
  you just call it again from a different place.
- **`src/core/ports.ts`** declares the interfaces the use-case needs
  (`ProductStore.all()`, `SearchIndex.put()/clear()`). These are the contract
  both entrypoints already speak through.
- **`src/adapters/`** holds the concrete implementations of those ports
  (`ElasticSearchIndex`, and the `PostgresProductStore` referenced from the
  server). These are reusable as-is from any entrypoint.
- **`src/run/`** is the composition root — the place where concrete adapters get
  constructed and handed to the core, and where a delivery mechanism (HTTP
  today) lives. Look at `src/run/server.ts`: lines 10-15 construct a
  `PostgresProductStore` and an `ElasticSearchIndex`, then call
  `reindexCatalog(store, index)`. That wiring block is the *only* thing an HTTP
  request actually adds on top of the use-case.

So a cron-driven CLI is not a new kind of logic — it's a **second entrypoint**
that performs the same wiring and calls the same use-case. In hexagonal terms,
HTTP and cron/CLI are two driving adapters in front of one core. The `src/run`
directory is precisely where driving entrypoints go, which is why the new file
belongs there next to `server.ts`, not in `core` or `adapters`.

## What goes where

### New file: `src/run/reindex-cli.ts`

This is the entire change. It mirrors the wiring already in `server.ts` but
exposes it as a runnable command:

```ts
import { Client } from "@elastic/elasticsearch";
import { reindexCatalog } from "../core/reindexCatalog";
import { ElasticSearchIndex } from "../adapters/elasticIndex";
import { PostgresProductStore } from "../adapters/postgresProductStore";
import { pool } from "./db";

async function main(): Promise<void> {
  const store = new PostgresProductStore(pool);
  const index = new ElasticSearchIndex(
    new Client({ node: process.env.ES_URL! }),
    "products",
  );

  const count = await reindexCatalog(store, index);
  console.log(`reindexed ${count} products`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("reindex failed:", err);
    process.exit(1); // non-zero so the cron job / scheduler sees the failure
  });
```

Note what this reuses verbatim, with no new logic:

- `reindexCatalog` from `src/core/reindexCatalog.ts` — the use-case itself.
- `ElasticSearchIndex` from `src/adapters/elasticIndex.ts` and
  `PostgresProductStore` from `src/adapters/postgresProductStore.ts` — the same
  adapters the server uses.
- `pool` from `src/run/db.ts` — the same DB handle the server imports on line 6.

The only thing this file adds that `server.ts` doesn't is what a command needs
that a request doesn't: a `main()`, a log line instead of a JSON response, and
an **explicit exit code** (`0` on success, non-zero on failure) so the cron
scheduler and your monitoring can tell a failed reindex from a successful one.
A long-lived HTTP server never exits; a batch command must.

### Run it from cron

Point the cron job at this entrypoint. With ts-node:

```
*/30 * * * *  node -r ts-node/register /app/src/run/reindex-cli.ts
```

or, more typically, compile and run the built artifact, e.g.
`node dist/run/reindex-cli.js`. Optionally add an npm script
(`"reindex": "ts-node src/run/reindex-cli.ts"`) so the cron line and local runs
share one command.

## What deliberately does NOT change

- **`src/core/reindexCatalog.ts`** — untouched. Both entrypoints call it. This
  is the whole point: the logic lives in one place and is invoked twice.
- **`src/core/ports.ts`** — untouched. No new port is needed; the CLI uses the
  same `ProductStore` / `SearchIndex` contract.
- **`src/adapters/*`** — untouched. Adapters are shared, not copied.
- **`src/run/server.ts`** — untouched. The HTTP route keeps working exactly as
  before.

## Why not the alternatives

- **Call the HTTP endpoint from cron (`curl localhost:3000/admin/reindex`).**
  This avoids duplicating reindex logic too, but it couples the cron job to the
  web server being up, to network/auth, and to HTTP timeouts for a long batch
  job — and it gives you an HTTP status code instead of a process exit code,
  which is awkward to wire into a scheduler's failure handling. A direct CLI
  entrypoint runs the same core without any of that.
- **Put a CLI file in `src/core` or `src/adapters`.** That would push
  process concerns (`process.argv`, `process.exit`, `console.log`, env reading)
  into layers that are currently free of them. `core` knows only ports;
  adapters implement ports; `run` is where the messy edge — wiring + the actual
  process — is allowed to live. Keeping the CLI in `src/run` preserves that.
- **Factor the wiring out of `server.ts` into a shared
  `buildReindexDeps()` helper and have both call it.** Reasonable and slightly
  DRYer, but it's an optional refinement, not required to avoid duplication: the
  duplication that matters (the reindex *logic*) is already centralized in
  `reindexCatalog`. The repeated three lines of adapter construction are cheap
  and explicit. If you want it, the natural home is a small factory in
  `src/run` (e.g. `src/run/wiring.ts`) that both `server.ts` and
  `reindex-cli.ts` import — but I'd treat that as a follow-up, not a blocker.

## Summary

| Concern | Location | Change |
| --- | --- | --- |
| Reindex logic (use-case) | `src/core/reindexCatalog.ts` | reused, no change |
| Ports / contract | `src/core/ports.ts` | reused, no change |
| Store / index adapters | `src/adapters/*` | reused, no change |
| HTTP entrypoint | `src/run/server.ts` | reused, no change |
| **CLI / cron entrypoint** | **`src/run/reindex-cli.ts`** | **new file** |

One new file in `src/run`, mirroring the wiring in `server.ts` and calling the
existing `reindexCatalog`. Cron points at it. The reindex logic is written once
and now has two driving entrypoints.
