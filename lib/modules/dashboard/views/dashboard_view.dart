import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/app/ui/ui_motion.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/core/feature_flags.dart';
import 'package:data_solaire/data/models/rtdb_connection_status.dart';
import 'package:data_solaire/data/services/fcm_service.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:data_solaire/modules/dashboard/widgets/health_diagnostics_widget.dart';
import 'package:data_solaire/modules/dashboard/widgets/power_chart_widget.dart';
import 'package:data_solaire/modules/dashboard/widgets/telemetry_cards_widget.dart';
import 'package:data_solaire/modules/dashboard/widgets/tracker_3d_widget.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = EdgeInsets.symmetric(
      horizontal: width < 600 ? 16 : 28,
      vertical: 20,
    );

    return Scaffold(
      backgroundColor: AppTheme.scaffold,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MeshBackdrop(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroHeader(padding: padding).heliosEntrance(context, index: 0),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final isWide = w >= 1200;
                      final isMedium = w >= 700 && w < 1200;

                      final telemetry = _section(
                        context,
                        index: 1,
                        title: AppStrings.telemetrySection,
                        child: const TelemetryCardsWidget(fillVertical: false),
                      );
                      final health = _section(
                        context,
                        index: 2,
                        title: AppStrings.diagnosticsSection,
                        child: const HealthDiagnosticsWidget(
                          fillVertical: false,
                        ),
                      );
                      final chart = _section(
                        context,
                        index: 3,
                        title: AppStrings.performanceSection,
                        child: const PowerChartWidget(fillVertical: false),
                      );
                      final viewer3d = _section(
                        context,
                        index: 4,
                        title: AppStrings.tracker3dSection,
                        child: const Tracker3dWidget(fillVertical: false),
                      );

                      if (isWide) {
                        return SingleChildScrollView(
                          padding: padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _section(
                                      context,
                                      index: 1,
                                      title: AppStrings.telemetrySection,
                                      child: const TelemetryCardsWidget(
                                        fillVertical: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 2,
                                    child: _section(
                                      context,
                                      index: 2,
                                      title: AppStrings.diagnosticsSection,
                                      child: const HealthDiagnosticsWidget(
                                        fillVertical: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _section(
                                      context,
                                      index: 3,
                                      title: AppStrings.performanceSection,
                                      child: const PowerChartWidget(
                                        fillVertical: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 2,
                                    child: _section(
                                      context,
                                      index: 4,
                                      title: AppStrings.tracker3dSection,
                                      child: const Tracker3dWidget(
                                        fillVertical: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      if (isMedium) {
                        return SingleChildScrollView(
                          padding: padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _section(
                                      context,
                                      index: 1,
                                      title: AppStrings.telemetrySection,
                                      child: const TelemetryCardsWidget(
                                        fillVertical: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _section(
                                      context,
                                      index: 2,
                                      title: AppStrings.diagnosticsSection,
                                      child: const HealthDiagnosticsWidget(
                                        fillVertical: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              chart,
                              const SizedBox(height: 20),
                              viewer3d,
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            telemetry,
                            const SizedBox(height: 20),
                            health,
                            const SizedBox(height: 20),
                            chart,
                            const SizedBox(height: 20),
                            viewer3d,
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _DashboardFooter(padding: padding),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required int index,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primary, AppTheme.teal],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: AppTheme.labelInstrument(
                  context,
                ).copyWith(color: AppTheme.onSurface, letterSpacing: 1.1),
              ),
            ],
          ),
        ).heliosEntrance(context, index: index),
        child.heliosEntrance(context, index: index + 1),
      ],
    );
  }
}

class _MeshBackdrop extends StatelessWidget {
  const _MeshBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.surfaceHigh.withValues(alpha: 0.35),
                AppTheme.scaffold,
                AppTheme.scaffold,
              ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
        Positioned(
          right: -80,
          top: -40,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.violet.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dash = Get.find<DashboardController>();

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.dashboardTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.appSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurface.withValues(alpha: 0.75),
                    ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _DashboardStatusIcons(),
          const SizedBox(width: 8),
          _RtdbLiveChip(controller: dash),
        ],
      ),
    );
  }
}

class _DashboardStatusIcons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dash = Get.find<DashboardController>();
    final fcm = Get.find<FcmService>();

    return Obx(() {
      dash.rtdbError.value;
      if (kIsWeb) {
        fcm.messagingAvailable.value;
        fcm.messagingLastError.value;
      }

      final icons = <Widget>[];
      if (FeatureFlags.useMockRealtimeData) {
        icons.add(
          Tooltip(
            message: AppStrings.demoModeBanner,
            child: Icon(
              Icons.waving_hand_outlined,
              size: 22,
              color: AppTheme.warning,
            ),
          ),
        );
      }
      final rErr = dash.rtdbError.value;
      if (rErr != null && rErr.isNotEmpty) {
        icons.add(
          Tooltip(
            message: rErr,
            child: Icon(
              Icons.cloud_sync_outlined,
              size: 22,
              color: AppTheme.warning,
            ),
          ),
        );
      }
      if (kIsWeb && !fcm.messagingAvailable.value) {
        final detail = fcm.messagingLastError.value;
        icons.add(
          Tooltip(
            message: detail ?? AppStrings.fcmDegradedBanner,
            child: Icon(
              Icons.notifications_off_outlined,
              size: 22,
              color: AppTheme.violet,
            ),
          ),
        );
      }

      if (icons.isEmpty) return const SizedBox.shrink();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < icons.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            icons[i],
          ],
        ],
      );
    });
  }
}

class _RtdbLiveChip extends StatelessWidget {
  const _RtdbLiveChip({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.rtdbStatus.value;
      final err = controller.rtdbError.value;
      final listening = status == RtdbConnectionStatus.listening && err == null;
      final lastUpdateMs = controller.lastTelemetryUpdatedMs.value;
      final hasData = lastUpdateMs != null;
      final dataStale = hasData &&
          DateTime.now().millisecondsSinceEpoch - lastUpdateMs > 5000;
      final awaitingData = listening && !hasData;
      final waitingStale = listening && hasData && dataStale;

      final Color fg;
      final Color bg;
      final IconData icon;
      final String tooltip;
      final String statusLabel;
      if (status == RtdbConnectionStatus.error ||
          (err != null && err.isNotEmpty)) {
        fg = AppTheme.danger;
        bg = AppTheme.danger.withValues(alpha: 0.15);
        icon = Icons.cloud_off_outlined;
        tooltip = (err != null && err.isNotEmpty) ? err : AppStrings.rtdbStatusUnavailable;
        statusLabel = 'Firebase indisponible';
      } else if (awaitingData) {
        fg = AppTheme.violet;
        bg = AppTheme.violet.withValues(alpha: 0.14);
        icon = Icons.cloud_done_outlined;
        tooltip = AppStrings.rtdbAwaitingData;
        statusLabel = AppStrings.rtdbAwaitingData;
      } else if (waitingStale) {
        fg = AppTheme.warning;
        bg = AppTheme.warning.withValues(alpha: 0.14);
        icon = Icons.cloud_queue_outlined;
        tooltip = AppStrings.rtdbStaleData;
        statusLabel = AppStrings.rtdbStaleData;
      } else if (listening) {
        fg = AppTheme.teal;
        bg = AppTheme.teal.withValues(alpha: 0.14);
        icon = Icons.podcasts_rounded;
        tooltip = AppStrings.rtdbConnected;
        statusLabel = AppStrings.rtdbConnected;
      } else {
        fg = AppTheme.warning;
        bg = AppTheme.warning.withValues(alpha: 0.14);
        icon = Icons.hourglass_top_rounded;
        tooltip = AppStrings.rtdbConnecting;
        statusLabel = AppStrings.rtdbConnecting;
      }

      final reduced = motionReduced(context);
      Widget dot = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening ? fg : fg.withValues(alpha: 0.85),
          boxShadow: listening
              ? [
                  BoxShadow(
                    color: fg.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      );
      if (listening && !reduced) {
        dot = dot
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.55, end: 1, duration: 1100.ms);
      }

      return Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot,
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                // Text(
                //   statusLabel,
                //   style: Theme.of(context).textTheme.labelMedium?.copyWith(
                //         color: fg,
                //         fontWeight: FontWeight.w700,
                //       ),
                // ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _DashboardFooter extends StatelessWidget {
  const _DashboardFooter({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.onSurface.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: padding.copyWith(bottom: 12, top: 16),
          child: Center(
            child: Text(
              AppStrings.blueCraftByline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onMuted.withAlpha(200),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
