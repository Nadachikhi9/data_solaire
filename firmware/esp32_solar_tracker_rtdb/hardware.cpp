#include "hardware.h"

#include <Wire.h>
#include <Adafruit_INA219.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include "DHT.h"
#include <WiFi.h>
#include "cloud.h"

#define DHTTYPE DHT22

static Adafruit_INA219 ina219;
static LiquidCrystal_I2C lcd(0x27, 16, 2);
static DHT dht(kDhtPin, DHTTYPE);
static Servo servoX;
static Servo servoY;

float gVoltageV = 0.0f;
float gCurrentA = 0.0f;
float gPowerW = 0.0f;
float gTemperatureC = NAN;
bool gIna219Ready = false;
bool gDhtOk = false;
bool gVentilationOn = false;

int gLdrHG = 0, gLdrHD = 0, gLdrBG = 0, gLdrBD = 0;
float gLdrTopNorm = 0.0f, gLdrBottomNorm = 0.0f, gLdrLeftNorm = 0.0f, gLdrRightNorm = 0.0f;
bool gLdrTopOk = false, gLdrBottomOk = false, gLdrLeftOk = false, gLdrRightOk = false;

bool gSunOptimal = false;
float gIrradianceNormalized = 0.0f;

static unsigned long sLastDisplayTime = 0;
static bool sToggleDisplay = true;

static inline float clamp01(float v) {
  if (v < 0.0f) return 0.0f;
  if (v > 1.0f) return 1.0f;
  return v;
}

void hwSetup() {
  #if DEBUG_HARDWARE
  delay(100);
  Serial.println("\n========== HARDWARE SETUP START ==========");
  Serial.println("[HW] Initializing pins and modules...");
  #endif

  // Setup fan pin
  pinMode(kFanPin, OUTPUT);
  digitalWrite(kFanPin, LOW);
  #if DEBUG_FAN
  Serial.println("[FAN] Pin " + String(kFanPin) + " configured as OUTPUT");
  #endif

  // Setup DHT
  #if DEBUG_DHT
  Serial.println("[DHT] Attempting to initialize DHT22 on pin " + String(kDhtPin) + "...");
  #endif
  dht.begin();
  delay(100);
  #if DEBUG_DHT
  float testTemp = dht.readTemperature();
  if (isnan(testTemp)) {
    Serial.println("[DHT] WARNING: First read returned NaN - sensor may not be ready");
  } else {
    Serial.println("[DHT] First read OK: " + String(testTemp, 1) + " C");
  }
  #endif

  // Setup LCD
  #if DEBUG_LCD
  Serial.println("[LCD] Attempting to initialize LCD at 0x27 (16x2)...");
  #endif
  lcd.init();
  lcd.backlight();
  lcd.print("System Booting...");
  #if DEBUG_LCD
  Serial.println("[LCD] LCD initialized successfully");
  #endif

  // Setup INA219
  #if DEBUG_INA219
  Serial.println("[INA219] Attempting to initialize INA219 on I2C (SDA=21, SCL=22)...");
  #endif
  if (!ina219.begin()) {
    Serial.println("[INA219] ERROR: INA219 not found! Check I2C address (0x40), wiring, and power.");
    gIna219Ready = false;
  } else {
    ina219.setCalibration_16V_400mA();
    gIna219Ready = true;
    #if DEBUG_INA219
    Serial.println("[INA219] Initialized successfully with 16V/400mA calibration");
    float v = ina219.getBusVoltage_V();
    float i = ina219.getCurrent_mA();
    float p = ina219.getPower_mW();
    Serial.println("[INA219] First read - V: " + String(v, 2) + "V, I: " + String(i, 1) + "mA, P: " + String(p, 1) + "mW");
    #endif
  }
  Wire.setTimeOut(100); // Set 100ms timeout to prevent I2C bus hangs due to noise

  // Setup Servos
  #if DEBUG_SERVO
  Serial.println("[SERVO] Allocating timers...");
  #endif
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  
  #if DEBUG_SERVO
  Serial.println("[SERVO] Attaching Servo X to pin " + String(kPinServoX) + "...");
  #endif
  servoX.attach(kPinServoX);
  
  #if DEBUG_SERVO
  Serial.println("[SERVO] Attaching Servo Y to pin " + String(kPinServoY) + "...");
  #endif
  servoY.attach(kPinServoY);
  
  // Center servos
  servoX.write(kServoStopVal);
  servoY.write(kServoStopVal);
  #if DEBUG_SERVO
  Serial.println("[SERVO] Both servos centered to " + String(kServoStopVal) + " degrees");
  #endif

  delay(2000);
  lcd.clear();

  #if DEBUG_HARDWARE
  Serial.println("========== HARDWARE SETUP COMPLETE ==========");
  Serial.println("[HW] Status Summary:");
  Serial.println("  - Fan:     READY (pin " + String(kFanPin) + ")");
  Serial.println("  - DHT22:   " + String(gDhtOk ? "OK" : "FAILED"));
  Serial.println("  - INA219:  " + String(gIna219Ready ? "OK" : "FAILED"));
  Serial.println("  - LCD:     INITIALIZED");
  Serial.println("  - Servos:  READY (X=" + String(kPinServoX) + ", Y=" + String(kPinServoY) + ")");
  Serial.println("  - LDRs:    Ready (HG=" + String(kPinLdrHG) + ", HD=" + String(kPinLdrHD) + 
                                        ", BG=" + String(kPinLdrBG) + ", BD=" + String(kPinLdrBD) + ")");
  Serial.println("===========================================\n");
  #endif
}

