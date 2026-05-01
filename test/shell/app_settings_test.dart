import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns defaults from empty prefs', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = await AppSettings.load(prefs);
    expect(s.themeMode, ThemeMode.system);
    expect(s.locale, const Locale('auto'));
    expect(s.logLevel, LogLevel.info);
    expect(s.onboardingCompleted, isFalse);
  });

  test('setters persist + notify', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = await AppSettings.load(prefs);
    var notified = 0;
    s.addListener(() => notified++);

    await s.setThemeMode(ThemeMode.dark);
    await s.setLocale(const Locale('en'));
    await s.setLogLevel(LogLevel.debug);
    await s.markOnboardingCompleted();

    expect(notified, 4);
    expect(s.themeMode, ThemeMode.dark);
    expect(s.locale, const Locale('en'));
    expect(s.logLevel, LogLevel.debug);
    expect(s.onboardingCompleted, isTrue);

    // Persisted — reload reflects same values.
    final reloaded = await AppSettings.load(prefs);
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.onboardingCompleted, isTrue);
  });

  test('no notify when setter value unchanged', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = await AppSettings.load(prefs);
    var notified = 0;
    s.addListener(() => notified++);

    await s.setThemeMode(ThemeMode.system); // default, same
    expect(notified, 0);
  });

  test('resetToDefaults clears persisted values', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = await AppSettings.load(prefs);
    await s.setThemeMode(ThemeMode.dark);
    await s.setLocale(const Locale('en'));

    await s.resetToDefaults();

    expect(s.themeMode, ThemeMode.system);
    expect(s.locale, const Locale('auto'));
  });
}
