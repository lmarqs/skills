Not started yet. I recommend refining the epic before running: no acceptance criterion in its 12 beads can be checked, and none of the three quality gates runs in this checkout. Here is the run plan. Reply with a **delivery strategy** plus "ok" or the lines you want changed. I won't start without both.

**Scope:** beads epic `e0-new-mel` "Billing export". I picked it because it is the epic created in this session and the only one in the repo. ralph-tui has no config here, so it uses its default `beads-bv` tracker (`bv` 0.25.2 is installed). 12 open beads, 0 done. They form one chain, each bead blocked by the one before:
.1 export_jobs migration → .2 ExportJob repository → .3 CSV serializer → .4 S3 upload client → .5 export orchestrator → .6 POST /exports → .7 GET /exports/:id → .8 retry failed uploads → .9 audit log → .10 admin list UI → .11 admin detail UI → .12 finance docs.
- Every bead's first criterion is "<title> works", which can't be checked. The other two are `npm run typecheck` and `npm run lint` passing. `npm test` appears in none of them.
- Each description just repeats the title, so a subagent gets no spec. For example, .1 doesn't name a database or migration tool, and .4 doesn't name an S3 SDK, bucket or credentials source.
- .10 and .11 ask for UI in a "TypeScript service" that has no UI framework. .12 is docs, yet its gates are typecheck and lint.
- Because all 12 beads are like this, I recommend refining them first (with `ralph-tui-create-beads`, or by hand) to give each one concrete, checkable criteria and the project's choices of database, migration tool, S3 SDK and UI stack.

**Gaps (each with a proposed fix):**
1. **Quality gates don't run.** `npm run typecheck`, `lint` and `test` all exit 127. There is no `node_modules`, `package.json` has no `typescript`/`eslint`/`vitest` devDependencies, and there is no `tsconfig.json` or eslint config. No bead can meet its criteria. Fix: add a bead "US-000: set up TypeScript/ESLint/Vitest toolchain" that blocks `.1`. This changes the task source, so I'll only do it with your approval. The alternative is that you set up the toolchain on `main` before the run.
2. **Your global `~/.claude/CLAUDE.md` conflicts with the run prompt.** Subagents inherit it. It says to commit and push on every bit of progress and to track work in GitHub issues. The ralph-tui prompt says "Do NOT create git commits", the repo has no remote, and beads is the tracker. Fix: add a project prompt override in `.ralph-tui/templates/beads-bv.hbs`. It would tell subagents that, as orchestrator instructions, they must not commit, push, or create or comment on GitHub issues, because the engine commits and beads tracks the work.
3. **The prompt's close step is broken here.** The active template (your global `~/.config/ralph-tui/templates/beads-bv.hbs`) runs `bd close <id> --db <cwd>/.beads/beads.db`. This repo uses embedded Dolt, so that file doesn't exist and the step will error. The engine still closes the bead when the subagent signals completion. Fix: in the same project override, change it to `bd close {{taskId}} --reason "..."` without `--db`.
4. **The run would produce no commits.** Auto-commit is off by default and the prompt forbids commits. Fix: see Commits below.
5. **No git remote, so no forge.** No pull request can be opened (see Delivery strategy).
6. **ralph-tui's output would dirty the tree.** It writes `.ralph-tui/` (progress.md, iterations, session) and `.ralph-output`, and `.gitignore` covers neither. With auto-commit, `git add -A` would commit them. Fix: add `.ralph-tui/` and `.ralph-output/` to `.git/info/exclude`. That file is shared by all worktrees and isn't tracked, so the tree stays clean.

**Harness, model, effort:** Claude Code 2.1.302 with ralph-tui's `claude` agent, model `opus`, effort `high`. One setting covers the whole run, so I sized it for the hardest beads: the orchestrator (.5) and retry (.8) need design judgment across files. ralph-tui 0.12.0's claude agent accepts only `sonnet`/`opus`/`haiku`. ralph-tui doesn't pass effort to the claude agent, so I'll set `CLAUDE_CODE_EFFORT_LEVEL=high` in ralph-tui's environment. Without it, your `modelSettings` would give `claude-opus-5-5` `medium`. Codex 0.160.1 is also installed if you prefer it.

**Budget:** 18 iterations: 12 beads plus 6 (50%) for retries. The headroom is above usual because the criteria are vague and the gates are new, so retries are likely. The ralph-tui default of 10 would stop before the epic ends.

**Check interval:** you didn't give one, so I propose every 10 minutes. With one bead at a time, that's about one check per bead.

**Parallel workers:** 1. The dependencies form a single chain, so nothing can run in parallel. The project has no setting for this.

**Subagent permissions:** by default the claude agent launches subagents with `--dangerously-skip-permissions`, and they are not sandboxed. They can run any command as you without prompting. If you want prompts, I can set `skipPermissions = false`, but a headless run would then stall on the first prompt.

**Worktree:** yes, at `/tmp/claude-1000/-home-lmarqs-Work-skills/ed71c398-ea87-4dfe-9387-c33d1b821de1/scratchpad/ev/e0-new-billing-export` on branch `feat/billing-export` (your convention is `feat/<topic>`, and nothing may be committed directly to main). I'll create it with `bd worktree create ../e0-new-billing-export --branch feat/billing-export`. It sits outside the repo, so `.gitignore` doesn't change and no tracked file changes. It shares the beads database, and I'll confirm with `bd list` inside it. It starts without `node_modules`, so whoever sets up the toolchain (gap 1) installs dependencies there.

**Commits:** I propose `autoCommit = true` in the worktree's `.ralph-tui/config.toml` with `commitMessageTemplate = "feat({{taskId}}): {{taskTitle}}"`. That gives one Conventional Commit per bead, such as `feat(e0-new-mel.3): US-003: CSV serializer for invoices`. The default `task: …` isn't a Conventional Commits type. Subagents don't commit (see gap 2). The engine commits with `git add -A`, so the tree must start clean (it is now) and ralph-tui's files must be excluded (see gap 6). If you keep auto-commit off, the run leaves all changes uncommitted on `feat/billing-export` and makes no commits.

**Delivery strategy (you choose; I don't recommend one):**
- **None:** the work stays on local branch `feat/billing-export` (one commit per bead, if auto-commit is on). Nothing is pushed. **This is the only option possible today.**
- **One PR for the whole run:** `feat/billing-export` → `main`, with 12 commits in one PR.
- **Grouped PRs:** you name the groups, e.g. data layer .1–.4 / service and API .5–.9 / UI and docs .10–.12. The chain is linear, so the PRs stack: each PR's base is the previous group's branch, and they merge in order.
- **One PR per bead:** 12 stacked branches. PR n is based on PR n-1, and they merge in order .1 → .12.
- **Draft or ready:** applies to any PR option.

All the PR options need a remote and a forge first. There is none, so I can't check which merge methods are allowed or whether `main` is protected. If you pick a PR option, add the remote (and tell me the forge). Squash or rebase merges rewrite the commits, so stacked PRs after the first would each need a rebase onto the new `main` before they merge.

**Start command after you confirm** (run headless, detached, logging to a file):
`CLAUDE_CODE_EFFORT_LEVEL=high nohup ralph-tui run --headless --agent claude --model opus --tracker beads-bv --epic e0-new-mel --iterations 18 > .ralph-tui/run.log 2>&1 &`, run in the worktree. Before starting I'll confirm that the gates pass there and that `ralph-tui doctor` passes (it sends one real prompt).
