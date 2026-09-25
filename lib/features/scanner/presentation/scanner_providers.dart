import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../notifications/domain/app_notification.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../signals/presentation/signals_providers.dart';
import '../data/mock_scanner_service.dart';
import '../data/api_scanner_service.dart';
import '../../../core/config/app_environment.dart';
import '../data/scanner_service.dart';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';

/// Swap for `ApiScannerService` in Phase 3 — UI depends only on this provider.
final scannerServiceProvider = Provider<ScannerService>((ref) =>
    ref.watch(appEnvironmentProvider) == AppEnvironment.mock
        ? MockScannerService()
        : ApiScannerService(ref.watch(apiClientProvider)));

/// The single place that decides which setups a caller is allowed to see.
///
/// This is data-layer enforcement, not just a hidden tab: a user without
/// [Permission.scannerReview] gets back an approved-only stream no matter
/// which `status` they ask for (including `null`/"History", which would
/// otherwise include pending and rejected setups). OWNER/ADMIN (who hold
/// `scannerReview` by default) see the real filter.
Stream<List<ScannerSetup>> _visibleSetups(Ref ref, SetupStatus? status) {
  final canReview = ref.watch(hasPermissionProvider(Permission.scannerReview));
  final service = ref.watch(scannerServiceProvider);
  if (!canReview && status != SetupStatus.approved) {
    return service.watchSetups(status: SetupStatus.approved);
  }
  return service.watchSetups(status: status);
}

final setupsByStatusProvider =
    StreamProvider.family<List<ScannerSetup>, SetupStatus?>((ref, status) {
  return _visibleSetups(ref, status);
});

final allSetupsProvider = StreamProvider<List<ScannerSetup>>((ref) {
  return _visibleSetups(ref, null);
});

/// One-shot lookup for the setup detail screen (`/scanner/setup/:id`).
/// Built on [allSetupsProvider], so it inherits the same visibility rule —
/// a non-reviewer deep-linking to a pending/rejected setup's id simply
/// finds nothing, the same as if it never existed for them.
final setupByIdProvider = Provider.family<AsyncValue<ScannerSetup?>, String>((ref, id) {
  final all = ref.watch(allSetupsProvider);
  return all.whenData((setups) {
    for (final s in setups) {
      if (s.id == id) return s;
    }
    return null;
  });
});

/// Thrown by [ScannerReviewController] when the acting user lacks
/// [Permission.scannerReview]. This is the domain/service-layer
/// enforcement the brief asks for: even if a widget bug ever put an
/// Approve/Reject/Edit control in front of an unauthorized user, the
/// action itself still fails here, not just at the UI.
class ScannerAuthorizationException implements Exception {
  const ScannerAuthorizationException(this.action);
  final String action;

  @override
  String toString() => 'Not authorized to $action.';
}

/// Orchestrates the full Approve/Reject/Edit workflow described in the
/// brief so none of it is hard-coded into a widget:
///
/// approve  → ScannerService.approve → SignalService.createFromSetup →
///            two NotificationService.notify() calls ("Setup approved",
///            "Signal created from approved setup")
/// reject   → ScannerService.reject (with a required reason) →
///            NotificationService.notify() ("Setup rejected")
/// updateSetup → ScannerService.update (edit before approval)
///
/// Exposes [AsyncValue] state so the UI can show loading/error feedback
/// with the app's existing reusable state widgets instead of each screen
/// managing its own booleans.
class ScannerReviewController extends StateNotifier<AsyncValue<void>> {
  ScannerReviewController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  bool get _canReview => _ref.read(hasPermissionProvider(Permission.scannerReview));
  String? get _reviewerName => _ref.read(currentUserProvider)?.displayName;

  Future<void> approve(String setupId, {String? note}) => _run(() async {
        if (!_canReview) {
          throw const ScannerAuthorizationException('approve scanner setups');
        }
        final approved = await _ref.read(scannerServiceProvider).approve(
              setupId,
              note: note,
              reviewedBy: _reviewerName,
            );
        await _ref.read(signalServiceProvider).createFromSetup(approved);
        final now = DateTime.now();
        final notifications = _ref.read(notificationServiceProvider);
        await notifications.notify(AppNotification(
          id: 'notif_setup_approved_${approved.id}_${now.microsecondsSinceEpoch}',
          title: 'Setup approved',
          body: '${approved.symbol} ${approved.direction.wireValue} approved by ${_reviewerName ?? 'a reviewer'}.',
          priority: NotificationPriority.success,
          category: 'scanner',
          createdAt: now,
          relatedEntityId: approved.id,
        ),);
        await notifications.notify(AppNotification(
          id: 'notif_signal_created_${approved.id}_${now.microsecondsSinceEpoch}',
          title: 'Signal created from approved setup',
          body: '${approved.symbol} ${approved.direction.wireValue} is now in the Signals module.',
          priority: NotificationPriority.info,
          category: 'signals',
          createdAt: now,
          relatedEntityId: approved.id,
        ),);
      });

  Future<void> reject(String setupId, {required String reason}) => _run(() async {
        if (!_canReview) {
          throw const ScannerAuthorizationException('reject scanner setups');
        }
        final rejected = await _ref.read(scannerServiceProvider).reject(
              setupId,
              reason: reason,
              reviewedBy: _reviewerName,
            );
        await _ref.read(notificationServiceProvider).notify(AppNotification(
              id: 'notif_setup_rejected_${rejected.id}_${DateTime.now().microsecondsSinceEpoch}',
              title: 'Setup rejected',
              body: '${rejected.symbol} ${rejected.direction.wireValue} rejected — $reason.',
              priority: NotificationPriority.warning,
              category: 'scanner',
              createdAt: DateTime.now(),
              relatedEntityId: rejected.id,
            ),);
      });

  Future<void> updateSetup(ScannerSetup setup) => _run(() async {
        if (!_canReview) {
          throw const ScannerAuthorizationException('edit scanner setups');
        }
        await _ref.read(scannerServiceProvider).update(setup);
      });

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final scannerReviewControllerProvider =
    StateNotifierProvider<ScannerReviewController, AsyncValue<void>>(
  (ref) => ScannerReviewController(ref),
);
