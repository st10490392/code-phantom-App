import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'phone_alert.dart';
import 'push_transport.dart';

/// Serializes registration / rotation / logout. Late token callbacks cannot
/// re-register a logged-out user. The backend is the entitlement authority.
class PhonePushController extends ChangeNotifier {
  PhonePushController({required this.api, required this.storage, required this.platform, required this.createTransport});
  final ApiClient api;
  final SecureStorage storage;
  final String platform;
  final Future<PushTransport> Function()? createTransport;
  bool get available => createTransport != null;
  bool enabled = false;
  bool busy = false;
  String? error;
  String? _user;
  int _generation = 0;
  bool _disposed = false;
  PushTransport? _transport;
  Future<void> _pending = Future.value();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final _foreground = StreamController<PhoneAlert>.broadcast();
  final _opened = StreamController<PhoneAlert>.broadcast();
  final _seenForeground = <String>{};
  final _seenOpened = <String>{};
  Stream<PhoneAlert> get foreground => _foreground.stream;
  Stream<PhoneAlert> get opened => _opened.stream;

  Future<void> _run(Future<void> Function() action) {
    _pending = _pending.then((_) async {
      if (_disposed || !available) return;
      busy = true;
      error = null;
      notifyListeners();
      try { await action(); } catch (_) { error = 'Unable to update phone alerts. Try again.'; }
      finally { busy = false; if (!_disposed) notifyListeners(); }
    });
    return _pending;
  }

  Future<PushTransport> _initialize() async {
    if (_transport != null) return _transport!;
    final transport = await createTransport!();
    if (_disposed) throw StateError('disposed');
    _transport = transport;
    _subscriptions.add(
      transport.tokenRefresh.listen(
        (token) {
          final generation = _generation;
          unawaited(_run(() => _register(generation, token: token)));
        },
        onError: (_) {
          if (_disposed) return;
          error = 'Unable to update phone alerts. Try again.';
          notifyListeners();
        },
      ),
    );
    void emit(PhoneAlert alert, Set<String> seen, StreamController<PhoneAlert> stream, {bool tap = false}) {
      final generation = _generation;
      unawaited(_run(() async {
        if (_disposed || generation != _generation || (!tap && (_user == null || !enabled)) || !seen.add(alert.eventId)) return;
        if (seen.length > 100) seen.remove(seen.first);
        // Account-scoped bounded history survives restarts. Foreground and tap
        // receipts stay separate so viewing an alert is never suppressed.
        final key = 'push_seen_${_user ?? 'signed_out'}_${tap ? 'opened' : 'foreground'}';
        final raw = await storage.read(key);
        final ids = raw == null ? <String>[] : (jsonDecode(raw) as List).cast<String>();
        if (ids.contains(alert.eventId)) return;
        ids.add(alert.eventId);
        await storage.write(key, jsonEncode(ids.length > 100 ? ids.sublist(ids.length - 100) : ids));
        if (!_disposed && generation == _generation) stream.add(alert);
      }));
    }
    _subscriptions.add(transport.foreground.listen((alert) => emit(alert, _seenForeground, _foreground)));
    _subscriptions.add(transport.opened.listen((alert) => emit(alert, _seenOpened, _opened, tap: true)));
    final initial = await transport.initialAlert();
    if (initial != null) emit(initial, _seenOpened, _opened, tap: true);
    return transport;
  }

  Future<String> _installationId() async {
    final existing = await storage.read('push_installation_id');
    if (existing != null) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await storage.write('push_installation_id', id);
    return id;
  }

  Future<void> _register(int generation, {String? token}) async {
    if (generation != _generation || _user == null || !enabled) return;
    final transport = await _initialize();
    if (!await transport.permission(prompt: false)) {
      enabled = false;
      await storage.write('push_enabled', 'false');
      await _unregister();
      return;
    }
    final value = token ?? await transport.token();
    final installation = await _installationId();
    final deviceId = await storage.read('account_device_id');
    if (generation != _generation || _user == null || !enabled) return;
    if (value == null) { error = 'Phone alerts are still connecting. Try again shortly.'; return; }
    await api.post(
      '/notifications/push/register',
      body: {
        'installation_id': installation,
        'token': value,
        'platform': platform,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
  }

  Future<void> setUser(String? userId) {
    if (_user == userId) return Future.value();
    _seenForeground.clear();
    _seenOpened.clear();
    _user = userId;
    final generation = ++_generation;
    return _run(() async {
      enabled = await storage.read('push_enabled') == 'true';
      if (generation != _generation) return;
      if (userId == null) {
        await storage.write('push_pending_unregister', 'true');
        if (_transport != null) await _transport!.deleteToken();
        return;
      }
      await _initialize(); // captures cold-start taps; does not ask permission
      if (!enabled && await storage.read('push_pending_unregister') == 'true') {
        await _unregister();
      } else {
        await _register(generation);
      }
    });
  }

  Future<void> enable() => _run(() async {
    final generation = _generation;
    if (_user == null) return;
    final transport = await _initialize();
    enabled = await transport.permission(prompt: true);
    await storage.write('push_enabled', enabled.toString());
    if (!enabled) { await _unregister(); error = 'Allow notifications in your phone settings to receive alerts.'; return; }
    await _register(generation);
  });

  Future<void> _unregister() async {
    await storage.write('push_pending_unregister', 'true');
    try {
      final installation = await storage.read('push_installation_id');
      if (installation != null) await api.postNoContent('/notifications/push/unregister', body: {'installation_id': installation});
    } finally {
      if (_transport != null) await _transport!.deleteToken();
    }
    await storage.delete('push_pending_unregister');
  }

  Future<void> disable() {
    ++_generation;
    enabled = false;
    return _run(() async { await storage.write('push_enabled', 'false'); await _unregister(); });
  }

  /// Called before auth tokens are cleared, including all logout entry points.
  Future<void> beforeLogout() {
    _user = null;
    ++_generation;
    return _run(_unregister);
  }

  Future<void> resume() {
    final generation = _generation;
    return _run(() async {
      if (_user == null && await storage.read('push_pending_unregister') == 'true') {
        final transport = await _initialize();
        await transport.deleteToken();
      } else if (_user != null && !enabled && await storage.read('push_pending_unregister') == 'true') {
        await _unregister();
      } else {
        await _register(generation);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    for (final sub in _subscriptions) { unawaited(sub.cancel()); }
    unawaited(_foreground.close());
    unawaited(_opened.close());
    super.dispose();
  }
}
