import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sets up SharedPreferences with the given [apps] list (omits `apps.v1` key
/// when null) and onboarding completed, then returns a loaded [AppSettings].
Future<AppSettings> _setupPrefs({List<AppConfig>? apps}) async {
  final values = <String, Object>{
    'settings.onboarding_completed': true,
  };
  if (apps != null) {
    values['apps.v1'] = AppConfig.encodeList(apps);
  }
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return AppSettings.load(prefs);
}

void main() {
  late MockCore core;

  setUp(() {
    core = MockCore();
    stubCoreLifecycle(core);
  });

  // ---------------------------------------------------------------------------
  // TC-HOME-007 — Empty state
  // ---------------------------------------------------------------------------

  group('TC-HOME-007 empty state', () {
    testWidgets('shows home.empty when apps.v1 key is absent', (tester) async {
      final settings = await _setupPrefs();
      await tester.pumpWidget(
        wrapScreen(child: const HomeScreen(), core: core, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.empty')), findsOneWidget);
    });

    testWidgets('shows home.empty when apps.v1 is an empty list', (tester) async {
      final settings = await _setupPrefs(apps: <AppConfig>[]);
      await tester.pumpWidget(
        wrapScreen(child: const HomeScreen(), core: core, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.empty')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-HOME-001 — Grid renders app icons
  // ---------------------------------------------------------------------------

  group('TC-HOME-001 grid renders app icons', () {
    testWidgets('renders home.app.{id} key for each stored app', (tester) async {
      final apps = <AppConfig>[
        AppConfig(id: 'app-1', name: 'App One', type: AppType.bundle),
        AppConfig(
          id: 'app-2',
          name: 'App Two',
          type: AppType.server,
          serverConfigId: 'srv-2',
        ),
      ];
      final settings = await _setupPrefs(apps: apps);
      await tester.pumpWidget(
        wrapScreen(child: const HomeScreen(), core: core, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.app.app-1')), findsOneWidget);
      expect(find.byKey(const Key('home.app.app-2')), findsOneWidget);
      // Empty state must not appear when apps are present.
      expect(find.byKey(const Key('home.empty')), findsNothing);
    });

    testWidgets('displays the app name label beneath each icon', (tester) async {
      final apps = <AppConfig>[
        AppConfig(id: 'dash-1', name: 'My Dashboard', type: AppType.dashboard),
      ];
      final settings = await _setupPrefs(apps: apps);
      await tester.pumpWidget(
        wrapScreen(child: const HomeScreen(), core: core, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Dashboard'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-HOME-005 — [+] button
  // ---------------------------------------------------------------------------

  group('TC-HOME-005 add button', () {
    testWidgets('home.add icon button is present', (tester) async {
      final settings = await _setupPrefs();
      await tester.pumpWidget(
        wrapScreen(child: const HomeScreen(), core: core, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.add')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-HOME-006 — [⚙] button
  // ---------------------------------------------------------------------------

  group('TC-HOME-006 settings button', () {
    testWidgets('home.settings icon button is present', (tester) async {
      final settings = await _setupPrefs();
      await tester.pumpWidget(
        wrapScreen(child: const HomeScreen(), core: core, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.settings')), findsOneWidget);
    });
  });

  // Connection-error UI moved to AppRendererScreen — covered by
  // TC-APPVW-002 / TC-APPVW-007 in test/ui/app_renderer_screen_test.dart.
}
