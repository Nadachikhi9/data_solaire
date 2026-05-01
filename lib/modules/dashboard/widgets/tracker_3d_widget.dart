import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';

class Tracker3dWidget extends StatefulWidget {
  const Tracker3dWidget({super.key});

  @override
  State<Tracker3dWidget> createState() => _Tracker3dWidgetState();
}

class _Tracker3dWidgetState extends State<Tracker3dWidget> {
  bool _userDisabled3d = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return RepaintBoundary(
      child: Card(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 320,
            child: _userDisabled3d
                ? _Disabled3d(onReenable: () => setState(() => _userDisabled3d = false))
                : Obx(() {
                    final o = controller.orientation.value;
                    final orbit =
                        '${o.yawDeg.toStringAsFixed(1)}deg ${o.pitchDeg.toStringAsFixed(1)}deg 108%';

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ModelViewer(
                          key: ValueKey<String>(orbit),
                          src: 'assets/models/solar_tracker_lowpoly.glb',
                          alt: 'Modèle 3D du tracker solaire',
                          backgroundColor: AppTheme.surface,
                          cameraControls: true,
                          cameraOrbit: orbit,
                          autoRotate: false,
                          debugLogging: false,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: AppTheme.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            child: IconButton(
                              tooltip: 'Masquer la 3D (mode dégradé)',
                              icon: const Icon(Icons.layers_clear_outlined),
                              color: AppTheme.onDark,
                              onPressed: () =>
                                  setState(() => _userDisabled3d = true),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Material(
                            color: AppTheme.scaffold.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Text(
                                AppStrings.tracker3dHint,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppTheme.onMuted),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
          ),
        ),
      ),
    );
  }
}

class _Disabled3d extends StatelessWidget {
  const _Disabled3d({required this.onReenable});

  final VoidCallback onReenable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined,
                size: 48, color: AppTheme.onMuted),
            const SizedBox(height: 12),
            Text(
              AppStrings.tracker3dUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onMuted,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReenable,
              icon: const Icon(Icons.restore),
              label: const Text('Réactiver la 3D'),
            ),
          ],
        ),
      ),
    );
  }
}
