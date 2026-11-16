import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/permissions/permission.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_integration_service.dart';
import '../data/integration_service.dart';
import '../data/mock_integration_service.dart';
import '../domain/integration.dart';

/// MOCK → in-memory [MockIntegrationService] (tests, demos, `flutter run`
/// without APP_ENV). Every connected environment (development, staging,
/// production) → [ApiIntegrationService] against the real backend, which is the
/// source of truth for integrations. The UI depends only on this provider.
final integrationServiceProvider = Provider<IntegrationService>((ref) =>
    ref.watch(appEnvironmentProvider) == AppEnvironment.mock
        ? MockIntegrationService()
        : ApiIntegrationService(ref.watch(apiClientProvider)));

/// Stream of all integrations visible to the current user.
final integrationsProvider = StreamProvider<List<Integration>>((ref) {
  return ref.watch(integrationServiceProvider).watchIntegrations();
});

/// Controller for integration mutations (create/revoke) with loading/error state.
/// Only OWNER role with integrationsManage permission may execute these actions.
class IntegrationController extends StateNotifier<AsyncValue<void>> {
  IntegrationController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Returns true only if the current user is an OWNER with the permission.
  bool get _canManage {
    final user = _ref.read(currentUserProvider);
    if (user == null) return false;
    // SECURITY: OWNER role AND permission required (defense in depth)
    return user.isOwner && _ref.read(hasPermissionProvider(Permission.integrationsManage));
  }

  Future<Integration> createScannerPublisher({required String name}) async {
    if (!_canManage) {
      throw const IntegrationAuthorizationException('create integrations');
    }
    state = const AsyncValue.loading();
    try {
      final integration = await _ref
          .read(integrationServiceProvider)
          .createScannerPublisher(name: name);
      state = const AsyncValue.data(null);
      return integration;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Integration> revoke(String integrationId) async {
    if (!_canManage) {
      throw const IntegrationAuthorizationException('revoke integrations');
    }
    state = const AsyncValue.loading();
    try {
      final integration = await _ref
          .read(integrationServiceProvider)
          .revoke(integrationId);
      state = const AsyncValue.data(null);
      return integration;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final integrationControllerProvider =
    StateNotifierProvider<IntegrationController, AsyncValue<void>>(
  (ref) => IntegrationController(ref),
);

/// Thrown when the acting user lacks OWNER role and integrationsManage permission.
/// This is the domain/service-layer enforcement the brief asks for:
/// even if a widget bug ever put a Create/Revoke control in front of an
/// unauthorized user, the action itself still fails here, not just at the UI.
class IntegrationAuthorizationException implements Exception {
  const IntegrationAuthorizationException(this.action);

  final String action;

  @override
  String toString() => 'IntegrationAuthorizationException: not allowed to $action';
}