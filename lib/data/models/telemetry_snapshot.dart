import 'package:flutter/foundation.dart';

/// Données brutes télémétrie + horodatages par voie (pour détection capteur mort).
@immutable
class TelemetrySnapshot {
  const TelemetrySnapshot({
    this.voltage,
    this.current,
    this.power,
    this.temperature,
    this.lastUpdatedMs,
    this.voltageUpdatedMs,
    this.currentUpdatedMs,
    this.powerUpdatedMs,
    this.temperatureUpdatedMs,
  });

  final double? voltage;
  final double? current;
  final double? power;
  final double? temperature;
  final int? lastUpdatedMs;
  final int? voltageUpdatedMs;
  final int? currentUpdatedMs;
  final int? powerUpdatedMs;
  final int? temperatureUpdatedMs;

  static TelemetrySnapshot fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const TelemetrySnapshot();
    return TelemetrySnapshot(
      voltage: _toDouble(map['voltage']),
      current: _toDouble(map['current']),
      power: _toDouble(map['power']),
      temperature: _toDouble(map['temperature']),
      lastUpdatedMs: _toInt(map['last_updated_ms']),
      voltageUpdatedMs: _toInt(map['voltage_updated_ms']),
      currentUpdatedMs: _toInt(map['current_updated_ms']),
      powerUpdatedMs: _toInt(map['power_updated_ms']),
      temperatureUpdatedMs: _toInt(map['temperature_updated_ms']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
