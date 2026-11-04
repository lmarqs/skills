I haven't started anything. I recommend we fix `tasks/prd.json` before running it. In 11 of the 12 stories, the only functional acceptance criterion is "<title> works", and the rest of each story is "typecheck passes" and "lint passes". In this repo none of those checks can run (`tsc`, `eslint` and `vitest` aren't installed, and there's no tsconfig or eslint config). So no subagent could fail a story, and every iteration would mark its story `passes: true` whatever it built. The plan is below. Reply with a delivery strategy plus "ok", or tell me which lines to change.

**Scope**: `tasks/prd.json` ("Billing export"). It's the file we created in this session and the only task source here: there's no `.beads/` and no ralph-tui config. It's committed in `18128fc`. All 12 stories have `passes: false` and none are done. They form one dependency chain and run in this order:
US-001 export_jobs migration → US-002 ExportJob repository → US-003 CSV serializer → US-004 S3 upload client → US-005 export orchestrator → US-006 POST /exports → US-007 GET /exports/:id → US-008 retry failed uploads → US-009 audit log → US-010 admin list UI → US-011 admin detail UI → US-012 finance docs.
Problems with these stories:
- US-001 to US-012: "… works" can't be checked. No story asks for tests, even though `npm test` is a project gate.
- US-001: the repo has no database, ORM or migration tool, so the story has to pick one.
- US-004: the repo has no AWS SDK and no rule for credentials or tests.
- US-010 and US-011: the repo has no UI framework, so "admin UI" is undefined.
- US-012: "docs works" is meaningless, and typecheck/lint don't check docs.
The fix is to rerun `ralph-tui-create-json`, or edit the file with me, and give each story concrete criteria. For example: "`npm test` covers X; vitest case Y passes". Also add a first story that sets up the toolchain.

**Gaps** (each with a proposed fix):
1. The quality gates don't run. `package.json` has no devDependencies, and there's no tsconfig, eslint config or test. Fix: add a US-000 "toolchain" story (typescript, eslint, vitest, configs) that everything else depends on, or set up the toolchain yourself before the run. After that I'll run `npm install` in the worktree.
2. The acceptance criteria can't be checked (see Scope). Fix: refine the stories first.
3. There's no git remote, so PRs, pushes and GitHub issues are impossible. Your global CLAUDE.md asks for frequent pushes and issue tracking. Subagents inherit those rules and will try to follow them. Fix: add a remote (`gh repo create` or an existing URL), or accept local-only delivery. Either way, I'll add one line to a project prompt (`.ralph-tui/prompt.hbs`, a copy of the json template) telling subagents not to push or create issues during this run.
4. Ralph-tui files would dirty the tree. The template writes `.ralph-tui/progress.md`, and there's no `.gitignore`. Fix: add `.ralph-tui/` to `.git/info/exclude`. That file is shared by the worktree and doesn't change any tracked file.
5. The branch name conflicts with your convention. The file says `branchName: ralph/billing-export`, but CLAUDE.md requires `feat/<topic>` and no commits to main. ralph-tui ignores `branchName`. Fix: run on `feat/billing-export` in a worktree.
6. The commit format doesn't match. Ralph-tui's default commit message, `story: US-001 …`, isn't a Conventional Commits type. Fix: set `commitMessageTemplate = "feat(billing-export): {{taskId}} {{taskTitle}}"`.

**Harness, model, effort**: Claude Code, `opus` at `high` effort. I sized for the hardest stories: the orchestrator, the retry logic, and choosing a migration and UI approach. ralph-tui's claude agent accepts only `sonnet`, `opus` and `haiku`, and it doesn't pass effort to Claude Code. Your settings give `claude-opus-5-5` medium effort, so I'll set `CLAUDE_CODE_EFFORT_LEVEL=high` on the start command.

**Budget**: 18 iterations. That's 12 stories plus 6 (50%) for retries. I'm allowing more headroom than usual because the criteria are vague and the gates are new. If you add US-000, it becomes 19.

**Check interval**: you didn't give one, so I propose every 15 minutes. That's about one opus iteration per check, which is enough to catch a stall early.

**Parallel workers**: 1 (serial). Each story depends on the one before it, so nothing can run in parallel. There's no project setting.

**Subagent permissions**: by default, ralph-tui's claude agent runs subagents with `--dangerously-skip-permissions` and no sandbox. I propose keeping the skip and adding `--sandbox=bwrap` (bubblewrap 0.9.0 is installed). Network access stays on, which the agent API needs.

**Worktree**: yes. `git worktree add ../e3-new2-billing-export -b feat/billing-export main`, a sibling of this repo, since the project has no worktree convention. It doesn't change any tracked file. `tasks/prd.json` is committed, so it will be there.

**Commits**: ralph-tui commits each story. I'll set `autoCommit = true` in `.ralph-tui/config.toml` inside the worktree; the folder is ignored through `.git/info/exclude`. That gives one commit per story on `feat/billing-export`, with the message `feat(billing-export): US-00N <title>`. Each commit includes that story's `passes: true` change in `tasks/prd.json`. The prompt still tells subagents not to commit, and auto-commit stages everything (`git add -A`), so the worktree must start clean. After `npm install`, `node_modules/` has to be ignored too, so I'll add it to `.git/info/exclude` as well.

**Start command** (run in the worktree, with output going to a log file):
```
cd /tmp/claude-1000/-home-lmarqs-Work-skills/ed71c398-ea87-4dfe-9387-c33d1b821de1/scratchpad/ev/e3-new2-billing-export && CLAUDE_CODE_EFFORT_LEVEL=high nohup ralph-tui run --headless --no-setup --no-notify --agent claude --model opus --prd /tmp/claude-1000/-home-lmarqs-Work-skills/ed71c398-ea87-4dfe-9387-c33d1b821de1/scratchpad/ev/e3-new2-billing-export/tasks/prd.json --iterations 18 --serial --sandbox=bwrap --prompt .ralph-tui/prompt.hbs > .ralph-tui/run.log 2>&1 &
```

**Delivery strategy**: you choose; I won't pick one. None of the PR options work until a remote exists.
- **None**: the 12 commits stay on local branch `feat/billing-export` and I report the branch. This is the only option that works today.
- **One PR for the whole run**: needs a remote. `feat/billing-export` → `main`, with all 12 stories in one PR. Allowed merge methods are unknown without a forge, and squash would collapse the stories into one commit.
- **Grouped PRs**: needs a remote, and you name the groups (for example data layer US-001–004, API US-005–009, UI and docs US-010–012). I'd build stacked branches from the story commits. Each PR's base is the previous group's branch, and they merge in order. Squash or rebase merges force a rebase of the next PR before it merges.
- **One PR per story**: needs a remote. That's 12 stacked PRs, each based on the previous one and merged strictly US-001 → US-012, with the same restack cost if you squash.
- Draft or ready: say which.

My recommendation: let me (or `ralph-tui-create-json`) rewrite the stories with checkable criteria and a toolchain story first. Then reply "ok" with a delivery strategy and any line changes.
