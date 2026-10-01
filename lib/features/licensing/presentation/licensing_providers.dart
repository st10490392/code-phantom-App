import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/licensing_service.dart';
import '../domain/licensing_models.dart';

final licensingServiceProvider = Provider<LicensingService?>((ref) {
  if (ref.watch(appEnvironmentProvider) == AppEnvironment.mock) return null;
  return LicensingService(
    ref.watch(apiClientProvider),
    ref.watch(deviceIdentityProvider),
  );
});

final ownerLicencesProvider = FutureProvider<List<CoreLicence>>((ref) async {
  final service = ref.watch(licensingServiceProvider);
  if (service == null) return const <CoreLicence>[];
  return service.listLicences();
});
