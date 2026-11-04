#include <Arduino.h>

// Generated from files in assets/ via `mise run assets:headers`.
// Uncomment once you have placed a binary in assets/ and regenerated:
// #include "assets.h"

#ifndef LED_BUILTIN
#define LED_BUILTIN 2
#endif

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(500);
  digitalWrite(LED_BUILTIN, LOW);
  delay(500);
  Serial.println("blink");
}
