import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_mark.dart';
import 'nav_destination.dart';

/// Persistent shell: bottom nav on phones. Only shows destinations the
/// current user has permission for — items are filtered out entirely,
/// never just disabled, per the brief.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final visible = visibleNavDestinationsFor(user);

    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = visible.indexWhere((d) => location.startsWith(d.path));

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 28),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.mutedText),
            tooltip: 'Log out',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (i) => context.go(visible[i].path),
        destinations: [
          for (final d in visible)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
