#include <Arduino.h>

// Onboard LED on most ESP32 dev boards is GPIO 2.
#ifndef LED_BUILTIN
#define LED_BUILTIN 2
#endif

void setup() {
  Serial.begin(SERIAL_BAUD);
  // Give the serial monitor a moment to attach.
  delay(100);
  Serial.println();
  Serial.println("ESP32 firmware booting...");

  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  Serial.println("LED ON");
  delay(1000);

  digitalWrite(LED_BUILTIN, LOW);
  Serial.println("LED OFF");
  delay(1000);
}
