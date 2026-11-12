import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/device/device_identity.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../live_feed/presentation/live_feed_providers.dart';
import '../../trading_status/presentation/trading_status_providers.dart';
import '../data/bridge_licence_service.dart';
import '../data/licence_activation_service.dart';
import '../domain/licence.dart';

/// Activation/validation against the Node backend's licence records
/// (`POST /licences/activate`, `/licences/validate`). Available in every
/// connected environment — this is the account-side licence system.
final licenceActivationServiceProvider = Provider<ApiLicenceActivationService>((ref) {
  final identity = ref.watch(deviceIdentityProvider);
  return ApiLicenceActivationService(
    ref.watch(apiClientProvider),
    identity,
    DeviceBoundRegistry(identity),
  );
});

/// Activation against the trading bridge's own key store
/// (`POST /api/v1/license/activate`). Only builds explicitly pointed at a
/// bridge have one; mock/unconfigured builds get `null` and the UI shows
/// "no bridge configured for this build" instead of a dead button.
final bridgeLicenceServiceProvider = Provider<BridgeLicenceService?>((ref) {
  if (ref.watch(appEnvironmentProvider) == AppEnvironment.mock) return null;
  final client = ref.watch(bridgeClientProvider);
  if (client == null) return null;
  return BridgeLicenceService(
    client: client,
    credentials: ref.watch(bridgeCredentialStorageProvider),
    identity: ref.watch(deviceIdentityProvider),
  );
});

/// Whether this device's `SIGNALS` key has been activated on the bridge, i.e.
/// whether the live feed has anything to authenticate with. Derived from
/// secure storage, never assumed.
final bridgeSignalsKeyActiveProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(bridgeCredentialStorageProvider).hasSignalsKey();
});

/// Activate a backend licence key on this device, then re-subscribe the live
/// feed so a freshly bound device starts receiving events without a restart.
Future<Licence> activateBackendLicence(
  WidgetRef ref, {
  required String licenceKey,
  required String platform,
  String? friendlyName,
}) async {
  final service = ref.read(licenceActivationServiceProvider);
  final identity = ref.read(deviceIdentityProvider);
  final licence = await service.activate(
    licenceKey: licenceKey,
    device: LicenceDevice(
      identifier: await identity.deviceId(),
      platform: platform,
      friendlyName: friendlyName,
    ),
  );
  await restartLiveFeed(ref);
  return licence;
}

/// Activate a bridge key. A `SIGNALS` key is stored in secure storage and the
/// feed re-subscribes with it; an `EA` key is never stored — it is the
/// operator's execution entitlement and this app must not hold it.
Future<BridgeLicenceActivation> activateBridgeLicence(
  WidgetRef ref, {
  required String key,
  required String serviceType,
}) async {
  final service = ref.read(bridgeLicenceServiceProvider);
  if (service == null) {
    throw Exception('No trading bridge is configured for this build.');
  }
  final result = await service.activate(key: key, serviceType: serviceType);
  if (serviceType == 'SIGNALS') {
    await restartLiveFeed(ref);
  }
  return result;
}

/// Drops the stored `SIGNALS` key and unsubscribes, e.g. after a licence is
/// revoked server-side.
Future<void> forgetBridgeSignalsKey(WidgetRef ref) => clearLiveFeedCredentials(ref);
