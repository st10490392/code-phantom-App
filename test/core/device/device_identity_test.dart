import 'package:code_phantom_app/core/device/device_identity.dart';
import 'package:code_phantom_app/core/storage/bridge_credentials.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../features/auth/fake_secure_storage.dart';

void main() {
  group('DeviceIdentity', () {
    test('the backend device identifier is a v4 UUID, stable across calls', () async {
      final identity = DeviceIdentity(FakeSecureStorage());
      final first = await identity.deviceId();
      final second = await identity.deviceId();
      expect(first, second);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(first),
        isTrue,
      );
    });

    test('the bridge hardware id is a separate identifier', () async {
      final identity = DeviceIdentity(FakeSecureStorage());
      expect(await identity.hardwareId(), isNot(await identity.deviceId()));
    });

    test('a device is only "bound" after the backend has bound it', () async {
      final identity = DeviceIdentity(FakeSecureStorage());
      expect(await identity.isDeviceBound(), isFalse);
      await identity.markDeviceBound();
      expect(await identity.isDeviceBound(), isTrue);
    });
  });

  test('uuidV4 is version 4 and a variant-1 layout', () {
    for (var i = 0; i < 20; i++) {
      final id = uuidV4();
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id),
        isTrue,
        reason: id,
      );
    }
    expect(uuidV4(), isNot(uuidV4()));
  });

  group('BridgeCredentialStorage', () {
    test('the SIGNALS key round-trips through secure storage and can be forgotten', () async {
      final storage = FakeSecureStorage();
      final credentials = BridgeCredentialStorage(storage);
      expect(await credentials.readSignalsKey(), isNull);
      await credentials.saveSignalsKey('PH-SIGNALS-ABC');
      expect(await credentials.readSignalsKey(), 'PH-SIGNALS-ABC');
      await credentials.clearSignalsKey();
      expect(await credentials.readSignalsKey(), isNull);
    });

    test('the control token is a separate, operator-only secret', () async {
      final storage = FakeSecureStorage();
      final credentials = BridgeCredentialStorage(storage);
      expect(await credentials.readControlToken(), isNull);
      await credentials.saveControlToken('control-jwt');
      expect(await credentials.readControlToken(), 'control-jwt');
      // Clearing the licence key must not touch the control credential, and
      // vice versa: they belong to different systems.
      await credentials.clearSignalsKey();
      expect(await credentials.readControlToken(), 'control-jwt');
      await credentials.clearControlToken();
      expect(await credentials.readControlToken(), isNull);
    });

    test('the identifiers are stored, never invented per call', () async {
      final storage = FakeSecureStorage();
      final identity = DeviceIdentity(storage);
      final deviceId = await identity.deviceId();
      final hardwareId = await identity.hardwareId();
      expect(await storage.read('account_device_id'), deviceId);
      expect(await storage.read('device_hardware_id'), hardwareId);
    });
  });
}
