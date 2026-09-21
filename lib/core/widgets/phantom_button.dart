import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

enum PhantomButtonVariant { primary, secondary, ghost }

/// Mirrors the website's three button variants (`components/ui/button.tsx`):
/// primary = brand gradient fill, secondary = silver border, ghost = text-only.
class PhantomButton extends StatelessWidget {
  const PhantomButton({
    required this.label,
    required this.onPressed,
    this.variant = PhantomButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final PhantomButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = _buildContent();
    final button = switch (variant) {
      PhantomButtonVariant.primary => _PrimaryShell(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      PhantomButtonVariant.secondary => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ghostWhite,
            side: BorderSide(color: AppColors.borderMedium),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          child: child,
        ),
      PhantomButtonVariant.ghost => TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(foregroundColor: AppColors.ghostWhite),
          child: child,
        ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 8),
        Icon(icon, size: 16),
      ],
    );
  }
}

class _PrimaryShell extends StatelessWidget {
  const _PrimaryShell({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? AppColors.brandGradient : null,
        color: enabled ? null : AppColors.surfaceRaised,
        borderRadius: AppRadius.pillRadius,
        boxShadow: enabled ? AppShadows.glowPurple : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.pillRadius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: AppColors.ghostWhite,
                fontWeight: FontWeight.w600,
              ),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
