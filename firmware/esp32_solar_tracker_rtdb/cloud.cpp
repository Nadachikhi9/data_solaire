#include "cloud.h"

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <sys/time.h>
#include <math.h>

#include "secrets.h"
#include "hardware.h"

#ifndef RTDB_TLS_INSECURE
#define RTDB_TLS_INSECURE 1
#endif

#ifndef ENABLE_HTTP_DATA_ENDPOINT
#define ENABLE_HTTP_DATA_ENDPOINT 1
#endif

#ifndef DEBUG_CLOUD
#define DEBUG_CLOUD 1
#endif

#if ENABLE_HTTP_DATA_ENDPOINT
#include <WebServer.h>
static WebServer server(80);
#endif

#if !defined(WIFI_SSID) || !defined(FIREBASE_DATABASE_URL)
#error "Create secrets.h from secrets.h.example"
#endif

static const char kNtpServer[] = "pool.ntp.org";
static int64_t sLastSuccessfulPushMs = 0;

static bool timeSynchronized() {
  struct tm ti;
  if (!getLocalTime(&ti)) {
    return false;
  }
  return ti.tm_year >= (2020 - 1900);
}

static String safeJsonNumber(double value, uint8_t precision) {
  if (isnan(value) || isinf(value)) {
    return "0";
  }
  char buf[32];
  dtostrf(value, 0, precision, buf);
  return String(buf);
}

static String jsonEscape(const String& input) {
  String escaped;
  escaped.reserve(input.length() * 2);
  for (size_t i = 0; i < input.length(); i++) {
    const char c = input[i];
    switch (c) {
      case '"': escaped += "\\\""; break;
      case '\\': escaped += "\\\\"; break;
      case '\b': escaped += "\\b"; break;
      case '\f': escaped += "\\f"; break;
      case '\n': escaped += "\\n"; break;
      case '\r': escaped += "\\r"; break;
      case '\t': escaped += "\\t"; break;
      default:
        if ((uint8_t)c < 0x20) {
          char buf[7];
          snprintf(buf, sizeof(buf), "\\u%04x", c);
          escaped += buf;
        } else {
          escaped += c;
        }
    }
  }
  return escaped;
}

static int64_t epochMsNow() {
  struct timeval tv {};
  gettimeofday(&tv, nullptr);
  return (int64_t)tv.tv_sec * 1000LL + (int64_t)tv.tv_usec / 1000LL;
}

static void connectWifi() {
  #if DEBUG_CLOUD
  Serial.println("\n[CLOUD] === WiFi Connection ===");
  #endif
  
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  if (WiFi.status() == WL_CONNECTED) {
    #if DEBUG_CLOUD
    Serial.print("[CLOUD] WiFi already connected. IP: ");
    Serial.println(WiFi.localIP());
    #endif
    return;
  }

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  #if DEBUG_CLOUD
  Serial.print("[CLOUD] Connecting to SSID: ");
  Serial.println(WIFI_SSID);
  Serial.print("[CLOUD] WiFi");
  #endif
  
  int attemptCount = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    attemptCount++;
    if (attemptCount > 40) {
      #if DEBUG_CLOUD
      Serial.println("\n[CLOUD] WiFi connection timeout!");
      #endif
      break;
    }
  }
  
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    #if DEBUG_CLOUD
    Serial.print("[CLOUD] WiFi connected! IP: ");
    Serial.println(WiFi.localIP());
    #endif
  } else {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] WARNING: WiFi connection failed!");
    #endif
  }
}

static int sendPatchRequest(HTTPClient& http, const String& body) {
  int code = http.PATCH(body);
  #if DEBUG_CLOUD
  if (code <= 0) {
    Serial.println("[CLOUD] WARNING: PATCH request failed, retrying with sendRequest(PATCH)");
  }
  #endif
  if (code <= 0) {
    code = http.sendRequest("PATCH", body);
  }
  if (code <= 0 || code == 405 || code == 501) {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] WARNING: PATCH unsupported or failed, retrying with PUT");
    #endif
    code = http.sendRequest("PUT", body);
  }
  return code;
}

