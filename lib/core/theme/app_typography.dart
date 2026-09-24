import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Matches the website's three font families: display = Space Grotesk,
/// body = Inter, mono = JetBrains Mono.
///
/// These are bundled as local app assets (see `pubspec.yaml`'s `fonts:`
/// section and `assets/fonts/`) rather than fetched at runtime via the
/// `google_fonts` package. That package's per-style calls each kick off a
/// background HTTP fetch (with no built-in timeout) the first time a given
/// family/weight is used; on a slow or offline connection those requests
/// can each hang for a long time, which is what made cold start take
/// minutes on a poorly-connected device — bundling the five weights the
/// app actually uses (Space Grotesk 600/700, Inter 400/600, JetBrains Mono
/// 500) removes that network dependency entirely. See
/// `docs/ARCHITECTURE.md` §Startup performance.
abstract final class AppTypography {
  static const String _spaceGrotesk = 'Space Grotesk';
  static const String _inter = 'Inter';
  static const String _jetBrainsMono = 'JetBrains Mono';

  /// A compile-time constant — unlike the old `GoogleFonts.xxx()`-built
  /// theme, there is no per-launch work here at all.
  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: _spaceGrotesk,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.ghostWhite,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: _spaceGrotesk,
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontFamily: _spaceGrotesk,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
    headlineSmall: TextStyle(
      fontFamily: _spaceGrotesk,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
    titleMedium: TextStyle(
      fontFamily: _inter,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
    bodyLarge: TextStyle(
      fontFamily: _inter,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.ghostWhite,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: _inter,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.ghostWhite,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: _inter,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.mutedText,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: _inter,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
  );

  /// Monospace style for symbols, prices, licence keys, timestamps — mirrors
  /// the website's use of JetBrains Mono for compact trading data. Every
  /// call site in this app uses the default (w500) weight — only that
  /// weight is bundled; passing a different one falls back to the platform
  /// default monospace font rather than fetching anything at runtime.
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.ghostWhite,
  }) =>
      TextStyle(
        fontFamily: _jetBrainsMono,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
}
