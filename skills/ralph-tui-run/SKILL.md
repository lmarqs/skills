---
name: ralph-tui-run
description: "Coordinates the implementation of a beads epic through ralph-tui without writing code itself. Reads the project's agent, ralph-tui, beads and git setup; proposes one run plan (scope, harness, model, effort, iteration budget, worktree, delivery strategy) for the user to confirm; starts ralph-tui headless so fresh subagents implement each bead; monitors progress at the user's interval; and delivers through the agreed pull request strategy. Use only when explicitly invoked: \"ralph run\", \"run the epic with ralph\", \"implement the epic with ralph-tui\", \"start ralph on the beads\"."
---

# Ralph TUI - Run

You coordinate; ralph-tui's subagents implement. Never edit project code, close beads or merge pull requests.

Assume as little as possible. Every project, tool version and forge differs: check, then act. [references/observed-behavior.md](references/observed-behavior.md) lists behavior seen on specific versions, with how each was observed; re-check what the run depends on.

Copy this checklist and track progress:

```
- [ ] 1. Read the project
- [ ] 2. Propose the run plan and get confirmation
- [ ] 3. Prepare and start ralph-tui
- [ ] 4. Monitor
- [ ] 5. Deliver
```

## 1. Read the project

Read whatever exists. Later steps act on these findings.

- **Agent instructions** and harness settings. They bind the subagents too.
- **ralph-tui:** merged config (`ralph-tui config show`), prompt template, any existing session, and the agents it supports.
- **Beads:** config, existing worktrees, open epics. If no beads epic is reachable, stop and point to the `ralph-tui-create-beads` skill.
- **Quality gates:** how the project runs its checks, and whether the beads name them.
- **Git and forge:** default branch and protection, branch and commit conventions, commit hooks, ignore rules, worktree conventions, PR template and allowed merge methods.
- **Harness options:** valid models and effort levels from each harness's own help or catalog. [references/harness-options.md](references/harness-options.md) has a snapshot for claude and codex with when to pick each.

## 2. Propose the run plan

Send one message with every item filled in from step 1. Mark anything step 1 could not determine as a question. The user replies "ok" or changes lines. Do not start without explicit confirmation.

- **Scope:** the epic created earlier in this session, else the only open epic, else ask. Child beads in execution order with blockers. Flag beads too big for one iteration or without acceptance criteria.
- **Gaps:** every conflict between the project setup and this plan, each with a proposed fix.
- **Harness, model, effort:** one setting covers the whole run, so size it for the hardest bead.
- **Budget:** maximum iterations. Propose the bead count plus headroom for retries, and say how much.
- **Check interval:** the user's value; if none was given, propose one and say why.
- **Parallel workers:** the project's setting, else ask. Parallel only suits beads the tree shows as independent.
- **Worktree:** yes or no. If yes, its path and branch, following the project's convention.
- **Delivery strategy:** required, no default. None, one PR for the epic, grouped PRs (the user names the groups), or one PR per bead; draft or ready. State the units, branches, base of each PR, merge order, and how the allowed merge methods affect them. How you build the branches is your call; nothing about delivery may surface for the first time after the run starts.

## 3. Prepare and start ralph-tui

Apply the fixes the user approved. Before starting, verify each of these in this project:

- **Budget:** the run's iteration limit equals the confirmed budget, not a config default.
- **Effort:** the chosen effort reaches the subagents. If ralph-tui does not pass it to this harness, set it through the harness itself.
- **Commits:** a delivery strategy that splits by bead needs one commit per bead that names the bead. Check what ralph-tui's auto-commit stages; if it stages everything, the tree must start clean and every file you add for the run must be ignored.
- **Worktree:** it exists at the confirmed path and reaches the same beads database (`bd list` inside it).
- **Agent health:** `ralph-tui doctor` passes for the chosen agent in the run directory.
- **Lifetime:** ralph-tui outlives the command that starts it, with output in a log file.

Start ralph-tui headless for the epic with the project's tracker, the confirmed agent, model and budget, in the run directory. Check the flags with `ralph-tui run --help`.

## 4. Monitor

Scheduling is your harness's call. Each check, read the session status and the epic's beads; do not infer progress from an exit code alone. Report in two or three lines: beads closed of total, current bead, iterations used of the budget, cost when logged, and any error or warning in the log.

- **Stalled** (no new log output or bead change since the last check, or an error): show the end of the log and that bead's iteration log. Stop the session before offering to resume it, then wait for the user.
- **Completed or failed:** stop monitoring.

## 5. Deliver

1. Run the quality gates once in the run directory. If they fail, deliver nothing and report the failures.
2. Execute the confirmed delivery strategy. PRs follow the project's template; each body lists its beads, the gate results and, when there are several, the merge order.
3. Report every PR URL in merge order, or the branch when the strategy is none.
4. Leave the worktree in place and tell the user how to remove it after merging.

## Rules

- Never implement a bead, close a bead or merge a PR.
- One ralph-tui session per directory. If one exists, ask: resume or force a new one.
