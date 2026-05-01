import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// MOD-SHELL-003 — Material 3 theme composed from design tokens.
///
/// Chrome layering follows the M3 tonal container hierarchy so that
/// AppBar / SnackBar / Scaffold read as distinct surfaces in both light
/// and dark without relying on shadow contrast:
///
///   Scaffold body  → `colorScheme.surface` (base)
///   AppBar         → `colorScheme.surfaceContainer` (one tonal step up)
///   Card (default) → M3 default (`surfaceContainerLow`)
///   Dialog         → M3 default (`surfaceContainerHigh`)
///   SnackBar       → `colorScheme.surfaceContainer` — matches the AppBar
///                    so transient notifications read as an extension of
///                    the chrome rather than a separate tonal layer.
class AppTheme {
  const AppTheme._();

  /// Brand seed colour (proxy to [AppColors.seed] for backward compatibility).
  static Color get seed => AppColors.seed;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
    final chrome = AppChrome.current();
    // Single source of typography scale: every textStyle in the host
    // TextTheme is multiplied by `chrome.textScale`. M3 baselines that
    // leave `fontSize` null (some headline/display roles do) get the
    // matching M3 default before scaling so the result is well-defined.
    final scaledTextTheme = _scaleTextTheme(base.textTheme, chrome.textScale);
    return base.copyWith(
      textTheme: scaledTextTheme,
      primaryTextTheme:
          _scaleTextTheme(base.primaryTextTheme, chrome.textScale),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level1,
        scrolledUnderElevation: AppElevation.level1,
        toolbarHeight: chrome.toolbarHeight,
        titleTextStyle: scaledTextTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: chrome.iconSize,
        ),
      ),
      iconTheme: base.iconTheme.copyWith(size: chrome.iconSize),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.all(chrome.iconButtonPadding),
          minimumSize: Size(chrome.iconButtonMin, chrome.iconButtonMin),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: chrome.listTileDense,
        visualDensity: chrome.listTileDense
            ? VisualDensity.compact
            : VisualDensity.standard,
        minLeadingWidth: 28,
        titleTextStyle: scaledTextTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: scaledTextTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: scaledTextTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: scaledTextTheme.titleSmall,
      ),
      cardTheme: const CardThemeData(
        elevation: AppElevation.level2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.brMd),
      ),
      dialogTheme: const DialogThemeData(
        elevation: AppElevation.level2,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.brMd),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
          textStyle: scaledTextTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
          textStyle: scaledTextTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.brSm),
          textStyle: scaledTextTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.brSm),
          ),
          textStyle: WidgetStatePropertyAll(scaledTextTheme.labelLarge),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(borderRadius: AppRadii.brSm),
        isDense: chrome.listTileDense,
        labelStyle: scaledTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        floatingLabelStyle: scaledTextTheme.bodyMedium,
        hintStyle: scaledTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        helperStyle: scaledTextTheme.bodySmall,
        errorStyle: scaledTextTheme.bodySmall?.copyWith(
          color: colorScheme.error,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: scaledTextTheme.bodyMedium,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: AppRadii.brSm),
        ),
      ),
      // SnackBar matches the AppBar's `surfaceContainer` so the toast
      // reads as an extension of the chrome rather than a separate
      // tonal layer. `behavior: floating` is required — M3 "fixed"
      // SnackBar otherwise overrides backgroundColor with an opaque
      // tonal overlay.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainer,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        actionTextColor: colorScheme.primary,
        closeIconColor: colorScheme.onSurface,
        elevation: AppElevation.level2,
      ),
    );
  }

  /// Scales every textStyle's `fontSize` by [factor]. When the source
  /// `fontSize` is null the corresponding Material 3 default is used so
  /// the scale always produces a concrete value (mirrors what
  /// `AppTypography._scale` would do, but guarantees no
  /// `fontSize == null` survives — important so downstream calls that
  /// rely on `fontSize` being non-null don't trip assertions).
  static TextTheme _scaleTextTheme(TextTheme base, double factor) {
    if (factor == 1.0) return base;
    TextStyle? s(TextStyle? style, double m3Default) {
      if (style == null) return null;
      final size = (style.fontSize ?? m3Default) * factor;
      return style.copyWith(fontSize: size);
    }

    return base.copyWith(
      // Material 3 defaults — see Typography.material2021 baseline.
      displayLarge: s(base.displayLarge, 57),
      displayMedium: s(base.displayMedium, 45),
      displaySmall: s(base.displaySmall, 36),
      headlineLarge: s(base.headlineLarge, 32),
      headlineMedium: s(base.headlineMedium, 28),
      headlineSmall: s(base.headlineSmall, 24),
      titleLarge: s(base.titleLarge, 22),
      titleMedium: s(base.titleMedium, 16),
      titleSmall: s(base.titleSmall, 14),
      bodyLarge: s(base.bodyLarge, 16),
      bodyMedium: s(base.bodyMedium, 14),
      bodySmall: s(base.bodySmall, 12),
      labelLarge: s(base.labelLarge, 14),
      labelMedium: s(base.labelMedium, 12),
      labelSmall: s(base.labelSmall, 11),
    );
  }
}
