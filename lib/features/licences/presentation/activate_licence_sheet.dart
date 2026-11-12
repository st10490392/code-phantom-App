import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/phantom_button.dart';
import '../../../core/widgets/phantom_card.dart';
import '../../../core/widgets/phantom_modal_sheet.dart';
import '../../../core/widgets/phantom_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../live_feed/data/live_feed_service.dart';
import '../../live_feed/presentation/live_feed_providers.dart';
import 'licence_activation_providers.dart';
import 'licences_providers.dart';

/// Activating a licence on THIS device. Two separate systems, shown as two
/// separate actions, because the two backends issue different kinds of key:
///
/// - the Node backend's licence record (`POST /licences/activate`) binds this
///   app's device identifier to the account's licence row, which is what turns
///   `X-CP-Device-Id` on and unlocks protected content;
/// - the trading bridge's `SIGNALS` key (`POST /api/v1/license/activate`)
///   authorizes the live feed and push registration for this hardware id.
///
/// An EA key is refused here on purpose: it authorizes the daemon's own
/// execution, never this app's signal feed.
class ActivateLicenceSheet extends ConsumerStatefulWidget {
  const ActivateLicenceSheet({super.key});

  @override
  ConsumerState<ActivateLicenceSheet> createState() => _ActivateLicenceSheetState();
}

Future<void> showActivateLicenceSheet(BuildContext context) => showPhantomModalSheet<void>(
      context: context,
      title: 'Activate licence',
      builder: (context) => const ActivateLicenceSheet(),
    );

class _ActivateLicenceSheetState extends ConsumerState<ActivateLicenceSheet> {
  final _backendKeyController = TextEditingController();
  final _bridgeKeyController = TextEditingController();
  bool _backendBusy = false;
  bool _bridgeBusy = false;
  String? _error;
  String? _result;

  @override
  void dispose() {
    _backendKeyController.dispose();
    _bridgeKeyController.dispose();
    super.dispose();
  }

  /// The backend's `device.platform` enum is `ANDROID`/`IOS`/`WEB`-shaped; a
  /// desktop/browser session is reported as `WEB`, never as a phone.
  String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'ANDROID',
        TargetPlatform.iOS => 'IOS',
        _ => 'WEB',
      };

  /// A rejected key is reported as "not valid for this device", never with the
  /// bridge's reason, which can name the key itself.
  Future<void> _activate(Future<String> Function() action, void Function() begin, void Function() end) async {
    begin();
    setState(() {
      _error = null;
      _result = null;
    });
    String? result;
    try {
      result = await action();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'The request was refused. Check the key and try again.');
    } finally {
      end();
    }
    if (result != null) setState(() => _result = result);
  }

  Future<void> _activateBackendLicence() => _activate(
        () async {
          final licence = await activateBackendLicence(
            ref,
            licenceKey: _backendKeyController.text.trim(),
            platform: _platform,
            friendlyName: _platform == 'WEB' ? 'Browser session' : null,
          );
          ref.invalidate(licenceListProvider);
          return 'Activated: ${licence.product} (${licence.status.wireValue}).';
        },
        () => setState(() => _backendBusy = true),
        () => setState(() => _backendBusy = false),
      );

  Future<void> _activateBridgeSignalsKey() => _activate(
        () async {
          final result = await activateBridgeLicence(
            ref,
            key: _bridgeKeyController.text.trim(),
            serviceType: 'SIGNALS',
          );
          return 'SIGNALS key bound (${result.status}) - live feed reconnected.';
        },
        () => setState(() => _bridgeBusy = true),
        () => setState(() => _bridgeBusy = false),
      );


  @override
  Widget build(BuildContext context) {
    final bridgeAvailable = ref.watch(bridgeLicenceServiceProvider) != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhantomTextField(
          label: 'Licence key',
          controller: _backendKeyController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        PhantomButton(
          label: 'Activate on this device',
          isLoading: _backendBusy,
          // No key typed, nothing to send: the button stays disabled rather
          // than firing a request the backend would reject as invalid.
          onPressed: _backendBusy || _backendKeyController.text.trim().isEmpty
              ? null
              : _activateBackendLicence,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Binds this device to your account licence. The backend hashes the identifier this '
          'app generates; it is never a hardware fingerprint.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (bridgeAvailable) ...[
          PhantomTextField(
            label: 'SIGNALS key (trading bridge)',
            controller: _bridgeKeyController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomButton(
            label: 'Activate SIGNALS key',
            variant: PhantomButtonVariant.secondary,
            isLoading: _bridgeBusy,
            onPressed: _bridgeBusy || _bridgeKeyController.text.trim().isEmpty
                ? null
                : _activateBridgeSignalsKey,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'An EA key is not accepted here: it authorizes the daemon own execution, never this '
            'app signal feed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ] else
          Text(
            'No trading bridge is configured for this build, so there is no SIGNALS key to activate.',
            style: AppTypography.mono(fontSize: 12, color: AppColors.mutedText),
          ),
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_result!, style: const TextStyle(color: AppColors.success)),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _FeedStatusRow(),
      ],
    );
  }
}

/// Whether the live feed can authenticate with this device key, derived from
/// secure storage and the feed own state - never assumed.
class _FeedStatusRow extends ConsumerWidget {
  const _FeedStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(liveFeedStatusProvider).value ?? LiveFeedStatus.unconfigured;
    final keyStored = ref.watch(bridgeSignalsKeyActiveProvider).value ?? false;
    return PhantomCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              keyStored ? 'SIGNALS key stored' : 'No SIGNALS key stored',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          StatusBadge(
            label: _feedLabel(status),
            color: status == LiveFeedStatus.live ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

String _feedLabel(LiveFeedStatus status) => switch (status) {
      LiveFeedStatus.live => 'Feed live',
      LiveFeedStatus.connecting => 'Feed connecting',
      LiveFeedStatus.reconnecting => 'Feed reconnecting',
      LiveFeedStatus.unavailable => 'Feed down',
      LiveFeedStatus.unauthenticated => 'No key',
      LiveFeedStatus.unconfigured => 'No bridge',
    };
