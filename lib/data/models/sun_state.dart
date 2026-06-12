import 'package:flutter/foundation.dart';

@immutable
class LdrRaw {
  const LdrRaw({this.hg, this.hd, this.bg, this.bd});

  final int? hg; // Haut-Gauche (top-left)  – pin 34
  final int? hd; // Haut-Droite (top-right) – pin 32
  final int? bg; // Bas-Gauche (bottom-left) – pin 35
  final int? bd; // Bas-Droite (bottom-right) – pin 33

  static LdrRaw? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    return LdrRaw(
      hg: _toInt(map['hg']),
      hd: _toInt(map['hd']),
      bg: _toInt(map['bg']),
      bd: _toInt(map['bd']),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  @override
  bool operator ==(Object other) {
    return other is LdrRaw &&
        other.hg == hg &&
        other.hd == hd &&
        other.bg == bg &&
        other.bd == bd;
  }

  @override
  int get hashCode => Object.hash(hg, hd, bg, bd);
}

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
    this.ldrRaw,
  });

  final bool? isOptimal;
  final double? irradianceNormalized;
  final LdrQuadrants? ldrQuadrants;
  final LdrRaw? ldrRaw;

  static SunState fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const SunState();
    Map<dynamic, dynamic>? lqMap;
    Map<dynamic, dynamic>? lrMap;
    final lq = map['ldr_quadrants'];
    if (lq is Map) lqMap = lq.cast<dynamic, dynamic>();
    final lr = map['ldr_raw'];
    if (lr is Map) lrMap = lr.cast<dynamic, dynamic>();
    return SunState(
      isOptimal: map['is_optimal'] as bool? ?? map['sun_optimal'] as bool?,
      irradianceNormalized: _toDouble(map['irradiance_normalized'] ?? map['irradiance']),
      ldrQuadrants: LdrQuadrants.fromMap(lqMap),
      ldrRaw: LdrRaw.fromMap(lrMap),
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
        other.ldrQuadrants == ldrQuadrants &&
        other.ldrRaw == ldrRaw;
  }

  @override
  int get hashCode =>
      Object.hash(isOptimal, irradianceNormalized, ldrQuadrants, ldrRaw);
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