void hwLoop() {
  const uint32_t now = millis();
  static uint32_t sLastTrackingTimeMs = 0;
  static uint32_t sLastSensorTimeMs = 0;

  // 1. LDR solar tracking & servo alignment (every 100ms)
  if (now - sLastTrackingTimeMs >= 100) {
    sLastTrackingTimeMs = now;

    // Read all LDRs
    const int HG = analogRead(kPinLdrHG);
    const int HD = analogRead(kPinLdrHD);
    const int BG = analogRead(kPinLdrBG);
    const int BD = analogRead(kPinLdrBD);
    gLdrHG = HG; gLdrHD = HD; gLdrBG = BG; gLdrBD = BD;

    #if DEBUG_LDR
    static unsigned long lastLdrPrint = 0;
    if (now - lastLdrPrint > 5000) {
      Serial.println("[LDR] Raw readings - HG: " + String(HG) + ", HD: " + String(HD) + 
                     ", BG: " + String(BG) + ", BD: " + String(BD));
      lastLdrPrint = now;
    }
    #endif

    const int moyHaut = (HG + HD) >> 1;
    const int moyBas = (BG + BD) >> 1;
    const int moyGauche = (HG + BG) >> 1;
    const int moyDroite = (HD + BD) >> 1;

    const int diffY = moyHaut - moyBas;
    int servoYTarget = kServoStopVal;
    if (abs(diffY) > kLdrTolerance) {
      servoYTarget = diffY > 0 ? (kServoStopVal + kServoSpeed) : (kServoStopVal - kServoSpeed);
    }
    servoY.write(servoYTarget);

    const int diffX = moyGauche - moyDroite;
    int servoXTarget = kServoStopVal;
    if (abs(diffX) > kLdrTolerance) {
      servoXTarget = diffX > 0 ? (kServoStopVal - kServoSpeed) : (kServoStopVal + kServoSpeed);
    }
    servoX.write(servoXTarget);

    #if DEBUG_SERVO
    static unsigned long lastServoPrint = 0;
    if (now - lastServoPrint > 5000) {
      Serial.println("[SERVO] Targets - X: " + String(servoXTarget) + "°, Y: " + String(servoYTarget) + 
                     "° | Differences - X: " + String(diffX) + ", Y: " + String(diffY));
      lastServoPrint = now;
    }
    #endif

    gSunOptimal = (abs(diffY) <= kLdrTolerance) && (abs(diffX) <= kLdrTolerance);
    gIrradianceNormalized = clamp01((float)(HG + HD + BG + BD) / (4.0f * 4095.0f));
    gLdrTopNorm = clamp01((float)moyHaut / 4095.0f);
    gLdrBottomNorm = clamp01((float)moyBas / 4095.0f);
    gLdrLeftNorm = clamp01((float)moyGauche / 4095.0f);
    gLdrRightNorm = clamp01((float)moyDroite / 4095.0f);
    // LDR channels are considered valid when data is present; do not treat low light as a sensor fault.
    gLdrTopOk = true;
    gLdrBottomOk = true;
    gLdrLeftOk = true;
    gLdrRightOk = true;
  }

  // 2. Read DHT22, Control Fan, and Read INA219 (every 2000ms)
  if (now - sLastSensorTimeMs >= 2000) {
    sLastSensorTimeMs = now;

    // Read DHT22
    const float t = dht.readTemperature();
    gDhtOk = !isnan(t);
    if (gDhtOk) {
      gTemperatureC = t;
      #if DEBUG_DHT
      static unsigned long lastDhtPrint = 0;
      if (now - lastDhtPrint > 5000) {
        Serial.println("[DHT] Temperature: " + String(t, 1) + " C");
        lastDhtPrint = now;
      }
      #endif
    } else {
      #if DEBUG_DHT
      static unsigned long lastDhtErrorPrint = 0;
      if (now - lastDhtErrorPrint > 10000) {
        Serial.println("[DHT] ERROR: Failed to read temperature (NaN)");
        lastDhtErrorPrint = now;
      }
      #endif
    }

    // Control Fan
    const bool fanOn = gDhtOk && t >= kFanOnTempC;
    digitalWrite(kFanPin, fanOn ? HIGH : LOW);
    gVentilationOn = fanOn;
    
    #if DEBUG_FAN
    static unsigned long lastFanPrint = 0;
    if (now - lastFanPrint > 5000) {
      Serial.println("[FAN] State: " + String(gVentilationOn ? "ON" : "OFF") + 
                     " | Temp threshold: " + String(kFanOnTempC) + "C | Temp: " + 
                     String(gDhtOk ? String(t, 1) : "ERROR") + "C");
      lastFanPrint = now;
    }
    #endif

    // Read INA219
    if (gIna219Ready) {
      gVoltageV = ina219.getBusVoltage_V();
      gCurrentA = ina219.getCurrent_mA() / 1000.0f;
      gPowerW = ina219.getPower_mW() / 1000.0f;
      
      #if DEBUG_INA219
      static unsigned long lastInaPrint = 0;
      if (now - lastInaPrint > 5000) {
        Serial.println("[INA219] V: " + String(gVoltageV, 2) + "V, I: " + String(gCurrentA * 1000, 1) + 
                       "mA, P: " + String(gPowerW * 1000, 1) + "mW");
        lastInaPrint = now;
      }
      #endif
    } else {
      gVoltageV = 0.0f;
      gCurrentA = 0.0f;
      gPowerW = 0.0f;
      #if DEBUG_INA219
      static unsigned long lastInaErrorPrint = 0;
      if (now - lastInaErrorPrint > 10000) {
        Serial.println("[INA219] ERROR: Module not ready, skipping read");
        lastInaErrorPrint = now;
      }
      #endif
    }
  }

  // 3. Update LCD Display (every 3000ms)
  if (now - sLastDisplayTime > 3000) {
    lcd.clear();
    
    String errorMsg = "";
    if (WiFi.status() != WL_CONNECTED) {
      errorMsg = "WIFI DISCON.";
    } else if (!gFirebaseOk) {
      errorMsg = "FIREBASE ERR";
    } else if (!gIna219Ready) {
      errorMsg = "INA219 FAULT";
    } else if (!gDhtOk) {
      errorMsg = "DHT22 FAULT";
    }

    if (errorMsg.length() > 0 && sToggleDisplay) {
      lcd.setCursor(0, 0);
      lcd.print("SYSTEM ERROR:");
      lcd.setCursor(0, 1);
      lcd.print(errorMsg);
      
      #if DEBUG_LCD
      Serial.println("[LCD] Display Error - " + errorMsg);
      #endif
    } else if (sToggleDisplay || (errorMsg.length() == 0 && sToggleDisplay)) {
      const float V = gVoltageV;
      const float I_mA = gCurrentA * 1000.0f;
      const float P_mW = gPowerW * 1000.0f;
      lcd.setCursor(0, 0);
      lcd.print("V:"); lcd.print(V, 1); lcd.print("V I:"); lcd.print(I_mA, 0); lcd.print("mA");
      lcd.setCursor(0, 1);
      lcd.print("P: "); lcd.print(P_mW, 1); lcd.print(" mW");
      
      #if DEBUG_LCD
      Serial.println("[LCD] Display 1 - V: " + String(V, 1) + "V, I: " + String(I_mA, 0) + 
                     "mA, P: " + String(P_mW, 1) + "mW");
      #endif
    } else {
      lcd.setCursor(0, 0);
      lcd.print("Temp: ");
      if (gDhtOk) { lcd.print(gTemperatureC, 1); } else { lcd.print("---"); }
      lcd.print(" C");
      lcd.setCursor(0, 1);
      lcd.print("FAN: "); lcd.print(gVentilationOn ? "ON (COOLING)" : "OFF");
      
      #if DEBUG_LCD
      Serial.println("[LCD] Display 2 - Temp: " + String(gDhtOk ? String(gTemperatureC, 1) : "ERROR") + 
                     "C, Fan: " + String(gVentilationOn ? "ON" : "OFF"));
      #endif
    }
    sToggleDisplay = !sToggleDisplay;
    sLastDisplayTime = now;
  }
}

