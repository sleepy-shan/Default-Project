import 'package:flutter/material.dart';

/// Design tokens for the Sandwich app.
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

  /// Max content width for centered layouts on ultra-wide screens.
  static const double maxContentWidth = 1280;

  /// Max width for narrow forms (search field, settings cards).
  static const double narrowMaxWidth = 720;

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
  static const Duration durationReveal = Duration(milliseconds: 480);
  static const Duration durationHero = Duration(milliseconds: 700);

  static const Curve curveSmooth = Curves.easeOutCubic;
  static const Curve curveSnap = Curves.easeOutBack;

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

  // ---------------------------------------------------------------------
  // Signature gradients / surfaces (the "unique" look)
  // ---------------------------------------------------------------------
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFF6C4DF6), Color(0xFF00B8A9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1B1440), Color(0xFF0B0D14)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const RadialGradient auroraViolet = RadialGradient(
    colors: [Color(0x557C5CFF), Color(0x00000000)],
  );
  static const RadialGradient auroraTeal = RadialGradient(
    colors: [Color(0x4400B8A9), Color(0x00000000)],
  );

  static List<BoxShadow> cardShadow(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.45)
            : const Color(0xFF1B1440).withValues(alpha: 0.10),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Accent color choices offered in Settings.
///
/// The seed drives `ColorScheme.fromSeed`, so light/dark contrast (primary
/// vs onPrimary, surface text) stays accessible for every choice — screens
/// must use `scheme.primary / onSurface / onSurfaceVariant` instead of
/// hardcoding the old violet.
enum AppAccent {
  violet('Violet', Color(0xFF6C4DF6)),
  teal('Teal', Color(0xFF00B8A9)),
  rose('Rose', Color(0xFFE54666)),
  amber('Amber', Color(0xFFF4A62A)),
  sky('Sky', Color(0xFF2D9CDB)),
  mint('Mint', Color(0xFF21A179));

  const AppAccent(this.label, this.seed);

  final String label;
  final Color seed;
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
