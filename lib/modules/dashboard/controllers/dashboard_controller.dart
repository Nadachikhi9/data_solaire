import 'dart:async';
import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:data_solaire/core/app_runtime_state.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/data/models/aux_state.dart';
import 'package:data_solaire/data/models/rtdb_connection_status.dart';
import 'package:data_solaire/data/models/sun_state.dart';
import 'package:data_solaire/data/models/tracker_orientation.dart';
import 'package:data_solaire/data/models/tracker_rtdb_state.dart';
import 'package:data_solaire/data/services/rtdb_data_service.dart';

class _PowerSample {
  _PowerSample(this.tMs, this.power);

  final int tMs;
  final double power;
}

/// Logique métier : pannes, buffer graphique, heartbeat.
class DashboardController extends GetxController {
  DashboardController({RtdbDataService? dataService})
      : _data = dataService ?? Get.find<RtdbDataService>();

  final RtdbDataService _data;
  StreamSubscription<TrackerRtdbState>? _sub;
  Timer? _healthTimer;
  Timer? _rtdbReconnectTimer;
  TrackerRtdbState? _latestState;
  int _rtdbRetryCount = 0;

  static const int _maxRtdbRetries = 120;

  final RxnDouble voltage = RxnDouble();
  final RxnDouble current = RxnDouble();
  final RxnDouble power = RxnDouble();
  final RxnDouble temperature = RxnDouble();

  final Rx<SunState> sun = Rx(SunState());
  final Rx<AuxState> auxState = Rx(const AuxState());
  final Rx<TrackerOrientation> orientation = Rx(const TrackerOrientation());

  final RxBool systemOffline = false.obs;
  final RxBool cleaningAlert = false.obs;
  final RxDouble cleaningSeverity = 0.0.obs;

  final RxList<String> sensorFaultMessages = <String>[].obs;
  final RxnDouble chartMaxY = RxnDouble(100);

  final RxList<FlSpot> powerSpots = <FlSpot>[].obs;

  final Queue<_PowerSample> _powerBuffer = Queue<_PowerSample>();

  final Rx<RtdbConnectionStatus> rtdbStatus =
      RtdbConnectionStatus.idle.obs;
  final RxnString rtdbError = RxnString();
  final RxBool rtdbStreamStarted = false.obs;
  final RxnInt lastTelemetryUpdatedMs = RxnInt();

  static const int _staleMs = 5000;
  static const int _chartWindowMs = 60000;
  static const int _maxChartPoints = 120;

