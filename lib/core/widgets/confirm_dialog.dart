import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'phantom_button.dart';

/// Standard confirmation dialog for destructive/irreversible actions
/// (emergency stop, revoke licence, suspend account...).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(color: AppColors.mutedText)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        PhantomButton(
          label: confirmLabel,
          variant: destructive
              ? PhantomButtonVariant.secondary
              : PhantomButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
