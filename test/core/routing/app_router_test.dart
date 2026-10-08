import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/core/routing/app_router.dart';
import 'package:code_phantom_app/features/auth/data/auth_service.dart';
import 'package:code_phantom_app/features/auth/domain/auth_session.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_callback_screen.dart';
import 'package:code_phantom_app/features/auth/presentation/create_account_screen.dart';
import 'package:code_phantom_app/features/auth/presentation/register_placeholder_screen.dart';

/// Resolves `restoreSession()` to a fixed user immediately, so
/// [AuthController] reaches `AuthStatus.authenticated` without ever touching
/// the real `flutter_secure_storage` platform channel (unavailable in
/// `flutter_test`).
class _FixedAuthService implements AuthService {
  _FixedAuthService(this.user);
  final AuthUser user;

  @override
  Future<AuthSession?> restoreSession() async => AuthSession(
        user: user,
        accessToken: 'test-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

  @override
  Future<AuthSession> login(
          {required String email, required String password,}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset(
          {required String accessToken, required String newPassword,}) =>
      throw UnimplementedError();

  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail({required String email}) =>
      throw UnimplementedError();
}

/// Always unauthenticated — for exercising pre-login routes (`/register`)
/// without the router immediately bouncing to `/dashboard`.
class _UnauthenticatedAuthService implements AuthService {
  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login(
          {required String email, required String password,}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset(
          {required String accessToken, required String newPassword,}) =>
      throw UnimplementedError();

  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail({required String email}) =>
      throw UnimplementedError();
}

void main() {
  group('CodePhantom auth callback URI', () {
    test('recognizes the registered custom scheme and host', () {
      expect(
        isCodePhantomAuthCallback(
            Uri.parse('codephantom://auth-callback#type=recovery'),),
        isTrue,
      );
      expect(
          isCodePhantomAuthCallback(
              Uri.parse('https://example.com/auth-callback'),),
          isFalse,);
    });

    test('parses Supabase callback values from the fragment', () {
      final params = authCallbackParameters(
        Uri.parse(
            'codephantom://auth-callback#access_token=abc123&type=recovery',),
      );
      expect(params['access_token'], 'abc123');
      expect(params['type'], 'recovery');
    });
  });

  group('permissionForPath — route → permission mapping', () {
    test('gated module routes map to their permission', () {
      expect(permissionForPath('/scanner'), Permission.scannerAccess);
      expect(permissionForPath('/scanner/setup/abc'), Permission.scannerAccess);
      expect(permissionForPath('/signals'), Permission.signalsAccess);
      expect(permissionForPath('/signals/87654321-4321-4321-4321-210987654321'), Permission.signalsAccess);
      expect(permissionForPath('/ea'), Permission.systemAdmin);
    });

    test('always-open routes have no gate', () {
      expect(permissionForPath('/dashboard'), isNull);
      expect(permissionForPath('/notifications'), isNull);
      expect(permissionForPath('/settings'), isNull);
      expect(permissionForPath('/settings/profile'), isNull);
    });
  });

  group('appRouterProvider redirect — navigation authorization', () {
    Future<GoRouter> pumpRouterAs(WidgetTester tester, AuthUser user) async {
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_FixedAuthService(user)),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(appRouterProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      // Bounded pump instead of pumpAndSettle: a loading screen's
      // CircularProgressIndicator repeats forever and would never let
      // pumpAndSettle finish, even though the mock auth restore itself
      // resolves on the next microtask.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return router;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    String locationOf(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('an EA customer cannot reach the private command centre',
        (tester) async {
      const eaClient = AuthUser(
        id: 'u_ea',
        email: 'ea.client@codephantom.dev',
        displayName: 'EA-Only Client',
        role: AppRole.eaClient,
        permissions: PermissionSet({Permission.eaAccess}),
      );

      final router = await pumpRouterAs(tester, eaClient);

      router.go('/ea');
      await settle(tester);

      expect(locationOf(router), isNot('/ea'));
    });

    testWidgets(
      'a new CLIENT with zero permissions cannot reach any gated module via a deep link',
      (tester) async {
        const client = AuthUser(
          id: 'u_client',
          email: 'new.client@codephantom.dev',
          displayName: 'New Client',
          role: AppRole.client,
          permissions: PermissionSet.none,
        );

        final router = await pumpRouterAs(tester, client);
        expect(locationOf(router), '/dashboard');

        for (final path in ['/scanner', '/signals', '/signals/87654321-4321-4321-4321-210987654321', '/ea']) {
          router.go(path);
          await settle(tester);
          expect(
            locationOf(router),
            '/dashboard',
            reason: 'CLIENT with no grants must be redirected away from $path',
          );
        }
      },
    );

    testWidgets('OWNER can reach every gated route regardless of stored grants',
        (tester) async {
      const owner = AuthUser(
        id: 'u_owner',
        email: 'owner@codephantom.dev',
        displayName: 'Owner',
        role: AppRole.owner,
        permissions: PermissionSet.none,
      );

      final router = await pumpRouterAs(tester, owner);

      for (final path in ['/scanner', '/signals', '/ea']) {
        router.go(path);
        await settle(tester);
        expect(locationOf(router), path,
            reason: 'OWNER must not be redirected away from $path',);
      }
    });
  });

  group('/register — environment-based screen selection', () {
    Future<GoRouter> pumpRegisterRouteAs(
        WidgetTester tester, AppEnvironment env,) async {
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider
                .overrideWithValue(_UnauthenticatedAuthService()),
            appEnvironmentProvider.overrideWithValue(env),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(appRouterProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      router.go('/register');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return router;
    }

    testWidgets('MOCK mode shows the placeholder registration screen',
        (tester) async {
      await pumpRegisterRouteAs(tester, AppEnvironment.mock);

      expect(find.byType(RegisterPlaceholderScreen), findsOneWidget);
      expect(find.byType(CreateAccountScreen), findsNothing);
    });

    testWidgets(
        'DEVELOPMENT mode shows the real Create Account screen (selects the API service)',
        (tester) async {
      await pumpRegisterRouteAs(tester, AppEnvironment.development);

      expect(find.byType(CreateAccountScreen), findsOneWidget);
      expect(find.byType(RegisterPlaceholderScreen), findsNothing);
    });

    testWidgets('PRODUCTION mode also shows the real Create Account screen',
        (tester) async {
      await pumpRegisterRouteAs(tester, AppEnvironment.production);

      expect(find.byType(CreateAccountScreen), findsOneWidget);
    });
  });
}
