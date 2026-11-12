import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bridge_credentials.dart';
import 'secure_storage.dart';
import 'token_storage.dart';

/// The single `SecureStorage` instance for the whole app: tokens, device
/// identifiers and bridge credentials all live in this one Keystore-backed
/// store. Defined in `core` so the device and bridge layers can reach it
/// without importing a feature module; `auth_providers.dart` re-exports it so
/// existing call sites keep the same import path.
final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

/// Keystore-backed store for session tokens. Never `shared_preferences`.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);

/// See `bridge_credentials.dart` for exactly what may be stored here.
final bridgeCredentialStorageProvider = Provider<BridgeCredentialStorage>(
  (ref) => BridgeCredentialStorage(ref.watch(secureStorageProvider)),
);
