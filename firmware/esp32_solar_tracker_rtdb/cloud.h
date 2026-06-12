#pragma once

#include <Arduino.h>

void cloudSetup();
void cloudServeHttp();
void cloudPushTracker();

extern bool gFirebaseOk;
