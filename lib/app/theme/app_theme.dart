import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Thème sombre industriel (inspiré dashboard SCADA).
abstract final class AppTheme {
  static const Color scaffold = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceVariant = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color accent = Color(0xFF58A6FF);
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color danger = Color(0xFFF85149);
  static const Color onDark = Color(0xFFE6EDF3);
  static const Color onMuted = Color(0xFF8B949E);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: warning,
        error: danger,
        onSurface: onDark,
      ),
      scaffoldBackgroundColor: scaffold,
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
        bodyColor: onDark,
        displayColor: onDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onDark,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
