# Observed behavior

Seen on ralph-tui 0.12.0, beads 1.3.1, Claude Code 2.1.292 to 2.1.306 and codex-cli 0.160.1. Each entry says how it was observed. Re-check any entry the plan relies on; versions change.

## ralph-tui

- **Iteration cap:** the engine's `maxIterations` default is 10. Seen in the bundled source and `ralph-tui config show`.
- **Tracker selection:** `--tracker` wins, then the config's `tracker` key, then a `trackers` list entry; with none of these the tracker is `beads-bv`. `--prd <path>` switches to `json` unless `--tracker` is also given. Tracker settings live under `[trackerOptions]`. Seen in the config builder in the bundled source and `ralph-tui run --help`.
- **Models:** the claude agent accepts only `sonnet`, `opus` and `haiku` and refuses to start on anything else. The codex agent accepts any model name. Seen in each agent's `validateModel` in the bundled source.
- **Effort:** `--variant` is passed only to the opencode agent; the claude and codex agents receive `--model` but no effort. Seen in each agent's argument builder. The environment passes through to workers, so `CLAUDE_CODE_EFFORT_LEVEL` set where ralph-tui starts reaches Claude workers: a fake worker logged it (lmarqs/the-cook#42).
- **Permissions:** the claude agent launches subagents with `--dangerously-skip-permissions` unless the agent config sets `skipPermissions = false` under `[agents.options]`; a `skipPermissions` at the top of the `[[agents]]` entry is dropped silently, and the bypass stays. The codex agent passes `--sandbox`, default `workspace-write`. Seen in the bundled source and a logged argv (lmarqs/the-cook#42).
- **Agent flags:** `defaultFlags` sits at the top of an `[[agents]]` entry and comes before the agent's own arguments; under `[agents.options]` it is replaced silently. `command` names the executable, which ralph-tui first runs with `--version` alone. Seen in a logged argv and the bundled source (lmarqs/the-cook#42).
- **Completion:** a task completes, and with auto-commit is committed, when the agent's output holds `<promise>COMPLETE</promise>` anywhere, at any exit code, even in a sentence saying it is not done. Seen in the bundled source; a wrapper that withholds the output until the checks pass kept a story open (lmarqs/the-cook#55).
- **Rate limits:** stderr naming a rate limit, `429`, `quota exceeded` or `overloaded` marks the iteration rate-limited, and ralph-tui retries or switches agent. Seen in the bundled source.
- **Config lookup:** `.ralph-tui/config.toml` is read only from the directory ralph-tui starts in and its parent. Prompts come from `--prompt`, then `prompt_template`, then `.ralph-tui/templates/<tracker>.hbs` in that directory, then the user's `~/.config/ralph-tui/templates`, then the built-in ones. Seen in the bundled source.
- **Parallel workers:** worktrees beside the run directory, in `.ralph-worktrees/<its name>/`; each gets only `config.toml` copied in, so a `--prompt` path reaches them and project prompts reach them only when committed. Parallel mode refuses fewer than three tasks. Seen in the bundled source and test runs (lmarqs/the-cook#53, lmarqs/the-cook#57).
- **Prompt:** `ralph-tui template show` prints the default template; `--tracker <name>` prints the one that tracker uses. The builtin beads templates tell subagents not to create commits and to close the bead with `bd close <id> --db <cwd>/.beads/beads.db`, a file that does not exist with the embedded Dolt backend. The engine also closes the bead itself when the subagent reports completion. Seen in `ralph-tui template show --tracker beads-bv` and the bundled source.
- **Auto-commit:** off by default; enabled with `autoCommit = true` in `.ralph-tui/config.toml`. When on, it runs `git add -A` and commits after each completed task. The message comes from `commitMessageTemplate`, default `{{taskType}}: {{taskId}} {{taskTitle}}`, where `{{taskType}}` is the bead type, such as `task`. Seen in the config schema and the bundled source.
- **Output locations:** iteration logs default to `.ralph-tui/iterations` (engine default and `ralph-tui run --help`), but `ralph-tui config show` prints `.ralph-output` when no config exists. The progress file defaults to `.ralph-tui/progress.md`. Seen in the bundled source.
- **Parallel merges:** with `--direct-merge`, each task merges as `feat(<taskId>): <title>`. Seen in the bundled source.
- **Environment:** variables matching `*_API_KEY`, `*_SECRET_KEY` and `*_SECRET` are removed before spawning an agent. Seen in the bundled source; `ralph-tui doctor` reports the filter.
- **Status:** `ralph-tui status` exits 0 when completed, 1 when running or paused, 2 when failed or no session. Seen in `ralph-tui status --help`.
- **Pull requests:** ralph-tui never opens one; at the end of a parallel run it prints `gh pr create` guidance. Seen in the bundled source.

## json tracker

- **Task file:** a JSON object with `name` and `userStories` at the root; each story has `id`, `title` and `passes`, and optionally `description`, `acceptanceCriteria`, `priority`, `dependsOn`, `labels` and `notes`. The root may carry `description`, `branchName` and `metadata`. Seen in the schema validator in the bundled source and the json tracker docs.
- **Path:** `--prd <path>` or `[trackerOptions] path`. A relative path resolves against the directory ralph-tui was started in, not `--cwd`. `--tracker json` without a path opens an interactive file browser. Seen in the tracker's `initialize` in the bundled source and the json tracker docs.
- **Selection:** the next story is one with `passes: false` whose `dependsOn` stories all pass, lowest `priority` first, then file order. `--epic` does not apply; the tracker reports one epic, `prd:<name>`. Seen in the bundled source and the json tracker docs.
- **Write-back:** the engine rewrites the file when a story starts (`passes: false`, `metadata.updatedAt`) and when it completes (`passes: true`, `completionNotes`, `metadata.updatedAt`), reformatted with two-space indentation. Completion is written before auto-commit runs, so with auto-commit on each story's commit carries its own `passes` change. Seen in the tracker's `updateTaskStatus` and `completeTask` and the engine's iteration loop in the bundled source.
- **Auto-commit:** stages with `git add -A` in the run directory, so a task file outside it, or ignored by git, is never committed. `{{taskType}}` is `story`, so the default message is `story: <id> <title>`. Seen in the bundled source.
- **branchName:** read from the file but never acted on; ralph-tui does not create or check out that branch. Seen in the bundled source: `getBranchName` has no caller.
- **Prompt:** `ralph-tui template show --tracker json` prints it. It tells subagents not to commit and has no step that edits the task file; the engine marks the story. Seen on one machine with a user-level template override.

## beads

- **Worktree location:** `bd worktree create <name>` creates the worktree at `./<name>` relative to the current directory and adds it to `.gitignore` when that path is inside the repo root. A path such as `../<name>` is accepted. `--branch` defaults to the worktree name. Seen in `bd worktree create --help` and a test run.
- **Shared database:** git worktrees share the beads database through git common directory discovery. Seen in `bd worktree --help`.

## Claude Code

- **Effort:** the `CLAUDE_CODE_EFFORT_LEVEL` environment variable sets effort for headless `claude -p` and takes precedence over settings files. A test run with `low` and `max` reported each level. The `effortLevel` settings key accepts `low` to `xhigh`, not `max`. Seen in the CLI's settings schema.
- **Trust:** in a workspace nobody has trusted, `--print` ignores the project's `permissions.allow` and prints `Ignoring … permissions.allow entries … this workspace has not been trusted`; denies and hooks still apply, and allows passed with `--settings <file>` apply. A worktree of a trusted checkout is trusted. Seen in test runs (lmarqs/the-cook#42).
- **Inherited instructions:** headless subagents load the user's global instructions; a `claude -p` run quoted `~/.claude/CLAUDE.md`. Without the environment variable, effort comes from the user's settings, which can set it per model under `modelSettings`; a `haiku` run with no entry for its model reported `medium`. Seen in test runs on one machine.

## Codex

- **Effort:** `model_reasoning_effort` in `.codex/config.toml`; a project-level file is read only in a trusted project. Seen in the binary's config strings and the user config.
- **Models:** `codex debug models` renders the catalog with each model's supported effort levels.
- **Sandbox:** under `workspace-write`, `.git` and the Beads database are read-only, so a Codex worker can neither commit nor run `bd`; ralph-tui commits and closes beads for it. Codex's default writable roots include `/tmp` and `$TMPDIR`, so a test repository there passes falsely. Seen in test runs (lmarqs/the-cook#42).
- **Hooks:** trust is stored per absolute path of `.codex/hooks.json`, so every new worktree starts with its project hooks untrusted and silently skipped, unless started with `--dangerously-bypass-hook-trust`. Seen in test runs (lmarqs/the-cook#42).