static void setupNtp() {
  #if DEBUG_CLOUD
  Serial.println("[CLOUD] === NTP Time Synchronization ===");
  #endif
  
  configTime(0, 0, kNtpServer);
  
  #if DEBUG_CLOUD
  Serial.print("[CLOUD] Synchronizing with " );
  Serial.print(kNtpServer);
  Serial.print(": ");
  #endif
  
  for (int i = 0; i < 40 && !timeSynchronized(); i++) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  
  if (!timeSynchronized()) {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] WARNING: Time NOT synchronized! Firebase auth may fail.");
    #endif
  } else {
    #if DEBUG_CLOUD
    time_t now = time(nullptr);
    Serial.print("[CLOUD] NTP OK - Epoch: ");
    Serial.println(now);
    #endif
  }
}

static String trackerPatchUrl() {
  String base = FIREBASE_DATABASE_URL;
  base.trim();
  while (base.endsWith("/")) {
    base.remove(base.length() - 1);
  }
  
  // Add database secret for authentication
  String url = base + "/tracker.json?print=silent";
  
  #if defined(FIREBASE_DATABASE_SECRET)
  if (strlen(FIREBASE_DATABASE_SECRET) > 0 && strcmp(FIREBASE_DATABASE_SECRET, "YOUR_DATABASE_SECRET") != 0) {
    url += "&auth=";
    url += FIREBASE_DATABASE_SECRET;
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] [URL] Auth parameter added to URL");
    #endif
  } else {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] WARNING: FIREBASE_DATABASE_SECRET not set or placeholder - request may fail if rules require auth");
    #endif
  }
  #else
  #if DEBUG_CLOUD
  Serial.println("[CLOUD] WARNING: FIREBASE_DATABASE_SECRET not defined - request may fail if rules require auth");
  #endif
  #endif
  
  return url;
}

static bool rtdbPatchTrackerJson(const String& body) {
  #if DEBUG_CLOUD
  Serial.println("\n[CLOUD] === Firebase RTDB PATCH ===");
  #endif
  
  if (WiFi.status() != WL_CONNECTED) {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] ERROR: WiFi not connected!");
    #endif
    return false;
  }
  
  /* Time sync is not required for HTTPS in insecure mode and static database secrets */
  /*
  if (!timeSynchronized()) {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] ERROR: Time not synchronized (needed for HTTPS)");
    #endif
    return false;
  }
  */
  
  WiFiClientSecure client;
  #if RTDB_TLS_INSECURE
  client.setInsecure();
  #if DEBUG_CLOUD
  Serial.println("[CLOUD] TLS: Insecure mode (no certificate verification)");
  #endif
  #else
  #if DEBUG_CLOUD
  Serial.println("[CLOUD] TLS: Strict certificate verification");
  #endif
  #endif
  
  HTTPClient http;
  const String url = trackerPatchUrl();
  
  #if DEBUG_CLOUD
  Serial.print("[CLOUD] URL: ");
  // Hide the auth token in logs for security
  String urlSafe = url;
  int authIdx = urlSafe.indexOf("&auth=");
  if (authIdx > 0) {
    urlSafe = urlSafe.substring(0, authIdx + 6) + "***";
  }
  Serial.println(urlSafe);
  Serial.print("[CLOUD] Body size: ");
  Serial.print(body.length());
  Serial.println(" bytes");
  #endif
  
  if (!http.begin(client, url)) {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] ERROR: HTTP begin failed!");
    #endif
    return false;
  }
  
  http.setTimeout(10000);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("User-Agent", "DataSolaire-ESP32/1.0");
  
  #if DEBUG_CLOUD
  Serial.println("[CLOUD] Sending PATCH request...");
  #endif
  
  const int code = sendPatchRequest(http, body);
  const String response = http.getString();
  
  #if DEBUG_CLOUD
  Serial.print("[CLOUD] HTTP Response Code: ");
  Serial.println(code);
  if (response.length() > 0 && response.length() < 500) {
    Serial.print("[CLOUD] Response: ");
    Serial.println(response);
  }
  #endif
  
  const bool ok = code >= 200 && code < 300;
  
  if (!ok) {
    #if DEBUG_CLOUD
    Serial.print("[CLOUD] ERROR: PATCH failed with code ");
    Serial.println(code);
    Serial.println("[CLOUD] Request body:");
    Serial.println(body);
    
    // Print error codes with explanations
    switch(code) {
      case 400:
        Serial.println("[CLOUD]   └─ 400 Bad Request: Check JSON format");
        break;
      case 401:
        Serial.println("[CLOUD]   └─ 401 Unauthorized: Check Firebase auth secret or rules");
        break;
      case 403:
        Serial.println("[CLOUD]   └─ 403 Forbidden: Firebase rules may prevent write access");
        break;
      case 404:
        Serial.println("[CLOUD]   └─ 404 Not Found: Check FIREBASE_DATABASE_URL");
        break;
      case 500:
        Serial.println("[CLOUD]   └─ 500 Server Error: Firebase service issue");
        break;
      default:
        Serial.print("[CLOUD]   └─ See Firebase RTDB rules and network connection");
        break;
    }
    #endif
  } else {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] ✓ PATCH successful");
    #endif
  }
  
  http.end();
  return ok;
}

