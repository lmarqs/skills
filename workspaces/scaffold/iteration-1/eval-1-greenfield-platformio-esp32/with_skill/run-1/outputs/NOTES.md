# Scaffold decisions — choices recorded at every advisory fork

This project was scaffolded with the `scaffold` skill, non-interactively. Because there was no
user to choose at the advisory forks, the skill's **recommended default** was taken at each one.
The choices below parameterize the generated files.

## Step 1 — Context detection
- Target directory was empty → **greenfield**. Generated from the chosen toolchain rather than auditing.

## Step 2 — Toolchains
- Task is an ESP32 PlatformIO firmware project → single toolchain: **pio** (PlatformIO).
- No AWS / node / python / go / docker / terraform / localstack involved, so no `aws-auth` helper
  and no env-sourced cloud internals.

## Step 3 — Advisory forks (recommended default taken at each)
| Fork | Recommended default | Chosen | Rationale |
|------|--------------------|--------|-----------|
| Namespacing | namespace by toolchain (`pio:<task>`) | namespaced | Uniform across repos and matches the house standard; kept even though this is single-toolchain (flat names like `build`/`upload` were the offered alternative). |
| Env file | `.env.yaml` (mise auto-loads via `_.file`) | `.env.yaml` | House default; committed a `.env.example`, gitignored `.env.yaml`. |
| Version pinning | major.minor, resolved now | `platformio = "6.1"` | PlatformIO Core 6.1 stable line. Note: the task forbade network commands, so the version was NOT live-resolved — pinned to the well-known current 6.1.x stable line instead. |
| Account/machine internals | parameterize via env | `PIO_UPLOAD_PORT` from `.env.yaml` | Serial port is the only machine-specific value; kept out of task scripts and `platformio.ini`. |
| Agent-asset destination | `.claude/` | `.claude/` | No existing `.agents/` tree, so used the out-of-the-box location. |

## Step 4 — Tool versions
- `platformio = "6.1"` (major.minor). See the pinning note above re: no network resolution.

## Step 5 — Files materialized
- `mise.toml` (lean: settings, tools, env; no inline tasks)
- `platformio.ini` (esp32dev board, arduino framework)
- `.env.yaml` + `.env.example` (env file pair)
- `.gitignore`
- `.mise/tasks/pio/{setup,build,upload,monitor}` (chmod +x, each follows the task contract)
- `.claude/skills/esp32-firmware-mise/SKILL.md` (house-rules skill, always generated)
- `src/main.cpp` (minimal blink + serial heartbeat so the project builds)
- `README.md` (Tasks section)
- Empty `include/`, `lib/`, `test/` are the standard PlatformIO project layout.

## Command-skills decision
- **None generated.** Per the agent layer rule, command-skills are only for destructive or multi-step
  tasks that change remote/shared state (e.g. `tf:apply`, `localstack:deploy`). build/upload/monitor
  of local firmware do not qualify — the house-rules skill + raw `mise run` covers them.

## Verification
- `mise tasks` was run within the project directory to confirm every task lists without a parse error.
  Result is noted alongside this file's commit / the final report.
