import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_providers.dart';

/// Real self-service registration. v1 is intentionally a Scanner-first
/// client app: public accounts select CPT Scanner as their requested service,
/// but the selection never grants access. The backend still creates a CLIENT
/// with zero privileges; the one-time owner-issued activation key is the
/// authority that binds the device and grants Scanner/Signals entitlements.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _usernamePattern =
    RegExp(r'^[a-z0-9](?:[a-z0-9_]{1,28})[a-z0-9]$');
const int _minPasswordLength = 12;

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      await ref.read(authControllerProvider.notifier).register(
            displayName: _nameController.text.trim(),
            username: _usernameController.text.trim().toLowerCase(),
            email: email,
            password: _passwordController.text,
          );
      if (mounted) context.go('/verify-email', extra: email);
    } catch (e) {
      final message =
          e is AppException ? e.message : 'Something went wrong. Please try again.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.phantomBlack,
      appBar: AppBar(backgroundColor: AppColors.phantomBlack),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandHeader(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Create account',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PhantomTextField(
                      label: 'Display name',
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PhantomTextField(
                      label: 'Username',
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
                      autofillHints: const [AutofillHints.username],
                      validator: (v) {
                        final username = v?.trim().toLowerCase() ?? '';
                        if (username.isEmpty) return 'Enter a username';
                        if (!_usernamePattern.hasMatch(username)) {
                          return 'Use 3–30 letters, numbers, or _; start and end with a letter or number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PhantomTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) =>
                          (v == null || !_emailPattern.hasMatch(v.trim()))
                              ? 'Enter a valid email'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Service',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PhantomCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radar_outlined,
                            color: AppColors.cyberBlue,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CPT Scanner',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Selected for this account. A one-time activation key is required after sign-in.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PhantomTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: true,
                      canToggleObscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => (v == null || v.length < _minPasswordLength)
                          ? 'Password must be at least $_minPasswordLength characters'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PhantomTextField(
                      label: 'Confirm password',
                      controller: _confirmPasswordController,
                      obscureText: true,
                      canToggleObscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) =>
                          (v != _passwordController.text) ? 'Passwords do not match' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PhantomButton(
                      label: 'Create account',
                      expand: true,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
