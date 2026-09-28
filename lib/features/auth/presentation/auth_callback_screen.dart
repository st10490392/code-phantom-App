import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_providers.dart';

/// Mobile: `codephantom://auth-callback`. Web: the app's own
/// `/auth/callback` page (see `ApiConfig.authRedirectUrl`).
bool isCodePhantomAuthCallback(Uri uri) =>
    (uri.scheme.toLowerCase() == 'codephantom' && uri.host.toLowerCase() == 'auth-callback') ||
    uri.path == ApiConfig.webAuthCallbackPath;

/// Web only: the auth-callback URL as the browser first opened it, captured
/// in `main()` before its `#fragment` (which carries Supabase tokens) is
/// stripped from the address bar. Held in memory only and consumed once.
final pendingWebAuthCallbackProvider = StateProvider<Uri?>((ref) => null);

Map<String, String> authCallbackParameters(Uri uri) {
  final result = <String, String>{...uri.queryParameters};
  if (uri.fragment.isNotEmpty) {
    try {
      result.addAll(Uri.splitQueryString(uri.fragment));
    } on FormatException {
      // The UI below handles malformed callbacks without crashing.
    }
  }
  return result;
}

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({required this.uri, super.key});

  final Uri uri;

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _completed = false;
  String? _errorMessage;

  late final Map<String, String> _params = authCallbackParameters(widget.uri);

  @override
  void initState() {
    super.initState();
    // Consume the captured web callback: a later visit to /auth/callback
    // (or a refresh) must not reuse its tokens.
    Future.microtask(() {
      if (mounted) ref.read(pendingWebAuthCallbackProvider.notifier).state = null;
    });
  }

  String get _type => _params['type']?.toLowerCase() ?? '';
  String? get _accessToken => _params['access_token'];

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _returnToLogin() async {
    if (ref.read(authControllerProvider).status == AuthStatus.authenticated) {
      await ref.read(authControllerProvider.notifier).logout();
    }
    if (mounted) context.go('/login');
  }

  Future<void> _submitRecovery() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _accessToken;
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'This password reset link is invalid or has expired.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).confirmPasswordReset(
            accessToken: token,
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _completed = true;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Could not reset your password. Request a new reset link and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isCodePhantomAuthCallback(widget.uri)) {
      return _message(
        title: 'Invalid link',
        icon: Icons.link_off_outlined,
        message: 'This CodePhantom authentication link is invalid.',
      );
    }

    return switch (_type) {
      'recovery' => _recovery(),
      'signup' => _message(
          title: 'Email verified',
          icon: Icons.verified_outlined,
          message: 'Your email address is verified. You can now sign in to CodePhantom.',
        ),
      'email_change' => _message(
          title: 'Email updated',
          icon: Icons.mark_email_read_outlined,
          message: 'Your new email address has been confirmed. Sign in again to refresh your account.',
        ),
      _ => _message(
          title: 'Link unavailable',
          icon: Icons.link_off_outlined,
          message: 'This authentication link is invalid, expired, or no longer supported.',
        ),
    };
  }

  Widget _message({
    required String title,
    required IconData icon,
    required String message,
  }) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: AppSpacing.lg),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
              PhantomButton(label: 'Continue to sign in', onPressed: _returnToLogin),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recovery() {
    if (_completed) {
      return _message(
        title: 'Password updated',
        icon: Icons.lock_reset_outlined,
        message: 'Your password has been changed. Sign in again with your new password.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Use at least 8 characters. After the change, CodePhantom signs out your other sessions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                PhantomTextField(
                  label: 'New password',
                  controller: _passwordController,
                  obscureText: true,
                  canToggleObscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    final password = value ?? '';
                    if (password.length < 8) return 'Password must be at least 8 characters.';
                    if (password.length > 128) return 'Password must be 128 characters or fewer.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                PhantomTextField(
                  label: 'Confirm new password',
                  controller: _confirmController,
                  obscureText: true,
                  canToggleObscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      value == _passwordController.text ? null : 'Passwords do not match.',
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PhantomButton(
                  label: 'Update password',
                  onPressed: _submitRecovery,
                  isLoading: _submitting,
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
