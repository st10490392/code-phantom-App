import 'dart:math';

import '../storage/secure_storage.dart';

/// The two identities this app presents to the two backends, generated once
/// per installation and kept in secure storage.
///
/// - [deviceId] is the Node backend's `device_identifier` /
///   `X-CP-Device-Id` / push `device_id`: a random UUID, never derived from
///   hardware, so it cannot be used to fingerprint the user beyond their own
///   account (docs/DEVICE_BINDING.md).
/// - [hardwareId] is the trading bridge's `hardware_id`, which its licence
///   store binds a key to permanently.
///
/// Neither is secret in the sense of a credential — but neither belongs in a
/// log, and both live in `flutter_secure_storage`, not `shared_preferences`.
class DeviceIdentity {
  DeviceIdentity(this._storage);

  final SecureStorage _storage;

  static const _deviceIdKey = 'account_device_id';
  static const _hardwareIdKey = 'device_hardware_id';
  static const _deviceBoundKey = 'device_bound';

  Future<String> deviceId() => _readOrCreate(_deviceIdKey);

  Future<String> hardwareId() => _readOrCreate(_hardwareIdKey);

  /// Set once the account's licence has actually bound this device
  /// (`POST /licences/activate` succeeded). Only then does `ApiClient` send
  /// `X-CP-Device-Id`: sending an unbound id would make the backend's
  /// `deviceGate` reject every protected request.
  Future<void> markDeviceBound() => _storage.write(_deviceBoundKey, 'true');

  Future<bool> isDeviceBound() async => await _storage.read(_deviceBoundKey) == 'true';

  Future<String> _readOrCreate(String key) async {
    final existing = await _storage.read(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = uuidV4();
    await _storage.write(key, created);
    return created;
  }
}

/// Whether this device is bound to a licence by the backend. A small registry
/// because `ApiClient` must decide per request, and sending `X-CP-Device-Id`
/// before a real activation would make the backend's `deviceGate` reject every
/// protected request.
class DeviceBoundRegistry {
  DeviceBoundRegistry(this._identity);

  final DeviceIdentity _identity;

  Future<void> markBound() => _identity.markDeviceBound();
  Future<bool> isBound() => _identity.isDeviceBound();
}

/// RFC 4122 v4 UUID from the CSPRNG — the same shape the backend's Zod
/// `uuid()` schemas and `deviceGate`'s regex require.
String uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
