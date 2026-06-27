# Digispark (ATtiny85) USB device

An Arduino sketch for a Digispark (ATtiny85) board, built and flashed with **arduino-cli**
(not PlatformIO) and driven through [mise](https://mise.jdx.dev) tasks.

## Prerequisites

- [mise](https://mise.jdx.dev) installed. `arduino-cli` is pinned in `mise.toml` and
  installed by mise (`mise install`).

## Setup

```bash
cp .env.yaml.example .env.yaml   # adjust board values if needed
mise install                     # install the pinned arduino-cli
mise run arduino:setup           # install the AVR core + libraries
```

## Tasks

All tasks are mise file tasks under `.mise/tasks/arduino/`:

| Command | What it does |
|---|---|
| `mise run arduino:setup` | Install the arduino-cli core (`$ARDUINO_FQBN_CORE`) and libraries (`$ARDUINO_LIBS`) |
| `mise run arduino:compile` | Compile the sketch for `$ARDUINO_FQBN` |
| `mise run arduino:upload [--port <port>]` | Flash the board. The Digispark is portless (plug it in when prompted); `--port`/`$ARDUINO_PORT` is only for other boards |
| `mise run arduino:run` | Compile, then upload — the single build-and-flash command |

List everything with `mise tasks`.

## Board configuration

Board-specific values live in `.env.yaml` (gitignored — copy from `.env.yaml.example`):
`ARDUINO_FQBN`, `ARDUINO_FQBN_CORE`, `ARDUINO_BOARD_MANAGER_URL`, `ARDUINO_LIBS`,
`ARDUINO_PORT`. The task scripts read these so they stay generic — change boards by
editing the env file, not the scripts.
