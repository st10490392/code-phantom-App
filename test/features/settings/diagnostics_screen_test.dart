import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/settings/presentation/diagnostics_screen.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

void main() {
  setUp(() {
    // `PackageInfo.fromPlatform()` has no platform implementation in plain
    // `flutter_test` — this stands in for the real installed build's
    // metadata the same way the app does on-device.
    PackageInfo.setMockInitialValues(
      appName: 'CodePhantom',
      packageName: 'com.codephantom.app',
      version: '0.2.0',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  Future<void> pumpDiagnostics(
    WidgetTester tester, {
    required AppEnvironment environment,
    ApiClient? apiClient,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
        ],
        child: const MaterialApp(home: DiagnosticsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('mock mode shows every module as Mock and offers no connection test', (tester) async {
    await pumpDiagnostics(tester, environment: AppEnvironment.mock);

    // "Target" also reads "Mock" alongside the 4 module rows (Auth, Scanner,
    // Signals, EA) — 5 in total.
    expect(find.text('Mock'), findsNWidgets(5));
    expect(find.text('API'), findsNothing);
    expect(find.text('Test connection'), findsNothing);
    expect(find.text('Mock mode has no backend to connect to — every module above is Mock.'),
        findsOneWidget,);
  });

  testWidgets('a connected environment shows every module as API and the target label',
      (tester) async {
    final tokenStorage = TokenStorage(FakeSecureStorage());
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = FakeHttpClientAdapter((_) => const FakeResponse(statusCode: 500, body: {}));
    final apiClient = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);

    await pumpDiagnostics(tester, environment: AppEnvironment.staging, apiClient: apiClient);

    expect(find.text('Staging'), findsOneWidget);
    expect(find.text('API'), findsNWidgets(4));
    expect(find.text('Mock'), findsNothing);
    expect(find.text('Test connection'), findsOneWidget);
  });

  testWidgets('tapping Test connection on a reachable backend shows env/version and flags '
      'a mismatch against this build\'s own target', (tester) async {
    final tokenStorage = TokenStorage(FakeSecureStorage());
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    Uri? requestedUri;
    dio.httpClientAdapter = FakeHttpClientAdapter((options) {
      requestedUri = options.uri;
      return const FakeResponse(
        statusCode: 200,
        body: {'status': 'ok', 'env': 'staging', 'version': '2.1.0', 'started_at': 'x'},
      );
    });
    final apiClient = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);

    // This build claims Production, but the backend it reaches reports
    // staging — exactly the real-world mismatch this screen exists to
    // surface (the original Staging 9 build used APP_ENV=production while
    // pointed at the staging API).
    await pumpDiagnostics(tester, environment: AppEnvironment.production, apiClient: apiClient);

    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(requestedUri.toString(), 'http://test.local/health');
    expect(find.textContaining('Reachable'), findsOneWidget);
    expect(find.textContaining('Backend reports: staging'), findsOneWidget);
    expect(find.textContaining('Mismatch'), findsOneWidget);
  });

  testWidgets('tapping Test connection on an unreachable backend shows a clean failure message',
      (tester) async {
    final tokenStorage = TokenStorage(FakeSecureStorage());
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = FakeHttpClientAdapter((_) => const FakeResponse.networkFailure());
    final apiClient = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);

    await pumpDiagnostics(tester, environment: AppEnvironment.staging, apiClient: apiClient);

    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unreachable'), findsOneWidget);
  });
}
