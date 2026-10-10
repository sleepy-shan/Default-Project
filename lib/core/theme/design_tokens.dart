import 'package:flutter/material.dart';

/// Design tokens for the Dartotsu Web app.
///
/// Every visual decision (color, spacing, radius, typography, duration,
/// breakpoint) is defined here so screens and components stay consistent
/// and re-theming is a single-file change.
abstract final class Tokens {
  // ---------------------------------------------------------------------
  // Spacing scale (4pt grid)
  // ---------------------------------------------------------------------
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ---------------------------------------------------------------------
  // Radii
  // ---------------------------------------------------------------------
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // ---------------------------------------------------------------------
  // Component sizes
  // ---------------------------------------------------------------------
  static const double appBarHeight = 64;
  static const double posterAspect = 0.68; // classic 2:3 poster
  static const double iconButtonSize = 40;
  static const double inputHeight = 44;

  // ---------------------------------------------------------------------
  // Responsive breakpoints
  // ---------------------------------------------------------------------
  static const double breakpointCompact = 600; // phones
  static const double breakpointMedium = 1000; // tablets
  static const double breakpointExpanded = 1400; // large desktop

  // ---------------------------------------------------------------------
  // Motion
  // ---------------------------------------------------------------------
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ---------------------------------------------------------------------
  // Brand palette
  // ---------------------------------------------------------------------
  static const Color brand = Color(0xFF6C4DF6); // violet
  static const Color brandDark = Color(0xFF8E74FF);
  static const Color accent = Color(0xFF00B8A9); // teal
  static const Color like = Color(0xFFE54666); // score / heart
  static const Color success = Color(0xFF21A179);
  static const Color warning = Color(0xFFF4A62A);
  static const Color danger = Color(0xFFD64545);

  // Status colors used for list-status chips
  static const Color statusWatching = Color(0xFF2D9CDB);
  static const Color statusPlanning = Color(0xFF9B51E0);
  static const Color statusCompleted = Color(0xFF21A179);
  static const Color statusPaused = Color(0xFFF2C94C);
  static const Color statusDropped = Color(0xFFEB5757);
}

/// Typography scale. The app uses the platform font stack (system-ui /
/// Roboto) rather than bundling web fonts to keep the bundle small.
abstract final class TypeScale {
  static const String? fontFamily = null; // platform default

  static const TextStyle displaySmall = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
}
