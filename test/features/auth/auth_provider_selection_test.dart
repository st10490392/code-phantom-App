import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/features/auth/data/api_auth_service.dart';
import 'package:code_phantom_app/features/auth/data/mock_auth_service.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'fake_secure_storage.dart';

void main() {
  test('MOCK mode (the default) resolves authServiceProvider to MockAuthService', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appEnvironmentProvider), AppEnvironment.mock);
    expect(container.read(authServiceProvider), isA<MockAuthService>());
  });

  test('DEVELOPMENT mode resolves authServiceProvider to ApiAuthService', () {
    final container = ProviderContainer(
      overrides: [appEnvironmentProvider.overrideWithValue(AppEnvironment.development)],
    );
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), isA<ApiAuthService>());
  });

  test('STAGING mode also resolves authServiceProvider to ApiAuthService', () {
    final container = ProviderContainer(
      overrides: [appEnvironmentProvider.overrideWithValue(AppEnvironment.staging)],
    );
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), isA<ApiAuthService>());
  });

  test('PRODUCTION mode also resolves authServiceProvider to ApiAuthService', () {
    final container = ProviderContainer(
      overrides: [appEnvironmentProvider.overrideWithValue(AppEnvironment.production)],
    );
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), isA<ApiAuthService>());
  });

  test('mock accounts are untouched and still authenticate through the provider chain in MOCK mode', () async {
    final container = ProviderContainer(
      overrides: [secureStorageProvider.overrideWithValue(FakeSecureStorage())],
    );
    addTearDown(container.dispose);

    final service = container.read(authServiceProvider) as MockAuthService;
    final session = await service.login(email: 'owner@codephantom.dev', password: 'owner123');
    expect(session.user.displayName, 'Ripfumelo (Owner)');
  });
}
