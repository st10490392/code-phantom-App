import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/storage/device_identity_store.dart';
import '../../features/auth/fake_secure_storage.dart';

void main() {
  test('installation id is a stable random UUID per installation', () async {
    final store = DeviceIdentityStore(FakeSecureStorage());
    final first = await store.getOrCreateInstallationId();
    final second = await store.getOrCreateInstallationId();

    expect(second, first);
    expect(
      first,
      matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}
    );
  });

  test('server device id is persisted separately from installation id', () async {
    final store = DeviceIdentityStore(FakeSecureStorage());
    final installation = await store.getOrCreateInstallationId();
    await store.saveServerDeviceId('11111111-1111-4111-8111-111111111111');

    expect(
      await store.readServerDeviceId(),
      '11111111-1111-4111-8111-111111111111',
    );
    expect(await store.getOrCreateInstallationId(), installation);

    await store.clearServerDeviceId();
    expect(await store.readServerDeviceId(), isNull);
    expect(await store.getOrCreateInstallationId(), installation);
  });
}
,
      ),
    ),
    );
  });

  test('server device id is persisted separately from installation id', () async {
    final store = DeviceIdentityStore(FakeSecureStorage());
    final installation = await store.getOrCreateInstallationId();
    await store.saveServerDeviceId('11111111-1111-4111-8111-111111111111');

    expect(
      await store.readServerDeviceId(),
      '11111111-1111-4111-8111-111111111111',
    );
    expect(await store.getOrCreateInstallationId(), installation);

    await store.clearServerDeviceId();
    expect(await store.readServerDeviceId(), isNull);
    expect(await store.getOrCreateInstallationId(), installation);
  });
}
