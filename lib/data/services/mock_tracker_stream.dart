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
      ),
      thresholds: const ThresholdsSnapshot(cleaningPowerW: 30),
      aux: const AuxState(
        ventilationOn: true,
        ldrLeftOk: true,
        ldrRightOk: true,
      ),
      orientation: TrackerOrientation(
        pitchDeg: 8 * s,
        yawDeg: (t * 4.0) % 360.0,
        rollDeg: 1.2 * c,
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
