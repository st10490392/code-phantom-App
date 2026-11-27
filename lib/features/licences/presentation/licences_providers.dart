import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../data/api_licence_service.dart';
import '../data/licence_service.dart';
import '../data/mock_licence_service.dart';
import '../domain/licence.dart';
import '../../auth/presentation/auth_providers.dart' show appEnvironmentProvider;

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: ApiConfig.baseUrl, tokenStorage: ref.watch(tokenStorageProvider)),
);

final licenceServiceProvider = Provider<LicenceService>((ref) {
  final env = ref.watch(appEnvironmentProvider);
  if (env == AppEnvironment.mock) return MockLicenceService();
  return ApiLicenceService(ref.watch(apiClientProvider));
});

final licenceListProvider = StreamProvider<List<Licence>>((ref) {
  return ref.watch(licenceServiceProvider).watchLicences();
});
