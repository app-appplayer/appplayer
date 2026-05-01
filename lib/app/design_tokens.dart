import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Responsive token classes (AppSpacing, AppIconSizes, AppTypography,
// AppDensity) and the FormFactor axis are owned by
// `flutter_mcp_ui_runtime` and surfaced through `appplayer_core`. This
// file re-exports them so existing call sites that only import
// `design_tokens.dart` continue to see `AppSpacing.sm` / `.of(context)`
// etc. without additional imports.
export 'package:appplayer_core/appplayer_core.dart'
    show
        FormFactor,
        FormFactorScope,
        ViewMode,
        ViewModeResolver,
        AppSpacing,
        AppSpacingScale,
        AppIconSizes,
        AppIconSizesScale,
        AppTypography,
        AppTypographyScale,
        AppDensity;

/// Design tokens — single source of layout/colour/motion primitives.
///
/// Mirrored by `docs/00_PRD/DESIGN-SYSTEM.md`; changes must update both.

// -----------------------------------------------------------------------------
// Color
// -----------------------------------------------------------------------------

class AppColors {
  const AppColors._();

  /// Brand seed used for [ColorScheme.fromSeed].
  static const Color seed = Color(0xFF3F51B5);

  // Semantic — choose by [Brightness] to preserve contrast in dark mode.
  static Color success(Brightness b) =>
      b == Brightness.light ? const Color(0xFF2E7D32) : const Color(0xFF81C784);

  static Color warning(Brightness b) =>
      b == Brightness.light ? const Color(0xFFED6C02) : const Color(0xFFFFB74D);

  static Color info(Brightness b) =>
      b == Brightness.light ? const Color(0xFF0288D1) : const Color(0xFF4FC3F7);
}

// -----------------------------------------------------------------------------
// Radius
// -----------------------------------------------------------------------------

class AppRadii {
  const AppRadii._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));
}

// -----------------------------------------------------------------------------
// Elevation (Material 3 levels)
// -----------------------------------------------------------------------------

class AppElevation {
  const AppElevation._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
  static const double level3 = 6;
  static const double level4 = 8;
  static const double level5 = 12;
}

// -----------------------------------------------------------------------------
// Motion
// -----------------------------------------------------------------------------

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration deliberate = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve decelerate = Curves.decelerate;
}

// -----------------------------------------------------------------------------
// Chrome density (platform-aware: desktop vs mobile)
//
// Chrome (AppBar / ListTile / IconButton / Dropdown) visual density differs
// between desktop and mobile. `AppChrome.current()` picks the right set
// based on `defaultTargetPlatform`. Widgets must NOT branch on platform
// directly — they read the active set from theme via `AppChrome.current()`
// at build time, or rely on `AppTheme` which already wires it.
// -----------------------------------------------------------------------------

class AppChrome {
  const AppChrome._({
    required this.toolbarHeight,
    required this.iconSize,
    required this.iconButtonMin,
    required this.iconButtonPadding,
    required this.listTileDense,
    required this.textScale,
  });

  /// Layout-only tokens. Typography is a single ratio applied uniformly
  /// to the host `TextTheme` — see `AppTheme._build` which calls
  /// `base.textTheme.apply(fontSizeFactor: chrome.textScale)`. Magic
  /// font-size numbers do NOT live in this class.
  final double toolbarHeight;
  final double iconSize;
  final double iconButtonMin;
  final double iconButtonPadding;
  final bool listTileDense;
  final double textScale;

  /// Desktop chrome — macOS / Windows / Linux / Web (browser). Same
  /// expanded-form-factor ratio used by `AppTypography._scaleFor`.
  static const AppChrome desktop = AppChrome._(
    toolbarHeight: 44,
    iconSize: 20,
    iconButtonMin: 28,
    iconButtonPadding: 6,
    listTileDense: true,
    textScale: 0.85,
  );

  /// Mobile chrome — iOS / Android / Fuchsia. Material 3 baseline.
  static const AppChrome mobile = AppChrome._(
    toolbarHeight: 56,
    iconSize: 24,
    iconButtonMin: 48,
    iconButtonPadding: 8,
    listTileDense: false,
    textScale: 1.0,
  );

  /// Returns the chrome set appropriate for the current platform.
  static AppChrome current() {
    if (kIsWeb) return desktop;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return desktop;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return mobile;
    }
  }
}

// -----------------------------------------------------------------------------
// Breakpoints (reference constants; effective classification happens via
// `FormFactor.of(context)` from appplayer_core)
// -----------------------------------------------------------------------------

class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 0;
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double extraLarge = 1600;
}
