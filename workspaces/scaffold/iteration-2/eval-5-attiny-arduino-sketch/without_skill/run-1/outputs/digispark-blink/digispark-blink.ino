/*
 * digispark-blink — minimal Digispark (ATtiny85) USB device sketch.
 *
 * Blinks the on-board LED. On most Digispark clones the LED is on
 * pin 1 (some revisions use pin 0); change LED_PIN below if yours
 * does not blink.
 *
 * Board:    Digispark (Default - 16.5 MHz)  [digistump-avr:avr:digispark-tiny]
 * Upload:   via micronucleus bootloader over USB (no serial port).
 *           Run the upload task, then plug the board in within 60s.
 */

#define LED_PIN 1

void setup() {
  pinMode(LED_PIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_PIN, HIGH);
  delay(500);
  digitalWrite(LED_PIN, LOW);
  delay(500);
}
