# blinky

PlatformIO firmware for two boards, driven by [mise](https://mise.jdx.dev) tasks.

| Board    | PlatformIO env | MCU     |
| -------- | -------------- | ------- |
| ESP-01S  | `esp01s`       | ESP8266 |
| ESP32    | `esp32`        | ESP32   |

## Getting started

```bash
cp .env.example .env.yaml   # adjust PIO_PORT / PIO_DEFAULT_ENV for your machine
mise install                # installs the pinned Python toolchain
mise run python:setup       # creates the venv and installs PlatformIO into it
mise run pio:setup          # downloads platforms & libraries for both boards
```

## Tasks

All repeatable work runs through mise (`mise tasks` to list). The PlatformIO board is the first arg to
`pio:*` tasks (`esp01s` or `esp32`); omit it to use `$PIO_DEFAULT_ENV` from `.env.yaml`.

| Task                                          | What it does                                                |
| --------------------------------------------- | ----------------------------------------------------------- |
| `mise run python:setup`                       | Create venv, install Python build tooling (incl. PlatformIO)|
| `mise run pio:setup`                          | Install PlatformIO platforms & libraries                    |
| `mise run pio:build [env]`                    | Build firmware for a board                                  |
| `mise run pio:upload [env] [--port <port>]`   | Build and flash firmware to a board                         |
| `mise run pio:monitor [env] [--port <port>]`  | Open the serial monitor                                     |
| `mise run assets:headers [--src] [--out]`     | Turn binaries in `assets/` into C headers in `include/generated/` |

### Examples

```bash
mise run pio:build esp32
mise run pio:upload esp01s --port /dev/ttyUSB0
mise run pio:monitor esp32
mise run assets:headers          # then #include "assets.h" in your firmware
```

## Assets → C headers

Drop binary files (logos, fonts, certs, sound clips) into `assets/`, run `mise run assets:headers`, and
each becomes a header under `include/generated/` exposing a `const unsigned char <name>[]` + `<name>_len`.
A roll-up `assets.h` includes them all; `platformio.ini` already adds `include/generated` to the include
path, so `#include "assets.h"` just works. The generated directory is gitignored — regenerate as part of
the build.

## Layout

- `platformio.ini` — board environments (`esp01s`, `esp32`)
- `src/` — firmware source
- `assets/` — binary assets (source of truth for generated headers)
- `tools/bin2header.py` — the asset → header converter (Python build tooling)
- `.mise/tasks/` — task scripts (`pio:*`, `python:*`, `assets:*`)
- `include/generated/` — generated headers (gitignored)
