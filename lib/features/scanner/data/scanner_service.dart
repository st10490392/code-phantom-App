import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';

/// External-engine boundary: the CPT Scanner is a separate product. This
/// interface is the ONLY contact point the app has with it — Phase 3 wires
/// `ApiScannerService` to the real Scanner backend behind this same
/// contract. Strategy/detection logic is never implemented here.
///
/// `watchSetups(status: ...)` already serves as "getPendingSetups" /
/// "getApprovedSetups" / "getRejectedSetups" (filter by [SetupStatus] and
/// take `.first` for a one-shot read, or watch it live) — there is no
/// separate getter per status so the stream stays the single source of
/// truth for list data.
abstract class ScannerService {
  Stream<List<ScannerSetup>> watchSetups({SetupStatus? status});

  /// One-shot lookup by id, e.g. for a `/scanner/setup/:id` deep link.
  /// Returns `null` if no setup with that id exists.
  Future<ScannerSetup?> getSetupById(String id);

  /// Approves a pending setup. [reviewedBy] should be the acting reviewer's
  /// display name; callers are expected to have already checked
  /// [Permission.scannerReview] before calling this — see
  /// `ScannerReviewController` in `scanner_providers.dart` for the actual
  /// enforcement point.
  Future<ScannerSetup> approve(String setupId, {String? note, String? reviewedBy});

  /// Rejects a pending setup with a required [reason] (see
  /// `scannerRejectionReasons` for the canned reason list).
  Future<ScannerSetup> reject(String setupId, {required String reason, String? reviewedBy});

  /// Field edits only (entry/stopLoss/takeProfits/direction/timeframe/notes)
  /// on a still-`pending` setup — throws [StateError] otherwise. Stamps
  /// `editedBeforeApproval = true` automatically when a material trade
  /// field actually changed.
  Future<ScannerSetup> update(ScannerSetup setup);
}
