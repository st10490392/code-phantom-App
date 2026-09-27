import 'package:web/web.dart' as web;
import 'key_value_store.dart';

/// Browser session storage for the web build.
///
/// Values live in `window.localStorage` under a `codephantom.` prefix so the
/// installed PWA stays signed in across launches. This is deliberately
/// plain: any client-side encryption would keep its key in the same origin
/// storage and add no protection. Anything that can run script on this
/// origin (XSS) can read these values, which is why the web build ships a
/// strict Content-Security-Policy and never renders untrusted HTML — see
/// docs/WEB.md "Token storage". Only CodePhantom's own keys are ever
/// removed; other origin storage is left untouched.
class WebKeyValueStore implements KeyValueStore {
  static const _prefix = 'codephantom.';

  @override
  Future<void> write(String key, String value) async => web.window.localStorage.setItem('$_prefix$key', value);

  @override
  Future<String?> read(String key) async => web.window.localStorage.getItem('$_prefix$key');

  @override
  Future<void> delete(String key) async => web.window.localStorage.removeItem('$_prefix$key');
}

KeyValueStore createWebKeyValueStore() => WebKeyValueStore();
