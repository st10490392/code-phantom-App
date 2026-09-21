import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_placeholder_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/clients/presentation/client_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/ea/presentation/ea_dashboard_screen.dart';
import '../../features/licences/presentation/licence_list_screen.dart';
import '../../features/notifications/presentation/notification_centre_screen.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
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
  final authNotifier = ref.watch(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loggingIn = ['/login', '/forgot-password', '/register'].contains(state.matchedLocation);
      final atSplash = state.matchedLocation == '/splash';

      if (authState.status == AuthStatus.unknown) {
        return atSplash ? null : '/splash';
      }
      if (authState.status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }
      // authenticated
      if (loggingIn || atSplash) return '/dashboard';

      final user = authState.user;
      final gate = _permissionForPath(state.matchedLocation);
      if (gate != null && user != null && !user.isOwner && !user.permissions.has(gate)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPlaceholderScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/scanner', builder: (context, state) => const ScannerScreen()),
          GoRoute(path: '/signals', builder: (context, state) => const SignalsScreen()),
          GoRoute(path: '/ea', builder: (context, state) => const EADashboardScreen()),
          GoRoute(path: '/clients', builder: (context, state) => const ClientListScreen()),
          GoRoute(path: '/licences', builder: (context, state) => const LicenceListScreen()),
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

Permission? _permissionForPath(String path) {
  if (path.startsWith('/scanner')) return Permission.scannerAccess;
  if (path.startsWith('/signals')) return Permission.signalsAccess;
  if (path.startsWith('/ea')) return Permission.eaAccess;
  if (path.startsWith('/clients')) return Permission.clientAdmin;
  if (path.startsWith('/licences')) return Permission.licenceAdmin;
  return null;
}

/// Bridges Riverpod's `AuthState` changes into something `go_router`'s
/// `refreshListenable` can observe, so login/logout trigger re-evaluation
/// of `redirect` immediately.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
