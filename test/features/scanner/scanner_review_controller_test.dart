import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_enums.dart';
import 'package:code_phantom_app/features/scanner/presentation/scanner_providers.dart';
import 'package:code_phantom_app/features/signals/presentation/signals_providers.dart';

const _owner = AuthUser(
  id: 'u_owner',
  email: 'owner@codephantom.dev',
  displayName: 'Owner',
  role: AppRole.owner,
  permissions: PermissionSet.none,
);

const _scannerClient = AuthUser(
  id: 'u_scanner_client',
  email: 'scanner.client@codephantom.dev',
  displayName: 'Scanner Client',
  role: AppRole.scannerClient,
  permissions: PermissionSet({Permission.scannerAccess}),
);

void main() {
  ProviderContainer buildContainer(AuthUser user) {
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(user)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('pending setups load correctly for a reviewer', () async {
    final container = buildContainer(_owner);
    final pending = await container.read(setupsByStatusProvider(SetupStatus.pending).future);

    expect(pending, isNotEmpty);
    expect(pending.every((s) => s.status == SetupStatus.pending), isTrue);
  });

  test('approved setups load correctly', () async {
    final container = buildContainer(_owner);
    final approved = await container.read(setupsByStatusProvider(SetupStatus.approved).future);

    expect(approved, isNotEmpty);
    expect(approved.every((s) => s.status == SetupStatus.approved), isTrue);
  });

  test('rejected setups load correctly', () async {
    final container = buildContainer(_owner);
    final rejected = await container.read(setupsByStatusProvider(SetupStatus.rejected).future);

    expect(rejected, isNotEmpty);
    expect(rejected.every((s) => s.status == SetupStatus.rejected), isTrue);
  });

  test('OWNER can approve a pending setup', () async {
    final container = buildContainer(_owner);
    final target = (await container.read(setupsByStatusProvider(SetupStatus.pending).future)).first;

    await container.read(scannerReviewControllerProvider.notifier).approve(target.id);

    final updated = await container.read(scannerServiceProvider).getSetupById(target.id);
    expect(updated!.status, SetupStatus.approved);
    expect(updated.reviewedBy, 'Owner');
  });

  test('unauthorized role cannot approve — throws and leaves the setup untouched', () async {
    final container = buildContainer(_scannerClient);
    final rawService = container.read(scannerServiceProvider);
    final anyPending = (await rawService.watchSetups(status: SetupStatus.pending).first).first;

    await expectLater(
      container.read(scannerReviewControllerProvider.notifier).approve(anyPending.id),
      throwsA(isA<ScannerAuthorizationException>()),
    );

    final stillPending = await rawService.getSetupById(anyPending.id);
    expect(stillPending!.status, SetupStatus.pending, reason: 'a rejected authorization must not mutate data');
  });

  test('OWNER can reject a pending setup and the reason is stored', () async {
    final container = buildContainer(_owner);
    final target = (await container.read(setupsByStatusProvider(SetupStatus.pending).future)).first;

    await container.read(scannerReviewControllerProvider.notifier).reject(target.id, reason: 'Poor R:R');

    final updated = await container.read(scannerServiceProvider).getSetupById(target.id);
    expect(updated!.status, SetupStatus.rejected);
    expect(updated.rejectionReason, 'Poor R:R');
    expect(updated.reviewedBy, 'Owner');
  });

  test('unauthorized role cannot reject either', () async {
    final container = buildContainer(_scannerClient);
    final rawService = container.read(scannerServiceProvider);
    final anyPending = (await rawService.watchSetups(status: SetupStatus.pending).first).first;

    await expectLater(
      container.read(scannerReviewControllerProvider.notifier).reject(anyPending.id, reason: 'Other'),
      throwsA(isA<ScannerAuthorizationException>()),
    );
  });

  test('approving removes the setup from the Pending list', () async {
    final container = buildContainer(_owner);
    final pendingBefore = await container.read(setupsByStatusProvider(SetupStatus.pending).future);
    final target = pendingBefore.first;

    await container.read(scannerReviewControllerProvider.notifier).approve(target.id);
    final pendingAfter = await container.read(setupsByStatusProvider(SetupStatus.pending).future);

    expect(pendingAfter.length, pendingBefore.length - 1);
    expect(pendingAfter.any((s) => s.id == target.id), isFalse);
  });

  test('approving a setup creates the corresponding signal', () async {
    final container = buildContainer(_owner);
    final target = (await container.read(setupsByStatusProvider(SetupStatus.pending).future)).first;

    await container.read(scannerReviewControllerProvider.notifier).approve(target.id);

    final signals = await container.read(signalServiceProvider).watchSignals().first;
    final created = signals.where((s) => s.setupId == target.id).toList();

    expect(created, hasLength(1));
    expect(created.single.symbol, target.symbol);
    expect(created.single.direction, target.direction);
  });

  test(
    'route/action authorization: a non-reviewer never receives pending or rejected '
    'data even when asking for it directly (History/null included)',
    () async {
      final container = buildContainer(_scannerClient);

      final pending = await container.read(setupsByStatusProvider(SetupStatus.pending).future);
      final rejected = await container.read(setupsByStatusProvider(SetupStatus.rejected).future);
      final history = await container.read(setupsByStatusProvider(null).future);

      // By design, a non-reviewer's request for ANY status silently falls
      // back to the approved-only list rather than ever exposing a real
      // pending/rejected setup — see _visibleSetups in scanner_providers.dart.
      expect(pending.any((s) => s.status != SetupStatus.approved), isFalse);
      expect(rejected.any((s) => s.status != SetupStatus.approved), isFalse);
      expect(history.every((s) => s.status == SetupStatus.approved), isTrue);
    },
  );

  test('setupByIdProvider resolves nothing for a non-reviewer on a pending setup id', () async {
    final owner = buildContainer(_owner);
    final pendingId = (await owner.read(setupsByStatusProvider(SetupStatus.pending).future)).first.id;

    final client = buildContainer(_scannerClient);
    await client.read(allSetupsProvider.future); // let the underlying stream emit once
    final result = client.read(setupByIdProvider(pendingId));

    expect(result.value, isNull);
  });
}
