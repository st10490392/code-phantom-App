import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_scanner_service.dart';
import '../data/scanner_service.dart';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';

/// Swap for `ApiScannerService` in Phase 3 — UI depends only on this provider.
final scannerServiceProvider = Provider<ScannerService>((ref) => MockScannerService());

final setupsByStatusProvider =
    StreamProvider.family<List<ScannerSetup>, SetupStatus?>((ref, status) {
  return ref.watch(scannerServiceProvider).watchSetups(status: status);
});

final allSetupsProvider = StreamProvider<List<ScannerSetup>>((ref) {
  return ref.watch(scannerServiceProvider).watchSetups();
});
