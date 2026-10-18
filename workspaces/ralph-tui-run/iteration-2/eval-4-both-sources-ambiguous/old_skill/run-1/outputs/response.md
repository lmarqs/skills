Nothing started yet. Two blockers first, then the run plan. Reply with (a) which scope, (b) a delivery strategy, and (c) "ok" or the lines you want changed.

**Blocker 1: two task sources, unclear which to run.**
- Beads epic `e4-old-uuo` "Billing export": 12 open child beads, the only open beads epic.
- `tasks/prd.json` "Invoice PDF rendering": 3 stories (US-001..US-003), all `passes: false`, committed in `13a79e5 chore: add prd.json`. It's a different feature from the epic, not a copy of it.
- They overlap only in story IDs (both use US-001..). Which one should run? I won't pick, because whichever one I skip just sits there.

**Blocker 2: quality gates don't run in this checkout.** `npm run typecheck`, `lint` and `test` all fail with `tsc/eslint/vitest: not found`. `package.json` has no dependencies or devDependencies, there's no lockfile, no `tsconfig.json` and no ESLint config. Every bead and story requires "npm run typecheck passes", so no iteration can pass honestly. Fix: you or a setup bead adds `typescript`, `eslint`, `vitest`, a `tsconfig.json` and `eslint.config.js`, then installs them. I won't write those files myself, since that's project code.

---

**Scope**
- Option A, epic `e4-old-uuo`, a strict linear chain: .1 export_jobs migration → .2 ExportJob repository → .3 CSV serializer → .4 S3 upload client → .5 export service orchestrator → .6 POST /exports → .7 GET /exports/:id → .8 retry failed uploads → .9 audit log → .10 admin list UI → .11 admin detail UI → .12 finance docs.
  - Flag: none of the 12 beads has a checkable criterion. Each one's only functional criterion is "<title> works", and the description just repeats the title. I recommend refining them before the run: concrete behavior, a test per bead, and `npm test` named as a gate. Most also need decisions a subagent shouldn't guess: migration tool and DB, S3 SDK, bucket and credentials, UI framework. The repo has only `src/index.ts`.
- Option B, `tasks/prd.json`, linear: US-001 PDF template → US-002 GET /invoices/:id/pdf → US-003 download button. Criteria are partly checkable ("returns application/pdf"). "Button downloads the PDF" is not, and the repo has no web UI.

**Gaps (each with a proposed fix)**
1. Gates broken: see blocker 2.
2. Unclear acceptance criteria (A: 12/12; B: 1/3): refine before running.
3. The prompt's close command won't work. The global `beads-bv` template (`~/.config/ralph-tui/templates/beads-bv.hbs`) tells subagents `bd close <id> --db <beadsDbPath>`, but this project uses the embedded Dolt backend (`.beads/embeddeddolt`), so that db file doesn't exist. The engine closes the bead itself on completion, so this doesn't block, but subagents will hit the error. Fix: a project template at `.ralph-tui/templates/beads-bv.hbs` that runs plain `bd close <id>`. Only applies to A.
4. Conflict with your global `~/.claude/CLAUDE.md`, which subagents inherit. It says "commit and push as soon as meaningful progress" and "track all work in GitHub issues". The prompt says "Do NOT create git commits", and the repo has no remote and no GitHub issues. Fix: the project prompt states that the engine commits, subagents never commit or push, and bead status is the tracker.
5. Branch naming: CLAUDE.md requires `feat/<topic>` and forbids committing to `main`. prd.json's `branchName` is `ralph/invoice-pdf`. Fix: run on `feat/billing-export` (A) or `feat/invoice-pdf` (B).
6. No git remote: see Delivery.

**Harness, model, effort:** Claude Code 2.1.302, ralph-tui agent `claude`, model `opus`, effort `high`. One setting covers the whole run. For A, the hardest beads are the orchestrator, retries and UI, which are cross-cutting and underspecified. For B, `sonnet`/`medium` would do, but I'd still use `opus`/`high` for US-002 and US-003 given the missing app scaffolding. ralph-tui passes no effort to the claude agent, so I'll set `CLAUDE_CODE_EFFORT_LEVEL=high` in the environment that starts ralph-tui. Without it, effort comes from your `~/.claude/settings.json` `modelSettings`.

**Budget:** A: 16 iterations (12 beads + 4, about 33% for retries, since the chain is serial and one failed bead blocks the rest). B: 5 (3 stories + 2). ralph-tui's default is 10, which is wrong for both, so I'll pass `--iterations` explicitly.

**Check interval:** you gave none. I propose 10 minutes: one opus/high iteration usually takes several minutes, so shorter checks would mostly show no change.

**Parallel workers:** 1. No ralph-tui config exists, and both sources are strict chains, so nothing can run in parallel.

**Subagent permissions:** ralph-tui's claude agent defaults to `--dangerously-skip-permissions` with no sandbox. Subagents can run any command without prompting. I'll keep that unless you want `skipPermissions = false`, which would stall a headless run on the first prompt.

**Worktree:** yes. There's no project convention, so I propose `bd worktree create ../e4-old-<topic> --branch feat/<topic>` (topic `billing-export` or `invoice-pdf`). It sits outside the repo, so it doesn't touch `.gitignore` or any tracked file, and it shares the beads database. Your `main` checkout stays clean.

**Commits:** ralph-tui auto-commit is off by default, and the prompt tells subagents not to commit, so as configured the run produces no commits. I propose `.ralph-tui/config.toml` (inside the worktree) with `autoCommit = true` and `commitMessageTemplate = "feat: {{taskId}} {{taskTitle}}"`, giving one Conventional Commit per bead or story. Auto-commit runs `git add -A`, so I'll add `.ralph-tui/` to `.git/info/exclude` (untracked, shared by worktrees). That keeps the progress file, logs and config out of the commits without dirtying the tree. For B, each commit will also include the `passes: true` update to `tasks/prd.json`.

**Delivery strategy (your choice, I won't default it):**
- **None:** commits stay on `feat/<topic>` in the worktree. You merge or push yourself.
- **One PR for the scope:** one branch `feat/<topic>`, one PR into `main`.
- **Grouped PRs:** you name the groups (e.g. A: data layer .1–.4 / service+API .5–.8 / audit+UI+docs .9–.12). Branches are stacked, each PR based on the previous group's branch and merged in order.
- **One PR per bead/story:** 12 (A) or 3 (B) stacked branches and PRs, merged strictly in chain order.
- Each PR option can be draft or ready.
- **Not supported yet:** every PR option. This repo has no git remote and no forge (`git remote -v` is empty, no `.github/`), so branch protection, PR template and allowed merge methods are unknown. As things stand, only "none" can be delivered. To pick a PR option, add the remote first and say which merge methods it allows. Squash-merging a stacked chain would force a rebase of each later branch.

Current state: tree clean on `main`, no ralph-tui session or config, ralph-tui 0.12.0, bd 1.3.1.
