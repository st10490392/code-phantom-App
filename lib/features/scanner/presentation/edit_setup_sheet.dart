import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';
import 'scanner_providers.dart';

/// Edit-before-approval: entry / stop loss / take profits / notes, and
/// (per the brief, "only if the architecture supports it cleanly" — it
/// does, both are plain fields) direction and timeframe. The original
/// detection timestamp is never shown here as editable — there is no
/// field for it, so it can't be changed by this form even by mistake.
Future<void> showEditSetupSheet(BuildContext context, ScannerSetup setup) {
  return showPhantomModalSheet(
    context: context,
    title: 'Edit ${setup.symbol} setup',
    builder: (context) => _EditSetupBody(setup: setup),
  );
}

class _EditSetupBody extends ConsumerStatefulWidget {
  const _EditSetupBody({required this.setup});
  final ScannerSetup setup;

  @override
  ConsumerState<_EditSetupBody> createState() => _EditSetupBodyState();
}

class _EditSetupBodyState extends ConsumerState<_EditSetupBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _entryController;
  late final TextEditingController _stopLossController;
  late final TextEditingController _tp1Controller;
  late final TextEditingController _tp2Controller;
  late final TextEditingController _tp3Controller;
  late final TextEditingController _timeframeController;
  late final TextEditingController _notesController;
  late SetupDirection _direction;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.setup;
    _entryController = TextEditingController(text: s.entry.toString());
    _stopLossController = TextEditingController(text: s.stopLoss.toString());
    _tp1Controller = TextEditingController(text: s.tp1?.toString() ?? '');
    _tp2Controller = TextEditingController(text: s.tp2?.toString() ?? '');
    _tp3Controller = TextEditingController(text: s.tp3?.toString() ?? '');
    _timeframeController = TextEditingController(text: s.timeframe);
    _notesController = TextEditingController(text: s.notes ?? '');
    _direction = s.direction;
  }

  @override
  void dispose() {
    _entryController.dispose();
    _stopLossController.dispose();
    _tp1Controller.dispose();
    _tp2Controller.dispose();
    _tp3Controller.dispose();
    _timeframeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parse(String text) => double.tryParse(text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final takeProfits = [_tp1Controller, _tp2Controller, _tp3Controller]
        .map((c) => _parse(c.text))
        .whereType<double>()
        .toList();

    final edited = widget.setup.copyWith(
      direction: _direction,
      timeframe: _timeframeController.text.trim(),
      entry: _parse(_entryController.text),
      stopLoss: _parse(_stopLossController.text),
      takeProfits: takeProfits,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(scannerReviewControllerProvider.notifier).updateSetup(edited);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save changes.\n$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PhantomChip(
                  label: 'BUY',
                  selected: _direction == SetupDirection.buy,
                  onTap: () => setState(() => _direction = SetupDirection.buy),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PhantomChip(
                  label: 'SELL',
                  selected: _direction == SetupDirection.sell,
                  onTap: () => setState(() => _direction = SetupDirection.sell),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'Timeframe',
            controller: _timeframeController,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'Entry',
            controller: _entryController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _parse(v ?? '') == null ? 'Enter a number' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'Stop loss',
            controller: _stopLossController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _parse(v ?? '') == null ? 'Enter a number' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'TP1',
            controller: _tp1Controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'TP2 (optional)',
            controller: _tp2Controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'TP3 (optional)',
            controller: _tp3Controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomTextField(
            label: 'Notes',
            controller: _notesController,
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          PhantomButton(
            label: 'Save changes',
            expand: true,
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
