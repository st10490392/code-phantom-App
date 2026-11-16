import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/licences/presentation/licence_list_screen.dart';
import '../config/api_config.dart';
import '../config/app_environment.dart';
import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/auth_callback_screen.dart';
import '../../features/auth/presentation/create_account_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_placeholder_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/ea/presentation/ea_dashboard_screen.dart';
import '../../features/integrations/presentation/integrations_screen.dart';
import '../../features/notifications/presentation/notification_centre_screen.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/scanner/presentation/setup_detail_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/signals/presentation/signals_screen.dart';
import '../permissions/permission.dart';
import 'app_shell.dart';

/// Route guards are defense-in-depth on top of the hidden-nav-item UX:
/// hitting a gated path directly (e.g. via a deep link) still redirects if
/// the user lacks the permission. This is still a UX safeguard, not
/// authorization — see docs/ARCHITECTURE.md §5/§8.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) {
      if (isCodePhantomAuthCallback(state.uri)) return null;

      final authState = ref.read(authControllerProvider);
      final loggingIn = ['/login', '/forgot-password', '/register', '/verify-email']
          .contains(state.matchedLocation);
      final atSplash = state.matchedLocation == '/splash';
      final atRoot = state.matchedLocation == '/';

      // A browser refresh or pasted link starts at the requested page before
      // the session is restored; remember it so the user lands back there
      // (permission gates below still apply once they arrive).
      final returnTo = (atSplash || loggingIn || atRoot)
          ? safeReturnPath(state.uri.queryParameters['from'])
          : state.uri.toString();

      if (authState.status == AuthStatus.unknown) {
        return atSplash ? null : _withReturn('/splash', returnTo);
      }
      if (authState.status == AuthStatus.unauthenticated) {
        return loggingIn ? null : _withReturn('/login', returnTo);
      }
      // authenticated
      if (loggingIn || atSplash || atRoot) return returnTo ?? '/dashboard';

      final user = authState.user;
      final gate = permissionForPath(state.matchedLocation);
      final isOwnerOnly = isOwnerOnlyPath(state.matchedLocation);

      // Check for owner-only paths first
      if (isOwnerOnly && (user == null || !user.isOwner)) {
        return '/dashboard';
      }

      // Then check regular permission-based gates
      if (gate != null && user != null && !user.isOwner && !user.permissions.has(gate)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => FormPage(child: AuthCallbackScreen(uri: state.uri)),
      ),
      GoRoute(
        path: ApiConfig.webAuthCallbackPath,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) =>
              FormPage(child: AuthCallbackScreen(uri: ref.read(pendingWebAuthCallbackProvider) ?? state.uri)),
        ),
      ),
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const FormPage(child: LoginScreen())),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const FormPage(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/register',
        // MOCK mode has no signup path (its account list is fixed) — only
        // DEVELOPMENT/PRODUCTION show the real registration screen.
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final isMock = ref.watch(appEnvironmentProvider) == AppEnvironment.mock;
            return FormPage(child: isMock ? const RegisterPlaceholderScreen() : const CreateAccountScreen());
          },
        ),
      ),
      GoRoute(
        path: '/verify-email',
        // `extra` is the email just registered (or the one just attempted at
        // login, if that attempt reported the account isn't verified yet).
        // In-app navigation still passes the email through extra; actual
        // verification links return through AuthCallbackScreen.
        builder: (context, state) => FormPage(child: VerifyEmailScreen(email: state.extra as String? ?? '')),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(
            path: '/scanner',
            builder: (context, state) => const ScannerScreen(),
            routes: [
              GoRoute(
                path: 'setup/:id',
                builder: (context, state) =>
                    SetupDetailScreen(setupId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/signals', builder: (context, state) => const SignalsScreen()),
          GoRoute(path: '/ea', builder: (context, state) => const EADashboardScreen()),
          GoRoute(
            path: '/licences',
            builder: (context, state) => const LicenceListScreen(),
          ),
          GoRoute(
            path: '/integrations',
            builder: (context, state) => const IntegrationsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationCentreScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
              GoRoute(path: 'profile', builder: (context, state) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

String _withReturn(String path, String? returnTo) =>
    returnTo == null ? path : Uri(path: path, queryParameters: {'from': returnTo}).toString();

/// A same-app path to return to after sign-in, or `null`. Only plain
/// in-app paths are accepted (`/scanner/setup/42`); absolute URLs,
/// protocol-relative `//host` values and auth/splash pages are refused so
/// the parameter cannot redirect anywhere unexpected.
String? safeReturnPath(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.startsWith('/') || raw.startsWith('//') || raw.contains('\\')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  const excluded = ['/', '/splash', '/login', '/register', '/forgot-password', '/verify-email', ApiConfig.webAuthCallbackPath];
  if (excluded.contains(uri.path)) return null;
  return raw;
}

/// The permission a route requires, or `null` if it's open to every
/// authenticated user (Dashboard, Notifications, Settings). Used by the
/// `redirect` guard above and unit-testable on its own — see
/// `test/core/routing/app_router_test.dart`.
Permission? permissionForPath(String path) {
  if (path.startsWith('/scanner')) return Permission.scannerAccess;
  if (path.startsWith('/signals')) return Permission.signalsAccess;
  if (path.startsWith('/ea')) return Permission.eaAccess;
  if (path.startsWith('/licences')) return Permission.licenceAdmin;
  return null;
}

/// Routes that require OWNER role in addition to any permission check.
/// These are sensitive administrative functions that only the account owner
/// may access, regardless of granted permissions.
bool isOwnerOnlyPath(String path) {
  return path.startsWith('/integrations');
}

/// Bridges Riverpod's `AuthState` changes into something `go_router`'s
/// `refreshListenable` can observe, so login/logout trigger re-evaluation
/// of `redirect` immediately.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

/// Sign-in, registration and auth-callback pages: full screen on phones, a
/// centred form-width column on tablets and desktop browsers.
class FormPage extends StatelessWidget {
  const FormPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.phantomBlack,
      child: ContentWidth(maxWidth: ContentWidth.form, child: child),
    );
  }
}
