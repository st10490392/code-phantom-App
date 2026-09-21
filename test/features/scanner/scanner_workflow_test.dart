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
    expect(rejected.rejectionReason, 'Low confluence');
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

  test('approve() stamps reviewedAt and reviewedBy', () async {
    final pending = (await service.watchSetups(status: SetupStatus.pending).first).first;

    final approved = await service.approve(pending.id, reviewedBy: 'Owner');

    expect(approved.reviewedAt, isNotNull);
    expect(approved.reviewedBy, 'Owner');
  });

  test('reject() stamps reviewedAt and reviewedBy alongside the reason', () async {
    final pending = (await service.watchSetups(status: SetupStatus.pending).first).first;

    final rejected = await service.reject(pending.id, reason: 'Duplicate', reviewedBy: 'Ops Admin');

    expect(rejected.reviewedAt, isNotNull);
    expect(rejected.reviewedBy, 'Ops Admin');
    expect(rejected.rejectionReason, 'Duplicate');
  });

  test('re-approving an already-approved setup is an invalid transition', () async {
    final approved = (await service.watchSetups(status: SetupStatus.approved).first).first;
    expect(() => service.approve(approved.id), throwsA(isA<StateError>()));
  });

  test('update() edits allowed fields and marks editedBeforeApproval on a material change', () async {
    final original = (await service.watchSetups(status: SetupStatus.pending).first).first;

    final edited = original.copyWith(entry: original.entry + 0.0010, notes: 'Tightened entry');
    final result = await service.update(edited);

    expect(result.entry, closeTo(original.entry + 0.0010, 1e-9));
    expect(result.notes, 'Tightened entry');
    expect(result.editedBeforeApproval, isTrue);
    expect(result.detectedAt, original.detectedAt, reason: 'detection time must never change');
  });

  test('update() does not set editedBeforeApproval when no trade field actually changed', () async {
    final original = (await service.watchSetups(status: SetupStatus.pending).first).first;

    final edited = original.copyWith(notes: 'Just a comment');
    final result = await service.update(edited);

    expect(result.editedBeforeApproval, isFalse);
  });

  test('update() rejects editing a setup that is no longer pending', () async {
    final approved = (await service.watchSetups(status: SetupStatus.approved).first).first;
    expect(
      () => service.update(approved.copyWith(entry: approved.entry + 1)),
      throwsA(isA<StateError>()),
    );
  });

  test('getSetupById finds an existing setup and returns null for an unknown id', () async {
    final pending = (await service.watchSetups(status: SetupStatus.pending).first).first;

    expect((await service.getSetupById(pending.id))?.id, pending.id);
    expect(await service.getSetupById('does_not_exist'), isNull);
  });
}
