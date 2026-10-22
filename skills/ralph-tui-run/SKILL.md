---
name: ralph-tui-run
description: "Coordinates the implementation of a beads epic or a prd.json task file through ralph-tui without writing code itself. Reads the project's agent, ralph-tui, task source and git setup; proposes one run plan (scope, harness, model, effort, iteration budget, permissions, worktree, delivery strategy) for the user to confirm; starts ralph-tui headless so fresh subagents implement each task; monitors progress at the user's interval; and delivers through the pull request strategy the user chose. Use only when explicitly invoked: \"ralph run\", \"run the epic with ralph\", \"run the prd.json with ralph\", \"implement the epic with ralph-tui\", \"start ralph on the beads\", \"start ralph on the stories\"."
---

# Ralph TUI - Run

You coordinate; ralph-tui's subagents implement. Never edit product code, close beads, mark stories as passing or merge pull requests.

Assume as little as possible. Projects, tool versions and forges differ: check, then act. [references/observed-behavior.md](references/observed-behavior.md) lists behavior seen on specific versions and how each was observed; re-check what the plan relies on.

A run works through one task source: a beads epic or a JSON task file such as `prd.json`. [references/task-sources.md](references/task-sources.md) says how to pick one and where each step differs; read it before step 1 ends.

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
- **ralph-tui:** merged config, including its `tracker`; the prompt the run will use (`ralph-tui template show --tracker <tracker>`); any existing session; and the agents it supports (`ralph-tui plugins agents`). Whether each agent entry's `command` is a wrapper, such as `.ralph-tui/bin/worker`, that holds a task's completion until the project's checks pass.
- **Launcher:** scripts the project ships for runs, such as `.ralph-tui/bin/run` and `.ralph-tui/bin/clean`, and the instruction files that name them. When present, they decide the worktree, the branch and how ralph-tui starts; read their usage and their own help.
- **Task source:** pick it as task-sources.md says, then read it: for beads, the config, existing worktrees, open epics, and each child bead's acceptance criteria and blockers; for a JSON file, its stories with their acceptance criteria, `priority`, `dependsOn` and `passes`, its `branchName`, and whether git tracks the file. If no source is reachable, stop and point to `ralph-tui-create-beads` or `ralph-tui-create-json`.
- **Quality gates:** how the project runs its checks, whether they run in this checkout today, and whether the tasks name them.
- **Git and forge:** remote and forge, default branch and protection, branch and commit conventions, commit hooks, ignore rules, worktree conventions, PR template and allowed merge methods. A `.worktrees/README.md` states the convention: worktrees at `.worktrees/<branch>`, and an optional executable `.worktrees/setup` that prepares a new one.
- **Models and effort:** read [references/harness-options.md](references/harness-options.md), then confirm against the harness and ralph-tui's agent. Offer only models both accept.

## 2. Propose the run plan

Send one message. Fill each item from step 1, never from memory; where step 1 found nothing, write a question. The user replies with a delivery strategy plus "ok" or changed lines. Do not start without both.

