// Minimal Digispark (ATtiny85) USB device sketch — blinks the onboard LED.
// arduino-cli requires the main .ino to share the sketch directory's name.
//
// Build / upload via mise:
//   mise run arduino:setup     # install the core + libraries (once)
//   mise run arduino:compile   # compile only
//   mise run arduino:upload    # flash (plug the Digispark in when prompted)
//   mise run arduino:run       # compile, then upload

// Onboard LED is on P1 on most Digispark boards (P0 on some clones).
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
