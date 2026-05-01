/**
 * Data Solaire — ESP32 solar tracker firmware
 *
 * Merges LDR dual-axis tracking (SG90), INA219 (V/I/P), DHT22 + fan, optional I2C LCD,
 * optional HTTP /data JSON, and Firebase Realtime Database updates under `tracker/` via **HTTPS REST
 * PATCH** (no Firebase Auth — requires open RTDB rules on `tracker`)
 * matching the Flutter app schema (see lib/core/constants/rtdb_tracker_write_keys.dart).
 *
 * Copy secrets.h.example → secrets.h before building.
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <sys/time.h>

#include "secrets.h"

#ifndef RTDB_TLS_INSECURE
#define RTDB_TLS_INSECURE 1
#endif

#ifndef ENABLE_HTTP_DATA_ENDPOINT
#define ENABLE_HTTP_DATA_ENDPOINT 1
#endif

#if ENABLE_HTTP_DATA_ENDPOINT
#include <WebServer.h>
#endif

#include <Adafruit_INA219.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>

#if !defined(WIFI_SSID) || !defined(FIREBASE_DATABASE_URL)
#error "Create secrets.h from secrets.h.example"
#endif

// --- Pins (align with your wiring) ---
static const int kPinServoX = 18;
static const int kPinServoY = 19;
static const int kLdrH = 32;
static const int kLdrB = 33;
static const int kLdrG = 34;
static const int kLdrD = 35;
static const int kDhtPin = 27;
static const int kFanPin = 5;
static const int kSda = 21;
static const int kScl = 22;

static const uint8_t kLcdAddr = 0x27;
#define DHTTYPE DHT22

static const int kLdrTolerance = 40;
static const int kServoStep = 3;
static const float kFanOnTempC = 30.0f;
static const int kLdrOkMin = 50;
static const uint32_t kIntervalTrackingMs = 10;
static const uint32_t kIntervalSlowMs = 1000;
static const char kNtpServer[] = "pool.ntp.org";

Adafruit_INA219 ina219;
DHT dht(kDhtPin, DHTTYPE);
LiquidCrystal_I2C lcd(kLcdAddr, 16, 2);
Servo servoX;
Servo servoY;

#if ENABLE_HTTP_DATA_ENDPOINT
WebServer server(80);
#endif

bool gIna219Ready = false;
int gPosX = 90;
int gPosY = 90;

float gVoltage = 0;
float gCurrentA = 0;
float gPowerW = 0;
float gTemperature = NAN;
bool gVentilationOn = false;
bool gDhtOk = false;

String gCleanStatus = "OK";
String gSystemStatus = "NORMAL";

static uint32_t gLastTrackingMs = 0;
static uint32_t gLastSlowMs = 0;

static bool timeSynchronized() {
  struct tm ti;
  if (!getLocalTime(&ti)) {
    return false;
  }
  return ti.tm_year >= (2020 - 1900);
}

static int64_t epochMsNow() {
  struct timeval tv {};
  gettimeofday(&tv, nullptr);
  return (int64_t)tv.tv_sec * 1000LL + (int64_t)tv.tv_usec / 1000LL;
}

static void setupNtp() {
  configTime(0, 0, kNtpServer);
  Serial.print("Synchronisation NTP");
  for (int i = 0; i < 40 && !timeSynchronized(); i++) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  if (!timeSynchronized()) {
    Serial.println("Avertissement : temps non synchronisé — timestamps RTDB peuvent être incorrects.");
  } else {
    Serial.println("NTP OK");
  }
}

static void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("IP : ");
  Serial.println(WiFi.localIP());
}

/// Base RTDB URL + `/tracker.json` (aucune auth : exiger des règles ouvertes sur `tracker`).
static String trackerPatchUrl() {
  String base = FIREBASE_DATABASE_URL;
  base.trim();
  while (base.endsWith("/")) {
    base.remove(base.length() - 1);
  }
  return base + "/tracker.json?print=silent";
}

/** Fusionne les champs sous `tracker` via l’API REST PATCH (sans jeton). */
static bool rtdbPatchTrackerJson(const String& jsonBody) {
  WiFiClientSecure client;
#if RTDB_TLS_INSECURE
  client.setInsecure();
#endif
  HTTPClient http;
  const String url = trackerPatchUrl();
  if (!http.begin(client, url)) {
    Serial.println("RTDB : begin HTTP échoué");
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  const int code = http.PATCH(jsonBody);
  const bool ok = code >= 200 && code < 300;
  if (!ok) {
    Serial.printf("RTDB PATCH code=%d\n", code);
    Serial.println(http.getString());
  }
  http.end();
  return ok;
}

static void runTrackingOnce() {
  int vH = analogRead(kLdrH);
  int vB = analogRead(kLdrB);
  int vG = analogRead(kLdrG);
  int vD = analogRead(kLdrD);

  if (abs(vH - vB) > kLdrTolerance) {
    if (vH > vB && gPosY < 180) {
      gPosY += kServoStep;
    }
    if (vB > vH && gPosY > 0) {
      gPosY -= kServoStep;
    }
    servoY.write(gPosY);
  }
  if (abs(vG - vD) > kLdrTolerance) {
    if (vG > vD && gPosX > 0) {
      gPosX -= kServoStep;
    }
    if (vD > vG && gPosX < 180) {
      gPosX += kServoStep;
    }
    servoX.write(gPosX);
  }

  Serial.printf("LDR [H:%d B:%d G:%d D:%d] | AXES [X:%d Y:%d]\n", vH, vB, vG, vD, gPosX,
                gPosY);
}

static void readEnvironmentalAndPower() {
  if (gIna219Ready) {
    float busV = ina219.getBusVoltage_V();
    float ma = ina219.getCurrent_mA();
    float mw = ina219.getPower_mW();
    gVoltage = busV;
    gCurrentA = ma / 1000.0f;
    gPowerW = mw / 1000.0f;
  } else {
    gVoltage = 0;
    gCurrentA = 0;
    gPowerW = 0;
  }

  float t = dht.readTemperature();
  gDhtOk = !isnan(t);
  if (gDhtOk) {
    gTemperature = t;
  }

  if (gDhtOk && gTemperature > kFanOnTempC) {
    digitalWrite(kFanPin, HIGH);
    gVentilationOn = true;
  } else {
    digitalWrite(kFanPin, LOW);
    gVentilationOn = false;
  }
}

static void lcdDraw() {
  lcd.clear();
  if (!gIna219Ready) {
    lcd.setCursor(0, 0);
    lcd.print("INA219 Error");
    return;
  }
  lcd.setCursor(0, 0);
  lcd.print("V:");
  lcd.print(gVoltage, 2);
  lcd.print(" I:");
  lcd.print(gCurrentA * 1000.0f, 0);
  lcd.print("mA");

  lcd.setCursor(0, 1);
  if (gDhtOk) {
    lcd.print("T:");
    lcd.print(gTemperature, 1);
    lcd.print(" P:");
    lcd.print(gPowerW, 1);
    lcd.print("W");
  } else {
    lcd.print("DHT erreur");
  }
}

static void analyzeStatus() {
  const float kLowPowerWarnW = 0.05f * (float)CLEANING_POWER_W;
  if (gPowerW < kLowPowerWarnW) {
    gCleanStatus = "NEED_CLEAN";
  } else {
    gCleanStatus = "OK";
  }
  if (gVoltage < 0.5f && gIna219Ready) {
    gSystemStatus = "FAULT";
  } else {
    gSystemStatus = "NORMAL";
  }
}

static void pushTrackerToFirebase() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }
  if (!timeSynchronized()) {
    return;
  }

  int vH = analogRead(kLdrH);
  int vB = analogRead(kLdrB);
  int vG = analogRead(kLdrG);
  int vD = analogRead(kLdrD);

  const bool sunOpt =
      abs(vH - vB) <= kLdrTolerance && abs(vG - vD) <= kLdrTolerance;
  float irr =
      (float)(vH + vB + vG + vD) / (4.0f * 4095.0f);
  if (irr > 1.0f) {
    irr = 1.0f;
  }
  if (irr < 0.0f) {
    irr = 0.0f;
  }

  const bool ldrLeftOk = vG >= kLdrOkMin;
  const bool ldrRightOk = vD >= kLdrOkMin;
  const int64_t ts = epochMsNow();

  bool fault = !gIna219Ready || !gDhtOk;
  const char* code = "OK";
  String msg = "OK";
  if (!gIna219Ready) {
    code = "INA219";
    msg = "INA219 introuvable";
  } else if (!gDhtOk) {
    code = "DHT22";
    msg = "Lecture DHT22 echouee";
  }

  char tsBuf[22];
  snprintf(tsBuf, sizeof(tsBuf), "%lld", (long long)ts);

  String body = "{";
  body += "\"telemetry\":{";
  body += "\"voltage\":" + String(gVoltage, 4);
  body += ",\"current\":" + String(gCurrentA, 6);
  body += ",\"power\":" + String(gPowerW, 4);
  if (gDhtOk) {
    body += ",\"temperature\":" + String(gTemperature, 2);
  }
  body += ",\"last_updated_ms\":" + String(tsBuf);
  body += ",\"voltage_updated_ms\":" + String(tsBuf);
  body += ",\"current_updated_ms\":" + String(tsBuf);
  body += ",\"power_updated_ms\":" + String(tsBuf);
  if (gDhtOk) {
    body += ",\"temperature_updated_ms\":" + String(tsBuf);
  }
  body += "}";

  body += ",\"sun\":{";
  body += "\"is_optimal\":";
  body += sunOpt ? "true" : "false";
  body += ",\"irradiance_normalized\":" + String(irr, 4);
  body += "}";

  body += ",\"thresholds\":{";
  body += "\"cleaning_power_w\":" + String((double)CLEANING_POWER_W, 2);
  body += "}";

  body += ",\"aux\":{";
  body += "\"ventilation_on\":";
  body += gVentilationOn ? "true" : "false";
  body += ",\"ldr_left_ok\":";
  body += ldrLeftOk ? "true" : "false";
  body += ",\"ldr_right_ok\":";
  body += ldrRightOk ? "true" : "false";
  body += "}";

  body += ",\"orientation\":{";
  body += "\"pitch_deg\":" + String((double)gPosY, 2);
  body += ",\"yaw_deg\":" + String((double)gPosX, 2);
  body += ",\"roll_deg\":0";
  body += "}";

  body += ",\"faults\":{\"latest\":{";
  body += "\"hasError\":";
  body += fault ? "true" : "false";
  body += ",\"code\":\"";
  body += code;
  body += "\",\"message\":\"";
  body += msg;
  body += "\",\"timestamp_ms\":" + String(tsBuf);
  body += "}}";
  body += "}";

  if (rtdbPatchTrackerJson(body)) {
    Serial.println("RTDB OK");
  }
}

