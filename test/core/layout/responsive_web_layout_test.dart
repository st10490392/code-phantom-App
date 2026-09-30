import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:code_phantom_app/app.dart';
import 'package:code_phantom_app/core/layout/breakpoints.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/core/routing/app_router.dart';
import 'package:code_phantom_app/features/auth/data/auth_service.dart';
import 'package:code_phantom_app/features/auth/domain/auth_session.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_callback_screen.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';

const _owner = AuthUser(
  id: 'u_owner',
  email: 'owner@codephantom.dev',
  displayName: 'Owner',
  role: AppRole.owner,
  permissions: PermissionSet.none,
);

class _Auth implements AuthService {
  _Auth(this.user);
  final AuthUser? user;

  @override
  Future<AuthSession?> restoreSession() async => user == null
      ? null
      : AuthSession(user: user!, accessToken: 't', expiresAt: DateTime.now().add(const Duration(hours: 1)));

  @override
  Future<AuthSession> login({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset({required String email}) async {}
  @override
  Future<void> confirmPasswordReset({required String accessToken, required String newPassword}) async {}
  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> resendVerificationEmail({required String email}) async {}
}

/// Viewports the web build must work in (logical pixels).
const _viewports = <String, Size>{
  'iPhone SE (Safari)': Size(375, 667),
  'iPhone 15 (Safari)': Size(393, 852),
  'iPad portrait': Size(820, 1180),
  'desktop browser': Size(1440, 900),
};

const _shellRoutes = [
  '/dashboard',
  '/scanner',
  '/signals',
  '/ea',
  '/clients',
  '/licences',
  '/notifications',
  '/settings',
  '/settings/about',
  '/settings/profile',
];

Future<GoRouter> _pumpApp(WidgetTester tester, Size size, {AuthUser? user, List<Override> overrides = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(_Auth(user)), ...overrides],
      child: Consumer(
        builder: (context, ref, _) {
          router = ref.watch(appRouterProvider);
          return const CodePhantomApp();
        },
      ),
    ),
  );
  await _settle(tester);
  return router;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

String _location(GoRouter router) => router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  test('window size classes follow width, not platform', () {
    expect(WindowSize.ofWidth(375), WindowSize.compact);
    expect(WindowSize.ofWidth(820), WindowSize.medium);
    expect(WindowSize.ofWidth(1440), WindowSize.expanded);
  });

  for (final entry in _viewports.entries) {
    testWidgets('every signed-in screen lays out without overflow — ${entry.key}', (tester) async {
      final router = await _pumpApp(tester, entry.value, user: _owner);
      final compact = WindowSize.ofWidth(entry.value.width) == WindowSize.compact;
      for (final route in _shellRoutes) {
        router.go(route);
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$route at ${entry.key}');
        expect(_location(router), route);
        expect(find.byType(NavigationBar), compact ? findsOneWidget : findsNothing, reason: route);
        expect(find.byType(NavigationRail), compact ? findsNothing : findsOneWidget, reason: route);
      }
      if (compact) {
        // OWNER has 8 destinations: icons only, so labels never wrap mid-word.
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
      }
      await _unmount(tester);
    });

    testWidgets('sign-in and recovery screens lay out without overflow — ${entry.key}', (tester) async {
      final router = await _pumpApp(tester, entry.value);
      for (final route in ['/login', '/register', '/forgot-password']) {
        router.go(route);
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$route at ${entry.key}');
      }
      final form = tester.getSize(find.descendant(of: find.byType(ContentWidth).first, matching: find.byType(Scaffold)).first);
      expect(form.width, lessThanOrEqualTo(ContentWidth.form));
      await _unmount(tester);
    });
  }

  group('browser deep links and refresh', () {
    testWidgets('a signed-out visit to a deep link returns there after sign-in', (tester) async {
      final router = await _pumpApp(tester, const Size(1440, 900));
      router.go('/scanner/setup/abc');
      await _settle(tester);
      expect(_location(router), '/login?from=%2Fscanner%2Fsetup%2Fabc');
      await _unmount(tester);
    });

    testWidgets('a refresh on a deep link restores the session and stays on that page', (tester) async {
      final router = await _pumpApp(tester, const Size(1440, 900), user: _owner);
      router.go('/splash?from=%2Fsignals');
      await _settle(tester);
      expect(_location(router), '/signals');
      await _unmount(tester);
    });

    test('only in-app paths are accepted as a return target', () {
      expect(safeReturnPath('/scanner/setup/42'), '/scanner/setup/42');
      expect(safeReturnPath('/signals?status=ACTIVE'), '/signals?status=ACTIVE');
      for (final bad in ['https://evil.example/x', '//evil.example/x', 'javascript:alert(1)', 'scanner', '/login', '/splash', '/auth/callback', '', null]) {
        expect(safeReturnPath(bad), isNull, reason: '$bad');
      }
    });
  });

  group('web auth callback', () {
    test('the web callback page is recognised alongside the mobile scheme', () {
      expect(isCodePhantomAuthCallback(Uri.parse('https://app.codephantom.example/auth/callback')), isTrue);
      expect(isCodePhantomAuthCallback(Uri.parse('codephantom://auth-callback#type=recovery')), isTrue);
      expect(isCodePhantomAuthCallback(Uri.parse('https://app.codephantom.example/auth/other')), isFalse);
    });

    testWidgets('a password-reset link opens the reset form from the captured callback, then forgets it', (tester) async {
      final captured = Uri.parse('https://app.codephantom.example/auth/callback#access_token=reset-token&type=recovery');
      final router = await _pumpApp(
        tester,
        const Size(393, 852),
        overrides: [pendingWebAuthCallbackProvider.overrideWith((ref) => captured)],
      );
      router.go('/auth/callback');
      await _settle(tester);
      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.textContaining('reset-token'), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.byType(CodePhantomApp)));
      expect(container.read(pendingWebAuthCallbackProvider), isNull);
      await _unmount(tester);
    });
  });
}
