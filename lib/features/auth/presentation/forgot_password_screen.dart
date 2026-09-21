import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: _sent
            ? const EmptyView(
                icon: Icons.mark_email_read_outlined,
                message: 'If that email is registered, a reset link has been sent.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter your account email and we\'ll send reset instructions.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PhantomTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PhantomButton(
                    label: 'Send reset link',
                    isLoading: _isSubmitting,
                    onPressed: () async {
                      setState(() => _isSubmitting = true);
                      await ref
                          .read(authControllerProvider.notifier)
                          .requestPasswordReset(_emailController.text.trim());
                      if (mounted) setState(() {
                        _isSubmitting = false;
                        _sent = true;
                      });
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
