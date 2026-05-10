import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Split-complementary palette (Stitch: « Helios » / « Énergie Lumineuse »):
/// deep blue anchor, amber primary, teal data, violet focus — high contrast on dark UI.
abstract final class AppTheme {
  static const Color scaffold = Color(0xFF0B1220);
  static const Color surface = Color(0xFF121B2E);
  static const Color surfaceHigh = Color(0xFF1A2744);
  static const Color surfaceVariant = Color(0xFF1E2A42);
  static const Color surfaceGlow = Color(0xFF243352);
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  static const Color primary = Color(0xFFF5B942);
  static const Color primaryDim = Color(0xFFC9922E);
  static const Color onPrimary = Color(0xFF1A1204);

  static const Color teal = Color(0xFF3DD9C3);
  static const Color violet = Color(0xFF8B7CF6);
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFF87171);

  static const Color onSurface = Color(0xFFE8EDF5);
  static const Color onMuted = Color(0xFF8B9BB8);

  /// Legacy aliases used across modules
  static const Color accent = teal;
  static const Color onDark = onSurface;

  static const double radiusSm = 12;
  static const double radiusMd = 20;
  static const double radiusLg = 28;

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        surface: surface,
        primary: primary,
        onPrimary: onPrimary,
        secondary: violet,
        onSecondary: Colors.white,
        tertiary: teal,
        onTertiary: const Color(0xFF002822),
        error: danger,
        onError: Colors.white,
        onSurface: onSurface,
        outline: borderStrong,
      ),
      scaffoldBackgroundColor: scaffold,
      dividerColor: borderStrong,
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: onPrimary,
          backgroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: onSurface, displayColor: onSurface);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.02,
        ),
      ),
    );
  }

  static BoxDecoration bentoDecoration({double radius = radiusMd}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface.withValues(alpha: 0.92),
          surfaceHigh.withValues(alpha: 0.88),
        ],
      ),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 32,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static Widget glassLayer({
    required Widget child,
    double radius = radiusMd,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: surface.withValues(alpha: 0.55),
            border: Border.all(color: border),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  static TextStyle labelInstrument(BuildContext context) {
    return GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.35,
      color: onMuted,
    );
  }

  static TextStyle metricValue(BuildContext context) {
    return GoogleFonts.plusJakartaSans(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.02,
      color: onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
