import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Glow shadows mirroring the website's `.shadow-glow` / `.shadow-glow-blue`.
///
/// Used sparingly (primary CTAs, EA "online" indicator) — the brand
/// direction explicitly warns against overusing neon/glow effects.
abstract final class AppShadows {
  static List<BoxShadow> glowPurple = [
    BoxShadow(
      color: AppColors.phantomPurple.withValues(alpha: 0.25),
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> glowBlue = [
    BoxShadow(
      color: AppColors.cyberBlue.withValues(alpha: 0.25),
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> cardElevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
