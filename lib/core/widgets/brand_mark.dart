import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/brand_assets.dart';

/// Small nav/app-bar treatment: cropped mark + wordmark. Never render a
/// large logo on every screen — see docs/ARCHITECTURE.md §7.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 32, this.showWordmark = true, super.key});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.asset(
            BrandAssets.logoMark,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium,
              children: const [
                TextSpan(text: BrandAssets.appNameSplit),
                TextSpan(
                  text: BrandAssets.appNameAccent,
                  style: TextStyle(color: AppColors.phantomPurple),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Full lockup for splash/about/empty-state contexts. Note: `logo.png` bakes
/// the company name and tagline into the raster itself — legible at the
/// splash screen's size, but not reliably at smaller widths. Auth screens
/// (login/signup/verification) use [AuthBrandHeader] instead, which pairs
/// the mark alone with real, scalable Flutter text.
class BrandLockup extends StatelessWidget {
  const BrandLockup({this.width = 220, super.key});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(BrandAssets.logoFull, width: width);
  }
}

/// Branding header for auth screens (login, create account, verify email):
/// a large, uncropped-text mark plus real Flutter text for the company name
/// and tagline, so legibility never depends on tiny text baked into an
/// image at small render sizes on a physical phone.
///
/// Sizes itself down on short screens (small Android phones, or a phone in
/// a multi-window/split-screen layout) so it never crowds out the form
/// below it — callers still wrap the whole screen in a scroll view as a
/// second line of defense.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final markSize = screenHeight < 700 ? 72.0 : 96.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(markSize * 0.28),
          child: Image.asset(
            BrandAssets.logoMark,
            width: markSize,
            height: markSize,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          BrandAssets.companyFullName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          BrandAssets.tagline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedText,
                letterSpacing: 1.1,
              ),
        ),
      ],
    );
  }
}
