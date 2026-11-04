I haven't started anything yet. This project has two task sources and nothing in it tells me which one to run, so you need to pick one. The plan for each is below. Reply with **the source (A or B), a delivery strategy, and "ok" or the lines you want changed.**

## Scope: which source? (you decide)

There is no `.ralph-tui/config.toml`, so no `tracker` is configured. Your message doesn't name an epic or a file, and both sources exist:

- **A. Beads epic `e4-new-ci0` "Billing export"**: 12 open beads, 0 closed. It's a strict chain: `.1 → .2 → .3 → … → .12` (US-001 export_jobs migration, ExportJob repository, CSV serializer, S3 upload client, orchestrator, POST /exports, GET /exports/:id, retry failed uploads, audit log, admin list UI, admin detail UI, finance docs).
- **B. `tasks/prd.json` "Invoice PDF rendering"** (tracked in git): 3 stories, none passing. Also a chain: US-001 PDF template (p1) → US-002 GET /invoices/:id/pdf (p2) → US-003 download button on invoice page (p3).

Task quality:
- **A:** every bead's first acceptance criterion is "<title> works", which nobody can check, and the only checkable ones are typecheck and lint. US-004/005/008 (S3 client, orchestrator, retries) are each probably too big for one iteration given descriptions that only repeat the title. **I recommend refining A's beads before running it.**
- **B:** the criteria are concrete ("Returns application/pdf…"). US-003 asks for a button on an invoice page, but the repo has no UI: `src/` holds only `index.ts`, which exports a version string. Confirm where that page lives, or drop the story.

## Gaps (each blocks the run or the delivery)

1. **The quality gates can't run.** `npm run typecheck`, `lint` and `test` all fail with "not found". `package.json` declares no dependencies at all (no typescript, eslint or vitest), and there's no lockfile, `tsconfig.json` or eslint config. **Fix:** you add the dev toolchain and configs, or approve me adding one setup task at the head of the chosen source for a subagent to do. I won't write it myself.
2. **There's no git remote, so no PR can be opened.** **Fix:** add a remote (forge, default branch, protection and merge methods are unknown until you do). Without one, only delivery "none" works.
3. **Instruction conflict about commits.** Subagents load your `~/.claude/CLAUDE.md` ("commit and push as soon as … meaningful progress"). The ralph-tui prompt for both trackers says "Do NOT create git commits", and this repo's CLAUDE.md says "Never commit directly to main". **Fix:** turn on auto-commit (see Commits) and run on a feature branch. The prompt's "do not commit" line stays, and with no remote nothing can be pushed anyway.
4. **(A only) Broken close step.** The beads prompt tells subagents to run `bd close <id> --db <cwd>/.beads/beads.db`, but this repo uses embedded Dolt and that file doesn't exist. The engine closes the bead itself on completion, so the run still progresses, but each subagent hits a failing command. **Fix:** a project prompt (`--prompt`) that drops `--db`. I'll re-check this against the user-level override in `~/.config/ralph-tui/templates/beads-bv.hbs` before applying it.
5. **(B only) Branch name clash.** `branchName` is `ralph/invoice-pdf`, but the convention here is `feat/<topic>`. ralph-tui never checks out `branchName`, so I'll use the convention (see Worktree).

## Harness, model, effort
- **Harness:** Claude Code 2.1.302 through ralph-tui 0.12.0's `claude` agent (the default; codex-cli 0.160.1 is also installed if you prefer it).
- **Model:** **opus** for A (S3, orchestration and retry logic need judgment). For B, **sonnet** is enough: 3 small, well-specified stories. The claude agent accepts only `sonnet`, `opus` or `haiku`.
- **Effort:** **high** for A, **medium** for B. ralph-tui passes no effort to the claude agent, so I'll set `CLAUDE_CODE_EFFORT_LEVEL` in ralph-tui's environment. Otherwise your `modelSettings` would apply: `medium` for claude-opus-5-5, `high` for claude-sonnet-5-5.

## Budget
- **A:** 15 iterations, which is 12 tasks plus 3 retries (25%, since the criteria are vague).
- **B:** 5 iterations, which is 3 tasks plus 2 retries.
- The config default of 10 would cut A short, so I'll pass `--iterations` explicitly.

## Check interval
You didn't give one. I propose **every 10 minutes**: one opus or sonnet iteration on tasks this size likely takes 5–15 minutes, so each check should see about one task change.

## Parallel workers
**1 (serial).** Both sources are single dependency chains, so no two tasks are independent.

## Subagent permissions
By default the claude agent runs subagents with `--dangerously-skip-permissions` and no sandbox. I propose keeping the permission skip, which a headless run needs, and adding `--sandbox=bwrap` (bwrap is installed at `/usr/bin/bwrap`). The sandbox keeps network access unless you also want `--no-network`. Note that the npm installs in gap 1 need network.

## Worktree
**Yes.** The project has no worktree convention, so I propose a sibling directory, which changes no tracked file:
- **A:** `bd worktree create ../e4-new-billing-export --branch feat/billing-export` shares the beads database, and I'll check `bd list` inside it.
- **B:** `git worktree add ../e4-new-invoice-pdf -b feat/invoice-pdf`. `tasks/prd.json` is committed, so it will be there, and the run uses `--prd <worktree>/tasks/prd.json` (absolute path).

## Commits
- ralph-tui's auto-commit is off by default and the prompt tells subagents not to commit, so **as configured, the run would produce no commits**. With B, `prd.json` would also be left modified.
- **Proposal:** `autoCommit = true` in `.ralph-tui/config.toml` inside the worktree, with `commitMessageTemplate = "feat({{taskId}}): {{taskTitle}}"` to follow Conventional Commits. The default would give `task: …` / `story: …`.
- That gives one commit per task. For B, each commit also carries that story's `passes: true` change.
- Auto-commit stages everything (`git add -A`). So the worktree starts clean, and I'll exclude `.ralph-tui/` through `.git/info/exclude` so no tracked `.gitignore` changes.
- The beads git hooks (`core.hooksPath=.beads/hooks`) will run on each commit.

## Delivery strategy (you choose; I won't default)
The units are 12 beads (A) or 3 stories (B), committed in sequence on `feat/billing-export` or `feat/invoice-pdf`. Base: `main`.
- **None:** the work stays on the feature branch in the worktree, and I report the branch. **This is the only option possible today.**
- **One PR for the whole run:** feature branch → `main`. One review, one merge.
- **Grouped PRs (you name the groups,** for example A: data layer .1–.3, export pipeline .4–.8, audit/UI/docs .9–.12): each group is a branch stacked on the previous one, and they merge in order. A squash merge would force the later PRs to be rebased.
- **One PR per task:** 12 (A) or 3 (B) stacked PRs, merged strictly in chain order, with the same squash caveat.
- **Draft or ready:** your choice for any PR option.

Every PR option needs a remote first (gap 2). Allowed merge methods and the PR template are unknown until there's a forge.
