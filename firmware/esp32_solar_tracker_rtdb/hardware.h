#pragma once

#include <Arduino.h>

// DEBUG FLAGS
#define DEBUG_HARDWARE 1
#define DEBUG_LDR 0
#define DEBUG_INA219 0
#define DEBUG_DHT 0
#define DEBUG_SERVO 0
#define DEBUG_LCD 0
#define DEBUG_FAN 0

// Pins (matches the new hardware wiring).
constexpr int kDhtPin = 4;
constexpr int kFanPin = 5;
constexpr int kPinLdrHG = 34;
constexpr int kPinLdrHD = 32;
constexpr int kPinLdrBG = 35;
constexpr int kPinLdrBD = 33;
constexpr int kPinServoX = 18;
constexpr int kPinServoY = 19;

// Tracking tuning.
constexpr int kServoStopVal = 90;
constexpr int kServoSpeed = 60;
constexpr int kLdrTolerance = 50;
constexpr int kLdrOkMinRaw = 50;
constexpr float kFanOnTempC = 25.0f;

void hwSetup();
void hwLoop();
void hwRunDiagnostics();
void hwShowStatus(const char* line1, const char* line2);

// Telemetry produced by hwLoop() (read-only from outside).
extern float gVoltageV;
extern float gCurrentA;
extern float gPowerW;
extern float gTemperatureC;
extern bool gIna219Ready;
extern bool gDhtOk;
extern bool gVentilationOn;

extern int gLdrHG, gLdrHD, gLdrBG, gLdrBD;
extern float gLdrTopNorm, gLdrBottomNorm, gLdrLeftNorm, gLdrRightNorm;
extern bool gLdrTopOk, gLdrBottomOk, gLdrLeftOk, gLdrRightOk;

extern bool gSunOptimal;
extern float gIrradianceNormalized;
