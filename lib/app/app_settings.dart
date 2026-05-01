import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MOD-SHELL-001 — app-level settings store as a ChangeNotifier.
class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._prefs, {
    required ThemeMode themeMode,
    required Locale locale,
    required LogLevel logLevel,
    required bool onboardingCompleted,
    required bool freshConnect,
    required ViewMode defaultViewMode,
  })  : _themeMode = themeMode,
        _locale = locale,
        _logLevel = logLevel,
        _onboardingCompleted = onboardingCompleted,
        _freshConnect = freshConnect,
        _defaultViewMode = defaultViewMode;

  static const String _kThemeMode = 'settings.theme_mode';
  static const String _kLocale = 'settings.locale';
  static const String _kLogLevel = 'settings.log_level';
  static const String _kOnboarded = 'settings.onboarding_completed';
  static const String _kFreshConnect = 'settings.fresh_connect';
  static const String _kDefaultViewMode = 'settings.default_view_mode';

  static const ThemeMode defaultThemeMode = ThemeMode.system;
  /// 'auto' means follow system locale. Stored as language code string.
  static final Locale defaultLocale = const Locale('auto');
  static const LogLevel defaultLogLevel = LogLevel.info;
  static const ViewMode defaultDefaultViewMode = ViewMode.auto;

  final SharedPreferences _prefs;

  ThemeMode _themeMode;
  Locale _locale;
  LogLevel _logLevel;
  bool _onboardingCompleted;
  bool _freshConnect;
  ViewMode _defaultViewMode;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  LogLevel get logLevel => _logLevel;
  bool get onboardingCompleted => _onboardingCompleted;

  /// true = always fresh connection, false = use cached runtime
  bool get freshConnect => _freshConnect;

  /// Global view-mode pin (responsive-rendering plan §4, rung 2). Per
  /// the priority chain, the per-app pin wins over this value, and this
  /// value wins over any DSL `responsive` hint and the MediaQuery
  /// auto-classification. [ViewMode.auto] means "defer to the next rung".
  ViewMode get defaultViewMode => _defaultViewMode;

  static Future<AppSettings> load(SharedPreferences prefs) async {
    return AppSettings._(
      prefs,
      themeMode: _parseThemeMode(prefs.getString(_kThemeMode)),
      locale: _parseLocale(prefs.getString(_kLocale)),
      logLevel: _parseLogLevel(prefs.getString(_kLogLevel)),
      onboardingCompleted: prefs.getBool(_kOnboarded) ?? false,
      freshConnect: prefs.getBool(_kFreshConnect) ?? false,
      defaultViewMode: ViewMode.parse(prefs.getString(_kDefaultViewMode)),
    );
  }

  Future<void> setThemeMode(ThemeMode v) async {
    if (_themeMode == v) return;
    _themeMode = v;
    await _prefs.setString(_kThemeMode, v.name);
    notifyListeners();
  }

  Future<void> setLocale(Locale v) async {
    if (_locale == v) return;
    _locale = v;
    await _prefs.setString(_kLocale, v.languageCode);
    notifyListeners();
  }

  Future<void> setLogLevel(LogLevel v) async {
    if (_logLevel == v) return;
    _logLevel = v;
    await _prefs.setString(_kLogLevel, v.name);
    notifyListeners();
  }

  Future<void> setFreshConnect(bool v) async {
    if (_freshConnect == v) return;
    _freshConnect = v;
    await _prefs.setBool(_kFreshConnect, v);
    notifyListeners();
  }

  Future<void> setDefaultViewMode(ViewMode v) async {
    if (_defaultViewMode == v) return;
    _defaultViewMode = v;
    if (v == ViewMode.auto) {
      await _prefs.remove(_kDefaultViewMode);
    } else {
      await _prefs.setString(_kDefaultViewMode, v.value);
    }
    notifyListeners();
  }

  Future<void> markOnboardingCompleted() async {
    if (_onboardingCompleted) return;
    _onboardingCompleted = true;
    await _prefs.setBool(_kOnboarded, true);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _themeMode = defaultThemeMode;
    _locale = defaultLocale;
    _logLevel = defaultLogLevel;
    _freshConnect = false;
    _defaultViewMode = defaultDefaultViewMode;
    await _prefs.remove(_kThemeMode);
    await _prefs.remove(_kLocale);
    await _prefs.remove(_kLogLevel);
    await _prefs.remove(_kFreshConnect);
    await _prefs.remove(_kDefaultViewMode);
    notifyListeners();
  }

  static ThemeMode _parseThemeMode(String? raw) {
    return ThemeMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => defaultThemeMode,
    );
  }

  static Locale _parseLocale(String? raw) {
    if (raw == null || raw.isEmpty) return defaultLocale;
    return Locale(raw);
  }

  static LogLevel _parseLogLevel(String? raw) {
    return LogLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => defaultLogLevel,
    );
  }
}
