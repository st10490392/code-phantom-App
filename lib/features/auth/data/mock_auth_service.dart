import '../../../core/permissions/permission.dart';
import '../../../core/permissions/permission_set.dart';
import '../../../core/permissions/app_role.dart';
import '../../../core/permissions/role_defaults.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import 'auth_service.dart';

/// Development-only mock credentials. NEVER ship real credentials this way —
/// Phase 2 replaces this whole class with an API-backed implementation.
class MockAccount {
  const MockAccount(this.email, this.password, this.user);
  final String email;
  final String password;
  final AuthUser user;
}

final List<MockAccount> mockAccounts = [
  const MockAccount(
    'owner@codephantom.dev',
    'owner123',
    AuthUser(
      id: 'user_owner',
      email: 'owner@codephantom.dev',
      displayName: 'Ripfumelo (Owner)',
      role: AppRole.owner,
      permissions: PermissionSet.owner,
    ),
  ),
  MockAccount(
    'admin@codephantom.dev',
    'admin123',
    AuthUser(
      id: 'user_admin',
      email: 'admin@codephantom.dev',
      displayName: 'Ops Admin',
      role: AppRole.admin,
      permissions: defaultPermissionsFor(AppRole.admin),
    ),
  ),
  MockAccount(
    'trader@codephantom.dev',
    'trader123',
    AuthUser(
      id: 'user_trader',
      email: 'trader@codephantom.dev',
      displayName: 'Sample Trader',
      role: AppRole.trader,
      permissions: defaultPermissionsFor(AppRole.trader),
    ),
  ),
  MockAccount(
    'scanner.client@codephantom.dev',
    'client123',
    AuthUser(
      id: 'user_scanner_client',
      email: 'scanner.client@codephantom.dev',
      displayName: 'Scanner-Only Client',
      role: AppRole.scannerClient,
      permissions: defaultPermissionsFor(AppRole.scannerClient),
    ),
  ),
  MockAccount(
    'signal.client@codephantom.dev',
    'client123',
    AuthUser(
      id: 'user_signal_client',
      email: 'signal.client@codephantom.dev',
      displayName: 'Signals-Only Client',
      role: AppRole.signalClient,
      permissions: defaultPermissionsFor(AppRole.signalClient),
    ),
  ),
  MockAccount(
    'ea.client@codephantom.dev',
    'client123',
    AuthUser(
      id: 'user_ea_client',
      email: 'ea.client@codephantom.dev',
      displayName: 'EA-Only Client',
      role: AppRole.eaClient,
      permissions: defaultPermissionsFor(AppRole.eaClient),
    ),
  ),
  const MockAccount(
    'friend@codephantom.dev',
    'internal123',
    AuthUser(
      id: 'user_internal_1',
      email: 'friend@codephantom.dev',
      displayName: 'Beta Tester',
      role: AppRole.internal,
      // Illustrates independent role/permission axes from the brief:
      // scanner+signals ON, EA/admin OFF, for an INTERNAL tester.
      permissions: PermissionSet({
        Permission.scannerAccess,
        Permission.signalsAccess,
      }),
    ),
  ),
];

class MockAuthService implements AuthService {
  MockAuthService(this._secureStorage);

  final SecureStorage _secureStorage;
  static const _sessionKey = 'mock_session_user_id';

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final match = mockAccounts.where(
      (a) => a.email.toLowerCase() == email.toLowerCase() && a.password == password,
    );
    if (match.isEmpty) {
      throw const AuthException('Invalid email or password.');
    }
    final account = match.first;
    await _secureStorage.write(_sessionKey, account.user.id);
    return _sessionFor(account.user);
  }

  @override
  Future<void> logout() async {
    await _secureStorage.delete(_sessionKey);
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final storedId = await _secureStorage.read(_sessionKey);
    if (storedId == null) return null;
    final match = mockAccounts.where((a) => a.user.id == storedId);
    if (match.isEmpty) return null;
    return _sessionFor(match.first.user);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // Mock: always "succeeds" without sending anything real.
  }

  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    // Self-service registration is an API-mode feature — MOCK mode's fixed
    // account list (above) has no signup path, and the login screen only
    // ever routes to this in DEVELOPMENT/PRODUCTION (see `app_router.dart`).
    throw const AuthException('Self-service registration is not available in MOCK mode.');
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    throw const AuthException('Email verification is not available in MOCK mode.');
  }

  AuthSession _sessionFor(AuthUser user) => AuthSession(
        user: user,
        accessToken: 'mock-access-token.${user.id}',
        refreshToken: 'mock-refresh-token.${user.id}',
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );
}
