import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/app/ui/ui_motion.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/modules/splash/controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final reduced = motionReduced(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AuroraBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SunGlyph(animate: !reduced),
                const SizedBox(height: 32),
                Text(
                      AppStrings.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                            letterSpacing: -0.04,
                          ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideY(begin: 0.05, curve: Curves.easeOutCubic),
                const SizedBox(height: 10),
                Text(
                      AppStrings.appSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.onMuted,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 320.ms)
                    .slideY(begin: 0.05, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.scaffold, AppTheme.surfaceHigh, AppTheme.scaffold],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              diameter: 280,
              color: AppTheme.primary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -50,
            child: _GlowOrb(
              diameter: 240,
              color: AppTheme.teal.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            top: 120,
            left: -30,
            child: _GlowOrb(
              diameter: 180,
              color: AppTheme.violet.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _SunGlyph extends StatelessWidget {
  const _SunGlyph({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDim],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.45),
            blurRadius: 40,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppTheme.teal.withValues(alpha: 0.2),
            blurRadius: 56,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        Icons.solar_power_rounded,
        size: 56,
        color: AppTheme.onPrimary,
      ),
    );

    if (!animate) return core;

    return core
        .animate()
        .scale(
          duration: 900.ms,
          curve: Curves.easeOutBack,
          begin: const Offset(0.85, 0.85),
        )
        .fadeIn(duration: 600.ms)
        .then()
        .shimmer(delay: 400.ms, duration: 2200.ms, color: Colors.white24);
  }
}
