import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/features/auth/data/auth_service.dart';
import 'package:code_phantom_app/features/auth/domain/auth_session.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/auth/presentation/verify_email_screen.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.resendError});

  final AppException? resendError;
  int resendCalls = 0;
  String? lastEmail;

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    resendCalls++;
    lastEmail = email;
    if (resendError != null) throw resendError!;
  }

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
  Future<void> confirmPasswordReset({required String accessToken, required String newPassword}) =>
      throw UnimplementedError();

  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();
}

void main() {
  Future<GoRouter> pumpVerifyEmail(
    WidgetTester tester,
    AuthService service, {
    String email = 'new.client@codephantom.dev',
    Size surfaceSize = const Size(400, 800),
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/verify-email',
      routes: [
        GoRoute(
          path: '/verify-email',
          builder: (_, __) => VerifyEmailScreen(email: email),
        ),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login screen'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  testWidgets('shows the email that was registered', (tester) async {
    final service = _FakeAuthService();
    await pumpVerifyEmail(tester, service, email: 'someone@codephantom.dev');

    expect(
      find.textContaining('We sent a verification link to someone@codephantom.dev'),
      findsOneWidget,
    );
  });

  testWidgets('resend success shows a confirmation and starts a cooldown', (tester) async {
    final service = _FakeAuthService();
    await pumpVerifyEmail(tester, service);

    await tester.tap(find.text('Resend verification email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.resendCalls, 1);
    expect(service.lastEmail, 'new.client@codephantom.dev');
    expect(find.text('Verification email sent again.'), findsOneWidget);
    // Cooldown started — the button now shows a countdown instead of the
    // resend label, so a second tap can't fire immediately.
    expect(find.textContaining('Resend in'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('resend failure shows a clean error message, not a stack trace', (tester) async {
    final service = _FakeAuthService(
      resendError: const NetworkException(),
    );
    await pumpVerifyEmail(tester, service);

    await tester.tap(find.text('Resend verification email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Network error. Check your connection and try again.'), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget,
        reason: 'a failed resend must not start a cooldown — the user should be able to retry',);
  });

  testWidgets('a rate-limited resend shows the backend\'s own message, not a generic server error',
      (tester) async {
    final service = _FakeAuthService(
      resendError: const RateLimitedException('Too many requests. Please try again later.'),
    );
    await pumpVerifyEmail(tester, service);

    await tester.tap(find.text('Resend verification email'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Too many requests. Please try again later.'), findsOneWidget);
  });

  testWidgets('does not fake or auto-mark verification locally', (tester) async {
    final service = _FakeAuthService();
    await pumpVerifyEmail(tester, service);

    expect(find.text('Verified'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('"Back to sign in" navigates to the login route', (tester) async {
    final service = _FakeAuthService();
    final router = await pumpVerifyEmail(tester, service);

    await tester.tap(find.text('Back to sign in'));
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
  });

  testWidgets('renders without overflow on a small Android screen', (tester) async {
    final service = _FakeAuthService();
    await pumpVerifyEmail(tester, service, surfaceSize: const Size(320, 568));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
