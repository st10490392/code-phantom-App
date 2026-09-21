import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/licence_enums.dart';
import 'licences_providers.dart';

const _products = ['Scanner', 'Signals', 'EA'];

Future<void> showGenerateLicenceSheet(BuildContext context) {
  return showPhantomModalSheet(
    context: context,
    title: 'Generate licence',
    builder: (context) => const _GenerateLicenceBody(),
  );
}

class _GenerateLicenceBody extends ConsumerStatefulWidget {
  const _GenerateLicenceBody();

  @override
  ConsumerState<_GenerateLicenceBody> createState() => _GenerateLicenceBodyState();
}

class _GenerateLicenceBodyState extends ConsumerState<_GenerateLicenceBody> {
  final _userIdController = TextEditingController();
  String _product = _products.first;
  LicenceDuration _duration = LicenceDuration.thirtyDays;
  int _maxDevices = 1;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhantomTextField(label: 'User ID', controller: _userIdController),
        const SizedBox(height: AppSpacing.lg),
        Text('Service', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final p in _products)
              PhantomChip(
                label: p,
                selected: _product == p,
                onTap: () => setState(() => _product = p),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Duration', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final d in LicenceDuration.values)
              PhantomChip(
                label: d.label,
                selected: _duration == d,
                onTap: () => setState(() => _duration = d),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text('Max devices', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _maxDevices > 1 ? () => setState(() => _maxDevices--) : null,
            ),
            Text('$_maxDevices'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => _maxDevices++),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PhantomButton(
          label: 'Generate key',
          expand: true,
          isLoading: _isSubmitting,
          onPressed: _userIdController.text.trim().isEmpty
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  await ref.read(licenceServiceProvider).generate(
                        userId: _userIdController.text.trim(),
                        product: _product,
                        duration: _duration,
                        maxDevices: _maxDevices,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}
