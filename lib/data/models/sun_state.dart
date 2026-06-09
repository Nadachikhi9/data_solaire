import 'package:flutter/foundation.dart';

@immutable
class LdrQuadrants {
  const LdrQuadrants({this.top, this.bottom, this.left, this.right});

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  static LdrQuadrants? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    return LdrQuadrants(
      top: _toDouble(map['top'] ?? map['haut']),
      bottom: _toDouble(map['bottom'] ?? map['bas']),
      left: _toDouble(map['left'] ?? map['gauche']),
      right: _toDouble(map['right'] ?? map['droite']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  bool operator ==(Object other) {
    return other is LdrQuadrants &&
        other.top == top &&
        other.bottom == bottom &&
        other.left == left &&
        other.right == right;
  }

  @override
  int get hashCode => Object.hash(top, bottom, left, right);
}

@immutable
class SunState {
  const SunState({
    this.isOptimal,
    this.irradianceNormalized,
    this.ldrQuadrants,
  });

  final bool? isOptimal;
  final double? irradianceNormalized;
  final LdrQuadrants? ldrQuadrants;

  static SunState fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const SunState();
    Map<dynamic, dynamic>? lqMap;
    final lq = map['ldr_quadrants'];
    if (lq is Map) lqMap = lq.cast<dynamic, dynamic>();
    return SunState(
      isOptimal: map['is_optimal'] as bool? ?? map['sun_optimal'] as bool?,
      irradianceNormalized: _toDouble(map['irradiance_normalized'] ?? map['irradiance']),
      ldrQuadrants: LdrQuadrants.fromMap(lqMap),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  bool operator ==(Object other) {
    return other is SunState &&
        other.isOptimal == isOptimal &&
        other.irradianceNormalized == irradianceNormalized &&
        other.ldrQuadrants == ldrQuadrants;
  }

  @override
  int get hashCode =>
      Object.hash(isOptimal, irradianceNormalized, ldrQuadrants);
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
