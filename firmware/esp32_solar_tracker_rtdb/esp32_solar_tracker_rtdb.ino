/**
 * Data Solaire — ESP32 solar tracker firmware (orchestrator).
 *
 * Hardware-only logic (LDR tracking, INA219, DHT22, fan, LCD) lives in hardware.cpp.
 * Wi-Fi + NTP + Firebase RTDB PATCH + local /data HTTP endpoint live in cloud.cpp.
 *
 * Copy secrets.h.example -> secrets.h and fill in your values before building.
 */

#include "hardware.h"
#include "cloud.h"

static uint32_t sLastPushMs = 0;
static constexpr uint32_t kPushIntervalMs = 1000;

void setup() {
  Serial.begin(115200);
  delay(200);

  hwSetup();
  cloudSetup();
}

void loop() {
  hwLoop();
  cloudServeHttp();

  const uint32_t now = millis();
  if (now - sLastPushMs >= kPushIntervalMs) {
    sLastPushMs = now;
    cloudPushTracker();
  }

  delay(5);
}
