/**
 * Data Solaire — ESP32 solar tracker firmware (orchestrator).
 *
 * Hardware-only logic (LDR tracking, INA219, DHT22, fan, LCD) lives in hardware.cpp.
 * Wi-Fi + NTP + Firebase RTDB PATCH + local /data HTTP endpoint live in cloud.cpp.
 *
 * Copy secrets.h.example -> secrets.h and fill in your values before building.
 * 
 * DIAGNOSTICS: Send 'd' or 'D' via Serial to run hardware diagnostics.
 */

#include "hardware.h"
#include "cloud.h"

static uint32_t sLastPushMs = 0;
static constexpr uint32_t kPushIntervalMs = 1000;

void setup() {
  Serial.begin(115200);
  delay(200);
  
  // Show menu
  Serial.println("\n\n========== ESP32 SOLAR TRACKER FIRMWARE ==========");
  Serial.println("Available commands:");
  Serial.println("  'd' or 'D' - Run hardware diagnostics");
  Serial.println("  Any other key - Start normal operation");
  Serial.println("=================================================\n");
  Serial.println("Waiting for serial input (5 seconds)...");

  // Wait for serial input with 5 second timeout
  uint32_t startWait = millis();
  bool diagnosticsMode = false;
  
  while (millis() - startWait < 5000) {
    if (Serial.available()) {
      char cmd = Serial.read();
      if (cmd == 'd' || cmd == 'D') {
        diagnosticsMode = true;
        Serial.println("\nDiagnostics mode activated!");
      }
      break;
    }
    delay(10);
  }

  if (!diagnosticsMode) {
    Serial.println("Starting normal operation...\n");
  }

  hwSetup();
  
  if (diagnosticsMode) {
    hwRunDiagnostics();
    Serial.println("\nDiagnostics complete. Device will now enter normal operation.");
    Serial.println("Open the Serial Monitor to see continuous debug output.\n");
  }
  
  cloudSetup();
}

void loop() {
  // Check for serial commands during operation
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 'd' || cmd == 'D') {
      Serial.println("\nRunning diagnostics...");
      hwRunDiagnostics();
    }
  }

  hwLoop();
  cloudServeHttp();

  const uint32_t now = millis();
  if (now - sLastPushMs >= kPushIntervalMs) {
    sLastPushMs = now;
    cloudPushTracker();
  }

  delay(5);
}
