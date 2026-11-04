# ESP32 Firmware

A PlatformIO firmware project for the ESP32, with [mise](https://mise.jdx.dev)
tasks wrapping the common PlatformIO commands so you don't have to remember the
raw `pio` invocations.

## Prerequisites

- [mise](https://mise.jdx.dev) installed and activated in your shell.

That's it. The toolchain (Python + PlatformIO Core) is declared in `.mise.toml`
and installed automatically. From the project root run:

```sh
mise install
```

This installs the pinned Python and PlatformIO Core. The ESP32 platform and
toolchain are downloaded by PlatformIO on the first `build`.

## Tasks

Run `mise tasks` to see the full list, or `mise run <task>`:

| Task               | What it does                                        |
| ------------------ | --------------------------------------------------- |
| `mise run build`   | Compile the firmware                                |
| `mise run upload`  | Build and flash to the connected ESP32              |
| `mise run flash`   | Alias for `upload`                                  |
| `mise run monitor` | Open the serial monitor (115200 baud)               |
| `mise run watch`   | Flash, then immediately attach the serial monitor   |
| `mise run clean`   | Remove build artifacts                              |
| `mise run fullclean` | Remove build artifacts and the `.pio` directory   |
| `mise run devices` | List connected serial devices / ports              |
| `mise run test`    | Run unit tests                                       |
| `mise run update`  | Update PlatformIO platforms and libraries           |

## Typical workflow

```sh
mise run build      # compile
mise run watch      # flash + serial monitor in one go
```

## Configuration

- **Board / build settings:** `platformio.ini` (target env is `esp32dev`).
- **Serial baud rate:** `monitor_speed` in `platformio.ini` (default `115200`).
- **Serial port:** auto-detected. To pin it, set `upload_port` in
  `platformio.ini`, or export `UPLOAD_PORT=/dev/ttyUSB0` before running a task.
- **Default PlatformIO env for tasks:** the `PIO_ENV` variable in `.mise.toml`.

## Layout

```
.
├── .mise.toml        # mise tasks + toolchain pins
├── platformio.ini    # PlatformIO project config
├── src/
│   └── main.cpp      # firmware entry point (blink + serial heartbeat)
├── include/          # project header files
├── lib/              # private libraries
└── test/             # unit tests
```
