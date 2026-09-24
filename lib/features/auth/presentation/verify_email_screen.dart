import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_providers.dart';

const _resendCooldown = Duration(seconds: 30);

/// Shown after successful registration (and reachable from the login screen
/// when a login attempt reports the account isn't verified yet). Never
/// fakes or locally marks an account verified — verification happens on the
/// backend when the user follows the emailed link; this screen only offers
/// to resend that email and a way back to sign in once they have.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isResending = false;
  String? _error;
  String? _info;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool get _canResend => !_isResending && _cooldownSeconds == 0;

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).resendVerificationEmail(widget.email);
      if (!mounted) return;
      setState(() {
        _info = 'Verification email sent again.';
        _isResending = false;
      });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : 'Could not resend the verification email. Please try again.';
      setState(() {
        _error = message;
        _isResending = false;
      });
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = _resendCooldown.inSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds -= 1;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.phantomBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuthBrandHeader(),
                const SizedBox(height: AppSpacing.xxl),
                const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.electricBlue,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'We sent a verification link to ${widget.email}. '
                  'Verify your email, then return to CodePhantom and sign in.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_info != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PhantomButton(
                  label: _cooldownSeconds > 0
                      ? 'Resend in ${_cooldownSeconds}s'
                      : 'Resend verification email',
                  variant: PhantomButtonVariant.secondary,
                  expand: true,
                  isLoading: _isResending,
                  onPressed: _canResend ? _resend : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
