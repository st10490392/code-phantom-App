import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';

/// Shown when an already-licensed account signs in on an installation that
/// is not the device bound during first activation. Protected backend routes
/// will refuse this installation until CodePhantom issues a replacement key.
class ClientDeviceBindingRequiredView extends StatelessWidget {
  const ClientDeviceBindingRequiredView({super.key});

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
                    'This account already has CPT Scanner access, but this installation is not the device that was activated for the licence.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const PhantomCard(
                    child: Text(
                      'For account security, the original one-time activation key cannot be reused. Contact CodePhantom to move the licence to a replacement device.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Sharing the APK or account password does not transfer the Scanner licence to another device.',
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
