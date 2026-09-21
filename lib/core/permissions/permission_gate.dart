import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'permission.dart';
import '../../features/auth/presentation/auth_providers.dart';

/// Hides [child] entirely when the current user lacks [permission].
///
/// This is a UX convenience, not enforcement — see [PermissionSet]'s
/// class doc. Real authorization must happen server-side once a backend
/// exists.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    required this.permission,
    required this.child,
    this.fallback,
    super.key,
  });

  final Permission permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(hasPermissionProvider(permission));
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
