import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Matches the website's three font families:
/// display = Space Grotesk, body = Inter, mono = JetBrains Mono.
abstract final class AppTypography {
  static TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.spaceGrotesk(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.ghostWhite,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.spaceGrotesk(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
      height: 1.25,
    ),
    headlineMedium: GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
    headlineSmall: GoogleFonts.spaceGrotesk(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.ghostWhite,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.ghostWhite,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.mutedText,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.ghostWhite,
    ),
  );

  /// Monospace style for symbols, prices, licence keys, timestamps — mirrors
  /// the website's use of JetBrains Mono for compact trading data.
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.ghostWhite,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
}
