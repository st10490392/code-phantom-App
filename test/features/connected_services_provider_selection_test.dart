import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/features/auth/data/api_auth_service.dart';
import 'package:code_phantom_app/features/auth/data/mock_auth_service.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/ea/data/api_ea_service.dart';
import 'package:code_phantom_app/features/ea/data/mock_ea_services.dart';
import 'package:code_phantom_app/features/ea/presentation/ea_providers.dart';
import 'package:code_phantom_app/features/scanner/data/api_scanner_service.dart';
import 'package:code_phantom_app/features/scanner/data/mock_scanner_service.dart';
import 'package:code_phantom_app/features/scanner/presentation/scanner_providers.dart';
import 'package:code_phantom_app/features/signals/data/api_signal_service.dart';
import 'package:code_phantom_app/features/signals/data/mock_signal_service.dart';
import 'package:code_phantom_app/features/signals/presentation/signals_providers.dart';

/// This is the direct proof the staging investigation asked for: for every
/// environment a real build can ship as (development, staging, production),
/// every connected module's service provider must resolve to its real
/// `Api*` implementation — never to the `Mock*` one, and never silently
/// falling back to it. A regression here (e.g. a provider that special-
/// cased `AppEnvironment.production` instead of checking `!=
/// AppEnvironment.mock`, as `authServiceProvider` used to) would have
/// produced exactly the symptom reported on a physical device: a
/// "connected" build that quietly keeps showing mock/trial data.
void main() {
  const connectedEnvironments = [
    AppEnvironment.development,
    AppEnvironment.staging,
    AppEnvironment.production,
  ];

  for (final env in connectedEnvironments) {
    group('${env.name} build', () {
      late ProviderContainer container;

      setUp(() {
        container = ProviderContainer(
          overrides: [appEnvironmentProvider.overrideWithValue(env)],
        );
      });
      tearDown(() => container.dispose());

      test('auth uses ApiAuthService, never MockAuthService', () {
        final service = container.read(authServiceProvider);
        expect(service, isA<ApiAuthService>());
        expect(service, isNot(isA<MockAuthService>()));
      });

      test('scanner uses ApiScannerService, never MockScannerService', () {
        final service = container.read(scannerServiceProvider);
        expect(service, isA<ApiScannerService>());
        expect(service, isNot(isA<MockScannerService>()));
      });

      test('signals use ApiSignalService, never MockSignalService', () {
        final service = container.read(signalServiceProvider);
        expect(service, isA<ApiSignalService>());
        expect(service, isNot(isA<MockSignalService>()));
      });

      test('EA uses ApiEAService for every EA role, never any Mock EA service', () {
        final eaService = container.read(eaServiceProvider);
        final eaAccountService = container.read(eaAccountServiceProvider);
        final eaControlService = container.read(eaControlServiceProvider);

        expect(eaService, isA<ApiEAService>());
        expect(eaAccountService, isA<ApiEAService>());
        expect(eaControlService, isA<ApiEAService>());
        expect(eaService, isNot(isA<MockEAService>()));
        expect(eaAccountService, isNot(isA<MockEAAccountService>()));
        expect(eaControlService, isNot(isA<MockEAControlService>()));
      });

      test('the real ApiScannerService never has mutating actions enabled by default', () {
        // A connected build must never let approve/reject/edit through
        // until the Scanner backtest is validated — see
        // ApiScannerService._requireActions(). This is the constructor
        // default the provider relies on; a regression here (someone
        // passing `actionsEnabled: true` in scannerServiceProvider) would
        // let a connected build execute real approvals before validation.
        final service = container.read(scannerServiceProvider) as ApiScannerService;
        expect(service.actionsEnabled, isFalse);
      });
    });
  }

  group('mock build (the default)', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('auth/scanner/signals/EA all resolve to their Mock* implementations', () {
      expect(container.read(appEnvironmentProvider), AppEnvironment.mock);
      expect(container.read(authServiceProvider), isA<MockAuthService>());
      expect(container.read(scannerServiceProvider), isA<MockScannerService>());
      expect(container.read(signalServiceProvider), isA<MockSignalService>());
      expect(container.read(eaServiceProvider), isA<MockEAService>());
    });
  });
}
