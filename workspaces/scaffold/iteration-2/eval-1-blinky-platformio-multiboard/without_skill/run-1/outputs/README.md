# Multi-board ESP firmware

A small PlatformIO firmware project that targets two boards from one source tree:

| Board    | PlatformIO env | Platform        | MCU     |
| -------- | -------------- | --------------- | ------- |
| ESP-01S  | `esp01s`       | espressif8266   | ESP8266 |
| ESP32    | `esp32`        | espressif32     | ESP32   |

Board-specific behavior (LED pin/polarity) is selected with build flags in
[`platformio.ini`](platformio.ini); the shared firmware lives in
[`src/main.cpp`](src/main.cpp).

## Prerequisites

- [mise](https://mise.jdx.dev/) for the task runner (and to pin Python).
- [PlatformIO Core](https://docs.platformio.org/page/core/index.html) (`pio`)
  available on your `PATH` (e.g. `pipx install platformio`).

## Tasks

All tasks run through `mise run <task>`. Board-aware tasks read the `BOARD`
environment variable (`esp01s` or `esp32`, default `esp32`); each also has a
pinned alias.

| Task                 | What it does                                            |
| -------------------- | ------------------------------------------------------- |
| `gen-headers`        | Convert `assets/*` into C headers in `include/generated`|
| `clean-headers`      | Delete the generated headers                            |
| `build`              | Compile for `$BOARD`                                     |
| `build:esp01s`       | Compile for the ESP-01S                                 |
| `build:esp32`        | Compile for the ESP32                                   |
| `flash`              | Build + upload to `$BOARD`                               |
| `flash:esp01s`       | Build + upload to the ESP-01S                           |
| `flash:esp32`        | Build + upload to the ESP32                             |
| `monitor`            | Open the serial monitor for `$BOARD`                    |
| `monitor:esp01s`     | Serial monitor for the ESP-01S                          |
| `monitor:esp32`      | Serial monitor for the ESP32                            |
| `clean`              | Remove PlatformIO build artifacts                       |

### Selecting a board

```sh
# Use the default board (esp32)
mise run build

# Pick a board for a single invocation
BOARD=esp01s mise run build
BOARD=esp01s mise run flash
BOARD=esp01s mise run monitor

# Or use the pinned aliases
mise run build:esp01s
mise run flash:esp32
mise run monitor:esp01s
```

## Assets -> C headers

Drop any binary file into `assets/` (subdirectories are supported). Running
`mise run gen-headers` — or any build, via the PlatformIO pre-build hook
[`scripts/generate_headers.py`](scripts/generate_headers.py) — converts each
file into a header under `include/generated/`.

The converter is [`tools/bin2header.py`](tools/bin2header.py). An asset at
`assets/banner.bin` produces `include/generated/banner_bin.h`:

```c
#include "banner_bin.h"

Serial.write(banner_bin, banner_bin_len);
```

The identifier is derived from the asset's path relative to `assets/`
(`fonts/big.bin` -> `fonts_big_bin`). Generated headers are git-ignored and
rewritten only when their contents change.
