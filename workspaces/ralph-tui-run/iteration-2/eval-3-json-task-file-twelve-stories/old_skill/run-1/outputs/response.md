I have not started ralph. The run coordinator I follow works only on a beads epic, and this project has none. It has `tasks/prd.json` and no beads database (`bd list`: "no beads database found"). Nothing was changed. The tree is still clean on `main` at `a178f11`.

**To unblock the run, pick one:**
1. **Convert to beads (what my run process supports):** run the `ralph-tui-create-beads` skill on the billing export PRD. It runs `bd init` and creates an epic with the 12 stories as child beads. Then ask me to "run the epic with ralph" again and I'll send you the full run plan.
2. **Run the JSON file directly:** ralph-tui 0.12.0 has a built-in `json` tracker for `prd.json`. My run process doesn't cover that tracker, so I can't propose or monitor a run on it with the same checks. You would have to start it yourself or tell me to go ahead outside that process.

**Fix the PRD before either route.** If it stays as it is, the run will mostly waste iterations:
- **None of the 12 stories has acceptance criteria that can be checked.** Each one says "<title> works", then "typecheck passes" and "lint passes". `npm test` isn't required by any story, though `CLAUDE.md` lists it as a quality gate. A subagent can't tell when "CSV serializer for invoices works" is done. Each story needs concrete criteria, such as columns and format, the endpoint request and response, and the retry policy, plus `npm test` passing.
- **Several stories are probably too big for one iteration:** US-005 (export orchestrator), US-008 (retry failed uploads), US-010 and US-011 (admin UIs).
- **The stories form one strict chain.** US-001 → US-002 → … → US-012, so nothing can run in parallel. Some dependencies look artificial, for example the S3 client depending on the CSV serializer, or the docs depending on the detail UI. Check whether that order is what you want.
- **The project can't run its quality gates yet.** It has no `node_modules` and no lockfile, and `package.json` lists no dependencies (no `typescript`, `eslint` or `vitest`). The gates will fail until those are added.
- **The branch name breaks your convention.** `prd.json` uses `branchName: ralph/billing-export`, but `CLAUDE.md` says branches are `feat/<topic>`, so it should be `feat/billing-export`.
- **No PR can be opened yet.** The repo has no git remote. Delivery can only be "none" (a local branch) until you add one.

Tell me which route you want and whether to refine the stories first.
