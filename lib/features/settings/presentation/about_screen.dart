import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/widgets/widgets.dart';

/// About screen — one of the few places the full brand lockup appears,
/// per docs/ARCHITECTURE.md §7 ("Logo Usage").
///
/// The version string below is hard-coded from `pubspec.yaml`. Add
/// `package_info_plus` later if a runtime-read version becomes worthwhile.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLockup(width: 200),
              const SizedBox(height: AppSpacing.xl),
              Text(
                BrandAssets.tagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Version 0.1.0 (Phase 1 — mock services)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '${BrandAssets.companyFullName} · ${BrandAssets.tradingBrand}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
