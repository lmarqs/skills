# Observed behavior

Seen on ralph-tui 0.12.0, beads 1.3.1, Claude Code 2.1.292 and codex-cli 0.160.1. Each entry says how it was observed. Re-check any entry the plan relies on; versions change.

## ralph-tui

- **Iteration cap:** the engine's `maxIterations` default is 10. Seen in the bundled source and `ralph-tui config show`.
- **Models:** the claude agent accepts only `sonnet`, `opus` and `haiku` and refuses to start on anything else. The codex agent accepts any model name. Seen in each agent's `validateModel` in the bundled source.
- **Effort:** `--variant` is passed only to the opencode agent; the claude and codex agents receive `--model` but no effort. Seen in each agent's argument builder.
- **Permissions:** the claude agent launches subagents with `--dangerously-skip-permissions` unless the agent config sets `skipPermissions = false`. The codex agent passes `--sandbox`, default `workspace-write`. Seen in the bundled source.
- **Prompt:** `ralph-tui template show` prints the default template; `--tracker <name>` prints the one that tracker uses. The builtin beads templates tell subagents not to create commits and to close the bead with `bd close <id> --db <cwd>/.beads/beads.db`, a file that does not exist with the embedded Dolt backend. The engine also closes the bead itself when the subagent reports completion. Seen in `ralph-tui template show --tracker beads-bv` and the bundled source.
- **Auto-commit:** off by default; enabled with `autoCommit = true` in `.ralph-tui/config.toml`. When on, it runs `git add -A` and commits after each completed task. The message comes from `commitMessageTemplate`, default `{{taskType}}: {{taskId}} {{taskTitle}}`, where `{{taskType}}` is the bead type, such as `task`. Seen in the config schema and the bundled source.
- **Output locations:** iteration logs default to `.ralph-tui/iterations` (engine default and `ralph-tui run --help`), but `ralph-tui config show` prints `.ralph-output` when no config exists. The progress file defaults to `.ralph-tui/progress.md`. Seen in the bundled source.
- **Parallel merges:** with `--direct-merge`, each task merges as `feat(<taskId>): <title>`. Seen in the bundled source.
- **Environment:** variables matching `*_API_KEY`, `*_SECRET_KEY` and `*_SECRET` are removed before spawning an agent. Seen in the bundled source; `ralph-tui doctor` reports the filter.
- **Status:** `ralph-tui status` exits 0 when completed, 1 when running or paused, 2 when failed or no session. Seen in `ralph-tui status --help`.
- **Pull requests:** ralph-tui never opens one; at the end of a parallel run it prints `gh pr create` guidance. Seen in the bundled source.

## beads

- **Worktree location:** `bd worktree create <name>` creates the worktree at `./<name>` relative to the current directory and adds it to `.gitignore` when that path is inside the repo root. A path such as `../<name>` is accepted. `--branch` defaults to the worktree name. Seen in `bd worktree create --help` and a test run.
- **Shared database:** git worktrees share the beads database through git common directory discovery. Seen in `bd worktree --help`.

## Claude Code

- **Effort:** the `CLAUDE_CODE_EFFORT_LEVEL` environment variable sets effort for headless `claude -p` and takes precedence over settings files. A test run with `low` and `max` reported each level. The `effortLevel` settings key accepts `low` to `xhigh`, not `max`. Seen in the CLI's settings schema.
- **Inherited instructions:** headless subagents load the user's global instructions; a `claude -p` run quoted `~/.claude/CLAUDE.md`. Without the environment variable, effort comes from the user's settings, which can set it per model under `modelSettings`; a `haiku` run with no entry for its model reported `medium`. Seen in test runs on one machine.

## Codex

- **Effort:** `model_reasoning_effort` in `.codex/config.toml`; a project-level file is read only in a trusted project. Seen in the binary's config strings and the user config.
- **Models:** `codex debug models` renders the catalog with each model's supported effort levels.
