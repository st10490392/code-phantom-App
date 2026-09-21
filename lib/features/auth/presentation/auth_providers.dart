import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_service.dart';
import '../data/mock_auth_service.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

/// Swap this single provider for an `ApiAuthService` in Phase 2 — nothing
/// else in the app needs to change.
final authServiceProvider = Provider<AuthService>(
  (ref) => MockAuthService(ref.watch(secureStorageProvider)),
);

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
    final session = await _authService.restoreSession();
    state = session != null
        ? AuthState(status: AuthStatus.authenticated, session: session)
        : const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login(String email, String password) async {
    try {
      final session = await _authService.login(email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, session: session);
    } on AuthException catch (e) {
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
