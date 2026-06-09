import 'dart:async';
import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:data_solaire/core/app_runtime_state.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/core/feature_flags.dart';
import 'package:data_solaire/data/models/aux_state.dart';
import 'package:data_solaire/data/models/rtdb_connection_status.dart';
import 'package:data_solaire/data/models/sun_state.dart';
import 'package:data_solaire/data/models/tracker_orientation.dart';
import 'package:data_solaire/data/models/tracker_rtdb_state.dart';
import 'package:data_solaire/data/services/fcm_service.dart';
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

  bool _mockAlertPrevOffline = false;
  bool _mockAlertPrevCleaning = false;
  int _mockAlertPrevFaultCount = 0;
  bool _mockAlertPrevFwFault = false;

  static const double _ldrHighCountThreshold = 2500.0;
  static const double _cleaningLowPowerThresholdW = 0.15;
  static const double _panelFaultPowerToleranceW = 0.0;
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
  final RxnDouble chartMaxY = RxnDouble(10000);

  final RxList<FlSpot> powerSpots = <FlSpot>[].obs;

  final Queue<_PowerSample> _powerBuffer = Queue<_PowerSample>();

  int? _powerChartEpochMs;
  double _powerDataMaxX = 0;

  /// Whether the chart view is pinned to the latest samples (user can pan away).
  final RxBool chartFollowLatest = true.obs;

  /// Visible X range in seconds since chart epoch ([_powerChartEpochMs]).
  final RxDouble chartViewportMin = 0.0.obs;
  final RxDouble chartViewportMax = 60.0.obs;

  final Rx<RtdbConnectionStatus> rtdbStatus = RtdbConnectionStatus.idle.obs;
  final RxnString rtdbError = RxnString();
  final RxBool rtdbStreamStarted = false.obs;
  final RxnInt lastTelemetryUpdatedMs = RxnInt();

  static const int _staleMs = 5000;

  /// Default visible window width when following live data.
  static const int _chartWindowMs = 60000;

  /// Retain samples this long so the user can drag back (15 minutes).
  static const int _retentionMs = 900000;
  static const int _maxChartPoints = 2000;

  /// Visible window width in seconds (constant scale on the time axis).
  double get powerChartWindowSec => _chartWindowMs / 1000.0;

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
    _fireAlertEdgesIfNeeded(state);
  }

  void _appendPowerSample(int nowMs, double p) {
    _powerBuffer.addLast(_PowerSample(nowMs, p));
    while (_powerBuffer.length > _maxChartPoints) {
      _powerBuffer.removeFirst();
    }
    final cutoff = nowMs - _retentionMs;
    while (_powerBuffer.isNotEmpty && _powerBuffer.first.tMs < cutoff) {
      _powerBuffer.removeFirst();
    }

    if (_powerBuffer.isEmpty) return;

    _powerChartEpochMs ??= _powerBuffer.first.tMs;
    final epoch = _powerChartEpochMs!;

    final spots = <FlSpot>[];
    var maxY = 10000.0;
    for (final s in _powerBuffer) {
      final x = (s.tMs - epoch) / 1000.0;
      final pMw = s.power * 1000.0;
      spots.add(FlSpot(x, pMw));
      if (pMw > maxY) maxY = pMw;
    }

    _powerDataMaxX = spots.isEmpty ? 0 : spots.last.x;

    if (chartFollowLatest.value) {
      _applyFollowLatestViewport();
    }

    chartMaxY.value = 300.0;
    powerSpots.assignAll(spots);
  }

  void _applyFollowLatestViewport() {
    final w = powerChartWindowSec;
    final dataMax = _powerDataMaxX;
    final viewMax = dataMax < w ? w : dataMax;
    var viewMin = viewMax - w;
    if (viewMin < 0) viewMin = 0;
    chartViewportMin.value = viewMin;
    chartViewportMax.value = viewMax;
  }

  /// Horizontal drag in logical pixels; [plotWidthPx] is the plot area width.
  void onPowerChartPan(double deltaPx, double plotWidthPx) {
    if (plotWidthPx <= 0) return;
    chartFollowLatest.value = false;
    final span = chartViewportMax.value - chartViewportMin.value;
    if (span <= 0) return;

    final deltaSec = -deltaPx / plotWidthPx * span;
    final maxRight = _powerDataMaxX < powerChartWindowSec
        ? powerChartWindowSec
        : _powerDataMaxX;

    var newMin = chartViewportMin.value + deltaSec;
    var newMax = chartViewportMax.value + deltaSec;

    if (newMin < 0) {
      newMax -= newMin;
      newMin = 0;
    }
    if (newMax > maxRight) {
      newMin -= newMax - maxRight;
      newMax = maxRight;
      if (newMin < 0) newMin = 0;
    }

    chartViewportMin.value = newMin;
    chartViewportMax.value = newMax;

    const snapSec = 0.35;
    if (maxRight - newMax <= snapSec) {
      chartFollowLatest.value = true;
      _applyFollowLatestViewport();
    }
  }

  void resetPowerChartToLive() {
    chartFollowLatest.value = true;
    _applyFollowLatestViewport();
  }

  void _reevaluateHealth({int? nowMs, TrackerRtdbState? state}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final snapshot = state ?? _latestState;
    final telemetry = snapshot?.telemetry;

    final lastGlobal = telemetry?.lastUpdatedMs;
    final offline = lastGlobal == null || (now - lastGlobal) > _staleMs;
    systemOffline.value = offline;

    if (offline) {
      voltage.value = null;
      current.value = null;
      power.value = null;
      temperature.value = null;
      orientation.value = const TrackerOrientation(pitchDeg: null, yawDeg: null, rollDeg: null);
      sun.value = const SunState(isOptimal: null, irradianceNormalized: null, ldrQuadrants: null);
      auxState.value = const AuxState(ventilationOn: null, ldrTopOk: null, ldrBottomOk: null, ldrLeftOk: null, ldrRightOk: null);
    }

    final cleaning = _computeCleaningAlert(snapshot, offline, now);
    cleaningAlert.value = cleaning.$1;
    cleaningSeverity.value = cleaning.$2;

    sensorFaultMessages.assignAll(_computeSensorFaults(snapshot, offline, now));
  }

  void _fireAlertEdgesIfNeeded(TrackerRtdbState state) {
    if (!Get.isRegistered<FcmService>()) {
      return;
    }
    final fcm = Get.find<FcmService>();
    final title = '${AppStrings.appTitle}${FeatureFlags.useMockRealtimeData ? ' (démo)' : ''}';

    final offline = systemOffline.value;
    final cleaning = cleaningAlert.value;
    final faultCount = sensorFaultMessages.length;
    final fw = state.fault;
    final fwFault = fw?.hasError == true;

    if (offline && !_mockAlertPrevOffline) {
      unawaited(
        fcm.showDiagnosticForegroundAlert(
          title: title,
          body: AppStrings.offlineTitle,
        ),
      );
    }
    if (cleaning && !_mockAlertPrevCleaning) {
      unawaited(
        fcm.showDiagnosticForegroundAlert(
          title: title,
          body: AppStrings.cleaningRequired,
        ),
      );
    }
    if (faultCount > 0 && _mockAlertPrevFaultCount == 0) {
      final msg = sensorFaultMessages.isEmpty
          ? AppStrings.sensorIna219
          : sensorFaultMessages.first;
      unawaited(fcm.showDiagnosticForegroundAlert(title: title, body: msg));
    }
    if (fwFault && !_mockAlertPrevFwFault) {
      final detail = fw!;
      unawaited(
        fcm.showDiagnosticForegroundAlert(
          title: title,
          body:
              detail.message ??
              '${AppStrings.statusFault} (${detail.code ?? '?'})',
        ),
      );
    }
    _mockAlertPrevOffline = offline;
    _mockAlertPrevCleaning = cleaning;
    _mockAlertPrevFaultCount = faultCount;
    _mockAlertPrevFwFault = fwFault;
  }

  bool _ldrQuadrantsAllAboveThreshold(LdrQuadrants? q) {
    if (q == null) return false;
    return (q.top ?? double.negativeInfinity) > _ldrHighCountThreshold &&
        (q.bottom ?? double.negativeInfinity) > _ldrHighCountThreshold &&
        (q.left ?? double.negativeInfinity) > _ldrHighCountThreshold &&
        (q.right ?? double.negativeInfinity) > _ldrHighCountThreshold;
  }

  bool _isSolarPanelFault(TrackerRtdbState state) {
    final p = state.telemetry.power;
    return p != null && p <= _panelFaultPowerToleranceW &&
        _ldrQuadrantsAllAboveThreshold(state.sun.ldrQuadrants);
  }

  bool _isCleaningWarning(TrackerRtdbState state) {
    final p = state.telemetry.power;
    return p != null && p < _cleaningLowPowerThresholdW &&
        _ldrQuadrantsAllAboveThreshold(state.sun.ldrQuadrants) &&
        !_isSolarPanelFault(state);
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

    if (_isSolarPanelFault(state)) {
      return (false, 0.0);
    }

    if (_isCleaningWarning(state)) {
      final ratio = (_cleaningLowPowerThresholdW - p) /
          _cleaningLowPowerThresholdW.clamp(1, double.infinity);
      return (true, ratio.clamp(0.0, 1.0));
    }

    return (false, 0.0);
  }

  List<String> _computeSensorFaults(
    TrackerRtdbState? state,
    bool offline,
    int now,
  ) {
    if (offline || state == null) return [];

    final t = state.telemetry;
    final out = <String>[];

    if (t.voltage == null) {
      out.add(AppStrings.sensorVoltageNa);
    }
    if (t.current == null) {
      out.add(AppStrings.sensorCurrentNa);
    }
    if (t.power == null) {
      out.add(AppStrings.sensorPowerNa);
    }
    if (t.temperature == null) {
      out.add(AppStrings.sensorTemperatureNa);
    }

    final vMs = t.voltageUpdatedMs ?? t.lastUpdatedMs;
    final iMs = t.currentUpdatedMs ?? t.lastUpdatedMs;
    final pMs = t.powerUpdatedMs ?? t.lastUpdatedMs;
    final tempMs = t.temperatureUpdatedMs ?? t.lastUpdatedMs;

    final ina219Bad =
        _staleOrNull(t.voltage, vMs, now) ||
        _staleOrNull(t.current, iMs, now) ||
        _staleOrNull(t.power, pMs, now);

    if (ina219Bad) {
      out.add('Erreur de lecture : Capteur INA219 déconnecté');
    }

    if (_staleOrNull(t.temperature, tempMs, now)) {
      out.add('Erreur de lecture : Capteur DHT22 déconnecté');
    }

    if (_isSolarPanelFault(state)) {
      out.add(AppStrings.panelFault);
    } else if (_isCleaningWarning(state)) {
      out.add(AppStrings.cleaningWarning);
    }

    return out;
  }

  bool _staleOrNull(double? value, int? updatedMs, int now) {
    if (value == null) return true;
    if (updatedMs == null) return true;
    return now - updatedMs > _staleMs;
  }
}
