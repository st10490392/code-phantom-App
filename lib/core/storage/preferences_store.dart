import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive UI preferences only (e.g. "last selected scanner tab").
/// Never store tokens or secrets here — use `secure_storage.dart`.
class PreferencesStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> setString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  Future<void> setBool(String key, {required bool value}) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _prefs;
    return prefs.getBool(key);
  }
}
