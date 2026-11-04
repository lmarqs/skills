---
name: digispark-attiny-mise
description: >-
  Digispark (ATtiny85) firmware task runner — all repeatable workflows (install the
  core/libraries, compile, upload, the compile+upload run loop) go through mise as
  `mise run arduino:<task>`, driven by arduino-cli (not PlatformIO). Use whenever
  compiling, flashing, or setting up this sketch, debugging a build/upload command, or
  when tempted to call `arduino-cli` directly — that means a mise task is missing. Only
  namespace here: arduino.
---

# Digispark ATtiny85 mise tasks

All repeatable work is a mise task wrapping `arduino-cli`. Prefer `mise run arduino:<task>`
over raw `arduino-cli` invocations — mise supplies the board FQBN, core, and port from
`.env.yaml` so every command is consistent.

## Tasks
- `mise run arduino:setup` — install the AVR core and any libraries (`$ARDUINO_LIBS`)
- `mise run arduino:compile` — compile the sketch
- `mise run arduino:upload [--port <port>]` — flash the board (Digispark is portless via
  micronucleus: plug it in when prompted; `--port`/`$ARDUINO_PORT` only for other boards)
- `mise run arduino:run` — compile, then upload (single command for the common loop)

Run a step across every module with the glob: `mise run '**:setup'`.

## Board configuration
Board-specific values live in `.env.yaml` (gitignored; see `.env.yaml.example`), not in
the scripts: `ARDUINO_FQBN`, `ARDUINO_FQBN_CORE`, `ARDUINO_BOARD_MANAGER_URL`,
`ARDUINO_LIBS`, `ARDUINO_PORT`. Change the board by editing those, not the task files.

## Adding a task
1. Create an executable bash file at `.mise/tasks/arduino/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for
   args/flags, `#MISE depends=[…]` to chain other tasks).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for a raw `arduino-cli …`, a task
is missing — add it instead of running it raw.
