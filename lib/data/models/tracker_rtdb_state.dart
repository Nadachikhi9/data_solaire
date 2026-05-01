import 'package:flutter/foundation.dart';
import 'package:data_solaire/data/models/aux_state.dart';
import 'package:data_solaire/data/models/fault_latest.dart';
import 'package:data_solaire/data/models/sun_state.dart';
import 'package:data_solaire/data/models/telemetry_snapshot.dart';
import 'package:data_solaire/data/models/tracker_orientation.dart';

/// Agrégat non-interprété (logique métier dans le controller).
@immutable
class TrackerRtdbState {
  const TrackerRtdbState({
    required this.telemetry,
    required this.sun,
    required this.thresholds,
    required this.aux,
    required this.orientation,
    this.fault,
  });

  final TelemetrySnapshot telemetry;
  final SunState sun;
  final ThresholdsSnapshot thresholds;
  final AuxState aux;
  final TrackerOrientation orientation;
  final FaultLatest? fault;

  factory TrackerRtdbState.fromRootMap(dynamic root) {
    if (root is! Map) {
      return const TrackerRtdbState(
        telemetry: TelemetrySnapshot(),
        sun: SunState(),
        thresholds: ThresholdsSnapshot(),
        aux: AuxState(),
        orientation: TrackerOrientation(),
        fault: null,
      );
    }
    final r = Map<dynamic, dynamic>.from(root);
    final t = r['telemetry'];
    final s = r['sun'];
    final th = r['thresholds'];
    final a = r['aux'];
    final o = r['orientation'];
    final f = r['faults'];
    Map<dynamic, dynamic>? telemetryMap;
    Map<dynamic, dynamic>? sunMap;
    Map<dynamic, dynamic>? thMap;
    Map<dynamic, dynamic>? auxMap;
    Map<dynamic, dynamic>? orientMap;
    Map<dynamic, dynamic>? faultMap;
    if (t is Map) telemetryMap = t.cast<dynamic, dynamic>();
    if (s is Map) sunMap = s.cast<dynamic, dynamic>();
    if (th is Map) thMap = th.cast<dynamic, dynamic>();
    if (a is Map) auxMap = a.cast<dynamic, dynamic>();
    if (o is Map) orientMap = o.cast<dynamic, dynamic>();
    if (f is Map) {
      final latest = f['latest'];
      if (latest is Map) faultMap = latest.cast<dynamic, dynamic>();
    }
    return TrackerRtdbState(
      telemetry: TelemetrySnapshot.fromMap(telemetryMap),
      sun: SunState.fromMap(sunMap),
      thresholds: ThresholdsSnapshot.fromMap(thMap),
      aux: AuxState.fromMap(auxMap),
      orientation: TrackerOrientation.fromMap(orientMap),
      fault: FaultLatest.fromMap(faultMap),
    );
  }
}
