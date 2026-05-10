#include "hardware.h"

#include <Wire.h>
#include <Adafruit_INA219.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include "DHT.h"

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
  pinMode(kFanPin, OUTPUT);
  digitalWrite(kFanPin, LOW);

  dht.begin();

  lcd.init();
  lcd.backlight();

  if (!ina219.begin()) {
    Serial.println("INA219 non trouve !");
    gIna219Ready = false;
  } else {
    ina219.setCalibration_16V_400mA();
    gIna219Ready = true;
  }

  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  servoX.attach(kPinServoX);
  servoY.attach(kPinServoY);

  lcd.print("System Booting...");
  delay(2000);
  lcd.clear();
}

void hwLoop() {
  const int HG = analogRead(kPinLdrHG);
  const int HD = analogRead(kPinLdrHD);
  const int BG = analogRead(kPinLdrBG);
  const int BD = analogRead(kPinLdrBD);
  gLdrHG = HG; gLdrHD = HD; gLdrBG = BG; gLdrBD = BD;

  const int moyHaut = (HG + HD) >> 1;
  const int moyBas = (BG + BD) >> 1;
  const int moyGauche = (HG + BG) >> 1;
  const int moyDroite = (HD + BD) >> 1;

  const int diffY = moyHaut - moyBas;
  if (abs(diffY) > kLdrTolerance) {
    servoY.write(diffY > 0 ? (kServoStopVal + kServoSpeed) : (kServoStopVal - kServoSpeed));
  } else {
    servoY.write(kServoStopVal);
  }

  const int diffX = moyGauche - moyDroite;
  if (abs(diffX) > kLdrTolerance) {
    servoX.write(diffX > 0 ? (kServoStopVal - kServoSpeed) : (kServoStopVal + kServoSpeed));
  } else {
    servoX.write(kServoStopVal);
  }

  gSunOptimal = (abs(diffY) <= kLdrTolerance) && (abs(diffX) <= kLdrTolerance);
  gIrradianceNormalized = clamp01((float)(HG + HD + BG + BD) / (4.0f * 4095.0f));
  gLdrTopNorm = clamp01((float)moyHaut / 4095.0f);
  gLdrBottomNorm = clamp01((float)moyBas / 4095.0f);
  gLdrLeftNorm = clamp01((float)moyGauche / 4095.0f);
  gLdrRightNorm = clamp01((float)moyDroite / 4095.0f);
  gLdrTopOk = moyHaut >= kLdrOkMinRaw;
  gLdrBottomOk = moyBas >= kLdrOkMinRaw;
  gLdrLeftOk = moyGauche >= kLdrOkMinRaw;
  gLdrRightOk = moyDroite >= kLdrOkMinRaw;

  const float t = dht.readTemperature();
  gDhtOk = !isnan(t);
  if (gDhtOk) {
    gTemperatureC = t;
  }
  const bool fanOn = gDhtOk && t >= kFanOnTempC;
  digitalWrite(kFanPin, fanOn ? HIGH : LOW);
  gVentilationOn = fanOn;

  if (gIna219Ready) {
    gVoltageV = ina219.getBusVoltage_V();
    gCurrentA = ina219.getCurrent_mA() / 1000.0f;
    gPowerW = ina219.getPower_mW() / 1000.0f;
  } else {
    gVoltageV = 0.0f;
    gCurrentA = 0.0f;
    gPowerW = 0.0f;
  }

  if (millis() - sLastDisplayTime > 3000) {
    lcd.clear();
    if (sToggleDisplay) {
      const float V = gVoltageV;
      const float I_mA = gCurrentA * 1000.0f;
      const float P_mW = gPowerW * 1000.0f;
      lcd.setCursor(0, 0);
      lcd.print("V:"); lcd.print(V, 1); lcd.print("V I:"); lcd.print(I_mA, 0); lcd.print("mA");
      lcd.setCursor(0, 1);
      lcd.print("P: "); lcd.print(P_mW, 1); lcd.print(" mW");
    } else {
      lcd.setCursor(0, 0);
      lcd.print("Temp: ");
      if (gDhtOk) { lcd.print(gTemperatureC, 1); } else { lcd.print("---"); }
      lcd.print(" C");
      lcd.setCursor(0, 1);
      lcd.print("FAN: "); lcd.print(gVentilationOn ? "ON (COOLING)" : "OFF");
    }
    sToggleDisplay = !sToggleDisplay;
    sLastDisplayTime = millis();
  }
}
