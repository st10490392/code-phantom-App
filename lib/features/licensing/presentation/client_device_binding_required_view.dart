import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import 'licensing_providers.dart';

/// Shown when a licensed account signs in on a different installation.
/// The original activation key cannot be reused; a support-issued one-time
/// device-binding key moves the licence and revokes the old device binding.
class ClientDeviceBindingRequiredView extends ConsumerStatefulWidget {
  const ClientDeviceBindingRequiredView({super.key});

  @override
  ConsumerState<ClientDeviceBindingRequiredView> createState() =>
      _ClientDeviceBindingRequiredViewState();
}

class _ClientDeviceBindingRequiredViewState
    extends ConsumerState<ClientDeviceBindingRequiredView> {
  final _keyController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _authorizeDevice() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Enter the replacement device key provided by CodePhantom.');
      return;
    }

    final userId = ref.read(currentUserProvider)?.id;
    final service = ref.read(licensingServiceProvider);
    if (userId == null || service == null) {
      setState(() => _error = 'Device authorization is unavailable in this build.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await service.rebindDevice(key, userId: userId);
      ref.invalidate(boundDeviceIdProvider(userId));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'Could not authorize this device. Check the key and try again.';
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
                    Icons.phonelink_lock_outlined,
                    color: AppColors.warning,
                    size: 46,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Device authorization required',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'This account already has CPT Scanner access, but this installation is not the device currently bound to the licence.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PhantomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Contact CodePhantom after your identity is verified. You will receive a one-time replacement device key.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _keyController,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Replacement device key',
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
                          label: 'Authorize this device',
                          expand: true,
                          isLoading: _busy,
                          onPressed: _busy ? null : _authorizeDevice,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'When the replacement key is redeemed, CodePhantom revokes the previous device binding. Sharing the APK or account password does not transfer the Scanner licence.',
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
