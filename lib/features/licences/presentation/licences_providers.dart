import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_licence_service.dart';
import '../data/licence_service.dart';
import '../data/mock_licence_service.dart';
import '../domain/licence.dart';

/// MOCK → `MockLicenceService`; every connected environment →
/// `ApiLicenceService`, on the same `ApiClient`/session-refresh wiring every
/// other connected module uses (`auth_providers.dart`) — one provider
/// instance per client, so a licence call and an auth call share the same
/// token refresh and the same session-expiry signal.
final licenceServiceProvider = Provider<LicenceService>((ref) {
  final env = ref.watch(appEnvironmentProvider);
  if (env == AppEnvironment.mock) return MockLicenceService();
  return ApiLicenceService(ref.watch(apiClientProvider));
});

final licenceListProvider = StreamProvider<List<Licence>>((ref) {
  return ref.watch(licenceServiceProvider).watchLicences();
});
