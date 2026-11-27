import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/secure_storage.dart';
import '../auth/presentation/auth_providers.dart';
import 'trading_service.dart';

final licenseStore = Provider((ref) => SecureStorage());
const tradingUrl = String.fromEnvironment('TRADING_API_URL');
final licenseProvider =
    AsyncNotifierProvider<LicenseController, TradingService?>(
  LicenseController.new,
);

class LicenseController extends AsyncNotifier<TradingService?> {
  String get user => ref.read(currentUserProvider)?.id ?? '';
  String slot(String id) => 'trading.license.$tradingUrl.$id';
  Future<String> device() async {
    final store = ref.read(licenseStore);
    final saved = await store.read('trading.installation');
    if (saved != null) return saved;
    final random = Random.secure();
    final value = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await store.write('trading.installation', value);
    return value;
  }

  Future<TradingService> verify(Json record, {bool restore = false}) async {
    final api = TradingService(
      TradingProfile.values.byName(record['profile']),
      record['key'],
      tradingUrl,
    );
    try {
      final id = await device();
      api.dio.options.headers['X-Device-ID'] = id;
      api.login = record['login'];
      api.server = record['server'];
      if (restore) {
        api.scope = record['scope'];
        if (!api.ea && !api.signals) {
          throw const FormatException('Unknown saved license scope.');
        }
        // Validate protected reads without silently re-binding a reset key.
        await api.snapshot();
        return api;
      }
      final response = await api.dio.post<Json>(
        '/licenses/activate',
        data: {
          'device_id': id,
          if (record['login'] != '') 'mt5_account_id': record['login'],
          if (record['server'] != '') 'mt5_server': record['server'],
        },
      );
      final result = response.data!;
      if (result['account'] != api.profile.account ||
          !['EA_ONLY', 'SIGNALS_ONLY', 'FULL_ACCESS']
              .contains(result['scope'])) {
        throw const FormatException(
          'License belongs to another configured account or has invalid scope.',
        );
      }
      api.scope = result['scope'];
      api.login = record['login'];
      api.server = record['server'];
      return api;
    } catch (_) {
      api.dio.close(force: true);
      rethrow;
    }
  }

  @override
  Future<TradingService?> build() async {
    final id = ref.watch(currentUserProvider)?.id;
    if (id == null || tradingUrl.isEmpty) return null;
    final raw = await ref.read(licenseStore).read(slot(id));
    if (raw == null) return null;
    final api = await verify(jsonDecode(raw) as Json, restore: true);
    ref.onDispose(() => api.dio.close(force: true));
    return api;
  }

  Future<void> activate(
    TradingProfile profile,
    String key,
    String login,
    String server,
  ) async {
    final id = user;
    final record = {
      'profile': profile.name,
      'key': key.trim(),
      'login': login.trim(),
      'server': server.trim(),
    };
    final api = await verify(record);
    if (user != id) {
      api.dio.close();
      return;
    }
    await ref
        .read(licenseStore)
        .write(slot(id), jsonEncode({...record, 'scope': api.scope}));
    if (user != id) {
      api.dio.close();
      return;
    }
    ref.onDispose(() => api.dio.close(force: true));
    state = AsyncData(api);
  }

  Future<void> clear() async {
    final id = user;
    state.valueOrNull?.dio.close(force: true);
    state = const AsyncData(null);
    await ref.read(licenseStore).delete(slot(id));
  }
}
