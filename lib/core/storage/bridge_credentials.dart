import '../../../core/storage/secure_storage.dart';

/// Credentials the live trading bridge accepts, held in secure storage.
///
/// Only the caller's own `SIGNALS` licence key and — for an operator build —
/// the bridge's control token live here. Nothing else: MT5 credentials, the
/// daemon's own `PHANTOM_LICENSE_KEY` (`EA`), the Supabase service-role key and
/// any backend secret are never present in a response this app receives, so
/// there is nothing here that could accidentally be persisted.
class BridgeCredentialStorage {
  BridgeCredentialStorage(this._storage);

  final SecureStorage _storage;

  static const _signalsKeyKey = 'bridge_signals_key';
  static const _controlTokenKey = 'bridge_control_token';

  Future<void> saveSignalsKey(String key) => _storage.write(_signalsKeyKey, key);

  Future<String?> readSignalsKey() => _storage.read(_signalsKeyKey);

  Future<void> clearSignalsKey() => _storage.delete(_signalsKeyKey);

  Future<bool> hasSignalsKey() async => await readSignalsKey() != null;

  /// Operator builds only (`--dart-define=BRIDGE_CONTROL_TOKEN=…` is refused;
  /// see `docs/BRIDGE_INTEGRATION.md`). Ordinary clients never hold this.
  Future<void> saveControlToken(String token) => _storage.write(_controlTokenKey, token);

  Future<String?> readControlToken() => _storage.read(_controlTokenKey);

  Future<void> clearControlToken() => _storage.delete(_controlTokenKey);
}
