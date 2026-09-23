import 'package:code_phantom_app/core/storage/secure_storage.dart';

/// In-memory [SecureStorage] double — never touches the real
/// `flutter_secure_storage` platform channel (unavailable in `flutter_test`).
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}
