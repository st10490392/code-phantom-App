import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_enums.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_setup.dart';
import 'package:code_phantom_app/features/signals/data/api_signal_service.dart';
import 'package:code_phantom_app/features/signals/domain/signal_enums.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

typedef _Route = FakeResponse Function(RequestOptions options);

Future<({ApiSignalService service, void Function(String, String, _Route) mock})>
    _build() async {
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

  final client = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: tokenStorage,
      dio: dio,);
  return (service: ApiSignalService(client), mock: mock);
}

void main() {
  test('watchSignals decodes real backend rows, not fixture signals', () async {
    final b = await _build();
    b.mock(
      'GET',
      '/signals',
      (_) => const FakeResponse(
        statusCode: 200,
        body: {
          'data': [
            {
              'id': 'signal_real_001',
              'source_setup_id': 'setup_real_001',
              'symbol': 'EURUSD',
              'direction': 'SELL',
              'entry': '1.0850',
              'stop_loss': '1.0880',
              'take_profits': ['1.0800'],
              'status': 'ACTIVE',
              'created_at': '2026-09-20T09:00:00Z',
              'closed_at': null,
              'result': null,
              'r_multiple': null,
              'notes': 'Real staging signal.',
            },
          ],
        },
      ),
    );

    final signals = await b.service.watchSignals().first;

    expect(signals, hasLength(1));
    final signal = signals.single;
    expect(signal.id, 'signal_real_001');
    expect(signal.setupId, 'setup_real_001');
    expect(signal.status, SignalStatus.active);
    expect(signal.entry, 1.0850);
  });

  test(
      'performanceSummary is computed from real closed signals, not fixture win/loss counts',
      () async {
    final b = await _build();
    b.mock(
      'GET',
      '/signals',
      (_) => const FakeResponse(
        statusCode: 200,
        body: {
          'data': [
            {
              'id': 's1',
              'symbol': 'EURUSD',
              'direction': 'BUY',
              'entry': '1',
              'stop_loss': '0.99',
              'take_profits': ['1.02'],
              'status': 'CLOSED',
              'created_at': '2026-09-01T00:00:00Z',
              'closed_at': '2026-09-02T00:00:00Z',
              'result': 'WIN',
              'r_multiple': '2.0',
            },
            {
              'id': 's2',
              'symbol': 'GBPUSD',
              'direction': 'SELL',
              'entry': '1',
              'stop_loss': '1.01',
              'take_profits': ['0.98'],
              'status': 'STOPPED',
              'created_at': '2026-09-01T00:00:00Z',
              'closed_at': '2026-09-02T00:00:00Z',
              'result': 'LOSS',
              'r_multiple': '-1.0',
            },
          ],
        },
      ),
    );

    final summary = await b.service.performanceSummary();

    expect(summary.totalSignals, 2);
    expect(summary.wins, 1);
    expect(summary.losses, 1);
    expect(summary.winRatePercent, 50);
    expect(summary.averageRMultiple, 0.5);
  });

  test('cancelled and ambiguous observations never count as wins', () async {
    final b = await _build();
    b.mock(
        'GET',
        '/signals',
        (_) => const FakeResponse(statusCode: 200, body: {
              'data': [
                {
                  'id': 'cancelled',
                  'symbol': 'EURUSD',
                  'direction': 'BUY',
                  'entry': '1',
                  'stop_loss': '0.9',
                  'take_profits': ['1.2'],
                  'status': 'CANCELLED',
                  'created_at': '2026-09-01T00:00:00Z',
                  'result': 'WIN',
                  'r_multiple': '2',
                },
                {
                  'id': 'ambiguous',
                  'symbol': 'EURUSD',
                  'direction': 'BUY',
                  'entry': '1',
                  'stop_loss': '0.9',
                  'take_profits': ['1.2'],
                  'status': 'CLOSED',
                  'created_at': '2026-09-01T00:00:00Z',
                  'result': 'PENDING',
                  'r_multiple': null,
                },
              ],
            },),);
    final summary = await b.service.performanceSummary();
    expect(summary.totalSignals, 0);
    expect(summary.wins, 0);
    expect(summary.losses, 0);
  });

  group('signal management stays paused until backtests pass', () {
    test('updateStatus throws without calling the backend', () async {
      final b = await _build();
      await expectLater(
        b.service.updateStatus('signal_real_001', SignalStatus.published),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'createFromSetup throws — only the backend creates a signal from an approved setup',
        () async {
      final b = await _build();
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
        status: SetupStatus.approved,
        detectedAt: DateTime.now(),
      );

      await expectLater(
          b.service.createFromSetup(setup), throwsA(isA<StateError>()),);
    });
  });
}
