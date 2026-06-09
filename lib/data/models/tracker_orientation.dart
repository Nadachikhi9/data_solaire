import 'package:flutter/foundation.dart';

@immutable
class TrackerOrientation {
  const TrackerOrientation({
    this.pitchDeg,
    this.yawDeg,
    this.rollDeg,
  });

  final double? pitchDeg;
  final double? yawDeg;
  final double? rollDeg;

  static TrackerOrientation fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const TrackerOrientation();
    return TrackerOrientation(
      pitchDeg: _toDouble(map['pitch_deg'] ?? map['pitch']),
      yawDeg: _toDouble(map['yaw_deg'] ?? map['yaw']),
      rollDeg: _toDouble(map['roll_deg'] ?? map['roll']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  bool operator ==(Object other) {
    return other is TrackerOrientation &&
        other.pitchDeg == pitchDeg &&
        other.yawDeg == yawDeg &&
        other.rollDeg == rollDeg;
  }

  @override
  int get hashCode => Object.hash(pitchDeg, yawDeg, rollDeg);
}
