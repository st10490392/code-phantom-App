import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Base card surface used across dashboard tiles, list rows, and detail
/// panels — mirrors the website's `bg-surface/40` + subtle border cards.
class PhantomCard extends StatelessWidget {
  const PhantomCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.raised = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: raised ? AppColors.surfaceRaised : AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
