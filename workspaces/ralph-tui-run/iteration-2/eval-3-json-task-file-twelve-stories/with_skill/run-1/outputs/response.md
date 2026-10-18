I haven't started ralph-tui. Before you confirm the plan below, the task file needs refining and the quality gates need to work. As written, the run can't verify any story.

## Run plan: billing export (`tasks/prd.json`)

**Scope.** The source is the JSON task file `tasks/prd.json` ("Billing export"). We created it this session, there is no `.beads/`, and no ralph-tui config picks a tracker. Git tracks it (commit `d848599`). None of the 12 stories pass yet. Each one depends on the one before it, so they run in this order:
US-001 export_jobs migration → US-002 ExportJob repository → US-003 CSV serializer → US-004 S3 upload client → US-005 export orchestrator → US-006 POST /exports → US-007 GET /exports/:id → US-008 retry failed uploads → US-009 audit log → US-010 admin list UI → US-011 admin detail UI → US-012 finance docs.
- **None of the 12 stories has acceptance criteria a subagent can check.** Each one's main criterion is "<title> works", and its description just repeats the title. No story asks for tests. Several look too big for one iteration: US-005 orchestrator, US-008 retries, US-010/011 UI (the repo has no UI stack). **I recommend refining the file before the run** (re-run `ralph-tui-create-json` / `ralph-tui-prd`) so each story gets concrete, testable criteria and `npm test passes`.

**Gaps (each with a proposed fix)**
1. **Quality gates don't run.** `npm run typecheck`, `lint` and `test` all exit 127 (`tsc: not found`). There's no `node_modules`, no lockfile, no `tsconfig.json`, and `package.json` has no devDependencies. Fix: add a story US-000 that sets up the TypeScript, ESLint and Vitest toolchain, or have you set it up before the run. I won't edit product code or tooling myself.
2. **No git remote.** No pull request strategy is possible yet. Fix: add the remote (and tell me the forge, the protection on `main` and the allowed merge methods), or choose delivery "none".
3. **Your instructions conflict with the run prompt.** Subagents load `~/.claude/CLAUDE.md`, which says to commit and push often and to track work in GitHub issues. The ralph-tui json prompt (your global override, `~/.config/ralph-tui/templates/json.hbs`) tells them not to commit. Fix: turn on auto-commit (see Commits) and add one line to that prompt for this run: "The engine commits; do not commit, push, or create/update GitHub issues."
4. **Branch names conflict.** The file's `branchName` is `ralph/billing-export`. Project CLAUDE.md says to use `feat/<topic>` and never commit to `main`. ralph-tui never checks out `branchName`. Fix: use `feat/billing-export`.
5. **No ignore rules.** There's no `.gitignore`, and the run creates `.ralph-tui/` (session, iterations, progress.md) plus `node_modules/`. Auto-commit runs `git add -A`, so those would land in each story's commit. Fix: add a `.gitignore` with `.ralph-tui/` and `node_modules/`, committed on the feature branch before the start.
6. **Budget default.** ralph-tui's default `maxIterations` is 10, which is fewer than the 12 stories. Fix: pass `--iterations` explicitly (see Budget).

**Harness, model, effort:** Claude Code 2.1.302 with the `opus` model (claude-opus-5-5). The stories span DB, S3, HTTP and UI work, so size for the orchestrator and retry logic. ralph-tui 0.12.0's claude agent accepts only `sonnet`, `opus` and `haiku`. Effort: **high**. ralph-tui doesn't pass effort to the claude agent, and your `modelSettings` would put opus-5-5 at `medium`. I'll launch with `CLAUDE_CODE_EFFORT_LEVEL=high`, which overrides that setting.

**Budget:** **18 iterations**. That's the 12 open stories plus 6 (50%) headroom for retries. The headroom is large because the vague criteria make reworks likely. If you refine the stories first, 15 is enough.

**Check interval:** you didn't give one. I propose **every 10 minutes**. A high-effort opus story here should take several minutes, so a shorter interval would mostly report no change.

**Parallel workers:** **1**. The `dependsOn` chain is strictly linear, so no two stories can run at once.

**Subagent permissions:** ralph-tui's claude agent starts subagents with `--dangerously-skip-permissions` by default (no `skipPermissions` override is configured), so they won't prompt. Sandboxing is not enabled unless `--sandbox` is passed. I propose **`--sandbox=bwrap`** (Bubblewrap is installed at `/usr/bin/bwrap`), with network allowed so `npm install` works.

**Worktree:** **yes**: `git worktree add ../billing-export -b feat/billing-export` (absolute: `/tmp/claude-1000/-home-lmarqs-Work-skills/ed71c398-ea87-4dfe-9387-c33d1b821de1/scratchpad/ev/e3-new/../billing-export`). The project has no worktree convention. A sibling directory keeps `main` clean and needs no ignore entry. Creating it changes no tracked file. `tasks/prd.json` is committed, so it'll be there. The run then uses `--prd <worktree>/tasks/prd.json`.

**Commits:** auto-commit is off today (no `.ralph-tui/config.toml`), and the prompt tells subagents not to commit, so **as configured the run would produce no commits** and would leave `tasks/prd.json` modified. Proposal: create `.ralph-tui/config.toml` in the worktree (ignored by fix 5) with `autoCommit = true` and `commitMessageTemplate = "feat: {{taskId}} {{taskTitle}}"`. That fits Conventional Commits; the default would be `story: …`. You'd get one commit per story on `feat/billing-export`, each carrying that story's `passes: true` change in `tasks/prd.json`.

**Delivery strategy: you choose.** I won't pick one. Every option except "none" needs a remote first (gap 2). The merge methods `main` allows are unknown until then.
- **None:** the work stays on local branch `feat/billing-export` in the worktree, 12 commits, no PR.
- **One PR for the whole run:** `feat/billing-export` → `main`, all 12 stories in one PR. A squash merge would collapse them into one commit; merge or rebase keeps the per-story commits.
- **Grouped PRs (you name the groups),** e.g. data layer US-001–004, API US-005–009, UI and docs US-010–012. That's one branch per group, stacked: each PR's base is the previous group's branch, and the first is based on `main`. They merge in order, and each base is retargeted to `main` after its predecessor merges. A squash merge rewrites history and forces a rebase of the later branches.
- **One PR per story:** 12 stacked branches and PRs (US-001 based on `main`, US-n based on US-n-1), merged strictly in order. The same squash caveat applies, multiplied by 12.
- For any PR option, also tell me **draft or ready**.

**Reply with:** a delivery strategy, plus "ok" or the lines you want changed. Also say whether you'll refine the stories (recommended) and how the toolchain gets set up (fix 1). I won't start until I have both.
