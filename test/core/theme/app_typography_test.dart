import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/theme/app_typography.dart';

/// Locks in that typography is wired to the locally-bundled fonts (see
/// `pubspec.yaml`'s `fonts:` section and `assets/fonts/`), not to the
/// `google_fonts` package — a regression here would silently reintroduce a
/// runtime network dependency for app startup.
void main() {
  group('AppTypography — bundled fonts, not runtime-fetched', () {
    test('display/headline styles use the locally-bundled Space Grotesk', () {
      for (final style in [
        AppTypography.textTheme.displayLarge,
        AppTypography.textTheme.displayMedium,
        AppTypography.textTheme.headlineMedium,
        AppTypography.textTheme.headlineSmall,
      ]) {
        expect(style?.fontFamily, 'Space Grotesk');
      }
    });

    test('body/title/label styles use the locally-bundled Inter', () {
      for (final style in [
        AppTypography.textTheme.titleMedium,
        AppTypography.textTheme.bodyLarge,
        AppTypography.textTheme.bodyMedium,
        AppTypography.textTheme.bodySmall,
        AppTypography.textTheme.labelLarge,
      ]) {
        expect(style?.fontFamily, 'Inter');
      }
    });

    test('mono() uses the locally-bundled JetBrains Mono', () {
      expect(AppTypography.mono().fontFamily, 'JetBrains Mono');
    });
  });
}
