/// Chemins racine Realtime Database (préfixe commun PC ↔ app).
abstract final class RtdbPaths {
  static const String trackerRoot = 'tracker';

  static String telemetry(String child) => '$trackerRoot/telemetry/$child';
  static String sun(String child) => '$trackerRoot/sun/$child';
  static String thresholds(String child) => '$trackerRoot/thresholds/$child';
  static String aux(String child) => '$trackerRoot/aux/$child';
  static String orientation(String child) => '$trackerRoot/orientation/$child';
  static String faultsLatest = '$trackerRoot/faults/latest';
}
