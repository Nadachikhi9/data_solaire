/// JSON keys written to Firebase RTDB under `tracker/` — keep in sync with
/// `TrackerRtdbState` / nested snapshots in `lib/data/models/` and the ESP32 sketch.
abstract final class RtdbTrackerWriteKeys {
  // --- telemetry ---
  static const String telemetry = 'telemetry';
  static const String voltage = 'voltage';
  static const String current = 'current';
  static const String power = 'power';
  static const String temperature = 'temperature';
  static const String lastUpdatedMs = 'last_updated_ms';
  static const String voltageUpdatedMs = 'voltage_updated_ms';
  static const String currentUpdatedMs = 'current_updated_ms';
  static const String powerUpdatedMs = 'power_updated_ms';
  static const String temperatureUpdatedMs = 'temperature_updated_ms';

  // --- sun ---
  static const String sun = 'sun';
  static const String isOptimal = 'is_optimal';
  static const String irradianceNormalized = 'irradiance_normalized';

  // --- thresholds ---
  static const String thresholds = 'thresholds';
  static const String cleaningPowerW = 'cleaning_power_w';

  // --- aux ---
  static const String aux = 'aux';
  static const String ventilationOn = 'ventilation_on';
  static const String ldrLeftOk = 'ldr_left_ok';
  static const String ldrRightOk = 'ldr_right_ok';

  // --- orientation ---
  static const String orientation = 'orientation';
  static const String pitchDeg = 'pitch_deg';
  static const String yawDeg = 'yaw_deg';
  static const String rollDeg = 'roll_deg';

  // --- faults (under faults/latest) ---
  static const String faults = 'faults';
  static const String latest = 'latest';
  static const String hasError = 'hasError';
  static const String code = 'code';
  static const String message = 'message';
  static const String timestampMs = 'timestamp_ms';
}
