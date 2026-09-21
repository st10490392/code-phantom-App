import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/scanner/data/mock_scanner_service.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_enums.dart';

void main() {
  late MockScannerService service;

  setUp(() => service = MockScannerService());

  test('a pending setup can be approved', () async {
    final setups = await service.watchSetups(status: SetupStatus.pending).first;
    final pending = setups.first;

    final approved = await service.approve(pending.id, note: 'Looks clean');

    expect(approved.status, SetupStatus.approved);
    expect(approved.notes, 'Looks clean');
  });

  test('a pending setup can be rejected with a reason', () async {
    final setups = await service.watchSetups(status: SetupStatus.pending).first;
    final pending = setups.first;

    final rejected = await service.reject(pending.id, reason: 'Low confluence');

    expect(rejected.status, SetupStatus.rejected);
    expect(rejected.notes, 'Low confluence');
  });

  test('approving one setup does not affect other setups\' status', () async {
    final pendingBefore = await service.watchSetups(status: SetupStatus.pending).first;
    expect(pendingBefore.length, greaterThan(1));

    await service.approve(pendingBefore.first.id);

    final pendingAfter = await service.watchSetups(status: SetupStatus.pending).first;
    expect(pendingAfter.length, pendingBefore.length - 1);
  });

  test('watchSetups(status: null) returns every status ("History")', () async {
    final all = await service.watchSetups().first;
    final statuses = all.map((s) => s.status).toSet();
    // The seed data spans pending/approved/rejected.
    expect(statuses.length, greaterThan(1));
  });

  test('acting on an unknown setup id throws', () {
    expect(() => service.approve('does_not_exist'), throwsA(isA<StateError>()));
  });
}
