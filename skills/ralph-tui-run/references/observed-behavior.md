# Observed behavior

Seen on ralph-tui 0.12.0, beads 1.3.1, Claude Code 2.1.292 and codex-cli 0.160.1. Each entry says how it was observed. Re-check any entry the run depends on; versions change.

## ralph-tui

- **Iteration cap:** `maxIterations` defaults to 10 when no config sets it. Seen in `ralph-tui config show` defaults.
- **Effort:** `--variant` is passed only to the opencode agent; the claude and codex agents receive `--model` but no effort. Seen in the bundled source of each agent's argument builder.
- **Auto-commit:** off by default. When on, it runs `git add -A` and commits after each completed task, with the default message `{{taskType}}: {{taskId}} {{taskTitle}}`. Seen in the bundled source.
- **Parallel merges:** with `--direct-merge`, each task merges as `feat(<taskId>): <title>`. Seen in the bundled source.
- **Environment:** variables matching `*_API_KEY`, `*_SECRET_KEY` and `*_SECRET` are removed before spawning an agent. Seen in the bundled source; `ralph-tui doctor` reports the filter.
- **Status:** `ralph-tui status` exits 0 when completed, 1 when running or paused, 2 when failed or no session. Seen in `ralph-tui status --help`.
- **Pull requests:** ralph-tui never opens one; at the end of a parallel run it prints `gh pr create` guidance. Seen in the bundled source.

## beads

- **Worktree location:** `bd worktree create <name>` creates the worktree at `./<name>` relative to the current directory and adds it to `.gitignore` when that path is inside the repo root. A path argument such as `../<name>` is accepted. Seen in `bd worktree create --help` and a test run.
- **Shared database:** git worktrees share the beads database through git common directory discovery. Seen in `bd worktree --help`.

## Claude Code

- **Effort:** the `CLAUDE_CODE_EFFORT_LEVEL` environment variable sets effort for headless `claude -p` and takes precedence over settings files. A test run with `low` and `max` reported each level. The `effortLevel` settings key accepts `low` to `xhigh`, not `max`. Seen in the CLI's settings schema.

## Codex

- **Effort:** `model_reasoning_effort` in `.codex/config.toml`; a project-level file is read only in a trusted project. Seen in the binary's config strings and the user config.
- **Models:** `codex debug models` renders the catalog with each model's supported effort levels.
