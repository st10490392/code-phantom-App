import 'secure_storage.dart';

/// Persists exactly the session fields a client needs and nothing else:
/// access token, refresh token, and expiry. Built on [SecureStorage]
/// (`flutter_secure_storage`), so nothing here ever touches
/// `shared_preferences` or plain disk storage.
///
/// Deliberately never stores: the account password, Supabase's service-role
/// key, the database URL/password, `LICENCE_KEY_PEPPER`, or any WhatsApp
/// secret — none of those ever appear in a backend response the client
/// receives, so there is nothing to accidentally persist here.
class TokenStorage {
  TokenStorage(this._secureStorage);

  final SecureStorage _secureStorage;

  static const _accessTokenKey = 'api_access_token';
  static const _refreshTokenKey = 'api_refresh_token';
  static const _expiresAtKey = 'api_expires_at';

  Future<void> save({
    required String accessToken,
    String? refreshToken,
    required DateTime expiresAt,
  }) async {
    await _secureStorage.write(_accessTokenKey, accessToken);
    if (refreshToken != null) {
      await _secureStorage.write(_refreshTokenKey, refreshToken);
    }
    await _secureStorage.write(_expiresAtKey, expiresAt.toIso8601String());
  }

  Future<String?> readAccessToken() => _secureStorage.read(_accessTokenKey);

  Future<String?> readRefreshToken() => _secureStorage.read(_refreshTokenKey);

  Future<DateTime?> readExpiresAt() async {
    final raw = await _secureStorage.read(_expiresAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> hasStoredSession() async => (await readAccessToken()) != null;

  Future<void> clear() async {
    await _secureStorage.delete(_accessTokenKey);
    await _secureStorage.delete(_refreshTokenKey);
    await _secureStorage.delete(_expiresAtKey);
  }
}
