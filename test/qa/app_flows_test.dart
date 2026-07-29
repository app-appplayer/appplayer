// QA-FLOW automated acceptance tests — top of the test pyramid
// (integration flows).
//
// Each test boots the REAL `AppPlayerApp` widget (real GoRouter, real
// AppSettings / PrefsAppsRegistry / SharedPrefsServerStorage) with only
// `AppPlayerCoreService` mocked (`MockCore`, reused from
// `test/ui/_helpers.dart`) and drives one full end-to-end user journey
// (QA-FLOW-001..006).
//
// Deterministic only — no real network / BLE / keychain. Standard has no
// marketplace / auto-discovery UI, so flows are limited to what the shell
// actually ships: onboarding gate, manual server registration, opening a
// registered app, and settings (theme / locale / toggles).
//
// NOTE on pumping: screens transiently show an indeterminate
// `CircularProgressIndicator` while an async call is in flight (form
// load, session open). In production the Core drives further
// asynchronous work after that (connections, lifecycle) that never
// fully quiesces, so `pumpAndSettle()` is avoided in this file in favour
// of a bounded `_settle()` helper that pumps a fixed number of
// fixed-duration frames — deterministic regardless of whether animations
// ever stop scheduling frames.

import 'package:appplayer/adapters/console_logger.dart';
import 'package:appplayer/adapters/prefs_apps_registry.dart';
import 'package:appplayer/adapters/secure_credential_vault.dart';
import 'package:appplayer/adapters/shared_prefs_server_storage.dart';
import 'package:appplayer/app/app_player_app.dart';
import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/app/composition_root.dart';
import 'package:appplayer/app/host_brightness.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/models/apps_list_notifier.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/_helpers.dart';

// ---------------------------------------------------------------------------
// Mocks / fakes
// ---------------------------------------------------------------------------

class MockSecureCredentialVault extends Mock implements SecureCredentialVault {}

class MockAppSession extends Mock implements AppSession {}

class _FakeBuildContext extends Fake implements BuildContext {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a full [AppContext] wired the same way [CompositionRoot.build]
/// does, except the Core is a caller-supplied [MockCore] (no real network
/// / process spawn) and the credential vault is mocked (no Keychain).
///
/// Set [resetPrefs] to `false` to reuse the SharedPreferences store from a
/// prior `_buildCtx` call — this is how the "restart" flows simulate a
/// fresh app boot reading back what a previous session persisted.
Future<AppContext> _buildCtx({
  required MockCore core,
  Map<String, Object> prefsValues = const <String, Object>{},
  bool resetPrefs = true,
}) async {
  if (resetPrefs) {
    SharedPreferences.setMockInitialValues(prefsValues);
  }
  final prefs = await SharedPreferences.getInstance();
  final settings = await AppSettings.load(prefs);
  final logger = ConsoleLogger();
  final storage = SharedPrefsServerStorage(prefs, logger: logger);
  final vault = MockSecureCredentialVault();
  final registry = PrefsAppsRegistry<AppConfig>(
    prefs: prefs,
    storageKey: 'apps.v1',
    decode: AppConfig.decodeList,
    encode: AppConfig.encodeList,
    idOf: (a) => a.id,
    onChanged: AppsListNotifier.markDirty,
  );
  stubCoreShell(core);
  stubCoreLifecycle(core);
  return AppContext(
    core: core,
    settings: settings,
    serverStorage: storage,
    credentialVault: vault,
    logger: logger,
    logBuffer: LogBuffer(),
    hostBrightness: HostBrightnessController(settings),
    appsRegistry: registry,
  );
}

/// Bounded settle helper — see file header. Pumps [steps] frames of
/// [step] duration each (default 10 × 50ms = 500ms of simulated time).
Future<void> _settle(
  WidgetTester tester, {
  int steps = 10,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
    // Needed for `when(() => core.saveServer(any()))` in QA-FLOW-003 —
    // mocktail requires a concrete fallback for non-primitive `any()`
    // argument types.
    registerFallbackValue(ServerConfig(
      name: 'fallback',
      description: '',
      transportType: TransportType.stdio,
      transportConfig: const <String, dynamic>{},
    ));
  });

  // ---------------------------------------------------------------------------
  // QA-FLOW-001 — Launch with onboarding already completed lands on Home.
  // ---------------------------------------------------------------------------

