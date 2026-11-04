---
name: pio-upload
description: >-
  Build and flash firmware to a connected board (esp01s or esp32) via mise. Use when the user wants to
  upload/flash firmware to a device. Flashing mutates physical hardware over a serial port, so confirm the
  target board and port before running.
argument-hint: "[esp01s|esp32] [--port <port>]"
---

# Flash firmware to a board

Run `mise run pio:upload <env> [--port <port>]` to build and flash firmware.

## Usage

```bash
mise run pio:upload esp32 --port /dev/ttyUSB0
mise run pio:upload esp01s            # uses $PIO_PORT from .env.yaml
```

## Instructions

1. Parse `$ARGUMENTS` for the board env (`esp01s` or `esp32`) and an optional `--port`.
   - If the board is omitted, the task falls back to `$PIO_DEFAULT_ENV`; if the port is omitted it falls
     back to `$PIO_PORT`. Confirm which board and port will be used before flashing.
2. Because flashing mutates physical hardware, confirm the target board and serial port with the user when
   either is ambiguous (e.g. multiple devices plugged in).
3. Run `mise run pio:upload <env> [--port <port>]`.
4. Report success/failure. On a port/permission error, suggest checking the cable, the port, and that no
   serial monitor is holding the port open.
