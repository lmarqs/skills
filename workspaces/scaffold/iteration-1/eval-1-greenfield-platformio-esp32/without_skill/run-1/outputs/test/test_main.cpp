#include <Arduino.h>
#include <unity.h>

// A trivial sanity test so `mise run test` has something to execute.
// Replace these with real tests as the firmware grows.

void test_sanity(void) {
  TEST_ASSERT_EQUAL(4, 2 + 2);
}

void setup() {
  // Wait a moment for the board/serial to settle before testing.
  delay(2000);

  UNITY_BEGIN();
  RUN_TEST(test_sanity);
  UNITY_END();
}

void loop() {
  // Tests run once in setup(); nothing to do here.
}
