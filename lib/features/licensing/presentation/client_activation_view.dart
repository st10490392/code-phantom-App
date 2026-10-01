import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import 'licensing_providers.dart';

class ClientActivationView extends ConsumerStatefulWidget {
  const ClientActivationView({super.key});

  @override
  ConsumerState<ClientActivationView> createState() =>
      _ClientActivationViewState();
}

class _ClientActivationViewState extends ConsumerState<ClientActivationView> {
  final _keyController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Enter the activation key you received from CodePhantom.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final service = ref.read(licensingServiceProvider);
      if (service == null) {
        throw StateError('Licensing is unavailable in this build.');
      }
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) {
        throw StateError('No signed-in account is available for activation.');
      }
      await service.activate(key, userId: userId);
      await ref.read(authControllerProvider.notifier).refreshAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'Activation failed. Check the key and try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.vpn_key_outlined,
                    color: AppColors.cyberBlue,
                    size: 46,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Activate CPT Scanner',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your CodePhantom account is ready. Enter the one-time Scanner key provided by CodePhantom to bind this installation and unlock approved Scanner setups and published signals.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PhantomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _keyController,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Scanner activation key',
                            hintText: 'CPA-XXXX-XXXX-XXXX-XXXX',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        PhantomButton(
                          label: 'Activate Scanner',
                          expand: true,
                          isLoading: _busy,
                          onPressed: _busy ? null : _activate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Each activation key can be redeemed only once. The licence is permanently linked to the account and this installation. If you replace or reset your device, contact CodePhantom for a replacement-device key.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
