---
name: arduino-run
description: >-
  Compile the Digispark sketch and flash it to the board in one step (compile then
  upload) via arduino-cli/mise. Use when the user wants to build and run/flash the
  firmware. Flashes physical hardware — confirm the right board is connected first, and
  note the Digispark must be plugged in when prompted (portless micronucleus bootloader).
argument-hint: "[--port <port>]"
---

# Arduino: compile and upload (run)

Run `mise run arduino:run` to compile the sketch and then flash it to the board. This
chains `arduino:compile` → `arduino:upload`.

## Usage
```bash
mise run arduino:run                 # stock Digispark: plug it in when prompted
mise run arduino:upload --port /dev/ttyACM0   # only for non-micronucleus boards
```

## Instructions
1. Parse `$ARGUMENTS`. The only optional arg is `--port`, which is forwarded to
   `arduino:upload` and is normally unset for a micronucleus Digispark.
2. This flashes physical hardware. Confirm the intended board is the one connected
   (`$ARDUINO_FQBN` in `.env.yaml`) before flashing.
3. Run `mise run arduino:run` (or `mise run arduino:upload [--port …]` if only the
   upload step is wanted). For a stock Digispark, tell the user to connect/replug the
   board when `arduino-cli` prints "Please plug in the device".
4. Report the compile result and the upload result.
