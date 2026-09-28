import 'package:flutter/widgets.dart';

/// Window-size classes shared by Android and web. Based on the available
/// width, never on the platform, so a narrow desktop window behaves like a
/// phone and an iPad in landscape like a tablet.
enum WindowSize {
  /// Phones and narrow browser windows: bottom navigation.
  compact,

  /// Tablets / small laptops: navigation rail.
  medium,

  /// Desktop browsers: extended navigation rail, width-capped content.
  expanded;

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 1024;

  static WindowSize ofWidth(double width) {
    if (width >= expandedMinWidth) return WindowSize.expanded;
    if (width >= mediumMinWidth) return WindowSize.medium;
    return WindowSize.compact;
  }

  static WindowSize of(BuildContext context) => ofWidth(MediaQuery.sizeOf(context).width);
}

/// Centers [child] and caps its width, so wide screens get a readable
/// column instead of stretched phone layouts. No effect below [maxWidth].
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, this.maxWidth = 1200, super.key});

  /// Width for dashboards and lists.
  static const double page = 1200;

  /// Width for sign-in/registration forms and single-column detail pages.
  static const double form = 480;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
