import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utilities/startup_trace.dart';
import '../data/api_auth_service.dart';
import '../data/auth_service.dart';
import '../data/mock_auth_service.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: ApiConfig.baseUrl, tokenStorage: ref.watch(tokenStorageProvider)),
);

/// The environment this build/run is targeting. Defaults to
/// [ApiConfig.environment] (a `--dart-define=APP_ENV=...` build flag,
/// itself defaulting to [AppEnvironment.mock]) — overridden directly in
/// tests (`appEnvironmentProvider.overrideWithValue(...)`) so DEVELOPMENT-
/// mode provider selection is testable without a build-time flag.
final appEnvironmentProvider = Provider<AppEnvironment>((ref) => ApiConfig.environment);

/// MOCK → `MockAuthService` (existing mock accounts, untouched).
/// DEVELOPMENT/PRODUCTION → `ApiAuthService` against the real CodePhantom
/// backend. This is the only provider that changes per environment —
/// everything downstream (`AuthController`, `PermissionGate`, route
/// guards, every screen) depends on the `AuthService` interface, not on
/// which implementation is active.
final authServiceProvider = Provider<AuthService>((ref) {
  switch (ref.watch(appEnvironmentProvider)) {
    case AppEnvironment.mock:
      return MockAuthService(ref.watch(secureStorageProvider));
    case AppEnvironment.development:
    case AppEnvironment.production:
      return ApiAuthService(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
  }
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.session, this.errorMessage});

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  AuthUser? get user => session?.user;

  static const initial = AuthState(status: AuthStatus.unknown);

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(AuthState.initial) {
    _restore();
  }

  final AuthService _authService;

  Future<void> _restore() async {
    // Whole splash-to-first-screen gate, end to end — see
    // `ApiAuthService.restoreSession` for the finer-grained breakdown
    // (secure-storage reads vs. the `/me` network call) when this is slow.
    final session = await traceStartup('AuthController._restore', _authService.restoreSession);
    state = session != null
        ? AuthState(status: AuthStatus.authenticated, session: session)
        : const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login(String email, String password) async {
    try {
      final session = await _authService.login(email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, session: session);
    } on AppException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> requestPasswordReset(String email) =>
      _authService.requestPasswordReset(email: email);

  /// Never touches [state] — a new registration has no session to hold
  /// (email verification is required first). Errors propagate to the
  /// caller (the Create Account screen) as-is.
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) =>
      _authService.register(
        displayName: displayName,
        username: username,
        email: email,
        password: password,
      );

  Future<void> resendVerificationEmail(String email) =>
      _authService.resendVerificationEmail(email: email);
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authServiceProvider)),
);

final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);

/// Central permission check used by [PermissionGate] and route guards.
/// OWNER always evaluates to `true` regardless of stored grants.
final hasPermissionProvider = Provider.family<bool, Permission>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.isOwner) return true;
  return user.permissions.has(permission);
});
