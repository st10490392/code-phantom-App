import 'package:flutter/widgets.dart';

/// "Rounded but not excessively rounded" per brand direction — full pill
/// radius is reserved for buttons/chips/badges only, not every surface.
abstract final class AppRadius {
  static const double sm = 10;
  static const double card = 16; // website: rounded-2xl
  static const double modal = 20;
  static const double pill = 999; // website: rounded-full

  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get modalRadius => BorderRadius.circular(modal);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}
