import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

bool motionReduced(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return true;
  return WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;
}

extension HeliosMotion on Widget {
  Widget heliosEntrance(
    BuildContext context, {
    required int index,
    Duration step = const Duration(milliseconds: 70),
  }) {
    if (motionReduced(context)) return this;
    final d = Duration(milliseconds: step.inMilliseconds * index);
    return animate()
        .fadeIn(duration: 420.ms, delay: d, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.08,
          duration: 480.ms,
          delay: d,
          curve: Curves.easeOutCubic,
        );
  }

  Widget heliosPulse(
    BuildContext context, {
    Duration period = const Duration(milliseconds: 2400),
  }) {
    if (motionReduced(context)) return this;
    return animate(
      onPlay: (c) => c.repeat(),
    ).shimmer(delay: 400.ms, duration: period, color: Colors.white24);
  }
}