  group('QA-FLOW-001 launch (onboarding completed) lands on Home', () {
    testWidgets('boots straight to HomeScreen and shows the empty state',
        (tester) async {
      final core = MockCore();
      final ctx = await _buildCtx(
        core: core,
        prefsValues: <String, Object>{'settings.onboarding_completed': true},
      );

      await tester.pumpWidget(AppPlayerApp(ctx: ctx));
      await _settle(tester);

      // No onboarding — never redirected there.
      expect(find.byKey(const Key('onboarding.next')), findsNothing);
      // Home launcher chrome is visible.
      expect(find.byKey(const Key('home.add')), findsOneWidget);
      expect(find.byKey(const Key('home.settings')), findsOneWidget);
      // No apps registered yet → empty state.
      expect(find.byKey(const Key('home.empty')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // QA-FLOW-002 — First launch is gated behind onboarding; completing it
  // persists the flag and lands on Home.
  // ---------------------------------------------------------------------------

  group('QA-FLOW-002 first launch is gated behind onboarding', () {
    testWidgets(
        'shows OnboardingScreen first; "Start" persists the flag and routes to Home',
        (tester) async {
      final core = MockCore();
      // No 'settings.onboarding_completed' key → defaults to false.
      final ctx = await _buildCtx(core: core);

      await tester.pumpWidget(AppPlayerApp(ctx: ctx));
      await _settle(tester);

      // Router redirected to /onboarding — Home chrome is not present.
      expect(find.byKey(const Key('onboarding.next')), findsOneWidget);
      expect(find.byKey(const Key('home.add')), findsNothing);

      // Page 1 -> 2 -> 3, then "Start".
      await tester.tap(find.byKey(const Key('onboarding.next')));
      await _settle(tester, steps: 4);
      await tester.tap(find.byKey(const Key('onboarding.next')));
      await _settle(tester, steps: 4);
      expect(find.byKey(const Key('onboarding.start')), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding.start')));
      await _settle(tester);

      // Landed on Home.
      expect(find.byKey(const Key('home.add')), findsOneWidget);
      expect(find.byKey(const Key('onboarding.next')), findsNothing);

      // The flag is actually persisted (not just true in memory) — a
      // fresh read of the same prefs store reflects it.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.onboarding_completed'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // QA-FLOW-003 — Adding a server via AppFormScreen registers it and it
  // appears on the Home grid.
  // ---------------------------------------------------------------------------

  group('QA-FLOW-003 add a server via AppFormScreen registers it', () {
    testWidgets(
        'save persists the AppConfig + ServerConfig and the tile appears on Home',
        (tester) async {
      final core = MockCore();
      when(() => core.listServers()).thenAnswer((_) async => <ServerConfig>[]);
      when(() => core.saveServer(any())).thenAnswer((_) async {});
      when(() => core.fetchServerMetadata(any()))
          .thenAnswer((_) async => null);

      final ctx = await _buildCtx(
        core: core,
        prefsValues: <String, Object>{'settings.onboarding_completed': true},
      );

      await tester.pumpWidget(AppPlayerApp(ctx: ctx));
      await _settle(tester);
      expect(find.byKey(const Key('home.empty')), findsOneWidget);

      // Home -> [+] -> AppFormScreen (create mode).
      await tester.tap(find.byKey(const Key('home.add')));
      await _settle(tester);
      expect(find.byKey(const Key('app_form.type')), findsOneWidget);

      // Default type is Server / STDIO transport. Fill name + command
      // (required) + args. Fields have no dedicated Keys beyond `name`,
      // so index into the rendered TextFormFields in DOM order:
      // 0 = name, 1 = description, 2 = command, 3 = args.
      await tester.enterText(
        find.byKey(const Key('app_form.name')),
        'My Test Server',
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(2), 'echo');
      await tester.enterText(fields.at(3), 'hello');
      await _settle(tester, steps: 2);

      final saveButton = find.byKey(const Key('app_form.save'));
      await tester.ensureVisible(saveButton);
      await _settle(tester, steps: 2);
      await tester.tap(saveButton);
      // Extra steps: the pop transition keeps AppFormScreen (and its
      // "My Test Server" text field) mounted alongside the Home tile
      // until the route animation finishes.
      await _settle(tester, steps: 20);

      // Back on Home — the form is gone, new tile visible, empty state gone.
      expect(find.byKey(const Key('app_form.type')), findsNothing);
      expect(find.byKey(const Key('home.empty')), findsNothing);
      expect(find.text('My Test Server'), findsOneWidget);

      // Registration actually reached the ServerConfig side.
      verify(() => core.saveServer(any())).called(1);

      // And the launcher entry is really persisted in apps.v1 — not just
      // reflected in transient widget state.
      final prefs = await SharedPreferences.getInstance();
      final apps = AppConfig.decodeList(prefs.getString('apps.v1'));
      expect(apps, hasLength(1));
      expect(apps.single.name, 'My Test Server');
      expect(apps.single.type, AppType.server);
    });
  });

  // ---------------------------------------------------------------------------
  // QA-FLOW-004 — Opening a registered server card renders it via
  // AppRendererScreen.
  // ---------------------------------------------------------------------------

  group('QA-FLOW-004 opening a server card renders AppRendererScreen', () {
    testWidgets('tapping the tile opens the session and shows its content',
        (tester) async {
      final core = MockCore();
      const serverId = 'srv-flow-004';
      final session = MockAppSession();
      when(() => session.handle)
          .thenReturn(const AppHandle.server(serverId));
      when(() => session.buildWidget(
            context: any(named: 'context'),
            onExit: any(named: 'onExit'),
          )).thenReturn(const Text('RENDERED-SESSION'));
      when(() => core.openAppFromServer(serverId))
          .thenAnswer((_) async => session);

      final apps = <AppConfig>[
        AppConfig(
          id: serverId,
          name: 'Echo Server',
          type: AppType.server,
          serverConfigId: serverId,
        ),
      ];
      final ctx = await _buildCtx(
        core: core,
        prefsValues: <String, Object>{
          'settings.onboarding_completed': true,
          'apps.v1': AppConfig.encodeList(apps),
        },
      );

      await tester.pumpWidget(AppPlayerApp(ctx: ctx));
      await _settle(tester);

      final tile = find.byKey(const Key('home.app.$serverId'));
      expect(tile, findsOneWidget);

      await tester.tap(tile);
      await _settle(tester);

      expect(find.text('RENDERED-SESSION'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // QA-FLOW-005 — Theme / locale changes made through SettingsScreen reflect
  // immediately at the MaterialApp root, across the whole shell.
  // ---------------------------------------------------------------------------

  group('QA-FLOW-005 theme/locale settings reflect app-wide', () {
    testWidgets(
        'toggling theme to dark and locale to English updates MaterialApp',
        (tester) async {
      final core = MockCore();
      final ctx = await _buildCtx(
        core: core,
        prefsValues: <String, Object>{'settings.onboarding_completed': true},
      );

      await tester.pumpWidget(AppPlayerApp(ctx: ctx));
      await _settle(tester);

      // Home -> Settings.
      await tester.tap(find.byKey(const Key('home.settings')));
      await _settle(tester);
      expect(find.byKey(const Key('settings.theme')), findsOneWidget);

      // Baseline: system theme, auto locale (MaterialApp.locale == null).
      var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(app.locale, isNull);

      // Theme -> dark.
      final darkSegment = find.descendant(
        of: find.byKey(const Key('settings.theme')),
        matching: find.text('dark'),
      );
      await tester.tap(darkSegment);
      await _settle(tester);

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      // Locale -> English.
      await tester.tap(find.byKey(const Key('settings.locale')));
      await _settle(tester, steps: 6);
      await tester.tap(find.text('English').last);
      await _settle(tester, steps: 6);

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale?.languageCode, 'en');
    });
  });

  // ---------------------------------------------------------------------------
  // QA-FLOW-006 — Settings toggles persist across an app restart.
  // ---------------------------------------------------------------------------

  group('QA-FLOW-006 settings toggles persist across restart', () {
    testWidgets(
        'dark theme + Debug MCP toggle survive a fresh AppPlayerApp boot on the same store',
        (tester) async {
      final core1 = MockCore();
      final ctx1 = await _buildCtx(
        core: core1,
        prefsValues: <String, Object>{'settings.onboarding_completed': true},
      );

      await tester.pumpWidget(AppPlayerApp(ctx: ctx1));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('home.settings')));
      await _settle(tester);

      // Toggle theme.
      await tester.tap(find.descendant(
        of: find.byKey(const Key('settings.theme')),
        matching: find.text('dark'),
      ));
      await _settle(tester);

      // Toggle the Debug MCP developer switch (desktop-only, but the VM
      // test target is treated as desktop — kIsWeb is false).
      final debugMcpSwitch = find.byKey(const Key('settings.debug_mcp'));
      await tester.ensureVisible(debugMcpSwitch);
      await _settle(tester, steps: 2);
      await tester.tap(debugMcpSwitch);
      await _settle(tester);

      expect(ctx1.settings.themeMode, ThemeMode.dark);
      expect(ctx1.settings.debugMcpEnabled, isTrue);

      // Persisted — a fresh AppSettings.load off the same store reflects
      // both toggles without relying on the live in-memory object.
      final prefs = await SharedPreferences.getInstance();
      final reloaded = await AppSettings.load(prefs);
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.debugMcpEnabled, isTrue);

      // Simulate an app restart: boot a brand new AppPlayerApp off a
      // brand new AppContext reading the SAME (not reset) prefs store.
      final core2 = MockCore();
      final ctx2 = await _buildCtx(core: core2, resetPrefs: false);

      await tester.pumpWidget(AppPlayerApp(ctx: ctx2));
      await _settle(tester);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(ctx2.settings.debugMcpEnabled, isTrue);
    });
  });
}
