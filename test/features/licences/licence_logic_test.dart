import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/licences/data/mock_licence_service.dart';
import 'package:code_phantom_app/features/licences/domain/licence_enums.dart';

void main() {
  late MockLicenceService service;
  setUp(() => service = MockLicenceService());

  test('generate() produces a key in the CPT-XXX-####-####-#### shape', () async {
    final licence = await service.generate(
      userId: 'user_test',
      product: 'Scanner',
      duration: LicenceDuration.thirtyDays,
      maxDevices: 2,
    );

    expect(licence.key, matches(RegExp(r'^CPT-[A-Z0-9]{3}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
    expect(licence.status, LicenceStatus.unactivated);
    expect(licence.maxDevices, 2);
  });

  test('generate() with a 30-day duration sets an expiry ~30 days out', () async {
    final before = DateTime.now();
    final licence = await service.generate(
      userId: 'user_test',
      product: 'Signals',
      duration: LicenceDuration.thirtyDays,
      maxDevices: 1,
    );

    expect(licence.expiresAt, isNotNull);
    final daysUntilExpiry = licence.expiresAt!.difference(before).inDays;
    expect(daysUntilExpiry, inInclusiveRange(29, 30));
  });

  test('generate() with lifetime duration sets no expiry', () async {
    final licence = await service.generate(
      userId: 'user_test',
      product: 'EA',
      duration: LicenceDuration.lifetime,
      maxDevices: 1,
    );

    expect(licence.expiresAt, isNull);
  });

  test('revoke() sets status to REVOKED', () async {
    final licences = await service.watchLicences().first;
    final target = licences.first;

    final revoked = await service.revoke(target.id);

    expect(revoked.status, LicenceStatus.revoked);
  });

  test('renew() reactivates and extends expiry', () async {
    final licences = await service.watchLicences().first;
    final suspended = licences.firstWhere((l) => l.status == LicenceStatus.suspended);

    final renewed = await service.renew(suspended.id, LicenceDuration.thirtyDays);

    expect(renewed.status, LicenceStatus.active);
    expect(renewed.expiresAt!.isAfter(DateTime.now()), isTrue);
  });

  test('acting on an unknown licence id throws', () {
    expect(() => service.revoke('does_not_exist'), throwsA(isA<StateError>()));
  });
}
