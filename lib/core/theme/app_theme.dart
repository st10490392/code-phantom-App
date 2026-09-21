import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles a single dark `ThemeData` from the design tokens above.
/// Dark-mode-first per brand direction; no light theme in Phase 1.
abstract final class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.phantomBlack,
      canvasColor: AppColors.phantomBlack,
      primaryColor: AppColors.phantomPurple,
      textTheme: AppTypography.textTheme,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.phantomPurple,
        secondary: AppColors.cyberBlue,
        tertiary: AppColors.electricBlue,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.ghostWhite,
        onSurface: AppColors.ghostWhite,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.phantomBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.textTheme.headlineSmall,
        iconTheme: const IconThemeData(color: AppColors.ghostWhite),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.midnightNavy,
        indicatorColor: AppColors.phantomPurple.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.textTheme.bodySmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.ghostWhite
                : AppColors.mutedText,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.electricBlue
                : AppColors.mutedText,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.textTheme.bodyMedium
            ?.copyWith(color: AppColors.mutedText),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: BorderSide(color: AppColors.borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: BorderSide(color: AppColors.borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: const BorderSide(color: AppColors.cyberBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.modalRadius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.modal),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: AppTypography.textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
      ),
    );
  }
}
