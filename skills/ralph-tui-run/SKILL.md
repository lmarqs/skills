---
name: ralph-tui-run
description: "Coordinates the implementation of a beads epic through ralph-tui. The agent running it does not write code: it first reads the project (agent instructions, ralph-tui config, beads, quality gates, git workflow), then picks the epic (the one created in this session when there is one), shows the beads it will implement and confirms, asks for harness (claude or codex), model, effort, worktree usage and pull request granularity (none, one per epic, grouped, or one per bead), starts ralph-tui headless so fresh subagents implement each bead, checks progress every N minutes (configurable), and on completion opens the chosen PRs. Explicit invocation only. Triggers on: ralph run, run the epic, implement the epic with ralph, start ralph on the beads."
---

# Ralph TUI - Run

You are the coordinator. ralph-tui spawns one fresh agent per bead; you start it, watch it, and report. Never edit project code and never close beads yourself.

Every project is set up differently. Learn this one before touching anything.

---

## Step 0: Read the project

Read, in this order, whatever exists:

1. **Agent instructions:** `CLAUDE.md`, `AGENTS.md`, `.claude/settings*.json`, `.codex/`, `.cursorrules`. These bind the subagents too.
2. **ralph-tui setup:** `ralph-tui config show`, `.ralph-tui/config.toml`, `.ralph-tui/prompt.md` (custom template), `.ralph-tui/progress.md`, `ralph-tui status`.
3. **Beads:** `.beads/` present, `bd list --type=epic`.
4. **Quality gates:** how the project runs checks (`mise task list`, `package.json` scripts, `Makefile`, CI). Confirm the beads name them.
5. **Git workflow:** default branch, branch protection, worktrees, commit conventions, hooks.

Write a five-line summary: harness, model and effort the project already configures, branch strategy, quality gates, anything in the agent instructions that constrains an autonomous run. Show it to the user together with the Step 1 scope and the Step 2 questions. Project config becomes the default answer; presets fill the gaps.

If `.beads/` is missing, stop. Point to the `ralph-tui-create-beads` skill.

---

## Step 1: Pick the epic and confirm the scope

If an epic was created earlier in this session, it is the default. Otherwise:

```bash
bd list --type=epic --status=open
```

One open epic: default to it. Several: ask which.

Then show what will be implemented and get an explicit yes before anything else:

```bash
bd show <epic-id>
bd list --parent=<epic-id> --deps --pretty
```

Summarize: epic title and goal, each child bead in execution order with its status, which beads are blocked and by what, and the quality gates the beads name. Flag beads that look too big for one iteration or have no acceptance criteria. Do not start on a scope the user has not confirmed.

---

## Step 2: Run settings (same message as the Step 1 confirmation)

Defaults are what Step 0 found in the project config. One setting applies to every bead in the run, so size it for the hardest bead in the epic, not the average one. Ask only what is missing or worth changing.

**Harness:** `claude` | `codex`. Use the one the project's agent instructions and hooks were written for.

**Model**
- claude `sonnet`: fastest and cheapest. Small, well-specified beads such as adding a column or repeating a known pattern.
- claude `opus`: stronger reasoning. Beads that touch several files or need design judgment.
- claude `fable`: most capable, slowest, costliest. Epics where a wrong decision is expensive to undo.
- codex: the configured model, named. Codex has no command to list models, so use another name only if the user supplies it.

**Effort:** claude `low` | `medium` | `high` | `xhigh` | `max`; codex `minimal` | `low` | `medium` | `high` | `xhigh`
- Low end: quick and cheap, little deliberation per bead. Mechanical beads where quality gates catch mistakes.
- Middle: the usual choice for feature work.
- High end: more thinking per iteration, slower, more tokens. Ambiguous or cross-cutting beads, or an epic that produced rework on a previous run.

**Check interval:** N minutes, default 5. Shorter for many small beads, longer for few large ones.

**Parallel workers:** default serial. `--parallel 3` runs three beads at once on a session branch. Only when the Step 1 tree shows beads without dependencies between them and the project accepts a branch merge at the end.

**Worktree:** yes | no. Yes runs the epic in a separate checkout on its own branch, so the user's working tree and current branch stay untouched while ralph-tui commits. Beads are shared with the main checkout. No runs in the current checkout; if that is the default or a protected branch, create a feature branch first.

