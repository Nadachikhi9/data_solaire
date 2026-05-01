import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/data/models/rtdb_connection_status.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';

class TelemetryCardsWidget extends GetView<DashboardController> {
  const TelemetryCardsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hubMs = controller.lastTelemetryUpdatedMs.value;
      final awaiting = hubMs == null &&
          !controller.systemOffline.value &&
          controller.rtdbStatus.value !=
              RtdbConnectionStatus.error;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (awaiting) ...[
            _InfoPill(text: AppStrings.telemetryAwaitingHub),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: AppStrings.voltage,
                unit: 'V',
                value: controller.voltage.value,
                icon: Icons.bolt_outlined,
                color: AppTheme.accent,
              ),
              _MetricCard(
                label: AppStrings.current,
                unit: 'A',
                value: controller.current.value,
                icon: Icons.electric_meter_outlined,
                color: AppTheme.warning,
              ),
              _MetricCard(
                label: AppStrings.power,
                unit: 'W',
                value: controller.power.value,
                icon: Icons.local_fire_department_outlined,
                color: AppTheme.success,
              ),
              _MetricCard(
                label: AppStrings.temperature,
                unit: '°C',
                value: controller.temperature.value,
                icon: Icons.thermostat_outlined,
                color: AppTheme.onMuted,
              ),
            ],
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
    return Material(
      color: AppTheme.surfaceVariant.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
            const SizedBox(width: 10),
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
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.unit,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String unit;
  final double? value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '—' : value!.toStringAsFixed(2);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.onMuted,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$text $unit',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onDark,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
