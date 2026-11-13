import 'package:code_phantom_app/core/device/device_identity.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/core/network/bridge_client.dart';
import 'package:code_phantom_app/core/storage/bridge_credentials.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/licences/data/bridge_licence_service.dart';
import 'package:code_phantom_app/features/licences/data/licence_activation_service.dart';
import 'package:code_phantom_app/features/licences/domain/licence_enums.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

/// The exact success shape of `POST /licences/activate` in
/// `code-phantom-backend`'s `src/modules/licences/routes.ts`.
const activatedResponse = {
  'data': {
    'licence': {
      'id': 'l1',
      'key_prefix': 'CPT-SIG',
      'user_id': 'u1',
      'service': 'SIGNALS',
      'status': 'ACTIVE',
      'created_at': '2026-11-01T00:00:00Z',
      'activated_at': '2026-11-12T00:00:00Z',
      'expires_at': '2027-11-01T00:00:00Z',
      'device_limit': 3,
      'active_devices': 1,
    },
    'device': {'id': 'd1'},
  },
};

/// A signed-in client on a scripted transport. `/licences/*` sits behind
/// `requireAuth`, so a session has to exist for these calls to be attempted.
Future<ApiClient> _signedInClient(
  List<RequestOptions> requests,
  FakeResponse Function(RequestOptions) route,
) async {
  final tokens = TokenStorage(FakeSecureStorage());
  await tokens.save(
    accessToken: 'jwt',
    refreshToken: 'r',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'));
  dio.httpClientAdapter = FakeHttpClientAdapter((o) {
    requests.add(o);
    return route(o);
  });
  return ApiClient(baseUrl: 'http://api.test/api/v1', tokenStorage: tokens, dio: dio);
}

BridgeLicenceService _bridge(
  List<RequestOptions> requests,
  FakeResponse Function(RequestOptions) route,
) {
  final storage = FakeSecureStorage();
  final dio = Dio(BaseOptions(baseUrl: 'http://bridge.test/api/v1'));
  dio.httpClientAdapter = FakeHttpClientAdapter((o) {
    requests.add(o);
    return route(o);
  });
  return BridgeLicenceService(
    client: BridgeClient(baseUrl: 'http://bridge.test/api/v1', dio: dio),
    credentials: BridgeCredentialStorage(storage),
    identity: DeviceIdentity(storage),
  );
}

void main() {
  group('backend licence activation', () {
    test('activation posts the backend contract and returns the licence row', () async {
      final requests = <RequestOptions>[];
      final identity = DeviceIdentity(FakeSecureStorage());
      final client = await _signedInClient(requests, (o) {
        return o.path == '/licences/activate'
            ? const FakeResponse(statusCode: 200, body: activatedResponse)
            : const FakeResponse(statusCode: 404, body: {'error': {'code': 'NOT_FOUND'}});
      });
      final service = ApiLicenceActivationService(client, identity, DeviceBoundRegistry(identity));

      final licence = await service.activate(
        licenceKey: 'CPT-SIG-ABCD-EFGH-IJKL',
        device: const LicenceDevice(identifier: 'dev-1', platform: 'ANDROID'),
      );

      expect(licence.product, 'SIGNALS');
      expect(licence.status, LicenceStatus.active);
      expect(licence.maxDevices, 3);
      expect(requests.single.path, '/licences/activate');
      expect(requests.single.headers['Authorization'], 'Bearer jwt');
      expect(requests.single.data, {
        'licence_key': 'CPT-SIG-ABCD-EFGH-IJKL',
        'device': {'platform': 'ANDROID', 'device_identifier': 'dev-1'},
      });
    });

    test('a successful activation is what marks this device bound', () async {
      final identity = DeviceIdentity(FakeSecureStorage());
      final client = await _signedInClient(<RequestOptions>[], (_) {
        return const FakeResponse(statusCode: 200, body: activatedResponse);
      });
      final service = ApiLicenceActivationService(client, identity, DeviceBoundRegistry(identity));
      await service.activate(
        licenceKey: 'k',
        device: const LicenceDevice(identifier: 'dev-1', platform: 'WEB'),
      );
      expect(await identity.isDeviceBound(), isTrue);
    });

    test('validation reports expiry from the server, not from a local copy', () async {
      final requests = <RequestOptions>[];
      final identity = DeviceIdentity(FakeSecureStorage());
      final client = await _signedInClient(requests, (_) {
        return const FakeResponse(
          statusCode: 200,
          body: {
            'data': {
              'valid': false,
              'status': 'EXPIRED',
              'service': 'SIGNALS',
              'expiresAt': '2026-10-01T00:00:00Z',
              'deviceRecognized': true,
            },
          },
        );
      },
      );
      final service = ApiLicenceActivationService(client, identity, DeviceBoundRegistry(identity));

      final result = await service.validate(licenceKey: 'k');
      expect(result.valid, isFalse);
      expect(result.status, 'EXPIRED');
      expect(result.isSignals, isTrue);
      expect(result.isEa, isFalse);
      expect(result.expiresAt, DateTime.parse('2026-10-01T00:00:00Z'));
      expect(requests.single.data, {'licence_key': 'k', 'device_identifier': isNotNull});
    });

    test('an invalid key is a server refusal, never a client-side success', () async {
      final identity = DeviceIdentity(FakeSecureStorage());
      final client = await _signedInClient(<RequestOptions>[], (_) {
        return const FakeResponse(
          statusCode: 404,
          body: {'error': {'code': 'NOT_FOUND', 'message': 'Invalid licence key.'}},
        );
      });
      final service = ApiLicenceActivationService(client, identity, DeviceBoundRegistry(identity));

      await expectLater(
        service.activate(
          licenceKey: 'nope',
          device: const LicenceDevice(identifier: 'd', platform: 'ANDROID'),
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('bridge licence activation', () {
    test('an EA key is refused before any request: it never authorizes this app', () async {
      final requests = <RequestOptions>[];
      final service = _bridge(requests, (_) => const FakeResponse(statusCode: 200, body: {}));

      await expectLater(
        service.activate(key: 'PH-EA-ABC', serviceType: 'EA'),
        throwsA(isA<ValidationException>()),
      );
      expect(await service.hasSignalsKey(), isFalse);
      expect(requests, isEmpty);
    });

    test('a SIGNALS key is bound to this hardware id and stored for the feed', () async {
      final requests = <RequestOptions>[];
      final service = _bridge(requests, (_) {
        return const FakeResponse(
          statusCode: 200,
          body: {
            'service_type': 'SIGNALS',
            'status': 'ACTIVE',
            'hardware_id': 'hw-1',
            'activated_at': '2026-11-12T00:00:00Z',
          },
        );
      },
      );

      final result = await service.activate(key: 'PH-SIGNALS-ABC', serviceType: 'SIGNALS');
      expect(result.serviceType, 'SIGNALS');
      expect(result.hardwareId, 'hw-1');
      expect(requests.single.path, '/license/activate');
      expect(requests.single.data, {'key': 'PH-SIGNALS-ABC', 'service_type': 'SIGNALS', 'hardware_id': isNotNull});
      expect(await service.hasSignalsKey(), isTrue);
      await service.forgetSignalsKey();
      expect(await service.hasSignalsKey(), isFalse);
    });

    test('the bridge licence view is distinct from the account entitlements', () async {
      final service = _bridge(<RequestOptions>[], (_) {
        return const FakeResponse(statusCode: 200, body: {'ea': false, 'signals': true});
      });

      final validity = await service.validity();
      expect(validity.eaLicensed, isFalse);
      expect(validity.signalsLicensed, isTrue);
    });

    test('a build with no bridge cannot offer an activation that cannot succeed', () {
      expect(bridgeActivationAvailable(), isFalse);
    });
  });
}

