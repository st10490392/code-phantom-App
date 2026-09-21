import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Neutral pill chip for tags/filters (session, timeframe, technologies...).
class PhantomChip extends StatelessWidget {
  const PhantomChip({
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.electricBlue : AppColors.mutedText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.electricBlue.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(
            color: selected ? AppColors.electricBlue.withValues(alpha: 0.5) : AppColors.borderMedium,
          ),
        ),
        child: Text(label, style: AppTypography.mono(fontSize: 12, color: color)),
      ),
    );
  }
}