**Pull requests:** no default; the user must choose. ralph-tui never opens PRs; the coordinator does it after the epic completes.
- **None:** nothing is pushed. The user reviews and merges the branch.
- **One for the epic:** a single PR with every bead. One review, but a large diff.
- **Grouped:** the user names the groups, for example schema, backend and UI. One PR per group. Groups must be contiguous in the Step 1 execution order; if they are not, say so and ask to regroup.
- **One per bead:** the smallest diffs to review, but many PRs.

Grouped and per-bead PRs are stacked: each targets the previous one's branch, so they merge bottom-up. Also ask: draft or ready for review.

---

## Step 3: Apply effort, then start

ralph-tui 0.12.0 forwards `--model` to claude and codex but not effort. Set effort in the harness config before starting:

- **claude:** `effortLevel` in `.claude/settings.local.json`.
- **codex:** `model_reasoning_effort` in `.codex/config.toml`. Codex applies project config only when the project is trusted; `codex` prompts for trust on first run in a directory.

Both files are project-local so the run never changes the user's global defaults. If one already sets effort, keep it and tell the user.

Tell the user what you changed.

Pick the working directory (`<dir>`):

- **Worktree:** `bd worktree create <epic-id> --branch <branch>`, with a branch name that follows the project's convention from Step 0. `<dir>` is the new worktree. Apply the effort config there, since project-local files do not carry over.
- **No worktree:** `<dir>` is the current checkout.

If any PR was chosen, ralph-tui must commit once per bead. Set `autoCommit = true` in `<dir>/.ralph-tui/config.toml` and keep the default commit message, which carries the bead id. Auto-commit stages everything, so if `.gitignore` does not cover `.ralph-tui/`, ask before adding it; otherwise the run logs get committed.

Then:

```bash
mkdir -p <dir>/.ralph-tui
ralph-tui doctor --agent <harness> --cwd <dir>
ralph-tui run --tracker beads --epic <epic-id> --agent <harness> --model <model> \
  --cwd <dir> --no-tui --no-setup > <dir>/.ralph-tui/run.log 2>&1 &
```

Pass `--model` only when the chosen model differs from the harness's configured one. Add `--parallel <n>` if requested; add `--direct-merge` with it when a PR is wanted, so all work lands on one branch. If `doctor` fails, report and stop.

---

## Step 4: Monitor every N minutes

```bash
ralph-tui status --json --cwd <dir>
bd list --parent=<epic-id>
```

Report in two or three lines: beads closed / total, current bead, last iteration result, any `[ERROR]` or `[WARN]` line in `<dir>/.ralph-tui/run.log`.

Stop when `ralph-tui status` exits `0` (completed) or `2` (failed). In Claude Code, pace the interval with the `loop` skill or `ScheduleWakeup`; elsewhere, sleep N minutes between checks.

---

## Step 5: Finish

- **Completed, PRs:** run the quality gates once in `<dir>`. If they fail, open nothing and report the failures. If they pass:
  1. **One for the epic:** the PR head is `<branch>`.
  2. **Grouped or per bead:** find each unit's last commit by bead id in `git log`. Create one branch per unit at that commit, named by the project's convention.
  3. Push each branch and run `gh pr create` per unit, adding `--draft` if chosen. The first PR targets the base branch; each next one targets the previous unit's branch.
  4. Follow the project's PR template and conventions. The title comes from the epic or group. The body lists its beads, the gate results and, when stacked, the merge order.
  5. Report every PR URL in merge order.
- **Completed, no PRs:** list closed beads and the branch. Ask the user to review the diff before merging.
- **Worktree:** leave it in place. Tell the user to run `bd worktree remove <epic-id>` after merging.
- **Failed or stuck** (same bead for 3 checks, or `[ERROR]`): show the last 30 lines of `<dir>/.ralph-tui/run.log` and that bead's log under `<dir>/.ralph-tui/iterations/`. Offer `ralph-tui resume`; wait for the user.

---

## Rules

- One session per project. If `ralph-tui status` shows one, ask: `resume` or `--force`.
- ralph-tui owns bead state. Do not run `bd close`.
- If a bead is beyond ralph-tui, report it. Do not implement it.
- Push and open PRs only as chosen in Step 2. Never merge them.