#if ENABLE_HTTP_DATA_ENDPOINT
static void handleHttpData() {
  #if DEBUG_CLOUD
  Serial.println("[CLOUD] [HTTP] GET /data request received");
  #endif
  
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
  
  #if DEBUG_CLOUD
  Serial.print("[CLOUD] [HTTP] Response sent: ");
  Serial.println(json);
  #endif
}

static void http404() {
  #if DEBUG_CLOUD
  Serial.print("[CLOUD] [HTTP] 404 Not Found: ");
  Serial.println(server.uri());
  #endif
  server.send(404, "text/plain", "Not found");
}
#endif

void cloudSetup() {
  #if DEBUG_CLOUD
  Serial.println("\n========== CLOUD SETUP START ==========");
  #endif
  
  connectWifi();
  setupNtp();
  
  #if ENABLE_HTTP_DATA_ENDPOINT
  server.on("/data", HTTP_GET, handleHttpData);
  server.onNotFound(http404);
  server.begin();
  #if DEBUG_CLOUD
  Serial.println("[CLOUD] HTTP server started on port 80");
  Serial.println("[CLOUD] Local endpoint: GET http://<ESP32_IP>/data");
  #endif
  #endif
  
  #if DEBUG_CLOUD
  Serial.println("========== CLOUD SETUP COMPLETE ==========\n");
  #endif
}

void cloudServeHttp() {
  #if ENABLE_HTTP_DATA_ENDPOINT
  server.handleClient();
  #endif
}

