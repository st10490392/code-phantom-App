import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'device_identity.dart';

/// The app-generated identifiers this installation presents to the two
/// backends. Both are created once, in secure storage, and never logged.
final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(ref.watch(secureStorageProvider)),
);

/// This app's own device identifier (a random UUID; the backend stores only
/// its hash). Surfaced on the Profile screen so a user can confirm which
/// device their licence is bound to without exposing anything secret.
final deviceIdProvider = FutureProvider<String>((ref) => ref.watch(deviceIdentityProvider).deviceId());

/// Whether the backend has bound this device to the account's licence — i.e.
/// whether `POST /licences/activate` succeeded, which is the only thing that
/// makes `X-CP-Device-Id` a truthful claim.
final deviceBoundProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceIdentityProvider).isDeviceBound(),
);

/// Whether this device has been bound by the backend's licence activation.
final deviceBoundRegistryProvider = Provider<DeviceBoundRegistry>(
  (ref) => DeviceBoundRegistry(ref.watch(deviceIdentityProvider)),
);
