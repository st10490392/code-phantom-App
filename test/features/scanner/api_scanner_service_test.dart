import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/scanner/data/api_scanner_service.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_enums.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_setup.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

typedef _Route = FakeResponse Function(RequestOptions options);

Future<({ApiScannerService service, void Function(String, String, _Route) mock})> _build() async {
  final tokenStorage = TokenStorage(FakeSecureStorage());
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
  return (service: ApiScannerService(client), mock: mock);
}

const _realSetupRow = {
  'id': 'setup_real_001',
  'symbol': 'XAUUSD',
  'timeframe': '4H',
  'direction': 'BUY',
  'entry': '2410.50',
  'stop_loss': '2398.00',
  'take_profits': ['2425.00', '2440.00'],
  'status': 'PENDING',
  'weekly_bias': 'BULLISH',
  'daily_bias': 'BULLISH',
  'session': 'LONDON',
  'confluence_score': 7,
  'confluence_max': 10,
  'detected_at': '2026-09-20T08:00:00Z',
  'notes': 'Real backend seed row for staging QA.',
  'chart_image_url': null,
  'reviewed_at': null,
  'reviewed_by': null,
  'rejection_reason': null,
  'edited_before_approval': false,
};

void main() {
  test('watchSetups decodes real snake_case backend rows, not fixture setups', () async {
    final b = await _build();
    b.mock('GET', '/scanner/setups', (_) => const FakeResponse(
          statusCode: 200,
          body: {
            'data': [_realSetupRow],
          },
        ),);

    final setups = await b.service.watchSetups().first;

    expect(setups, hasLength(1));
    final setup = setups.single;
    expect(setup.id, 'setup_real_001');
    expect(setup.symbol, 'XAUUSD');
    expect(setup.entry, 2410.50);
    expect(setup.status, SetupStatus.pending);
    expect(setup.confluenceScore, 7);
    // Mock fixtures (mock_scanner_service.dart) never use this id/symbol
    // pairing for a real-backend-shaped row — a sanity check that this
    // came from the fake HTTP response, not a fallback fixture.
    expect(setup.notes, 'Real backend seed row for staging QA.');
  });

  test('ApiScannerService.actionsEnabled defaults to false (constructor default)', () {
    // Constructed directly (no client needed) — this is a pure
    // configuration check: the class itself must default to safe/disabled,
    // independent of whatever a provider happens to pass.
    final client = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(FakeSecureStorage()),
    );
    expect(ApiScannerService(client).actionsEnabled, isFalse);
  });

  group('mutating actions stay disabled until the Scanner backtest is validated', () {
    test('approve throws without calling the backend', () async {
      final b = await _build();
      b.mock('POST', '/scanner/setups/setup_real_001/approve',
          (_) => throw StateError('must never be called while actions are disabled'),);

      await expectLater(b.service.approve('setup_real_001'), throwsA(isA<StateError>()));
    });

    test('reject throws without calling the backend', () async {
      final b = await _build();
      b.mock('POST', '/scanner/setups/setup_real_001/reject',
          (_) => throw StateError('must never be called while actions are disabled'),);

      await expectLater(
        b.service.reject('setup_real_001', reason: 'test'),
        throwsA(isA<StateError>()),
      );
    });

    test('update throws without calling the backend', () async {
      final b = await _build();
      b.mock('PATCH', '/scanner/setups/setup_real_001',
          (_) => throw StateError('must never be called while actions are disabled'),);

      final setup = ScannerSetup(
        id: 'setup_real_001',
        symbol: 'XAUUSD',
        timeframe: '4H',
        direction: SetupDirection.buy,
        entry: 2410.50,
        stopLoss: 2398.00,
        takeProfits: const [2425.00],
        weeklyBias: Bias.bullish,
        dailyBias: Bias.bullish,
        session: TradingSession.london,
        confluenceScore: 7,
        confluenceMaximum: 10,
        status: SetupStatus.pending,
        detectedAt: DateTime.now(),
      );

      await expectLater(b.service.update(setup), throwsA(isA<StateError>()));
    });
  });
}
