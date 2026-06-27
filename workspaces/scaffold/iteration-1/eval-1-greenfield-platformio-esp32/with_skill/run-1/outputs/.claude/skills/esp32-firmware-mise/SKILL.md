---
name: esp32-firmware-mise
description: >-
  ESP32 firmware task runner — all repeatable PlatformIO workflows (install deps, build, flash,
  serial monitor) run through mise as `mise run pio:<task>`. Use whenever building, flashing, or
  monitoring this ESP32 firmware, or when tempted to run raw `pio run` / `pio device monitor`
  commands — that means a mise task should be used (or is missing). Namespace here: pio.
---

# ESP32 firmware mise tasks

All repeatable work is a mise task. Prefer `mise run pio:<task>` over direct `pio` invocations —
mise handles the toolchain version, the serial port (from `.env.yaml`), and arguments consistently.

## Tasks
- `mise run pio:setup` — install PlatformIO platform & library dependencies (`pio pkg install`)
- `mise run pio:build [env]` — build firmware (optionally for a specific `platformio.ini` env/board)
- `mise run pio:upload [env]` — build and flash firmware to the board
- `mise run pio:monitor` — open the serial monitor

The serial port is read from `PIO_UPLOAD_PORT` in `.env.yaml`. Leave it empty to let PlatformIO
auto-detect the board. Run a step across every namespace with the glob: `mise run '**:build'`.

## Adding a task
1. Create an executable bash file at `.mise/tasks/pio/<task>` (or a new `.mise/tasks/<namespace>/<task>`).
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule
Every repeatable workflow is a mise task. If you reach for a raw `pio …` command, use the matching
`mise run pio:<task>` instead — and if none exists, add one rather than running it raw.
