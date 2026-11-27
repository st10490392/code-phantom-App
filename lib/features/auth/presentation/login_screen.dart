import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/app_exceptions.dart';
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
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  String? _error;

  bool get _isMockMode => ref.read(appEnvironmentProvider) == AppEnvironment.mock;

  @override
  void initState() {
    super.initState();
    // The mock owner pre-fill is a development convenience only for MOCK
    // mode — real/API modes always start from a blank form.
    _emailController = TextEditingController(text: _isMockMode ? 'owner@codephantom.dev' : '');
    _passwordController = TextEditingController(text: _isMockMode ? 'owner123' : '');
  }

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
    final email = _emailController.text.trim();
    try {
      await ref.read(authControllerProvider.notifier).login(email, _passwordController.text);
      // The router selects the landing screen after authentication.
    } on EmailNotVerifiedException {
      // Actionable, not just a message: send the user straight to the
      // resend/verify flow instead of leaving them stuck on a login error.
      if (mounted) context.push('/verify-email', extra: email);
    } catch (e) {
      final message = e is AppException ? e.message : 'Something went wrong. Please try again.';
      setState(() => _error = message);
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
                  const AuthBrandHeader(),
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
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'New to CodePhantom?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PhantomButton(
                    label: 'Create account',
                    variant: PhantomButtonVariant.secondary,
                    expand: true,
                    onPressed: () => context.push('/register'),
                  ),
                  if (_isMockMode) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    const _MockAccountsHint(),
                  ],
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
