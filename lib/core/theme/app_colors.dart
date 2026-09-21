import 'package:flutter/material.dart';

/// CodePhantom Technologies brand colours, carried over 1:1 from
/// `code-phantom-website`'s `tailwind.config.ts` / `globals.css` so the
/// mobile app and the website read as the same product family.
///
/// Do not hard-code hex values in widgets — always reference these tokens.
/// A future white-label skin only needs a new `core/theme/` implementation.
abstract final class AppColors {
  // --- Backgrounds & surfaces (website: phantom-black / midnight-navy /
  // surface / surface-raised) ---
  static const Color phantomBlack = Color(0xFF05070D);
  static const Color midnightNavy = Color(0xFF09111F);
  static const Color surface = Color(0xFF0D1627);
  static const Color surfaceRaised = Color(0xFF121D33);

  // --- Brand accents (website: phantom-purple / cyber-blue / electric-blue) ---
  static const Color phantomPurple = Color(0xFF7C3AED);
  static const Color cyberBlue = Color(0xFF168BFF);
  static const Color electricBlue = Color(0xFF00BFFF);

  // --- Neutral text & borders (website: metallic-silver / muted-text / ghost-white) ---
  static const Color metallicSilver = Color(0xFFC9CDD5);
  static const Color mutedText = Color(0xFF8792A5);
  static const Color ghostWhite = Color(0xFFF5F7FA);

  /// website: `.phantom-gradient`
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [phantomPurple, cyberBlue, electricBlue],
    stops: [0.0, 0.6, 1.0],
  );

  // --- Semantic system colours ---
  // Chosen to harmonize with, never replace, the brand palette above.
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFEF4444);

  /// Reserved for EA emergency states (more saturated than [error]).
  static const Color critical = Color(0xFFFF3B5C);
  static const Color neutral = metallicSilver;

  // --- Trading-specific semantics ---
  static const Color buy = success;
  static const Color sell = error;
  static const Color online = success;
  static const Color offline = Color(0xFF6B7280);

  /// Standard border colour used across cards/dividers.
  static Color borderSubtle = metallicSilver.withValues(alpha: 0.10);
  static Color borderMedium = metallicSilver.withValues(alpha: 0.20);
}