- **Scope:** the task source and why it was picked. The epic or task file created earlier in this session, else the only one present, else ask. Its open tasks in execution order with blockers; say which are already done. Flag tasks too big for one iteration or whose acceptance criteria cannot be checked, such as "works"; if most are, recommend refining them before the run.
- **Gaps:** anything that would stop the run or the delivery, and every conflict between the plan and the project or user setup, each with a proposed fix.
- **Harness, model, effort:** one setting covers the whole run, so size it for the hardest task. Say how the effort will reach the subagents.
- **Budget:** maximum iterations. Propose the open task count plus headroom for retries; say how much and why.
- **Check interval:** the user's value; if none was given, propose one and say why.
- **Parallel workers:** the project's setting, else a proposal based on how many tasks the dependencies show as independent.
- **Subagent permissions:** whether subagents skip permission prompts and whether they run sandboxed. State what ralph-tui does by default for the chosen agent.
- **Worktree:** yes or no. If yes, its path and branch: the project's launcher, such as `.ralph-tui/bin/run <name>` on `.worktrees/ralph/<name>` and branch `ralph/<name>`, else the project's convention, else a proposal with the reason. Say whether creating it changes a tracked file, and for a JSON source whether the file will be there.
- **Commits:** who commits each task and with what message, from ralph-tui's auto-commit setting and what the prompt tells subagents. If neither commits, say the run will produce no commits. For a JSON source, say what happens to the task file, which the engine rewrites as it goes.
- **Start command:** the exact line step 3 will use, headless, with every flag filled, so the user confirms what will run: the project's launcher when it has one, such as `.ralph-tui/bin/run <name> --prd <file> [--base <ref>] --headless`, which passes the remaining arguments to `ralph-tui run`; otherwise `ralph-tui run`. Include the environment it needs, such as `CLAUDE_CODE_EFFORT_LEVEL`.
- **Delivery strategy:** never pick, recommend or default to one. Present the options (none, one PR for the whole run, grouped PRs with groups the user names, one PR per task; draft or ready) with what each means here: units, branches, base of each PR, merge order, and the effect of the allowed merge methods. Say which options the project cannot support yet, for example without a remote. How you build the branches is your call; nothing about delivery may surface for the first time after the run starts.

## 3. Prepare and start ralph-tui

Apply the fixes the user approved. They may change run setup, such as ralph-tui config, prompt, ignore rules, worktree, dependencies or the task source, but never product code. Then verify each of these in the run directory:

- **Budget:** the run's iteration limit equals the confirmed budget, not a config default.
- **Effort:** the chosen effort reaches the subagents. ralph-tui passes none to Claude or Codex: set Claude's per run with `CLAUDE_CODE_EFFORT_LEVEL` in the environment that starts ralph-tui, which reaches every worker, and Codex's per agent entry with `"-c", "model_reasoning_effort=<level>"` in its `defaultFlags`.
- **Prompt:** what subagents are told to do does not conflict with the plan or with the instructions they inherit, and the commands it gives work in this project.
- **Commits:** a delivery strategy that splits by task needs one commit per task that names it. Check what auto-commit stages. If it stages everything, the tree must start clean, and every file the run creates, yours or ralph-tui's, must be ignored without dirtying the tree; a JSON task file is the exception, since its changes belong in each task's commit.
- **Gates:** the quality gates run here. A fresh worktree may lack installed dependencies.
- **Worktree:** it exists at the confirmed path and reaches the task source: `bd list` works inside it, or the JSON file is there.
- **Agent health:** `ralph-tui doctor` passes for the chosen agent. It sends one real prompt.
- **Lifetime:** ralph-tui outlives the command that starts it, with output in a log file.

Start ralph-tui headless with the confirmed agent, model and budget, and the task source: `--epic <id>` with the configured beads tracker, or `--prd <path>` for a JSON file. Through the project's launcher when it has one; otherwise in the run directory, with `--prd <absolute path>`. Check the flags with `ralph-tui run --help`.

## 4. Monitor

Scheduling is your harness's call. Each check, read the session status and the task source; do not infer progress from an exit code alone. Report in two or three lines: tasks done of total, current task, iterations used of the budget, cost when logged, and any error or warning in the log.

- **First task done:** confirm it was marked done (bead closed, or story `passes: true`) and committed as the plan expects. If not, stop the session and report.
- **Stalled** (no new log output or task change since the last check, or an error): show the end of the log and that task's iteration log. Stop the session before offering to resume it, then wait for the user.
- **Completed or failed:** stop monitoring.

## 5. Deliver

1. Run the quality gates once in the run directory. If they fail, deliver nothing and report the failures.
2. Execute the confirmed delivery strategy. PRs follow the project's template; each body lists its tasks, the gate results and, when there are several, the merge order.
3. Report every PR URL in merge order, or the branch when the strategy is none.
4. Leave the worktree in place and tell the user how to remove it after merging: the project's launcher, such as `.ralph-tui/bin/clean <name>`, when it has one.

## Rules

- Never edit product code, close a bead, set a story's `passes` or merge a PR. Change run setup and the task source only as the user approved, and never while ralph-tui runs.
- One ralph-tui session per directory. If one exists, ask: resume or force a new one.
