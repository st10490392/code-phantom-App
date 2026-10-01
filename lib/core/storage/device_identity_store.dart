import 'dart:math';
import '../storage/secure_storage.dart';

/// Privacy-preserving device identity for CodePhantom licensing.
///
/// The installation id is random app data, not IMEI / Android ID / serial /
/// MAC address. The backend hashes it before storage. Backend-issued device
/// ids are stored per account so signing into a different CodePhantom
/// account on the same phone can never leak another account's device binding.
class DeviceIdentityStore {
  DeviceIdentityStore(this._storage);

  final SecureStorage _storage;

  static const _installationIdKey = 'licensing_installation_id';
  static const _serverDeviceIdPrefix = 'licensing_server_device_id:';

  Future<String> getOrCreateInstallationId() async {
    final existing = await _storage.read(_installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuidV4();
    await _storage.write(_installationIdKey, created);
    return created;
  }

  Future<String?> readServerDeviceId(String userId) =>
      _storage.read('$_serverDeviceIdPrefix$userId');

  Future<void> saveServerDeviceId(String userId, String id) =>
      _storage.write('$_serverDeviceIdPrefix$userId', id);

  Future<void> clearServerDeviceId(String userId) =>
      _storage.delete('$_serverDeviceIdPrefix$userId');

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final raw = bytes.map(hex).join();
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
  }
}
