import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/ea/data/api_ea_service.dart';
import 'package:code_phantom_app/features/ea/domain/ea_enums.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

typedef _Route = FakeResponse Function(RequestOptions options);

Future<({ApiEAService service, void Function(String, String, _Route) mock})> _build() async {
  final tokenStorage = TokenStorage(FakeSecureStorage());
  // Every EA route requires an authenticated session on the real backend
  // (`eaRouter.use(requireAuth)`) — seed a still-valid token so these tests
  // exercise the actual request/decode path instead of failing on auth.
  await tokenStorage.save(
    accessToken: 'test-access-token',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  final routes = <String, _Route>{};

  void mock(String method, String path, _Route route) {
    routes['$method $path'] = route;
  }

  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = FakeHttpClientAdapter((options) {
    final key = '${options.method} ${options.path}';
    final route = routes[key];
    if (route == null) throw StateError('No fake route registered for $key');
    return route(options);
  });

  final client = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);
  return (service: ApiEAService(client), mock: mock);
}

void main() {
  group('ApiEAService.listAccounts — decodes real backend rows, not fixtures', () {
    test('maps snake_case account + status rows into an EAAccount with a live heartbeat', () async {
      final b = await _build();
      b.mock('GET', '/ea/accounts', (_) => const FakeResponse(
            statusCode: 200,
            body: {
              'data': [
                {
                  'id': 'ea_real_001',
                  'account_label': 'Client — Staging QA',
                  'broker': 'Staging Broker Ltd',
                  'trading_enabled': true,
                  'risk_mode': 'PROP_FIRM',
                  'risk_percentage': '1.25',
                },
              ],
            },
          ),);
      b.mock('GET', '/ea/accounts/ea_real_001/status', (_) => FakeResponse(
            statusCode: 200,
            body: {
              'data': {
                'balance': '25430.10',
                'equity': '25510.55',
                'daily_pl': '80.45',
                'drawdown_percentage': '0.3',
                'open_trades_count': 1,
                'last_heartbeat_at': DateTime.now().toIso8601String(),
              },
            },
          ),);

      final accounts = await b.service.listAccounts();

      expect(accounts, hasLength(1));
      final account = accounts.single;
      expect(account.accountId, 'ea_real_001');
      expect(account.nickname, 'Client — Staging QA',
          reason: 'must reflect the real account_label from the backend row, not a fixture name',);
      expect(account.broker, 'Staging Broker Ltd');
      expect(account.riskMode, RiskMode.prop);
      expect(account.balance, 25430.10);
      expect(account.equity, 25510.55);
      expect(account.status, EAConnectionStatus.online,
          reason: 'a heartbeat within the last 5 minutes must read as online',);

      // None of the known mock fixture values (see mock_ea_services.dart's
      // seed data: 'FTMO Challenge #1' / 'ea_001' / balance 10000, or
      // 'Live — Personal' / 'ea_002' / balance 4200) ever appear.
      expect(account.nickname, isNot('FTMO Challenge #1'));
      expect(account.nickname, isNot('Live — Personal'));
      expect(account.balance, isNot(10000));
      expect(account.balance, isNot(4200));
    });

    test('a stale heartbeat (>5 minutes old) reads as offline', () async {
      final b = await _build();
      b.mock('GET', '/ea/accounts', (_) => const FakeResponse(
            statusCode: 200,
            body: {
              'data': [
                {'id': 'ea_x', 'account_label': 'X', 'trading_enabled': false, 'risk_mode': 'STANDARD'},
              ],
            },
          ),);
      b.mock('GET', '/ea/accounts/ea_x/status', (_) => FakeResponse(
            statusCode: 200,
            body: {
              'data': {
                'balance': 0,
                'equity': 0,
                'daily_pl': 0,
                'drawdown_percentage': 0,
                'open_trades_count': 0,
                'last_heartbeat_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
              },
            },
          ),);

      final account = (await b.service.listAccounts()).single;

      expect(account.status, EAConnectionStatus.offline);
      expect(account.serverStatus, 'No recent heartbeat');
    });

    test('no accounts registered yields an empty list, not fixture accounts', () async {
      final b = await _build();
      b.mock('GET', '/ea/accounts', (_) => const FakeResponse(statusCode: 200, body: {'data': []}));

      expect(await b.service.listAccounts(), isEmpty);
    });
  });

  group('ApiEAService trading controls — backend command queue', () {
    test('control methods issue only allow-listed EA commands', () async {
      final b = await _build();
      final seen = <Map<String, dynamic>>[];

      b.mock('POST', '/ea/accounts/ea_1/commands', (options) {
        seen.add(Map<String, dynamic>.from(options.data as Map));
        return const FakeResponse(
          statusCode: 201,
          body: {'data': {'id': 'cmd_1', 'status': 'PENDING'}},
        );
      });

      await b.service.pauseTrading('ea_1');
      await b.service.resumeTrading('ea_1');
      await b.service.setRiskMode('ea_1', RiskMode.moderate);
      await b.service.setRiskPercentage('ea_1', 0.5);
      await b.service.disableNewEntries('ea_1');
      await b.service.emergencyStop('ea_1');

      expect(
        seen.map((x) => x['command_type']),
        [
          'PAUSE_TRADING',
          'RESUME_TRADING',
          'SET_RISK_MODE',
          'SET_RISK_PERCENTAGE',
          'DISABLE_NEW_ENTRIES',
          'EMERGENCY_STOP',
        ],
      );
      expect(seen[2]['payload'], {'risk_mode': RiskMode.moderate.wireValue});
      expect(seen[3]['payload'], {'risk_percentage': 0.5});
      expect(seen[0]['payload'], isEmpty);
    });
  });
}
