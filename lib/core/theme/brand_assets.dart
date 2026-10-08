/// Centralised brand asset paths and wordmark strings.
///
/// Keeping these in one place (rather than scattered literal strings) is
/// what makes future white-labelling realistic without an architecture
/// rewrite — a different brand skin only needs a new `BrandAssets`.
abstract final class BrandAssets {
  /// Full lockup (mark + wordmark + tagline) — splash, login, About screen.
  static const String logoFull = 'assets/brand/logo.png';

  /// Cropped square emblem — nav bar, app icon-sized contexts.
  static const String logoMark = 'assets/brand/mark.png';

  static const String appName = 'CodePhantom';
  static const String appNameSplit = 'CODE'; // + accent 'PHANTOM'
  static const String appNameAccent = 'PHANTOM';
  static const String companyFullName = 'CodePhantom Technologies';
  static const String tagline = 'Engineering Intelligent Systems';

  /// Trading-facing sub-brand, used within Scanner/Signals/EA contexts only.
  static const String tradingBrand = 'CPT Market Direction';
  static const String scannerBrandLine = 'CPT Scanner · by CodePhantom Technologies';
}
