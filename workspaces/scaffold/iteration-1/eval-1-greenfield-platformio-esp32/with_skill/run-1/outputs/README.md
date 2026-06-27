# ESP32 Firmware

A PlatformIO firmware project for the ESP32, with task running handled by [mise](https://mise.jdx.dev).

## Getting started

1. Install [mise](https://mise.jdx.dev) and let it provision the pinned PlatformIO toolchain (`mise install`).
2. Copy the env template: `cp .env.example .env.yaml`, then set `PIO_UPLOAD_PORT` if you want a fixed
   serial port (leave it empty to let PlatformIO auto-detect the board).
3. Install project dependencies: `mise run pio:setup`.

## Tasks

All repeatable workflows run through mise. Run `mise tasks` to list them.

| Task | Command | What it does |
|------|---------|--------------|
| setup   | `mise run pio:setup`        | Install PlatformIO platform & library dependencies |
| build   | `mise run pio:build [env]`  | Build firmware (optional `platformio.ini` env/board) |
| upload  | `mise run pio:upload [env]` | Build and flash firmware to the board |
| monitor | `mise run pio:monitor`      | Open the serial monitor |

The serial port comes from `PIO_UPLOAD_PORT` in `.env.yaml`. Board configuration lives in
`platformio.ini` — edit `board` / `default_envs` there to target different hardware.
