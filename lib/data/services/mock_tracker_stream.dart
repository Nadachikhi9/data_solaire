import 'dart:math' as math;

import 'package:data_solaire/data/models/aux_state.dart';
import 'package:data_solaire/data/models/fault_latest.dart';
import 'package:data_solaire/data/models/sun_state.dart';
import 'package:data_solaire/data/models/telemetry_snapshot.dart';
import 'package:data_solaire/data/models/tracker_orientation.dart';
import 'package:data_solaire/data/models/tracker_rtdb_state.dart';

/// Données factices pour tester l’UI sans Firebase — **phases cycliques** qui cassent la
/// télémétrie puis reviennent à la normale (capteurs, offline, alerte nettoyage, défaut équipement, LDR).
abstract final class MockTrackerStream {
  static const Duration tickInterval = Duration(milliseconds: 900);

  /// ~9 s par scénario puis passage au suivant.
  static const int _ticksPerPhase = 10;

  /// Nombre total de phases sur un cycle (indices 0 … _phaseCount - 1).
  static const int _phaseCount = 8;

  /// Miroir approximatif des butées servo du firmware (`kServoX/Y Min/Max`).
  static const double _yawMin = 52;
  static const double _yawMax = 128;
  static const double _pitchMin = 38;
  static const double _pitchMax = 142;

  static const int _staleSkewMs = 8200;

  static TrackerRtdbState snapshotForTick(int tick, int nowMs) {
    final rad = tick * 0.12;
    final s = math.sin(rad);
    final c = math.cos(rad * 0.7);

    final phase = (tick ~/ _ticksPerPhase) % _phaseCount;

    final voltage = double.parse((12.2 + 0.35 * s).toStringAsFixed(3));
    final current = double.parse((1.15 + 0.12 * c).toStringAsFixed(3));
    final powerHealthy = double.parse(
      ((voltage * current).clamp(8.0, 22.0)).toStringAsFixed(2),
    );
    final temperature = double.parse(
      (24.0 + 2.5 * math.sin(rad * 0.9 + 0.5)).toStringAsFixed(2),
    );

    final yawMid = (_yawMin + _yawMax) / 2;
    final yawAmp = (_yawMax - _yawMin) / 2;
    final pitchMid = (_pitchMin + _pitchMax) / 2;
    final pitchAmp = (_pitchMax - _pitchMin) / 2;
    final yawDeg = yawMid + yawAmp * math.sin(rad * 0.17);
    final pitchDeg = pitchMid + pitchAmp * 0.88 * math.cos(rad * 0.11);

    final freshTelem = TelemetrySnapshot(
      voltage: voltage,
      current: current,
      power: powerHealthy,
      temperature: temperature,
      lastUpdatedMs: nowMs,
      voltageUpdatedMs: nowMs,
      currentUpdatedMs: nowMs,
      powerUpdatedMs: nowMs,
      temperatureUpdatedMs: nowMs,
    );

    TelemetrySnapshot telemetry;
    SunState sun;
    AuxiliaryMock auxOverrides;
    FaultLatest fault;
    ThresholdsSnapshot thresholds = const ThresholdsSnapshot(
      cleaningPowerW: 30,
    );

    final staleTs = nowMs - _staleSkewMs;

    switch (phase) {
      case 0:
        telemetry = freshTelem;
        sun = _sunHealthy(c, rad);
        auxOverrides = AuxiliaryMock.none;
        fault = faultOk(nowMs);

      case 1:
        // INA219 : valeurs encore présentes mais horodatage stale.
        telemetry = TelemetrySnapshot(
          voltage: voltage,
          current: current,
          power: powerHealthy,
          temperature: temperature,
          lastUpdatedMs: staleTs,
          voltageUpdatedMs: staleTs,
          currentUpdatedMs: staleTs,
          powerUpdatedMs: staleTs,
          temperatureUpdatedMs: nowMs,
        );
        sun = _sunHealthy(c, rad);
        auxOverrides = AuxiliaryMock.none;
        fault = faultOk(nowMs);

      case 2:
        // DHT seul périmé.
        telemetry = TelemetrySnapshot(
          voltage: voltage,
          current: current,
          power: powerHealthy,
          temperature: temperature,
          lastUpdatedMs: nowMs,
          voltageUpdatedMs: nowMs,
          currentUpdatedMs: nowMs,
          powerUpdatedMs: nowMs,
          temperatureUpdatedMs: staleTs,
        );
        sun = _sunHealthy(c, rad);
        auxOverrides = AuxiliaryMock.none;
        fault = faultOk(nowMs);

      case 3:
        // Perte lien / hub — tout le bloc ancien (> 5 s).
        telemetry = TelemetrySnapshot(
          voltage: voltage,
          current: current,
          power: powerHealthy,
          temperature: temperature,
          lastUpdatedMs: staleTs,
          voltageUpdatedMs: staleTs,
          currentUpdatedMs: staleTs,
          powerUpdatedMs: staleTs,
          temperatureUpdatedMs: staleTs,
        );
        sun = _sunHealthy(c, rad);
        auxOverrides = AuxiliaryMock.none;
        fault = faultOk(nowMs);

      case 4:
        // Soleil jugé favorable mais puissance basse ⇒ alerte nettoyage UI.
        telemetry = TelemetrySnapshot(
          voltage: voltage,
          current: double.parse((0.45 + 0.02 * s).toStringAsFixed(3)),
          power: 9.8,
          temperature: temperature,
          lastUpdatedMs: nowMs,
          voltageUpdatedMs: nowMs,
          currentUpdatedMs: nowMs,
          powerUpdatedMs: nowMs,
          temperatureUpdatedMs: nowMs,
        );
        sun = SunState(
          isOptimal: true,
          irradianceNormalized: 0.88,
          ldrQuadrants: _ldrHealthy(rad),
        );
        auxOverrides = AuxiliaryMock.none;
        fault = faultOk(nowMs);

      case 5:
        telemetry = freshTelem;
        sun = _sunHealthy(c, rad);
        auxOverrides = AuxiliaryMock.none;
        fault = FaultLatest(
          hasError: true,
          code: 'E_MOCK_INVERTER',
          message: 'Démo : délestage simulé sur la chaîne DC (mock).',
          timestampMs: nowMs,
        );

      case 6:
        telemetry = freshTelem;
        sun = SunState(
          isOptimal: false,
          irradianceNormalized: (0.35 + 0.1 * s).clamp(0.0, 1.0),
          ldrQuadrants: _ldrHealthy(rad),
        );
        auxOverrides = const AuxiliaryMock(
          ldrTopOk: false,
          ldrBottomOk: true,
          ldrLeftOk: false,
          ldrRightOk: true,
        );
        fault = faultOk(nowMs);

      default:
        telemetry = freshTelem;
        sun = _sunHealthy(c, rad);
        auxOverrides = AuxiliaryMock.none;
        fault = faultOk(nowMs);
    }

    final aux = auxOverrides.applyTo(
      const AuxState(
        ventilationOn: true,
        ldrTopOk: true,
        ldrBottomOk: true,
        ldrLeftOk: true,
        ldrRightOk: true,
      ),
    );

    return TrackerRtdbState(
      telemetry: telemetry,
      sun: sun,
      thresholds: thresholds,
      aux: aux,
      orientation: TrackerOrientation(
        pitchDeg: pitchDeg,
        yawDeg: yawDeg,
        rollDeg: 0,
      ),
      fault: fault,
    );
  }

