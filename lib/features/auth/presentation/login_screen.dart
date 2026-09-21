import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'owner@codephantom.dev');
  final _passwordController = TextEditingController(text: 'owner123');
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = 'Invalid email or password.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.phantomBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLockup(width: 180)),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Sign in',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PhantomTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PhantomTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PhantomButton(
                    label: 'Sign in',
                    expand: true,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const _MockAccountsHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MockAccountsHint extends StatelessWidget {
  const _MockAccountsHint();

  @override
  Widget build(BuildContext context) {
    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEVELOPMENT ONLY — MOCK ACCOUNTS',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'owner@codephantom.dev / owner123\n'
            'admin@codephantom.dev / admin123\n'
            'trader@codephantom.dev / trader123\n'
            'scanner.client@codephantom.dev / client123\n'
            'signal.client@codephantom.dev / client123\n'
            'ea.client@codephantom.dev / client123\n'
            'friend@codephantom.dev / internal123',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
