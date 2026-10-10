import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Light and dark [ThemeData] built from the design tokens.
///
/// Colors use Material 3 seeded from the brand violet, with explicit
/// component themes so cards, chips, inputs and buttons stay consistent
/// across both modes.
abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: Tokens.brand,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? Tokens.brandDark : Tokens.brand,
          secondary: Tokens.accent,
          surface: isDark ? const Color(0xFF12141C) : const Color(0xFFF7F7FB),
          error: Tokens.danger,
        );

    final Color background = isDark
        ? const Color(0xFF0B0D14)
        : const Color(0xFFF2F3F8);
    final Color card = isDark ? const Color(0xFF181B26) : Colors.white;
    final Color border = isDark
        ? const Color(0xFF2A2E3D)
        : const Color(0xFFE3E4EC);

    final textTheme = Typography.material2021().black;
    final baseTextTheme = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: card,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      textTheme: baseTextTheme.copyWith(
        displaySmall: TypeScale.displaySmall,
        headlineMedium: TypeScale.headlineMedium,
        headlineSmall: TypeScale.headlineSmall,
        titleLarge: TypeScale.titleLarge,
        titleMedium: TypeScale.titleMedium,
        bodyLarge: TypeScale.bodyLarge,
        bodyMedium: TypeScale.bodyMedium,
        labelLarge: TypeScale.labelLarge,
        labelSmall: TypeScale.labelSmall,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          side: BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1F2330) : Colors.white,
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        side: BorderSide(color: border),
        labelStyle: TypeScale.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space12,
          vertical: Tokens.space8,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2330) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Tokens.space16,
          vertical: Tokens.space12,
        ),
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
        hintStyle: TypeScale.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, Tokens.inputHeight),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          textStyle: TypeScale.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, Tokens.inputHeight),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          textStyle: TypeScale.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: TypeScale.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(Tokens.iconButtonSize, Tokens.iconButtonSize),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? const Color(0xFF1F2330) : Colors.white,
          border: _inputBorder(border),
          enabledBorder: _inputBorder(border),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF10131C) : Colors.white,
        selectedLabelTextStyle: TypeScale.labelLarge,
        unselectedLabelTextStyle: TypeScale.labelSmall,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF10131C) : Colors.white,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF2A2E3D)
            : const Color(0xFF1F2230),
        contentTextStyle: TypeScale.bodyLarge.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFF1F2230),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        textStyle: TypeScale.bodyMedium.copyWith(color: Colors.white),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: border,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: border,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
