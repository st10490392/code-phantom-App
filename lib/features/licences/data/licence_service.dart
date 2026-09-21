import '../domain/licence.dart';
import '../domain/licence_enums.dart';

/// Mock only. A real backend must generate and validate keys server-side —
/// see brief's Security Principles and docs/ARCHITECTURE.md §8. This
/// service exists so the UI/UX and flows can be built now.
abstract class LicenceService {
  Stream<List<Licence>> watchLicences({String? userId});

  Future<Licence> generate({
    required String userId,
    required String product,
    required LicenceDuration duration,
    required int maxDevices,
  });

  Future<Licence> revoke(String licenceId);

  Future<Licence> renew(String licenceId, LicenceDuration duration);

  Future<Licence> suspend(String licenceId);
}
