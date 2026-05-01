import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/core/feature_flags.dart';
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
      horizontal: width < 600 ? 12 : 24,
      vertical: 16,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.dashboardTitle),
            Text(
              AppStrings.appSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onMuted,
                  ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DashboardAlertStrip(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final isWide = w >= 1200;
                final isMedium = w >= 600 && w < 1200;

                final telemetry = _section(
                  title: AppStrings.telemetrySection,
                  child: const TelemetryCardsWidget(),
                );
                final health = _section(
                  title: AppStrings.diagnosticsSection,
                  child: const HealthDiagnosticsWidget(),
                );
                final chart = _section(
                  title: AppStrings.performanceSection,
                  child: const PowerChartWidget(),
                );
                final viewer3d = _section(
                  title: AppStrings.tracker3dSection,
                  child: const Tracker3dWidget(),
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
                            Expanded(flex: 3, child: telemetry),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: health),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: chart),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: viewer3d),
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
                            Expanded(child: telemetry),
                            const SizedBox(width: 16),
                            Expanded(child: health),
                          ],
                        ),
                        const SizedBox(height: 16),
                        chart,
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      health,
                      const SizedBox(height: 16),
                      chart,
                      const SizedBox(height: 16),
                      viewer3d,
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.onDark,
              fontSize: 16,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DashboardAlertStrip extends StatelessWidget {
  const _DashboardAlertStrip();

  @override
  Widget build(BuildContext context) {
    final dash = Get.find<DashboardController>();
    final fcm = Get.find<FcmService>();

    return Obx(() {
      final parts = <Widget>[];
      if (FeatureFlags.useMockRealtimeData) {
        parts.add(
          _AlertLine(
            icon: Icons.waving_hand_outlined,
            text: AppStrings.demoModeBanner,
            accent: AppTheme.warning,
          ),
        );
      }
      final rErr = dash.rtdbError.value;
      if (rErr != null && rErr.isNotEmpty) {
        parts.add(
          _AlertLine(
            icon: Icons.cloud_sync_outlined,
            text: rErr,
            accent: AppTheme.warning,
          ),
        );
      }
      if (kIsWeb && !fcm.messagingAvailable.value) {
        final detail = fcm.messagingLastError.value;
        parts.add(
          _AlertLine(
            icon: Icons.notifications_off_outlined,
            text: detail ?? AppStrings.fcmDegradedBanner,
            accent: AppTheme.accent,
          ),
        );
      }
      if (parts.isEmpty) return const SizedBox.shrink();

      return Material(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                parts[i],
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({
    required this.icon,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onDark,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}
