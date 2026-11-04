---
name: blinky-mise
description: >-
  Blinky firmware task runner — all repeatable workflows (setup, build, flash, serial monitor, and
  generating C headers from binary assets) run through mise as `mise run <namespace>:<task>`. Use whenever
  building, flashing, monitoring, or installing deps for this PlatformIO project, when selecting a board
  (esp01s / esp32), when turning files in assets/ into headers, or when tempted to call `pio` / `pip` /
  `python tools/...` directly — that means a mise task is missing. Namespaces here: python, pio, assets.
---

# Blinky mise tasks

This is a PlatformIO firmware project targeting two boards:

- `esp01s` — ESP-01S (ESP8266)
- `esp32` — ESP32 dev board

All repeatable work is a mise task. Prefer `mise run <task>` over direct `pio` / `pip` / `python` calls —
mise handles the venv, working directory, board selection, args, flags, and environment consistently.

## Tasks

- `mise run python:setup` — create/populate the venv and install Python build tooling (incl. PlatformIO)
- `mise run pio:setup` — install PlatformIO platforms & libraries for all boards
- `mise run pio:build [env]` — build firmware; `env` is `esp01s` or `esp32` (defaults to `$PIO_DEFAULT_ENV`)
- `mise run pio:upload [env] [--port <port>]` — build and flash to a board (see the `/pio-upload` command)
- `mise run pio:monitor [env] [--port <port>]` — open the serial monitor for a board
- `mise run assets:headers [--src <dir>] [--out <dir>]` — convert binaries in `assets/` into C headers
  under `include/generated/` (include them in firmware via `#include "assets.h"`)

Build/flash/monitor every board with the env glob if you ever add more, or just pass the board name.

## Board selection

The PlatformIO environment (board) is the first positional arg to the `pio:*` tasks. Omit it to use
`$PIO_DEFAULT_ENV` from `.env.yaml`. Examples:

```bash
mise run pio:build esp32
mise run pio:upload esp01s --port /dev/ttyUSB0
mise run pio:monitor esp32
```

## Adding a task

1. Create an executable bash file at `.mise/tasks/<namespace>/<task>`.
2. Add `#!/usr/bin/env bash`, `set -e`, and `#MISE description="…"` (and `#USAGE` for args/flags).
3. `chmod +x` it and confirm with `mise tasks`.

## Rule

Every repeatable workflow is a mise task. If you reach for `pio …`, `pip …`, or `python tools/…` directly,
a task is missing — add it instead of running it raw.