void cloudPushTracker() {
  if (WiFi.status() != WL_CONNECTED) {
    #if DEBUG_CLOUD
    Serial.println("[CLOUD] WARNING: WiFi disconnected, attempting reconnect...");
    #endif
    connectWifi();
    if (WiFi.status() != WL_CONNECTED) {
      #if DEBUG_CLOUD
      static unsigned long lastWifiWarning = 0;
      if (millis() - lastWifiWarning > 10000) {
        Serial.println("[CLOUD] WARNING: WiFi still disconnected, skipping RTDB push");
        lastWifiWarning = millis();
      }
      #endif
      return;
    }
  }
  /* Time sync warning only - do not block push as we use Firebase server value for timestamps */
  #if DEBUG_CLOUD
  if (!timeSynchronized()) {
    static unsigned long lastTimeWarning = 0;
    if (millis() - lastTimeWarning > 30000) {
      Serial.println("[CLOUD] WARNING: NTP time is not synchronized (using Firebase server timestamps)");
      lastTimeWarning = millis();
    }
  }
  #endif

  // epochMsNow() is not strictly needed for RTDB anymore since we use .sv: timestamp, but we keep it for reference
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
  body += "\"secret\":\"" + jsonEscape(String(FIREBASE_DATABASE_SECRET)) + "\",";
  body += "\"voltage\":" + safeJsonNumber(gVoltageV, 4);
  body += ",\"current\":" + safeJsonNumber(gCurrentA, 6);
  body += ",\"power\":" + safeJsonNumber(gPowerW, 4);
  if (gDhtOk) {
    body += ",\"temperature\":" + safeJsonNumber(gTemperatureC, 2);
  }
  body += ",\"last_updated_ms\":{\".sv\":\"timestamp\"}";
  body += ",\"voltage_updated_ms\":{\".sv\":\"timestamp\"}";
  body += ",\"current_updated_ms\":{\".sv\":\"timestamp\"}";
  body += ",\"power_updated_ms\":{\".sv\":\"timestamp\"}";
  if (gDhtOk) {
    body += ",\"temperature_updated_ms\":{\".sv\":\"timestamp\"}";
  }
  body += "}";

  body += ",\"sun\":{";
  body += "\"is_optimal\":";
  body += gSunOptimal ? "true" : "false";
  body += ",\"irradiance_normalized\":" + safeJsonNumber(gIrradianceNormalized, 4);
  body += ",\"secret\":\"" + jsonEscape(String(FIREBASE_DATABASE_SECRET)) + "\",";
  body += "\"ldr_quadrants\":{";
  body += "\"top\":" + safeJsonNumber(gLdrTopNorm, 4);
  body += ",\"bottom\":" + safeJsonNumber(gLdrBottomNorm, 4);
  body += ",\"left\":" + safeJsonNumber(gLdrLeftNorm, 4);
  body += ",\"right\":" + safeJsonNumber(gLdrRightNorm, 4);
  body += "}";
  body += "}";

  body += ",\"thresholds\":{";
  body += "\"cleaning_power_w\":" + safeJsonNumber((double)CLEANING_POWER_W, 2);
  body += ",\"secret\":\"" + jsonEscape(String(FIREBASE_DATABASE_SECRET)) + "\"";
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
  body += ",\"secret\":\"" + jsonEscape(String(FIREBASE_DATABASE_SECRET)) + "\"";
  body += "}";

  // Continuous-rotation servos: no absolute angle is available.
  body += ",\"orientation\":{";
  body += "\"pitch_deg\":0";
  body += ",\"yaw_deg\":0";
  body += ",\"roll_deg\":0";
  body += ",\"secret\":\"" + jsonEscape(String(FIREBASE_DATABASE_SECRET)) + "\"";
  body += "}";

  body += ",\"faults\":{";
  body += "\"secret\":\"" + jsonEscape(String(FIREBASE_DATABASE_SECRET)) + "\",";
  body += "\"latest\":{";
  body += "\"hasError\":";
  body += fault ? "true" : "false";
  body += ",\"code\":\"";
  body += jsonEscape(String(code));
  body += "\",\"message\":\"";
  body += jsonEscape(msg);
  body += "\",\"timestamp_ms\":{\".sv\":\"timestamp\"}";
  body += ",\"secret\":\"" + jsonEscape(String(FIREBASE_DATABASE_SECRET)) + "\"";
  body += "}}";
  body += "}";

  if (rtdbPatchTrackerJson(body)) {
    sLastSuccessfulPushMs = epochMsNow();
    #if DEBUG_CLOUD
    // Only log success every ~5 seconds to reduce noise
    static unsigned long lastSuccess = 0;
    if (millis() - lastSuccess > 5000) {
      Serial.println("[CLOUD] ✓ Data synced to Firebase");
      lastSuccess = millis();
    }
    #endif
  } else {
    #if DEBUG_CLOUD
    if (sLastSuccessfulPushMs > 0) {
      const int64_t ageSec = (epochMsNow() - sLastSuccessfulPushMs) / 1000;
      Serial.print("[CLOUD] Last successful DB push was ");
      Serial.print(ageSec);
      Serial.println(" seconds ago");
    } else {
      Serial.println("[CLOUD] No successful DB push has occurred yet");
    }
    #endif
  }
}
