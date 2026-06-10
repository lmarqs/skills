# Adding a CLI entrypoint for the catalog reindex

Short answer: add a second **entrypoint** under `src/run/` — e.g. `src/run/reindexCli.ts` — that does the same wiring the HTTP server does today and calls the same `reindexCatalog` use-case. The reindex logic itself does not move and is not touched.

## Why this is easy: your code is already split the right way

Your three folders map cleanly onto the three kinds of code:

- **The reason** — `src/core/`. `reindexCatalog` (`src/core/reindexCatalog.ts`) is the use-case; `ports.ts` declares the interfaces it needs (`ProductStore`, `SearchIndex`). It depends on nothing outward — it's *handed* a store and an index.
- **The connections** — `src/adapters/`. `ElasticSearchIndex` (`src/adapters/elasticIndex.ts`) implements `SearchIndex`; `PostgresProductStore` (referenced by the server) implements `ProductStore`. All the I/O lives here.
- **How it's run** — `src/run/`. `server.ts` picks the concrete adapters, constructs them, and wires them into `reindexCatalog`. The `pool` from `./db` lives here too.

The crucial property: the reindex logic is **already not coupled to HTTP**. Look at `server.ts` lines 10–15 — the route handler does only three things:

1. Construct a `PostgresProductStore` and an `ElasticSearchIndex`.
2. Call `reindexCatalog(store, index)`.
3. Translate the result into an HTTP response (`res.json({ reindexed: count })`).

Only step 3 is HTTP-specific. Steps 1 and 2 are exactly what a cron job needs. So "without duplicating the reindex logic" is already satisfied by the existing shape — there is nothing to extract from `core`. The reuse boundary is `reindexCatalog` plus the two adapters; a CLI is just a different driver in front of them.

## Where the CLI goes

A cron command is a new **way of running the system** — a second entrypoint — not new business logic and not a new connection. That makes it `src/run/` code, alongside `server.ts`.

Add: **`src/run/reindexCli.ts`**

```ts
import { Client } from "@elastic/elasticsearch";
import { reindexCatalog } from "../core/reindexCatalog";
import { ElasticSearchIndex } from "../adapters/elasticIndex";
import { PostgresProductStore } from "../adapters/postgresProductStore";
import { pool } from "./db";

async function main() {
  const store = new PostgresProductStore(pool);
  const index = new ElasticSearchIndex(new Client({ node: process.env.ES_URL! }), "products");
  const count = await reindexCatalog(store, index);
  console.log(`reindexed ${count} products`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("reindex failed", err);
    process.exit(1);
  });
```

The cron job invokes this file (e.g. `node dist/run/reindexCli.js`, or via a `package.json` script / `ts-node`). It imports the **same** `reindexCatalog`, the **same** `ElasticSearchIndex` and `PostgresProductStore`, and the **same** `pool` that `server.ts` uses.

Note the only differences from the HTTP handler are the **edges**, which is exactly where they belong in an entrypoint:
- A `main()` that runs once and exits, instead of `app.listen(3000)` staying up.
- Output to stdout/exit-code (`console.log` / `process.exit`) instead of `res.json` — a cron job is judged by its exit status, so map failures to a non-zero exit (the HTTP version currently lets errors bubble to Express; a standalone process must handle them itself).

## What gets wired where, and what does NOT change

| File | Kind | Change |
|---|---|---|
| `src/core/reindexCatalog.ts` | reason | **none** — reused as-is |
| `src/core/ports.ts` | reason | **none** |
| `src/adapters/elasticIndex.ts` | connection | **none** — reused as-is |
| `src/adapters/postgresProductStore.ts` | connection | **none** — reused as-is |
| `src/run/db.ts` | how it's run | **none** — reused as-is |
| `src/run/server.ts` | how it's run | **none** — the HTTP entrypoint stays |
| `src/run/reindexCli.ts` | how it's run | **new** — the cron entrypoint |

All the new code is in `run/`. Dependencies still point inward: `reindexCli.ts` → `core` (the use-case) and → `adapters` (the concretes), exactly like `server.ts`. The reason gains a second driver without learning anything about either HTTP or cron — which is the reusability payoff this layout is meant to give you.

## Optional: factor out the shared wiring (only if you want it)

Steps 1–2 are now duplicated as a few lines in both `server.ts` and `reindexCli.ts`. That duplicated text is **wiring, not reindex logic** — the use-case in `core` is genuinely shared, so you have already met your stated goal. If the repetition bothers you, extract just the construction into a small composition helper in `run/`, e.g.:

**`src/run/wireReindex.ts`**

```ts
import { Client } from "@elastic/elasticsearch";
import { ElasticSearchIndex } from "../adapters/elasticIndex";
import { PostgresProductStore } from "../adapters/postgresProductStore";
import { reindexCatalog } from "../core/reindexCatalog";
import { pool } from "./db";

export function runReindex() {
  const store = new PostgresProductStore(pool);
  const index = new ElasticSearchIndex(new Client({ node: process.env.ES_URL! }), "products");
  return reindexCatalog(store, index);
}
```

Then both `server.ts` and `reindexCli.ts` call `runReindex()`. Keep this helper in `run/` (it reads env vars and chooses concretes — that's a "how it's run" responsibility, and config-reading must not leak into `core`). This is a nice-to-have for DRY wiring; it is not required to avoid duplicating the reindex logic, since that logic was never in the entrypoint to begin with.

## What to avoid

- **Don't put reindex logic, or a copy of it, in `reindexCli.ts`.** The loop belongs in `core/reindexCatalog.ts`; the CLI should only construct, call, and report.
- **Don't have the cron job call the HTTP endpoint** (e.g. curl `localhost:3000/admin/reindex`). That couples the batch job to the web server being up and to the network, when both entrypoints can sit directly on the same use-case.
- **Don't add CLI/HTTP concerns to `core`** — no argument parsing, no `process.exit`, no `console.log` in `reindexCatalog`. Keep those at the edge, in `run/`.
