import 'package:code_phantom_app/features/trading/trading_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('binds control reads and writes to the selected account', () async {
    final dio = Dio();
    final paths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          expect(o.headers['Authorization'], 'Bearer mobile-token');
          paths.add('${o.method} ${o.path}');
          dynamic value = <String, dynamic>{};
          if (o.path.endsWith('/status')) {
            value = {'profile': 'deriv_synthetics_mt5'};
          }
          if (o.path.endsWith('/history') || o.path.endsWith('/alerts')) {
            value = [];
          }
          if (o.path == '/market-bias') {
            expect(o.queryParameters['account'], TradingProfile.deriv.account);
          }
          h.resolve(Response(requestOptions: o, statusCode: 200, data: value));
        },
      ),
    );
    final api = TradingService(
      TradingProfile.deriv,
      'mobile-token',
      'https://example.test',
      transport: dio,
    );
    api.scope = 'FULL_ACCESS';
    final path = api.path;
    await api.snapshot();
    await api.settings({'risk_amount_usd': 5});
    await api.flatten();
    expect(
      paths,
      containsAll([
        'GET $path/status',
        'GET /market-bias',
        'GET $path/history',
        'GET $path/alerts',
        'PATCH $path/settings',
        'POST $path/commands/FLATTEN_ALL_AND_PAUSE',
      ]),
    );
    paths.clear();
    api.scope = 'EA_ONLY';
    await api.snapshot();
    expect(paths, ['GET $path/status', 'GET $path/history']);
    paths.clear();
    api.scope = 'SIGNALS_ONLY';
    await api.snapshot();
    await expectLater(api.flatten(), throwsStateError);
    await expectLater(api.settings({'risk_pct': 0.5}), throwsStateError);
    expect(paths, ['GET /market-bias', 'GET $path/alerts']);
    dio.close();
  });
}
