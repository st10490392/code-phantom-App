import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/scanner/data/api_scanner_service.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_enums.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_setup.dart';
import 'package:code_phantom_app/features/scanner/presentation/scanner_providers.dart';
import 'package:code_phantom_app/features/signals/data/api_signal_service.dart';
import 'package:code_phantom_app/features/signals/domain/signal_enums.dart';
import 'package:code_phantom_app/features/signals/presentation/signals_providers.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

/// A `public.scanner_setups` row exactly as the backend returns it for a
/// setup published by the CPT Scanner (shape asserted end-to-end in the
/// backend's tests/pg/scannerPipeline.test.ts): numeric scalars are strings,
/// numeric[] elements are numbers, optional descriptive fields are null.
Map<String, dynamic> scannerRow({
  String id = '6f1c2a4e-0000-4000-8000-000000000001',
  String status = 'PENDING',
  String stopLoss = '19210.000000',
  List<num> takeProfits = const [19331.5],
  bool edited = false,
}) =>
    {
      'id': id,
      'symbol': 'DE40',
      'timeframe': 'M30',
      'direction': 'BUY',
      'entry': '19250.500000',
      'stop_loss': stopLoss,
      'take_profits': takeProfits,
      'status': status,
      'weekly_bias': null,
      'daily_bias': null,
      'session': null,
      'confluence_score': 0,
      'confluence_max': 0,
      'detected_at': '2026-09-26T10:00:00.000Z',
      'notes': 'Frozen CPT setup; strategy_hash=91f6bd68',
      'chart_image_url': null,
      'reviewed_at': status == 'PENDING' ? null : '2026-09-26T10:05:00.000Z',
      'reviewed_by': status == 'PENDING' ? null : 'reviewer-uuid',
      'rejection_reason': status == 'REJECTED' ? 'News window' : null,
      'edited_before_approval': edited,
      'source': 'CPT_SCANNER:scanner-vps-1',
      'created_at': '2026-09-26T10:30:02.000Z',
      'updated_at': '2026-09-26T10:30:02.000Z',
      'market_code': 'INDICES',
      'external_id': 'DE40-3422f253bcbbf392bec1',
      'broker_symbol': 'DE30m',
      'strategy_profile': 'CPT-007-v0.2.0',
      'publisher_id': 'publisher-uuid',
      'payload_sha256': 'ab' * 32,
      'schema_version': 1,
    };

Map<String, dynamic> signalRow(String setupId) => {
      'id': 'signal-uuid-1',
      'source_setup_id': setupId,
      'symbol': 'DE40',
      'timeframe': 'M30',
      'direction': 'BUY',
      'entry': '19250.500000',
      'stop_loss': '19210.000000',
      'take_profits': [19331.5],
      'status': 'APPROVED',
      'result': null,
      'r_multiple': null,
      'notes': null,
      'published_at': null,
      'closed_at': null,
      'created_by': 'reviewer-uuid',
      'created_at': '2026-09-26T10:05:00.000Z',
      'updated_at': '2026-09-26T10:05:00.000Z',
    };

/// Minimal stateful stand-in for the backend scanner/signals routes.
class FakeBackend {
  Map<String, dynamic> setup = scannerRow();
  final signals = <Map<String, dynamic>>[];
  final requests = <RequestOptions>[];

  FakeResponse handle(RequestOptions o) {
    requests.add(o);
    if (o.headers['Authorization'] != 'Bearer access-1') {
      return const FakeResponse(statusCode: 401, body: {
        'error': {'code': 'UNAUTHORIZED'},
      },);
    }
    final id = setup['id'];
    final route = '${o.method} ${o.path.replaceFirst('/$id', '/:id')}';
    switch (route) {
      case 'GET /scanner/setups':
        final status = o.queryParameters['status'];
        return FakeResponse(
          statusCode: 200,
          body: {
            'data': [if (status == null || status == setup['status']) setup],
          },
        );
      case 'GET /scanner/setups/:id':
        return FakeResponse(statusCode: 200, body: {'data': setup});
      case 'POST /scanner/setups/:id/approve':
        if (setup['status'] == 'REJECTED') {
          return const FakeResponse(
            statusCode: 409,
            body: {
              'error': {'code': 'CONFLICT', 'message': 'Cannot approve a setup that has already been rejected.'},
            },
          );
        }
        final created = signals.isEmpty;
        if (created) signals.add(signalRow(id as String));
        setup = {
          ...setup,
          'status': 'APPROVED',
          'reviewed_by': 'reviewer-uuid',
          'reviewed_at': '2026-09-26T10:05:00.000Z',
        };
        return FakeResponse(
          statusCode: created ? 201 : 200,
          body: {
            'data': {'setup': setup, 'signal': signals.single, 'already_approved': !created},
          },
        );
      case 'POST /scanner/setups/:id/reject':
        final body = o.data as Map<String, dynamic>? ?? const {};
        setup = {...setup, 'status': 'REJECTED', 'rejection_reason': body['rejection_reason']};
        return FakeResponse(statusCode: 200, body: {'data': setup});
      case 'PATCH /scanner/setups/:id':
        final body = o.data as Map<String, dynamic>;
        for (final key in ['symbol', 'timeframe', 'direction']) {
          if (body.containsKey(key)) {
            return const FakeResponse(statusCode: 409, body: {
              'error': {'code': 'IMMUTABLE_FIELD'},
            },);
          }
        }
        setup = {
          ...setup,
          if (body['stop_loss'] != null) 'stop_loss': (body['stop_loss'] as num).toStringAsFixed(6),
          if (body['take_profits'] != null) 'take_profits': body['take_profits'],
          if (body.containsKey('notes')) 'notes': body['notes'],
          'edited_before_approval': true,
        };
        return FakeResponse(statusCode: 200, body: {'data': setup});
      case 'GET /signals':
        return FakeResponse(statusCode: 200, body: {'data': signals});
    }
    return const FakeResponse(statusCode: 404, body: {
      'error': {'code': 'NOT_FOUND'},
    },);
  }

