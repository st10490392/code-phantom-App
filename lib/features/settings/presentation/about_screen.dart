import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/widgets/widgets.dart';

/// About screen — one of the few places the full brand lockup appears,
/// per docs/ARCHITECTURE.md §7 ("Logo Usage").
///
/// For environment/connectivity/data-source details, see the "Diagnostics"
/// entry in Settings (`diagnostics_screen.dart`) — this screen stays purely
/// brand-forward, but its version string is read from the real installed
/// build via `package_info_plus` rather than a hand-maintained literal, so
/// it can never drift out of date the way the old hard-coded "Phase 1 —
/// mock services" string did on a build where that stopped being true.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionText = _packageInfo == null
        ? 'Loading version…'
        : 'Version ${_packageInfo!.version} (build ${_packageInfo!.buildNumber})';

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
              Text(versionText, style: Theme.of(context).textTheme.bodySmall),
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