  @override
  void onInit() {
    super.onInit();
    _healthTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      _reevaluateHealth();
    });
    _attachRtdbListener();
  }

  void _attachRtdbListener() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    _sub = null;

    final runtime = Get.find<AppRuntimeState>();
    if (!runtime.firebaseReady.value) {
      rtdbStatus.value = RtdbConnectionStatus.error;
      rtdbError.value = AppStrings.rtdbFirebaseNotInitialized;
      return;
    }

    rtdbStatus.value = RtdbConnectionStatus.listening;
    rtdbError.value = null;

    try {
      _sub = _data.watchTracker().listen(
        _onTrackerUpdate,
        onError: (Object e, StackTrace st) {
          rtdbStatus.value = RtdbConnectionStatus.error;
          rtdbError.value = '${AppStrings.rtdbListenError} : $e';
          if (kDebugMode) {
            debugPrint('RTDB onError: $e\n$st');
          }
          _scheduleRtdbReconnect();
        },
      );
      rtdbStreamStarted.value = true;
    } catch (e, st) {
      rtdbStatus.value = RtdbConnectionStatus.error;
      rtdbError.value = '${AppStrings.rtdbListenError} : $e';
      if (kDebugMode) {
        debugPrint('RTDB subscribe: $e\n$st');
      }
      _scheduleRtdbReconnect();
    }
  }

  void _scheduleRtdbReconnect() {
    _rtdbReconnectTimer?.cancel();
    if (isClosed) return;
    if (_rtdbRetryCount >= _maxRtdbRetries) {
      rtdbError.value = AppStrings.rtdbMaxRetries;
      return;
    }
    _rtdbRetryCount++;
    _rtdbReconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!isClosed) {
        _attachRtdbListener();
      }
    });
  }

  @override
  void onClose() {
    _healthTimer?.cancel();
    _rtdbReconnectTimer?.cancel();
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.onClose();
  }

  void _onTrackerUpdate(TrackerRtdbState state) {
    _rtdbRetryCount = 0;
    if (rtdbStatus.value == RtdbConnectionStatus.error) {
      rtdbStatus.value = RtdbConnectionStatus.listening;
    }
    rtdbError.value = null;

    _latestState = state;
    final t = state.telemetry;
    lastTelemetryUpdatedMs.value = t.lastUpdatedMs;
    voltage.value = t.voltage;
    current.value = t.current;
    power.value = t.power;
    temperature.value = t.temperature;

    sun.value = state.sun;
    auxState.value = state.aux;
    orientation.value = state.orientation;

    final now = DateTime.now().millisecondsSinceEpoch;
    final p = t.power;
    if (p != null) {
      _appendPowerSample(now, p);
    }

    _reevaluateHealth(nowMs: now, state: state);
  }

  void _appendPowerSample(int nowMs, double p) {
    _powerBuffer.addLast(_PowerSample(nowMs, p));
    while (_powerBuffer.length > _maxChartPoints) {
      _powerBuffer.removeFirst();
    }
    final cutoff = nowMs - _chartWindowMs;
    while (_powerBuffer.isNotEmpty && _powerBuffer.first.tMs < cutoff) {
      _powerBuffer.removeFirst();
    }

    if (_powerBuffer.isEmpty) return;

    final start = _powerBuffer.first.tMs;

    final spots = <FlSpot>[];
    var maxY = 10.0;
    for (final s in _powerBuffer) {
      final x = (s.tMs - start) / 1000.0;
      spots.add(FlSpot(x, s.power));
      if (s.power > maxY) maxY = s.power;
    }

    chartMaxY.value = maxY * 1.15;
    powerSpots.assignAll(spots);
  }

  void _reevaluateHealth({int? nowMs, TrackerRtdbState? state}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final snapshot = state ?? _latestState;
    final telemetry = snapshot?.telemetry;

    final lastGlobal = telemetry?.lastUpdatedMs;
    final offline = lastGlobal == null || (now - lastGlobal) > _staleMs;
    systemOffline.value = offline;

    final cleaning = _computeCleaningAlert(snapshot, offline, now);
    cleaningAlert.value = cleaning.$1;
    cleaningSeverity.value = cleaning.$2;

    sensorFaultMessages.assignAll(
      _computeSensorFaults(snapshot, offline, now),
    );
  }

  (bool, double) _computeCleaningAlert(
    TrackerRtdbState? state,
    bool offline,
    int now,
  ) {
    if (offline || state == null) return (false, 0.0);
    final t = state.telemetry;
    final p = t.power;
    if (p == null) return (false, 0.0);

    final sunOptimal = state.sun.isOptimal == true ||
        (state.sun.irradianceNormalized != null &&
            state.sun.irradianceNormalized! >= 0.75);
    if (!sunOptimal) return (false, 0.0);

    final threshold = state.thresholds.cleaningPowerW ?? 30.0;
    if (p >= threshold) return (false, 0.0);

    final ratio = (threshold - p) / threshold.clamp(1, double.infinity);
    return (true, ratio.clamp(0.0, 1.0));
  }

  List<String> _computeSensorFaults(
    TrackerRtdbState? state,
    bool offline,
    int now,
  ) {
    if (offline || state == null) return [];

    final t = state.telemetry;
    final out = <String>[];

    final vMs = t.voltageUpdatedMs ?? t.lastUpdatedMs;
    final iMs = t.currentUpdatedMs ?? t.lastUpdatedMs;
    final pMs = t.powerUpdatedMs ?? t.lastUpdatedMs;
    final tempMs = t.temperatureUpdatedMs ?? t.lastUpdatedMs;

    final ina219Bad = _staleOrNull(t.voltage, vMs, now) ||
        _staleOrNull(t.current, iMs, now) ||
        _staleOrNull(t.power, pMs, now);

    if (ina219Bad) {
      out.add('Erreur de lecture : Capteur INA219 déconnecté');
    }

    if (_staleOrNull(t.temperature, tempMs, now)) {
      out.add('Erreur de lecture : Capteur DHT11 déconnecté');
    }

    return out;
  }

  bool _staleOrNull(double? value, int? updatedMs, int now) {
    if (value == null) return true;
    if (updatedMs == null) return true;
    return now - updatedMs > _staleMs;
  }
}