  List<RequestOptions> where(String method, String pathSuffix) =>
      requests.where((r) => r.method == method && r.path.endsWith(pathSuffix)).toList();
}

Future<ApiClient> clientFor(FakeBackend backend) async {
  final storage = TokenStorage(FakeSecureStorage());
  await storage.save(accessToken: 'access-1', expiresAt: DateTime.now().add(const Duration(hours: 1)));
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = FakeHttpClientAdapter(backend.handle);
  return ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: storage, dio: dio);
}

const _owner = AuthUser(
  id: 'reviewer-uuid',
  email: 'owner@codephantom.dev',
  displayName: 'Owner',
  role: AppRole.owner,
  permissions: PermissionSet.none,
);

void main() {
  group('backend payload parsing', () {
    test('decodes a real scanner-published setup row', () {
      final s = ScannerSetup.fromBackendJson(scannerRow());
      expect(s.symbol, 'DE40');
      expect(s.brokerSymbol, 'DE30m');
      expect(s.market, 'INDICES');
      expect(s.direction, SetupDirection.buy);
      expect(s.timeframe, 'M30');
      expect(s.entry, 19250.5);
      expect(s.stopLoss, 19210.0);
      expect(s.takeProfits, [19331.5]);
      expect(s.detectedAt, DateTime.utc(2026, 9, 26, 10));
      expect(s.detectedAt.isUtc, isTrue);
      expect(s.strategyProfile, 'CPT-007-v0.2.0');
      expect(s.externalId, 'DE40-3422f253bcbbf392bec1');
      expect(s.isMachinePublished, isTrue);
      expect(s.status, SetupStatus.pending);
      // Not reported by the scanner: shown as absent, never fabricated.
      expect(s.weeklyBias, Bias.unknown);
      expect(s.dailyBias, Bias.unknown);
      expect(s.session, TradingSession.unknown);
    });

    test('accepts decimals as strings or numbers, and parses review fields', () {
      final s = ScannerSetup.fromBackendJson(
        scannerRow(status: 'REJECTED', stopLoss: '19210', takeProfits: [19331]),
      );
      expect(s.stopLoss, 19210.0);
      expect(s.takeProfits, [19331.0]);
      expect(s.status, SetupStatus.rejected);
      expect(s.rejectionReason, 'News window');
      expect(s.reviewedAt, DateTime.utc(2026, 9, 26, 10, 5));
    });

    test('never guesses a direction or status', () {
      expect(() => ScannerSetup.fromBackendJson({...scannerRow(), 'direction': 'LONG'}), throwsFormatException);
      expect(() => ScannerSetup.fromBackendJson({...scannerRow(), 'status': 'ARCHIVED'}), throwsFormatException);
      expect(() => ScannerSetup.fromBackendJson({...scannerRow(), 'entry': null}), throwsFormatException);
    });

    test('decodes the Signal created by approval', () {
      final s = signalFromBackendJson(signalRow('setup-1'));
      expect(s.setupId, 'setup-1');
      expect(s.status, SignalStatus.approved);
      expect(s.entry, 19250.5);
      expect(s.takeProfits, [19331.5]);
      expect(s.session, TradingSession.unknown);
    });
  });

  group('ApiScannerService against the backend contract', () {
    late FakeBackend backend;
    late ApiScannerService service;
    setUp(() async {
      backend = FakeBackend();
      service = ApiScannerService(await clientFor(backend), actionsEnabled: true);
    });

    test('lists PENDING setups with the session token and backend status filter', () async {
      final pending = await service.watchSetups(status: SetupStatus.pending).first;
      expect(pending.single.symbol, 'DE40');
      final req = backend.where('GET', '/scanner/setups').single;
      expect(req.queryParameters, {'limit': 200, 'status': 'PENDING'});
      expect(req.headers['Authorization'], 'Bearer access-1');
      expect(await service.watchSetups(status: SetupStatus.expired).first, isEmpty);
    });

    test('approve posts once and returns the authoritative APPROVED setup', () async {
      final approved = await service.approve(backend.setup['id'] as String);
      expect(approved.status, SetupStatus.approved);
      final req = backend.where('POST', '/approve').single;
      expect(req.data, isNull);
      expect(backend.signals, hasLength(1));
    });

    test('a watcher refreshes from the backend after a review action', () async {
      final emissions = <List<ScannerSetup>>[];
      final sub = service.watchSetups().listen(emissions.add);
      await pumpEventQueue();
      await service.reject(backend.setup['id'] as String, reason: 'News window');
      await pumpEventQueue();
      await sub.cancel();
      expect(emissions.first.single.status, SetupStatus.pending);
      expect(emissions.last.single.status, SetupStatus.rejected);
      expect(emissions.last.single.rejectionReason, 'News window');
    });

    test('reject sends the reason in the backend field name', () async {
      await service.reject(backend.setup['id'] as String, reason: 'Spread too wide');
      expect(backend.where('POST', '/reject').single.data, {'rejection_reason': 'Spread too wide'});
    });

    test('edit sends only changed reviewer fields, never detection metadata', () async {
      final current = ScannerSetup.fromBackendJson(backend.setup);
      final edited = current.copyWith(stopLoss: 19200, takeProfits: const [19351.5], notes: 'Widened SL');
      final result = await service.update(edited);
      final body = backend.where('PATCH', current.id).single.data as Map<String, dynamic>;
      expect(body, {
        'stop_loss': 19200.0,
        'take_profits': [19351.5],
        'notes': 'Widened SL',
      });
      expect(result.editedBeforeApproval, isTrue);
      expect(result.stopLoss, 19200.0);
      expect(result.detectedAt, current.detectedAt);
      expect(result.brokerSymbol, 'DE30m');
    });

    test('an unchanged edit makes no PATCH request', () async {
      await service.update(ScannerSetup.fromBackendJson(backend.setup));
      expect(backend.where('PATCH', ''), isEmpty);
    });

    test('backend refusals surface as typed errors', () async {
      await service.reject(backend.setup['id'] as String, reason: 'x');
      expect(
        service.approve(backend.setup['id'] as String),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', contains('rejected'))),
      );
    });
  });

  group('review controller in a real-backend environment', () {
    test('approve relies on the backend transaction and never creates a Signal client-side', () async {
      final backend = FakeBackend();
      final client = await clientFor(backend);
      final container = ProviderContainer(
        overrides: [
          appEnvironmentProvider.overrideWithValue(AppEnvironment.production),
          apiClientProvider.overrideWithValue(client),
          currentUserProvider.overrideWithValue(_owner),
          scannerReviewActionsEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(scannerServiceProvider), isA<ApiScannerService>());
      expect(container.read(signalServiceProvider), isA<ApiSignalService>());

      final id = backend.setup['id'] as String;
      await container.read(scannerReviewControllerProvider.notifier).approve(id);
      await container.read(scannerReviewControllerProvider.notifier).approve(id); // double tap

      expect(backend.where('POST', '/approve'), hasLength(2));
      expect(backend.signals, hasLength(1));
      expect(backend.requests.where((r) => r.path.startsWith('/signals') && r.method != 'GET'), isEmpty);
      final signals = await container.read(signalServiceProvider).watchSignals().first;
      expect(signals.single.setupId, id);
      await expectLater(
        container.read(signalServiceProvider).createFromSetup(ScannerSetup.fromBackendJson(backend.setup)),
        throwsA(isA<StateError>()),
      );
    });

    test('reject goes to the backend with the reason', () async {
      final backend = FakeBackend();
      final container = ProviderContainer(
        overrides: [
          appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
          apiClientProvider.overrideWithValue(await clientFor(backend)),
          currentUserProvider.overrideWithValue(_owner),
          scannerReviewActionsEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(scannerReviewControllerProvider.notifier)
          .reject(backend.setup['id'] as String, reason: 'Outside session');
      expect(backend.setup['status'], 'REJECTED');
      expect(jsonEncode(backend.where('POST', '/reject').single.data), '{"rejection_reason":"Outside session"}');
      expect(backend.signals, isEmpty);
    });

    test('connected builds keep review actions paused unless SCANNER_REVIEW_ACTIONS is set', () async {
      final backend = FakeBackend();
      final container = ProviderContainer(
        overrides: [
          appEnvironmentProvider.overrideWithValue(AppEnvironment.production),
          apiClientProvider.overrideWithValue(await clientFor(backend)),
          currentUserProvider.overrideWithValue(_owner),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(scannerReviewActionsEnabledProvider), isFalse);
      await expectLater(
        container.read(scannerReviewControllerProvider.notifier).approve(backend.setup['id'] as String),
        throwsA(isA<StateError>()),
      );
      expect(backend.where('POST', '/approve'), isEmpty);
      expect(backend.signals, isEmpty);
    });

    test('mock environment keeps the in-memory services for tests and demos', () {
      final container = ProviderContainer(overrides: [appEnvironmentProvider.overrideWithValue(AppEnvironment.mock)]);
      addTearDown(container.dispose);
      expect(container.read(scannerServiceProvider), isNot(isA<ApiScannerService>()));
      expect(container.read(signalServiceProvider), isNot(isA<ApiSignalService>()));
    });
  });
}
