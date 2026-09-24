import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/features/auth/data/auth_service.dart';
import 'package:code_phantom_app/features/auth/domain/auth_session.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/auth/presentation/login_screen.dart';

class _StubAuthService implements AuthService {
  @override
  Future<AuthSession> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> requestPasswordReset({required String email}) => throw UnimplementedError();

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail({required String email}) => throw UnimplementedError();
}

void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    required Size surfaceSize,
    AppEnvironment env = AppEnvironment.development,
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const Scaffold(body: Text('register'))),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const Scaffold(body: Text('forgot password')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_StubAuthService()),
          appEnvironmentProvider.overrideWithValue(env),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the brand header, sign-in form, and a create-account action', (tester) async {
    await pumpLogin(tester, surfaceSize: const Size(400, 800));

    expect(find.text('CodePhantom Technologies'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('renders without overflow on a small Android screen (e.g. 320x568)', (tester) async {
    await pumpLogin(tester, surfaceSize: const Size(320, 568));

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow on a very short screen (e.g. 360x600 with mock hints)',
      (tester) async {
    await pumpLogin(tester, surfaceSize: const Size(360, 600), env: AppEnvironment.mock);

    // MOCK mode also renders the dev-only mock-accounts hint block, which is
    // the tallest variant of this screen — the one most likely to overflow.
    expect(find.text('DEVELOPMENT ONLY — MOCK ACCOUNTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Create account navigates to /register', (tester) async {
    await pumpLogin(tester, surfaceSize: const Size(400, 800));

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('register'), findsOneWidget);
  });
}
