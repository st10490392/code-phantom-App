import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/features/auth/data/auth_service.dart';
import 'package:code_phantom_app/features/auth/domain/auth_session.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/auth/presentation/create_account_screen.dart';

/// Configurable double for [AuthService.register] — every other method is
/// unused by [CreateAccountScreen] and throws if accidentally invoked.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.registerError});

  final AppException? registerError;
  int registerCalls = 0;
  String? lastDisplayName;
  String? lastUsername;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    lastDisplayName = displayName;
    lastUsername = username;
    lastEmail = email;
    lastPassword = password;
    if (registerError != null) throw registerError!;
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
  Future<void> resendVerificationEmail({required String email}) => throw UnimplementedError();
}

void main() {
  Future<GoRouter> pumpCreateAccount(
    WidgetTester tester,
    AuthService service, {
    Size surfaceSize = const Size(400, 800),
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (_, __) => const CreateAccountScreen()),
        GoRoute(
          path: '/verify-email',
          builder: (_, state) => Scaffold(body: Text('verify:${state.extra}')),
        ),
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

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'New Client',
    String username = 'new_client',
    String email = 'new.client@codephantom.dev',
    String password = 'a-strong-password-123',
    String? confirmPassword,
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Display name'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), username);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      confirmPassword ?? password,
    );
  }

  testWidgets('registration clearly selects CPT Scanner without granting access', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    expect(find.text('Service'), findsOneWidget);
    expect(find.text('CPT Scanner'), findsOneWidget);
    expect(find.textContaining('one-time activation key'), findsOneWidget);
  });

  testWidgets('signup success navigates to /verify-email with the registered email',
      (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    await fillForm(tester);
    await tester.tap(find.text('Create account').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(service.registerCalls, 1);
    expect(service.lastDisplayName, 'New Client');
    expect(service.lastUsername, 'new_client');
    expect(service.lastEmail, 'new.client@codephantom.dev');
    expect(find.text('verify:new.client@codephantom.dev'), findsOneWidget);
  });


  testWidgets('an invalid username is rejected before any network call is made', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    await fillForm(tester, username: '_bad_username_');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(
      find.text('Use 3–30 letters, numbers, or _; start and end with a letter or number'),
      findsOneWidget,
    );
    expect(service.registerCalls, 0);
  });

  testWidgets('username is normalized to lower-case before submission', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    await fillForm(tester, username: 'New_Client');
    await tester.tap(find.text('Create account').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(service.registerCalls, 1);
    expect(service.lastUsername, 'new_client');
  });

  testWidgets('an invalid email is rejected before any network call is made', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    await fillForm(tester, email: 'not-an-email');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(service.registerCalls, 0);
  });

  testWidgets('a password under 12 characters is rejected as weak', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    await fillForm(tester, password: 'short1', confirmPassword: 'short1');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.text('Password must be at least 12 characters'), findsOneWidget);
    expect(service.registerCalls, 0);
  });

  testWidgets('mismatched password confirmation is rejected', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    await fillForm(tester, password: 'a-strong-password-123', confirmPassword: 'different-password-1');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(service.registerCalls, 0);
  });

  testWidgets('an empty display name is rejected', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    await fillForm(tester, name: '   ');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.text('Enter your name'), findsOneWidget);
    expect(service.registerCalls, 0);
  });

  testWidgets(
      'a genuine backend registration rejection (e.g. a Supabase-side password policy '
      'rejection, distinct from this screen\'s own 12-character check) shows the typed message '
      '— a duplicate email is NOT such a rejection; see api_auth_service_test.dart',
      (tester) async {
    final service = _FakeAuthService(
      registerError: const ValidationException('Could not register this account.'),
    );
    await pumpCreateAccount(tester, service);

    await fillForm(tester);
    await tester.tap(find.text('Create account').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Could not register this account.'), findsOneWidget);
    expect(find.text('verify:new.client@codephantom.dev'), findsNothing);
  });

  testWidgets('a network failure during signup shows a clean message, never a stack trace',
      (tester) async {
    final service = _FakeAuthService(registerError: const NetworkException());
    await pumpCreateAccount(tester, service);

    await fillForm(tester);
    await tester.tap(find.text('Create account').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Network error. Check your connection and try again.'), findsOneWidget);
  });

  testWidgets('the password is never left in a plain-text-visible state without an explicit toggle',
      (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service);

    expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2),
        reason: 'both Password and Confirm password start hidden with a toggle affordance',);

    // Toggling visibility is available (show/hide affordance) without
    // altering the underlying controller text used for submission.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('renders without overflow on a small Android screen', (tester) async {
    final service = _FakeAuthService();
    await pumpCreateAccount(tester, service, surfaceSize: const Size(320, 568));

    await fillForm(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