// Diagnostic function to test all hardware components
void hwRunDiagnostics() {
  Serial.println("\n\n========== HARDWARE DIAGNOSTICS START ==========");
  Serial.println("[DIAG] Running comprehensive hardware test...\n");

  // Test 1: LDR Readings
  Serial.println("--- TEST 1: LDR Sensors ---");
  Serial.println("Reading LDR values 10 times with 200ms intervals:");
  for (int i = 0; i < 10; i++) {
    int hg = analogRead(kPinLdrHG);
    int hd = analogRead(kPinLdrHD);
    int bg = analogRead(kPinLdrBG);
    int bd = analogRead(kPinLdrBD);
    Serial.println("[" + String(i) + "] HG: " + String(hg, 4) + ", HD: " + String(hd, 4) + 
                   ", BG: " + String(bg, 4) + ", BD: " + String(bd, 4));
    
    if (hg == 0 && hd == 0 && bg == 0 && bd == 0) {
      Serial.println("WARNING: All LDRs reading 0! Check pin configuration and ADC.");
    }
    if (hg == 4095 && hd == 4095 && bg == 4095 && bd == 4095) {
      Serial.println("WARNING: All LDRs maxed out at 4095! Check sensor wiring.");
    }
    delay(200);
  }
  Serial.println("LDR Test Complete\n");

  // Test 2: DHT22 Temperature Sensor
  Serial.println("--- TEST 2: DHT22 Temperature Sensor ---");
  Serial.println("Reading temperature 5 times with 2s intervals:");
  for (int i = 0; i < 5; i++) {
    float temp = dht.readTemperature();
    float hum = dht.readHumidity();
    if (isnan(temp) || isnan(hum)) {
      Serial.println("[" + String(i) + "] ERROR: NaN read (sensor may not be responding)");
    } else {
      Serial.println("[" + String(i) + "] Temp: " + String(temp, 2) + "C, Humidity: " + String(hum, 1) + "%");
    }
    delay(2000);
  }
  Serial.println("DHT22 Test Complete\n");

  // Test 3: INA219 Power Monitor
  Serial.println("--- TEST 3: INA219 Power Monitor ---");
  if (!gIna219Ready) {
    Serial.println("ERROR: INA219 not initialized! Check I2C wiring (SDA=21, SCL=22) and address (0x40)");
  } else {
    Serial.println("Reading INA219 values 5 times with 1s intervals:");
    for (int i = 0; i < 5; i++) {
      float v = ina219.getBusVoltage_V();
      float i_ma = ina219.getCurrent_mA();
      float p_mw = ina219.getPower_mW();
      Serial.println("[" + String(i) + "] V: " + String(v, 3) + "V, I: " + String(i_ma, 2) + 
                     "mA, P: " + String(p_mw, 1) + "mW");
      if (v < 0.1f) {
        Serial.println("WARNING: Very low voltage detected - check power supply");
      }
      delay(1000);
    }
  }
  Serial.println("INA219 Test Complete\n");

  // Test 4: Servo Motors
  Serial.println("--- TEST 4: Servo Motors (X & Y) ---");
  Serial.println("Testing servo X movements (pin " + String(kPinServoX) + "):");
  for (int angle = 30; angle <= 150; angle += 30) {
    servoX.write(angle);
    Serial.println("  Servo X -> " + String(angle) + " degrees");
    delay(500);
  }
  servoX.write(kServoStopVal);
  Serial.println("Servo X returned to center: " + String(kServoStopVal) + " degrees\n");

  Serial.println("Testing servo Y movements (pin " + String(kPinServoY) + "):");
  for (int angle = 30; angle <= 150; angle += 30) {
    servoY.write(angle);
    Serial.println("  Servo Y -> " + String(angle) + " degrees");
    delay(500);
  }
  servoY.write(kServoStopVal);
  Serial.println("Servo Y returned to center: " + String(kServoStopVal) + " degrees\n");
  Serial.println("Servo Test Complete\n");

  // Test 5: Fan Control
  Serial.println("--- TEST 5: Fan Control (pin " + String(kFanPin) + ") ---");
  Serial.println("Turning fan ON for 2 seconds...");
  digitalWrite(kFanPin, HIGH);
  delay(2000);
  digitalWrite(kFanPin, LOW);
  Serial.println("Fan turned OFF. If you heard it spin, the fan is OK.\n");

  // Test 6: LCD Display
  Serial.println("--- TEST 6: LCD Display (0x27, 16x2) ---");
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("DIAG: LCD OK");
  lcd.setCursor(0, 1);
  lcd.print("Line 2 works!");
  Serial.println("LCD displaying diagnostic message (if you see 'DIAG: LCD OK', display works)");
  delay(3000);
  lcd.clear();
  Serial.println("LCD Test Complete\n");

  // Summary
  Serial.println("========== DIAGNOSTICS SUMMARY ==========");
  Serial.println("Check the serial output above for errors and warnings.");
  Serial.println("Key things to verify:");
  Serial.println("  1. LDR values should change when you cover/uncover sensors");
  Serial.println("  2. DHT22 should read reasonable temp/humidity (not NaN)");
  Serial.println("  3. INA219 voltage should match your power supply");
  Serial.println("  4. Servos should move smoothly through all positions");
  Serial.println("  5. Fan should spin when turned ON");
  Serial.println("  6. LCD should display text clearly");
  Serial.println("=========================================\n");
}

void hwShowStatus(const char* line1, const char* line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);
}

