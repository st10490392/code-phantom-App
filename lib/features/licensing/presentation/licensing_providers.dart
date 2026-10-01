import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/licensing_service.dart';
import '../domain/licensing_models.dart';

final licensingServiceProvider = Provider<LicensingService>((ref) {
  return LicensingService(
    ref.watch(apiClientProvider),
    ref.watch(deviceIdentityProvider),
  );
});

final ownerLicencesProvider = FutureProvider<List<CoreLicence>>((ref) async {
  return ref.watch(licensingServiceProvider).listLicences();
});
