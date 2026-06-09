import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';

class HealthDiagnosticsWidget extends GetView<DashboardController> {
  const HealthDiagnosticsWidget({super.key, this.fillVertical = false});

  final bool fillVertical;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final offline = controller.systemOffline.value;
      final cleaning = controller.cleaningAlert.value;
      final sev = controller.cleaningSeverity.value;
      final faults = controller.sensorFaultMessages.toList();
      final aux = controller.auxState.value;

      final inaFault = faults.any((m) => m.contains('INA219'));
      final dhtFault = faults.any((m) => m.contains('DHT22'));

      final inner = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offline) ...[
            _StatusBanner(
              color: AppTheme.danger,
              icon: Icons.cloud_off_outlined,
              title: AppStrings.offlineTitle,
              subtitle: AppStrings.offlineHint,
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Indicateurs',
            style: AppTheme.labelInstrument(
              context,
            ).copyWith(color: AppTheme.onSurface),
          ),
          const SizedBox(height: 10),
          if (cleaning) ...[
            Text(
              AppStrings.cleaningRequired,
              style: const TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: sev,
                minHeight: 8,
                backgroundColor: AppTheme.surfaceGlow,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.danger,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Text(
              'Aucune alerte de nettoyage détectée.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.onMuted),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Capteurs',
            style: AppTheme.labelInstrument(
              context,
            ).copyWith(color: AppTheme.onSurface),
          ),
          const SizedBox(height: 10),
          _CapteurDeviceRow(
            title:
                '${AppStrings.sensorDht22} (${AppStrings.sensorDht22Detail})',
            offline: offline,
            faulty: dhtFault,
          ),
          _CapteurDeviceRow(
            title:
                '${AppStrings.sensorIna219} (${AppStrings.sensorIna219Detail})',
            offline: offline,
            faulty: inaFault,
          ),
          const SizedBox(height: 14),
          if (faults.isEmpty && !offline)
            Text(
              'Toutes les voies répondent sous 5 secondes.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (final m in faults)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.danger,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m,
                        style: const TextStyle(
                          color: AppTheme.danger,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          _AuxRow(label: AppStrings.ldrTop, ok: aux.ldrTopOk),
          _AuxRow(label: AppStrings.ldrBottom, ok: aux.ldrBottomOk),
          _AuxRow(label: AppStrings.ldrLeft, ok: aux.ldrLeftOk),
          _AuxRow(label: AppStrings.ldrRight, ok: aux.ldrRightOk),
          _AuxRow(label: AppStrings.ventilation, ok: aux.ventilationOn, showOnOff: true),
        ],
      );

      final shell =
          Container(
                decoration: AppTheme.bentoDecoration(),
                clipBehavior: Clip.hardEdge,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: fillVertical
                      ? SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: inner,
                        )
                      : inner,
                ),
              )
              .animate()
              .fadeIn(duration: 420.ms, delay: 40.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic);

      if (!fillVertical) return shell;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: shell)],
      );
    });
  }
}

class _CapteurDeviceRow extends StatelessWidget {
  const _CapteurDeviceRow({
    required this.title,
    required this.offline,
    required this.faulty,
  });

  final String title;
  final bool offline;
  final bool faulty;

  @override
  Widget build(BuildContext context) {
    late final IconData ic;
    late final Color col;
    late final String status;

    if (offline) {
      ic = Icons.help_outline_rounded;
      col = AppTheme.warning;
      status = 'N/A';
    } else if (faulty) {
      ic = Icons.error_outline_rounded;
      col = AppTheme.danger;
      status = AppStrings.statusFault;
    } else {
      ic = Icons.check_circle_outline_rounded;
      col = AppTheme.success;
      status = AppStrings.statusOk;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ic, color: col, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status,
            style: TextStyle(color: col, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onMuted,
                    height: 1.35,
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
  const _AuxRow({
    required this.label,
    required this.ok,
    this.showOnOff = false,
  });

  final String label;
  final bool? ok;
  final bool showOnOff;

  @override
  Widget build(BuildContext context) {
    late final IconData ic;
    late final Color col;
    late final String status;
    final isLdrRow = label == AppStrings.ldrTop ||
        label == AppStrings.ldrBottom ||
        label == AppStrings.ldrLeft ||
        label == AppStrings.ldrRight;

    if (ok == null) {
      ic = Icons.help_outline_rounded;
      col = AppTheme.warning;
      status = AppStrings.statusUnknown;
    } else if (isLdrRow) {
      ic = Icons.check_circle_outline_rounded;
      col = AppTheme.success;
      status = AppStrings.statusOk;
    } else if (showOnOff) {
      if (ok!) {
        ic = Icons.toggle_on_outlined;
        col = AppTheme.success;
        status = AppStrings.statusOn;
      } else {
        ic = Icons.toggle_off_outlined;
        col = AppTheme.onMuted;
        status = AppStrings.statusOff;
      }
    } else if (ok == false) {
      ic = Icons.error_outline_rounded;
      col = AppTheme.danger;
      status = AppStrings.statusFault;
    } else {
      ic = Icons.check_circle_outline_rounded;
      col = AppTheme.success;
      status = AppStrings.statusOk;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            ic,
            color: col,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            status,
            style: TextStyle(
              color: col,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
