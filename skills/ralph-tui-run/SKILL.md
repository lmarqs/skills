---
name: ralph-tui-run
description: "Coordinates the implementation of a beads epic through ralph-tui without writing code itself. Reads the project's agent, ralph-tui, beads and git setup; proposes one run plan (scope, harness, model, effort, iteration budget, worktree, delivery strategy) for the user to confirm; starts ralph-tui headless so fresh subagents implement each bead; monitors progress every N minutes; and delivers through the agreed pull request strategy. Use only when explicitly invoked: \"ralph run\", \"run the epic with ralph\", \"implement the epic with ralph-tui\", \"start ralph on the beads\"."
---

# Ralph TUI - Run

You coordinate; ralph-tui's subagents implement. Never edit project code, close beads or merge pull requests.

Copy this checklist and track progress:

```
- [ ] 1. Read the project
- [ ] 2. Propose the run plan and get confirmation
- [ ] 3. Prepare and start ralph-tui
- [ ] 4. Monitor every N minutes
- [ ] 5. Deliver
```

## 1. Read the project

Projects differ. Read whatever exists; later steps act on these findings.

- **Agent instructions:** `CLAUDE.md`, `AGENTS.md`, harness settings. They bind the subagents too.
- **ralph-tui:** `ralph-tui config show` for tracker, agent, model, `maxIterations`, `autoCommit`, `commitMessageTemplate` and parallel settings. Also `ralph-tui template show` and `ralph-tui status`.
- **Beads:** `bd config show`, `bd worktree list`, open epics. No `.beads/`: stop and point to the `ralph-tui-create-beads` skill.
- **Quality gates:** how the project runs its checks, and whether the beads name them.
- **Git:** default branch and protection, branch and commit conventions, commit hooks, PR template, `.gitignore`, and allowed merge methods (`gh repo view --json squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed`).
- **Harness options:** models and effort levels for claude and codex, with when to pick each, are in [references/harness-options.md](references/harness-options.md). Run its refresh commands; their output wins over the file.

## 2. Propose the run plan

Send one message with every item filled in from step 1. The user replies "ok" or changes lines. Do not start without explicit confirmation.

- **Scope:** the epic created earlier in this session, else the only open epic, else ask. List child beads in execution order with blockers (`bd list --parent=<epic-id> --deps --pretty`). Flag beads too big for one iteration or without acceptance criteria.
- **Gaps:** every conflict between the project setup and this plan, each with a proposed fix.
- **Harness, model, effort:** one setting covers every bead, so size it for the hardest one. Offer the options from the reference file with their one-line guidance.
- **Budget:** maximum iterations, default bead count plus half for retries. It is the only limit ralph-tui enforces.
- **Check interval:** N minutes, default 5.
- **Parallel workers:** default serial. Only for beads the tree shows as independent.
- **Worktree:** yes keeps the user's checkout untouched; no runs in the current checkout.
- **Delivery strategy:** required, no default. None, one PR for the epic, grouped PRs (the user names the groups), or one PR per bead; draft or ready. State the units, branches, base of each PR, merge order, and how the repo's merge methods affect them. For example, squash-merging a stacked PR forces the next one to rebase. How you build the branches is your call; nothing about delivery may surface for the first time after the run starts.

## 3. Prepare and start ralph-tui

Apply the fixes the user approved, then handle these traps exactly:

- **Iteration cap:** ralph-tui stops at `maxIterations` (default 10) without reporting failure. Always pass `--iterations <budget>`.
- **Tracker:** pass the project's tracker from step 1, not a hardcoded one.
- **Effort:** ralph-tui does not forward effort to claude or codex (confirm with `ralph-tui run --help`). For claude, launch ralph-tui with `CLAUDE_CODE_EFFORT_LEVEL=<level>`; subagents inherit it, and the settings file rejects `max`. For codex, set `model_reasoning_effort` in `<dir>/.codex/config.toml`; codex reads it only in a trusted project.
- **Commits:** any delivery strategy other than none needs `autoCommit = true` and a commit template containing `{{taskId}}`. Auto-commit runs `git add -A`, so the working tree must start clean and every file you add for the run must be ignored.
- **Worktree:** create it outside the repo with `bd worktree create ../<name> --branch <branch>`. Beads stay shared.
- **Environment:** ralph-tui strips variables matching `*_API_KEY`, `*_SECRET_KEY` and `*_SECRET` from subagents. `ralph-tui doctor --agent <harness> --cwd <dir>` must pass before starting.
- **Lifetime:** ralph-tui must outlive the command that starts it. Launch it detached with output in a log file.

```bash
ralph-tui run --tracker <tracker> --epic <epic-id> --agent <harness> [--model <model>] \
  --iterations <budget> --cwd <dir> --no-tui --no-setup [--parallel <n> --direct-merge]
```

`--direct-merge` keeps parallel work on one branch so the delivery strategy can split it.

## 4. Monitor every N minutes

Scheduling the checks is your harness's call. Each check:

```bash
ralph-tui status --json --cwd <dir>
bd list --parent=<epic-id>
```

Read the status field: exit code 1 means running or paused. Report in two or three lines: beads closed of total, current bead, iterations used of the budget, cost when logged, and any error or warning in the log.

- **Stuck** (same bead for three checks, or an error): show the end of the log and that bead's log under `<dir>/.ralph-tui/iterations/`. Stop the session before offering `ralph-tui resume`, then wait for the user.
- **Completed or failed:** stop monitoring.

## 5. Deliver

1. Run the quality gates once in `<dir>`. If they fail, deliver nothing and report the failures.
2. Execute the confirmed delivery strategy. PRs follow the project's template; each body lists its beads, the gate results and, when there are several, the merge order.
3. Report every PR URL in merge order, or the branch when the strategy is none.
4. Leave the worktree in place; tell the user to run `bd worktree remove` after merging.

## Rules

- Never implement a bead, close a bead or merge a PR.
- One ralph-tui session per directory. If one exists, ask: resume or `--force`.
