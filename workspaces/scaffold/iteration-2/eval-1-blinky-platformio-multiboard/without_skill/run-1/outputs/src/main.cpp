// Blinky firmware shared by the ESP-01S (ESP8266) and ESP32 builds.
//
// Board-specific details (LED pin and polarity) come from build flags defined
// per environment in platformio.ini:
//
//   LED_BUILTIN     GPIO of the onboard LED
//   LED_ACTIVE_LOW  1 if the LED turns on when the pin is driven LOW
//
// It also demonstrates including a generated asset header produced from the
// files in assets/ by tools/bin2header.py (run via `mise run gen-headers` or
// automatically before each PlatformIO build).

#include <Arduino.h>

// Generated from assets/banner.bin. Regenerated automatically by the
// pre-build hook (scripts/generate_headers.py).
#include "banner_bin.h"

#ifndef LED_BUILTIN
#define LED_BUILTIN 2
#endif

#ifndef LED_ACTIVE_LOW
#define LED_ACTIVE_LOW 0
#endif

static const uint32_t BLINK_INTERVAL_MS = 500;

static void ledWrite(bool on) {
#if LED_ACTIVE_LOW
  digitalWrite(LED_BUILTIN, on ? LOW : HIGH);
#else
  digitalWrite(LED_BUILTIN, on ? HIGH : LOW);
#endif
}

void setup() {
  Serial.begin(115200);
  delay(50);

  pinMode(LED_BUILTIN, OUTPUT);
  ledWrite(false);

#if defined(BOARD_ESP01S)
  Serial.println(F("Booting on ESP-01S (ESP8266)"));
#elif defined(BOARD_ESP32)
  Serial.println(F("Booting on ESP32"));
#else
  Serial.println(F("Booting on unknown board"));
#endif

  // Show that the embedded asset is available at runtime.
  Serial.print(F("Embedded banner asset: "));
  Serial.print((unsigned)banner_bin_len);
  Serial.println(F(" bytes"));
}

void loop() {
  static bool on = false;
  on = !on;
  ledWrite(on);
  Serial.println(on ? F("LED on") : F("LED off"));
  delay(BLINK_INTERVAL_MS);
}
