import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_mark.dart';
import 'nav_destination.dart';
import '../../features/enkidu_shadow/enkidu_shadow_screen.dart';

/// Persistent shell: bottom nav on phones (and narrow browser windows), a
/// navigation rail on tablets, an extended rail with width-capped content
/// on desktop browsers. Only shows destinations the current user has
/// permission for — items are filtered out entirely, never just disabled,
/// per the brief.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final visible = visibleNavDestinationsFor(
      user,
      enkiduShadowEnabled: ref.watch(enkiduShadowViewEnabledProvider),
    );

    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex =
        visible.indexWhere((d) => location.startsWith(d.path));

    final size = WindowSize.of(context);
    final currentIndex = selectedIndex < 0 ? 0 : selectedIndex;
    void select(int i) => context.go(visible[i].path);

    final appBar = AppBar(
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
    );

    if (size == WindowSize.compact) {
      return Scaffold(
        appBar: appBar,
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: select,
          // Staff accounts can have up to eight destinations; on a phone
          // their labels would wrap mid-word, so show icons (with tooltips)
          // instead. Five or fewer keep their labels.
          labelBehavior: visible.length > 5
              ? NavigationDestinationLabelBehavior.alwaysHide
              : NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in visible)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
                tooltip: d.label,
              ),
          ],
        ),
      );
    }

    final extended = size == WindowSize.expanded;
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height - kToolbarHeight,
                ),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: currentIndex,
                    onDestinationSelected: select,
                    extended: extended,
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: [
                      for (final d in visible)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: ContentWidth(child: child)),
        ],
      ),
    );
  }
}
