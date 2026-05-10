#include "cloud.h"

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <sys/time.h>

#include "secrets.h"
#include "hardware.h"

#ifndef RTDB_TLS_INSECURE
#define RTDB_TLS_INSECURE 1
#endif

#ifndef ENABLE_HTTP_DATA_ENDPOINT
#define ENABLE_HTTP_DATA_ENDPOINT 1
#endif

#if ENABLE_HTTP_DATA_ENDPOINT
#include <WebServer.h>
static WebServer server(80);
#endif

#if !defined(WIFI_SSID) || !defined(FIREBASE_DATABASE_URL)
#error "Create secrets.h from secrets.h.example"
#endif

static const char kNtpServer[] = "pool.ntp.org";

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

static void setupNtp() {
  configTime(0, 0, kNtpServer);
  Serial.print("Synchronisation NTP");
  for (int i = 0; i < 40 && !timeSynchronized(); i++) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  if (!timeSynchronized()) {
    Serial.println("Avertissement : temps non synchronise.");
  } else {
    Serial.println("NTP OK");
  }
}

static String trackerPatchUrl() {
  String base = FIREBASE_DATABASE_URL;
  base.trim();
  while (base.endsWith("/")) {
    base.remove(base.length() - 1);
  }
  return base + "/tracker.json?print=silent";
}

static bool rtdbPatchTrackerJson(const String& body) {
  WiFiClientSecure client;
#if RTDB_TLS_INSECURE
  client.setInsecure();
#endif
  HTTPClient http;
  const String url = trackerPatchUrl();
  if (!http.begin(client, url)) {
    Serial.println("RTDB : begin HTTP echoue");
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  const int code = http.PATCH(body);
  const bool ok = code >= 200 && code < 300;
  if (!ok) {
    Serial.printf("RTDB PATCH code=%d\n", code);
    Serial.println(http.getString());
  }
  http.end();
  return ok;
}

#if ENABLE_HTTP_DATA_ENDPOINT
static void handleHttpData() {
  String json = "{";
  json += "\"voltage\":" + String(gVoltageV, 2) + ",";
  json += "\"current\":" + String(gCurrentA, 3) + ",";
  json += "\"power\":" + String(gPowerW, 2) + ",";
  json += "\"temperature\":" + String(gDhtOk ? gTemperatureC : 0.0f, 1) + ",";
  json += "\"fan\":";
  json += gVentilationOn ? "true" : "false";
  json += ",\"sun_optimal\":";
  json += gSunOptimal ? "true" : "false";
  json += ",\"irradiance\":" + String(gIrradianceNormalized, 3);
  json += "}";
  server.send(200, "application/json", json);
}

static void http404() {
  server.send(404, "text/plain", "Not found");
}
#endif

void cloudSetup() {
  connectWifi();
  setupNtp();
#if ENABLE_HTTP_DATA_ENDPOINT
  server.on("/data", HTTP_GET, handleHttpData);
  server.onNotFound(http404);
  server.begin();
  Serial.println("HTTP /data actif");
#endif
}

void cloudServeHttp() {
#if ENABLE_HTTP_DATA_ENDPOINT
  server.handleClient();
#endif
}

void cloudPushTracker() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }
  if (!timeSynchronized()) {
    return;
  }

  const int64_t ts = epochMsNow();
  char tsBuf[22];
  snprintf(tsBuf, sizeof(tsBuf), "%lld", (long long)ts);

  const bool fault = !gIna219Ready || !gDhtOk;
  const char* code = "OK";
  String msg = "OK";
  if (!gIna219Ready) {
    code = "INA219";
    msg = "INA219 introuvable";
  } else if (!gDhtOk) {
    code = "DHT22";
    msg = "Lecture DHT22 echouee";
  }

  String body = "{";
  body += "\"telemetry\":{";
  body += "\"voltage\":" + String(gVoltageV, 4);
  body += ",\"current\":" + String(gCurrentA, 6);
  body += ",\"power\":" + String(gPowerW, 4);
  if (gDhtOk) {
    body += ",\"temperature\":" + String(gTemperatureC, 2);
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
  body += gSunOptimal ? "true" : "false";
  body += ",\"irradiance_normalized\":" + String(gIrradianceNormalized, 4);
  body += ",\"ldr_quadrants\":{";
  body += "\"top\":" + String(gLdrTopNorm, 4);
  body += ",\"bottom\":" + String(gLdrBottomNorm, 4);
  body += ",\"left\":" + String(gLdrLeftNorm, 4);
  body += ",\"right\":" + String(gLdrRightNorm, 4);
  body += "}";
  body += "}";

  body += ",\"thresholds\":{";
  body += "\"cleaning_power_w\":" + String((double)CLEANING_POWER_W, 2);
  body += "}";

  body += ",\"aux\":{";
  body += "\"ventilation_on\":";
  body += gVentilationOn ? "true" : "false";
  body += ",\"ldr_left_ok\":";
  body += gLdrLeftOk ? "true" : "false";
  body += ",\"ldr_right_ok\":";
  body += gLdrRightOk ? "true" : "false";
  body += ",\"ldr_top_ok\":";
  body += gLdrTopOk ? "true" : "false";
  body += ",\"ldr_bottom_ok\":";
  body += gLdrBottomOk ? "true" : "false";
  body += "}";

  // Continuous-rotation servos: no absolute angle is available.
  body += ",\"orientation\":{";
  body += "\"pitch_deg\":0";
  body += ",\"yaw_deg\":0";
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
