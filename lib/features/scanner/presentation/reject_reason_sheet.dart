import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';

/// Canned rejection reasons shown as quick-pick chips; "Other" reveals a
/// free-text field instead of forcing one of the fixed options.
const List<String> scannerRejectionReasons = [
  'Invalid structure',
  'Poor R:R',
  'News risk',
  'Setup expired',
  'Duplicate',
  'Manual rejection',
  'Other',
];

/// Returns the chosen reason text, or `null` if the sheet was dismissed
/// without rejecting.
Future<String?> showRejectReasonSheet(BuildContext context) {
  return showPhantomModalSheet<String>(
    context: context,
    title: 'Reject setup',
    builder: (context) => const _RejectReasonBody(),
  );
}

class _RejectReasonBody extends StatefulWidget {
  const _RejectReasonBody();

  @override
  State<_RejectReasonBody> createState() => _RejectReasonBodyState();
}

class _RejectReasonBodyState extends State<_RejectReasonBody> {
  String? _selected;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _isOther => _selected == 'Other';

  String? get _resolvedReason {
    if (_selected == null) return null;
    if (_isOther) {
      final text = _otherController.text.trim();
      return text.isEmpty ? null : text;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedReason;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why is this setup being rejected?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final reason in scannerRejectionReasons)
              PhantomChip(
                label: reason,
                selected: _selected == reason,
                onTap: () => setState(() => _selected = reason),
              ),
          ],
        ),
        if (_isOther) ...[
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'Reason',
            controller: _otherController,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PhantomButton(
          label: 'Reject setup',
          expand: true,
          onPressed: resolved == null ? null : () => Navigator.of(context).pop(resolved),
        ),
      ],
    );
  }
}
