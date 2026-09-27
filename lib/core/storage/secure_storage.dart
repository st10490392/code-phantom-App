import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'key_value_store.dart';
import 'web_key_value_store.dart';

/// Storage for tokens and any future secrets. Never use
/// `shared_preferences` for anything in this file's domain — see
/// docs/ARCHITECTURE.md §8.
///
/// Android/iOS: `flutter_secure_storage` (Keystore-backed
/// EncryptedSharedPreferences / Keychain). Web: browser storage, which has
/// no OS-level protection — see `WebKeyValueStore` and docs/WEB.md.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage, KeyValueStore? store})
      : _store = store ??
            (kIsWeb && storage == null
                ? createWebKeyValueStore()
                : _FlutterSecureKeyValueStore(
                    storage ??
                        const FlutterSecureStorage(
                          aOptions: AndroidOptions(encryptedSharedPreferences: true),
                        ),
                  ));

  final KeyValueStore _store;

  Future<void> write(String key, String value) => _store.write(key, value);

  Future<String?> read(String key) => _store.read(key);

  Future<void> delete(String key) => _store.delete(key);
}

class _FlutterSecureKeyValueStore implements KeyValueStore {
  const _FlutterSecureKeyValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
