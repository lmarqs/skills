---
name: ralph-tui-run
description: "Coordinates the implementation of a beads epic through ralph-tui. The agent running it does not write code: it first reads the project (agent instructions, ralph-tui config, beads, quality gates, git workflow), then picks the epic, asks for harness (claude or codex), model and effort from a preset list, starts ralph-tui headless so fresh subagents implement each bead, then checks progress every N minutes (configurable) and reports until the epic completes or fails. Explicit invocation only. Triggers on: ralph run, run the epic, implement the epic with ralph, start ralph on the beads."
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
4. **Quality gates:** how the project runs checks (`mise.toml`, `package.json` scripts, `Makefile`, CI). Confirm the beads name them.
5. **Git workflow:** default branch, branch protection, worktrees, commit conventions, hooks.

Write a five-line summary: harness and model the project already configures, branch strategy, quality gates, anything in the agent instructions that constrains an autonomous run. Show it to the user with the Step 2 questions. Project config becomes the default answer; presets fill the gaps.

If `.beads/` is missing, stop. Point to the `ralph-tui-create-beads` skill.

---

## Step 1: Pick the epic

```bash
bd list --type=epic --status=open
```

One open epic: use it. Several: ask which.

---

## Step 2: Ask for run settings (one message)

Offer these presets; accept custom values.

| Preset | Harness | Model | Effort |
|---|---|---|---|
| claude-fast   | claude | sonnet  | medium |
| claude-strong | claude | opus    | high   |
| claude-max    | claude | opus    | max    |
| codex-fast    | codex  | default | medium |
| codex-strong  | codex  | default | high   |
| codex-max     | codex  | default | xhigh  |

Also ask:
- **Check interval** in minutes (N). Default 5.
- **Parallel workers**. Default serial. `--parallel 3` runs three beads at once on a session branch.

---

## Step 3: Apply effort, then start

ralph-tui 0.12.0 forwards `--model` to claude and codex but not effort. Set effort in the harness config before starting:

- **claude:** `effortLevel` in the project's `.claude/settings.local.json`.
- **codex:** `model_reasoning_effort` in `~/.codex/config.toml`.

Tell the user what you changed. Respect the branch strategy from Step 0: `--direct-merge` or `--target-branch <name>` in parallel mode. Then:

```bash
ralph-tui doctor --agent <harness>
ralph-tui run --tracker beads --epic <epic-id> --agent <harness> --model <model> \
  --no-tui --no-setup > .ralph-tui/run.log 2>&1 &
```

Omit `--model` for codex default. Add `--parallel <n>` if requested. If `doctor` fails, report and stop.

---

## Step 4: Monitor every N minutes

```bash
ralph-tui status --json
bd list --parent=<epic-id>
```

Report in two or three lines: beads closed / total, current bead, last iteration result, any `[ERROR]` or `[WARN]` line in `.ralph-tui/run.log`.

Stop when `ralph-tui status` exits `0` (completed) or `2` (failed). In Claude Code, pace the interval with the `loop` skill or `ScheduleWakeup`; elsewhere, sleep N minutes between checks.

---

## Step 5: Finish

- **Completed:** list closed beads and the session branch (parallel mode). Ask the user to review the diff before merging.
- **Failed or stuck** (same bead for 3 checks, or `[ERROR]`): show the last 30 lines of `.ralph-tui/run.log` and that bead's log under `.ralph-tui/iterations/`. Offer `ralph-tui resume`; wait for the user.

---

## Rules

- One session per project. If `ralph-tui status` shows one, ask: `resume` or `--force`.
- ralph-tui owns bead state. Do not run `bd close`.
- If a bead is beyond ralph-tui, report it. Do not implement it.
