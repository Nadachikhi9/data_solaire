import 'dart:math' as math;

import 'package:data_solaire/data/models/aux_state.dart';
import 'package:data_solaire/data/models/fault_latest.dart';
import 'package:data_solaire/data/models/sun_state.dart';
import 'package:data_solaire/data/models/telemetry_snapshot.dart';
import 'package:data_solaire/data/models/tracker_orientation.dart';
import 'package:data_solaire/data/models/tracker_rtdb_state.dart';

/// Données factices pour tester l’UI sans Firebase.
abstract final class MockTrackerStream {
  static const Duration tickInterval = Duration(milliseconds: 900);

  /// Miroir approximatif des butées servo du firmware (`kServoX/Y Min/Max`).
  static const double _yawMin = 52;
  static const double _yawMax = 128;
  static const double _pitchMin = 38;
  static const double _pitchMax = 142;

  /// Un échantillon cohérent pour un tick et un temps [nowMs] (heartbeats frais).
  static TrackerRtdbState snapshotForTick(int tick, int nowMs) {
    final t = tick.toDouble();
    final rad = t * 0.12;
    final s = math.sin(rad);
    final c = math.cos(rad * 0.7);

    final voltage = 12.2 + 0.35 * s;
    final current = 1.15 + 0.12 * c;
    final power = (voltage * current).clamp(8.0, 22.0);
    final temperature = 24.0 + 2.5 * math.sin(rad * 0.9 + 0.5);

    final yawMid = (_yawMin + _yawMax) / 2;
    final yawAmp = (_yawMax - _yawMin) / 2;
    final pitchMid = (_pitchMin + _pitchMax) / 2;
    final pitchAmp = (_pitchMax - _pitchMin) / 2;
    final yawDeg = yawMid + yawAmp * math.sin(rad * 0.17);
    final pitchDeg = pitchMid + pitchAmp * 0.88 * math.cos(rad * 0.11);

    return TrackerRtdbState(
      telemetry: TelemetrySnapshot(
        voltage: double.parse(voltage.toStringAsFixed(3)),
        current: double.parse(current.toStringAsFixed(3)),
        power: double.parse(power.toStringAsFixed(2)),
        temperature: double.parse(temperature.toStringAsFixed(2)),
        lastUpdatedMs: nowMs,
        voltageUpdatedMs: nowMs,
        currentUpdatedMs: nowMs,
        powerUpdatedMs: nowMs,
        temperatureUpdatedMs: nowMs,
      ),
      sun: SunState(
        isOptimal: true,
        irradianceNormalized: (0.82 + 0.08 * c).clamp(0.0, 1.0),
        ldrQuadrants: LdrQuadrants(
          top: (0.52 + 0.38 * math.sin(rad)).clamp(0.0, 1.0),
          bottom: (0.52 + 0.38 * math.sin(rad + 1.1)).clamp(0.0, 1.0),
          left: (0.52 + 0.38 * math.cos(rad * 0.83)).clamp(0.0, 1.0),
          right: (0.52 + 0.38 * math.cos(rad * 0.83 + 1.05)).clamp(0.0, 1.0),
        ),
      ),
      thresholds: const ThresholdsSnapshot(cleaningPowerW: 30),
      aux: const AuxState(
        ventilationOn: true,
        ldrTopOk: true,
        ldrBottomOk: true,
        ldrLeftOk: true,
        ldrRightOk: true,
      ),
      orientation: TrackerOrientation(
        pitchDeg: pitchDeg,
        yawDeg: yawDeg,
        rollDeg: 0,
      ),
      fault: FaultLatest(
        hasError: false,
        code: 'OK',
        message: 'Simulation sans panne',
        timestampMs: nowMs,
      ),
    );
  }

  static Stream<TrackerRtdbState> createStream() {
    return Stream<TrackerRtdbState>.periodic(
      tickInterval,
      (tick) => snapshotForTick(
        tick,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
