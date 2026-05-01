import 'package:flutter/foundation.dart';

@immutable
class SunState {
  const SunState({this.isOptimal, this.irradianceNormalized});

  final bool? isOptimal;
  final double? irradianceNormalized;

  static SunState fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const SunState();
    return SunState(
      isOptimal: map['is_optimal'] as bool?,
      irradianceNormalized: _toDouble(map['irradiance_normalized']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

@immutable
class ThresholdsSnapshot {
  const ThresholdsSnapshot({this.cleaningPowerW});

  final double? cleaningPowerW;

  static ThresholdsSnapshot fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const ThresholdsSnapshot();
    return ThresholdsSnapshot(
      cleaningPowerW: _toDouble(map['cleaning_power_w']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