  static FaultLatest faultOk(int nowMs) => FaultLatest(
    hasError: false,
    code: 'OK',
    message: 'Simulation — phase en cours',
    timestampMs: nowMs,
  );

  static SunState _sunHealthy(double c, double rad) {
    return SunState(
      isOptimal: true,
      irradianceNormalized: (0.82 + 0.08 * c).clamp(0.0, 1.0),
      ldrQuadrants: _ldrHealthy(rad),
    );
  }

  static LdrQuadrants _ldrHealthy(double rad) {
    return LdrQuadrants(
      top: (0.52 + 0.38 * math.sin(rad)).clamp(0.0, 1.0),
      bottom: (0.52 + 0.38 * math.sin(rad + 1.1)).clamp(0.0, 1.0),
      left: (0.52 + 0.38 * math.cos(rad * 0.83)).clamp(0.0, 1.0),
      right: (0.52 + 0.38 * math.cos(rad * 0.83 + 1.05)).clamp(0.0, 1.0),
    );
  }

  static Stream<TrackerRtdbState> createStream() {
    return Stream<TrackerRtdbState>.periodic(
      tickInterval,
      (tick) => snapshotForTick(tick, DateTime.now().millisecondsSinceEpoch),
    );
  }
}

class AuxiliaryMock {
  const AuxiliaryMock({
    required this.ldrTopOk,
    required this.ldrBottomOk,
    required this.ldrLeftOk,
    required this.ldrRightOk,
  });

  static const AuxiliaryMock none = AuxiliaryMock(
    ldrTopOk: true,
    ldrBottomOk: true,
    ldrLeftOk: true,
    ldrRightOk: true,
  );

  final bool ldrTopOk;
  final bool ldrBottomOk;
  final bool ldrLeftOk;
  final bool ldrRightOk;

  AuxState applyTo(AuxState base) {
    return AuxState(
      ventilationOn: base.ventilationOn,
      ldrTopOk: ldrTopOk,
      ldrBottomOk: ldrBottomOk,
      ldrLeftOk: ldrLeftOk,
      ldrRightOk: ldrRightOk,
    );
  }
}
