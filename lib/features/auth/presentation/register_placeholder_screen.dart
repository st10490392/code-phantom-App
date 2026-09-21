import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';

/// Placeholder only, per brief — CodePhantom registration is provisioned by
/// OWNER/ADMIN (see Clients module), not self-service in Phase 1.
class RegisterPlaceholderScreen extends StatelessWidget {
  const RegisterPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: EmptyView(
          icon: Icons.person_add_alt_outlined,
          message:
              'Self-service registration is not yet available.\n\n'
              'Accounts are currently provisioned by CodePhantom administrators. '
              'Contact your CodePhantom representative for access.',
        ),
      ),
    );
  }
}
