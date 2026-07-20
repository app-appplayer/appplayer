import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show ThemeDefinition;
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart'
    show ThemeManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/app/host_brightness.dart';

/// Standard's theme chain: the launcher theme choice must reach the runtime
/// sessions as a live brightness feed (that feed is what appplayer_core
/// 0.1.12's per-entry rebaseline pins), and the runtime's system baseline
/// must carry REAL dark tokens — the two host-side halves of the
/// "weird dark" fixes, verified at the Standard tier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load(await SharedPreferences.getInstance());
  });

  group('HostBrightnessController (the feed rebaseline pins)', () {
    test('explicit launcher dark/light win over the platform', () async {
      await settings.setThemeMode(ThemeMode.dark);
      final c = HostBrightnessController(settings);
      expect(c.value, Brightness.dark);

      await settings.setThemeMode(ThemeMode.light);
      expect(c.value, Brightness.light);
      c.dispose();
    });

    test('theme toggle propagates live to an attached listener', () async {
      await settings.setThemeMode(ThemeMode.light);
      final c = HostBrightnessController(settings);
      final seen = <Brightness>[];
      c.addListener(() => seen.add(c.value));

      await settings.setThemeMode(ThemeMode.dark);
      expect(seen, [Brightness.dark]);
      c.dispose();
    });
  });

  group('runtime theme surface (what the session rebaselines onto)', () {
    test('a system baseline with dark override resolves REAL dark under a '
        'dark pin — the bare default does not', () {
      final tm = ThemeManager();
      tm.reset();

      // Bare default (the pre-fix state): dark pin over lightonly tokens.
      tm.setHostBrightness(Brightness.dark);
      expect(tm.flutterThemeMode, ThemeMode.dark);
      expect(tm.getThemeValue('dark'), isNull,
          reason: 'bare default has no dark token set — the "weird dark"');

      // The 0.1.12 system baseline shape: defaultLight + dark override.
      tm.setThemeDefinition(ThemeDefinition.fromJson({
        ...ThemeDefinition.defaultLight().toJson(),
        'mode': 'system',
        'dark': ThemeDefinition.defaultDark().toJson(),
      }));
      tm.setHostBrightness(Brightness.dark);
      expect(tm.flutterThemeMode, ThemeMode.dark);
      expect(tm.getThemeValue('dark'), isNotNull,
          reason: 'baseline must carry real dark tokens');
      tm.reset();
    });

    test('AppSessionImpl-class rebaseline gate is fingerprint-live: any '
        'external reset invalidates a skip', () {
      final tm = ThemeManager();
      tm.reset();
      tm.setTheme({
        'mode': 'system',
        'dark': {'mode': 'dark'},
      });
      tm.setHostBrightness(Brightness.dark);
      final applied = tm.fingerprint;

      expect(tm.fingerprint, applied); // untouched → skip is safe
      tm.reset(); // MCPUIRuntime.destroy() path
      expect(tm.fingerprint, isNot(applied)); // skip must re-apply
    });
  });
}
