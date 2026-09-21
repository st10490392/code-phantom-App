import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    // Route redirection (to /dashboard or /login) is handled centrally by
    // the router's `redirect`, driven by `authControllerProvider`'s status.
    ref.watch(authControllerProvider);
    return const Scaffold(
      backgroundColor: AppColors.phantomBlack,
      body: Center(child: BrandLockup(width: 200)),
    );
  }
}
