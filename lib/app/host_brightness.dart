import 'package:flutter/material.dart';

import 'app_settings.dart';

/// Resolves the launcher's effective brightness and publishes it as a
/// [ValueNotifier] so the MCP UI runtime can honour it for DSL
/// `mode: 'system'`.
///
/// Reacts to two inputs:
/// - [AppSettings.themeMode] — user-chosen launcher theme
///   (`system` / `light` / `dark`).
/// - `PlatformDispatcher.platformBrightness` — only consulted when the
///   setting is `system`.
///
/// Declared `mode: 'light'` / `mode: 'dark'` on a server DSL is
/// unaffected; the runtime override only feeds `system` resolution.
class HostBrightnessController extends ValueNotifier<Brightness>
    with WidgetsBindingObserver {
  HostBrightnessController(this._settings)
      : super(_resolveFrom(_settings)) {
    _settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  final AppSettings _settings;

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (_settings.themeMode == ThemeMode.system) {
      _update(_resolveFrom(_settings));
    }
  }

  void _onSettingsChanged() {
    _update(_resolveFrom(_settings));
  }

  void _update(Brightness next) {
    if (value == next) return;
    value = next;
  }

  static Brightness _resolveFrom(AppSettings settings) {
    switch (settings.themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
