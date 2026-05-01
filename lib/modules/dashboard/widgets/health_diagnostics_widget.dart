import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';

class HealthDiagnosticsWidget extends GetView<DashboardController> {
  const HealthDiagnosticsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final offline = controller.systemOffline.value;
      final cleaning = controller.cleaningAlert.value;
      final sev = controller.cleaningSeverity.value;
      final faults = controller.sensorFaultMessages.toList();
      final aux = controller.auxState.value;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (offline) ...[
                _StatusBanner(
                  color: AppTheme.danger,
                  icon: Icons.cloud_off_outlined,
                  title: AppStrings.offlineTitle,
                  subtitle: AppStrings.offlineHint,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Indicateurs',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.onMuted,
                    ),
              ),
              const SizedBox(height: 8),
              if (cleaning) ...[
                Text(
                  AppStrings.cleaningRequired,
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: sev,
                    minHeight: 10,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  'Aucune alerte de nettoyage détectée.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onMuted,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Capteurs',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.onMuted,
                    ),
              ),
              const SizedBox(height: 8),
              ...[
                if (faults.isEmpty && !offline)
                  Text(
                    'Toutes les voies répondent sous 5 secondes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  for (final m in faults)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m,
                              style:
                                  const TextStyle(color: AppTheme.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
              const Divider(height: 24),
              Text(
                'Systèmes auxiliaires',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.onMuted,
                    ),
              ),
              const SizedBox(height: 8),
              _AuxRow(
                label: AppStrings.ventilation,
                ok: aux.ventilationOn == true,
              ),
              _AuxRow(
                label: AppStrings.ldrLeft,
                ok: aux.ldrLeftOk == true,
              ),
              _AuxRow(
                label: AppStrings.ldrRight,
                ok: aux.ldrRightOk == true,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuxRow extends StatelessWidget {
  const _AuxRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.help_outline,
            color: ok ? AppTheme.success : AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            ok ? AppStrings.statusOk : AppStrings.statusUnknown,
            style: TextStyle(
              color: ok ? AppTheme.success : AppTheme.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
