import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/data/models/rtdb_connection_status.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';

class TelemetryCardsWidget extends GetView<DashboardController> {
  const TelemetryCardsWidget({super.key, this.fillVertical = false});

  /// When true (paired column with diagnostics), expands to band height.
  final bool fillVertical;

  static const double _metricTileMinHeight = 158;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hubMs = controller.lastTelemetryUpdatedMs.value;
      final awaiting = hubMs == null &&
          !controller.systemOffline.value &&
          controller.rtdbStatus.value != RtdbConnectionStatus.error;

      final metrics = [
        (
          AppStrings.voltage,
          'V',
          controller.voltage.value,
          Icons.bolt_rounded,
          AppTheme.teal,
        ),
        (
          AppStrings.current,
          'A',
          controller.current.value,
          Icons.electric_bolt_rounded,
          AppTheme.violet,
        ),
        (
          AppStrings.power,
          'W',
          controller.power.value,
          Icons.local_fire_department_rounded,
          AppTheme.primary,
        ),
        (
          AppStrings.temperature,
          '°C',
          controller.temperature.value,
          Icons.thermostat_rounded,
          AppTheme.onMuted,
        ),
      ];

      final wrap = LayoutBuilder(
        builder: (context, c) {
          var w = c.maxWidth;
          if (!w.isFinite || w <= 0) {
            w = MediaQuery.sizeOf(context).width;
          }
          final count = w >= 900
              ? 4
              : w >= 520
                  ? 2
                  : 1;
          final tileW = count == 1
              ? w
              : (w - 14 * (count - 1)) / count;
          final safeTileW = tileW.isFinite ? tileW.clamp(120.0, w) : 160.0;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < metrics.length; i++)
                SizedBox(
                  width: safeTileW,
                  height: _metricTileMinHeight,
                  child: _MetricTile(
                    label: metrics[i].$1,
                    unit: metrics[i].$2,
                    value: metrics[i].$3,
                    icon: metrics[i].$4,
                    accent: metrics[i].$5,
                    index: i,
                  ),
                ),
            ],
          );
        },
      );

      if (!fillVertical) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (awaiting) ...[
              const _InfoPill(text: AppStrings.telemetryAwaitingHub),
              const SizedBox(height: 14),
            ],
            wrap,
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (awaiting) ...[
            const _InfoPill(text: AppStrings.telemetryAwaitingHub),
            const SizedBox(height: 14),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: wrap,
            ),
          ),
        ],
      );
    });
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppTheme.glassLayer(
      radius: AppTheme.radiusSm,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.teal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.unit,
    required this.value,
    required this.icon,
    required this.accent,
    required this.index,
  });

  final String label;
  final String unit;
  final double? value;
  final IconData icon;
  final Color accent;
  final int index;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '—' : value!.toStringAsFixed(2);
    final reduced = MediaQuery.disableAnimationsOf(context);

    Widget tile = SizedBox.expand(
      child: Container(
        decoration: AppTheme.bentoDecoration(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.22),
                          accent.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.onMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                label.toUpperCase(),
                style: AppTheme.labelInstrument(context),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: AppTheme.metricValue(context).copyWith(fontSize: 26),
              ),
            ],
          ),
        ),
      ),
    );

    if (reduced) return tile;

    return tile
        .animate()
        .fadeIn(
          duration: 450.ms,
          delay: (index * 80).ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.06,
          duration: 500.ms,
          delay: (index * 80).ms,
          curve: Curves.easeOutCubic,
        );
  }
}