#if ENABLE_HTTP_DATA_ENDPOINT
static void handleHttpData() {
  analyzeStatus();
  String json = "{";
  json += "\"voltage\":" + String(gVoltage, 2) + ",";
  json += "\"current\":" + String(gCurrentA, 3) + ",";
  json += "\"power\":" + String(gPowerW, 2) + ",";
  json += "\"temperature\":" + String(gDhtOk ? gTemperature : 0.0, 1) + ",";
  json += "\"servoX\":" + String(gPosX) + ",";
  json += "\"servoY\":" + String(gPosY) + ",";
  json += "\"clean\":\"" + gCleanStatus + "\",";
  json += "\"system\":\"" + gSystemStatus + "\"";
  json += "}";
  server.send(200, "application/json", json);
}

static void http404() {
  server.send(404, "text/plain", "Not found");
}
#endif

void setup() {
  Serial.begin(115200);
  delay(200);

  pinMode(kFanPin, OUTPUT);
  digitalWrite(kFanPin, LOW);

  Wire.begin(kSda, kScl);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Data Solaire");
  lcd.setCursor(0, 1);
  lcd.print("Demarrage...");
  delay(800);

  dht.begin();

  if (!ina219.begin()) {
    Serial.println("INA219 : échec");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("INA219 Error");
    gIna219Ready = false;
  } else {
    ina219.setCalibration_16V_400mA();
    gIna219Ready = true;
  }

  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  servoX.setPeriodHertz(50);
  servoY.setPeriodHertz(50);
  servoX.attach(kPinServoX, 500, 2400);
  servoY.attach(kPinServoY, 500, 2400);
  servoX.write(gPosX);
  servoY.write(gPosY);

  connectWifi();
  setupNtp();

#if ENABLE_HTTP_DATA_ENDPOINT
  server.on("/data", HTTP_GET, handleHttpData);
  server.onNotFound(http404);
  server.begin();
  Serial.println("HTTP /data actif");
#endif
}

void loop() {
  const uint32_t now = millis();

  if (now - gLastTrackingMs >= kIntervalTrackingMs) {
    gLastTrackingMs = now;
    runTrackingOnce();
  }

#if ENABLE_HTTP_DATA_ENDPOINT
  server.handleClient();
#endif

  if (now - gLastSlowMs >= kIntervalSlowMs) {
    gLastSlowMs = now;
    readEnvironmentalAndPower();
    analyzeStatus();
    lcdDraw();
    pushTrackerToFirebase();
  }
}
