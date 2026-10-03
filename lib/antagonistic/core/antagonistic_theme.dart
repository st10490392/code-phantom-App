import 'package:flutter/material.dart';

/// Visual identity carried forward from the original Antagonistic Trading Co.
/// website. Keep strategy logic and credentials out of the presentation layer.
abstract final class AntagonisticTheme {
  static const Color background = Color(0xFF0C0F14);
  static const Color surface = Color(0xFF12161D);
  static const Color surfaceAlt = Color(0xFF0F1418);
  static const Color accent = Color(0xFF1E90FF);
  static const Color text = Color(0xFFF0F0F0);
  static const Color muted = Color(0xFF9AA4B2);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFEF4444);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: accent,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: text,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceAlt,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accent.withValues(alpha: 0.16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.18),
      ),
    );
  }
}
