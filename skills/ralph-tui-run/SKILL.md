---
name: ralph-tui-run
description: "Coordinates the implementation of a beads epic through ralph-tui without writing code itself. Reads the project's agent, ralph-tui, beads and git setup; proposes one run plan (scope, harness, model, effort, iteration budget, permissions, worktree, delivery strategy) for the user to confirm; starts ralph-tui headless so fresh subagents implement each bead; monitors progress at the user's interval; and delivers through the pull request strategy the user chose. Use only when explicitly invoked: \"ralph run\", \"run the epic with ralph\", \"implement the epic with ralph-tui\", \"start ralph on the beads\"."
---

# Ralph TUI - Run

You coordinate; ralph-tui's subagents implement. Never edit product code, close beads or merge pull requests.

Assume as little as possible. Projects, tool versions and forges differ: check, then act. [references/observed-behavior.md](references/observed-behavior.md) lists behavior seen on specific versions and how each was observed; re-check what the plan relies on.

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

- **Instructions and settings,** project and user level, for every harness involved. Subagents inherit them, including rules about committing, pushing, issue tracking and effort.
- **ralph-tui:** merged config, the prompt the run will use (`ralph-tui template show --tracker <tracker>`), any existing session, and the agents it supports.
- **Beads:** config, existing worktrees, open epics. If no beads epic is reachable, stop and point to the `ralph-tui-create-beads` skill.
- **Quality gates:** how the project runs its checks, whether they run in this checkout today, and whether the beads name them.
- **Git and forge:** remote and forge, default branch and protection, branch and commit conventions, commit hooks, ignore rules, worktree conventions, PR template and allowed merge methods.
- **Models and effort:** read [references/harness-options.md](references/harness-options.md), then confirm against the harness and ralph-tui's agent. Offer only models both accept.

## 2. Propose the run plan

Send one message. Fill each item from step 1, never from memory; where step 1 found nothing, write a question. The user replies "ok" or changes lines. Do not start without explicit confirmation.

- **Scope:** the epic created earlier in this session, else the only open epic, else ask. Child beads in execution order with blockers. Flag beads too big for one iteration or whose acceptance criteria cannot be checked; if most are, recommend refining them before the run.
- **Gaps:** anything that would stop the run or the delivery, and every conflict between the plan and the project or user setup, each with a proposed fix.
- **Harness, model, effort:** one setting covers the whole run, so size it for the hardest bead.
- **Budget:** maximum iterations. Propose the bead count plus headroom for retries; say how much and why.
- **Check interval:** the user's value; if none was given, propose one and say why.
- **Parallel workers:** the project's setting, else a proposal based on how many beads the tree shows as independent.
- **Subagent permissions:** whether subagents skip permission prompts and whether they run sandboxed. State what ralph-tui does by default for the chosen agent.
- **Worktree:** yes or no. If yes, its path and branch: the project's convention, else a proposal with the reason. Say whether creating it changes a tracked file.
- **Delivery strategy:** never pick it yourself. Present the options (none, one PR for the epic, grouped PRs with groups the user names, one PR per bead; draft or ready) with what each means here: units, branches, base of each PR, merge order, and the effect of the allowed merge methods. Say which options the project cannot support yet, for example without a remote. How you build the branches is your call; nothing about delivery may surface for the first time after the run starts.

## 3. Prepare and start ralph-tui

Apply the fixes the user approved. They may change run setup, such as ralph-tui config, prompt, ignore rules, worktree, dependencies or beads, but never product code. Then verify each of these in the run directory:

- **Budget:** the run's iteration limit equals the confirmed budget, not a config default.
- **Effort:** the chosen effort reaches the subagents. If ralph-tui does not pass it to this harness, set it through the harness itself.
- **Prompt:** what subagents are told to do does not conflict with the plan or with the instructions they inherit, and the commands it gives work in this project.
- **Commits:** a delivery strategy that splits by bead needs one commit per bead that names the bead. Check what auto-commit stages. If it stages everything, the tree must start clean, and every file the run creates, yours or ralph-tui's, must be ignored without dirtying the tree.
- **Gates:** the quality gates run here. A fresh worktree may lack installed dependencies.
- **Worktree:** it exists at the confirmed path and reaches the same beads database (`bd list` inside it).
- **Agent health:** `ralph-tui doctor` passes for the chosen agent. It sends one real prompt.
- **Lifetime:** ralph-tui outlives the command that starts it, with output in a log file.

Start ralph-tui headless for the epic with the tracker from its config, the confirmed agent, model and budget, in the run directory. Check the flags with `ralph-tui run --help`.

## 4. Monitor

Scheduling is your harness's call. Each check, read the session status and the epic's beads; do not infer progress from an exit code alone. Report in two or three lines: beads closed of total, current bead, iterations used of the budget, cost when logged, and any error or warning in the log.

- **First bead done:** confirm it was closed and committed as the plan expects. If not, stop the session and report.
- **Stalled** (no new log output or bead change since the last check, or an error): show the end of the log and that bead's iteration log. Stop the session before offering to resume it, then wait for the user.
- **Completed or failed:** stop monitoring.

## 5. Deliver

1. Run the quality gates once in the run directory. If they fail, deliver nothing and report the failures.
2. Execute the confirmed delivery strategy. PRs follow the project's template; each body lists its beads, the gate results and, when there are several, the merge order.
3. Report every PR URL in merge order, or the branch when the strategy is none.
4. Leave the worktree in place and tell the user how to remove it after merging.

## Rules

- Never edit product code, close a bead or merge a PR. Change run setup and beads only as the user approved.
- One ralph-tui session per directory. If one exists, ask: resume or force a new one.
