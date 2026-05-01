import 'package:flutter/foundation.dart';

@immutable
class TrackerOrientation {
  const TrackerOrientation({
    this.pitchDeg = 0,
    this.yawDeg = 0,
    this.rollDeg = 0,
  });

  final double pitchDeg;
  final double yawDeg;
  final double rollDeg;

  static TrackerOrientation fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const TrackerOrientation();
    return TrackerOrientation(
      pitchDeg: _toDouble(map['pitch_deg']) ?? 0,
      yawDeg: _toDouble(map['yaw_deg']) ?? 0,
      rollDeg: _toDouble(map['roll_deg']) ?? 0,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
