import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Premium, restrained loading state (no default Material spinner look).
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(AppColors.cyberBlue),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.mutedText, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
