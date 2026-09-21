import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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

/// Full lockup for splash/login/about/empty-state contexts.
class BrandLockup extends StatelessWidget {
  const BrandLockup({this.width = 220, super.key});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(BrandAssets.logoFull, width: width);
  }
}
