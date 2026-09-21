import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';

/// External-engine boundary: the CPT Scanner is a separate product. This
/// interface is the ONLY contact point the app has with it — Phase 3 wires
/// `ApiScannerService` to the real Scanner backend behind this same
/// contract. Strategy/detection logic is never implemented here.
abstract class ScannerService {
  Stream<List<ScannerSetup>> watchSetups({SetupStatus? status});

  Future<ScannerSetup> approve(String setupId, {String? note});

  Future<ScannerSetup> reject(String setupId, {required String reason});

  Future<ScannerSetup> update(ScannerSetup setup);
}
