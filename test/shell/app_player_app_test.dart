import 'package:appplayer/adapters/console_logger.dart';
import 'package:appplayer/adapters/prefs_apps_registry.dart';
import 'package:appplayer/adapters/secure_credential_vault.dart';
import 'package:appplayer/adapters/shared_prefs_server_storage.dart';
import 'package:appplayer/app/app_player_app.dart';
import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/app/composition_root.dart';
import 'package:appplayer/app/host_brightness.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/_helpers.dart';

class MockSecureCredentialVault extends Mock implements SecureCredentialVault {}

Future<AppContext> _buildCtx({
  AppPlayerCoreService? core,
  Map<String, Object> prefsValues = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
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
  );
  return AppContext(
    core: core ?? MockCore(),
    settings: settings,
    serverStorage: storage,
    credentialVault: vault,
    logger: logger,
    logBuffer: LogBuffer(),
    hostBrightness: HostBrightnessController(settings),
    appsRegistry: registry,
  );
}

void main() {
  // TC-APP-001: Provider injects core (FR-SHELL-001)
  testWidgets('TC-APP-001 Provider exposes injected core via context.read',
      (tester) async {
    final mockCore = MockCore();
    final ctx = await _buildCtx(
      core: mockCore,
      prefsValues: <String, Object>{'settings.onboarding_completed': true},
    );

    await tester.pumpWidget(AppPlayerApp(ctx: ctx));
    await tester.pumpAndSettle();

    // Grab a BuildContext from within the provider tree to verify injection.
    final element = tester.element(find.byType(MaterialApp));
    final readCore = element.read<AppPlayerCoreService>();

    expect(readCore, same(mockCore));
  });

  // TC-APP-002: themeMode reflects AppSettings (FR-SHELL-003)
  testWidgets('TC-APP-002 MaterialApp.themeMode reflects dark setting',
      (tester) async {
    final ctx = await _buildCtx(
      prefsValues: <String, Object>{
        'settings.theme_mode': 'dark',
        'settings.onboarding_completed': true,
      },
    );

    await tester.pumpWidget(AppPlayerApp(ctx: ctx));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  // TC-APP-003: locale reflects AppSettings
  testWidgets('TC-APP-003 MaterialApp.locale reflects ko setting',
      (tester) async {
    final ctx = await _buildCtx(
      prefsValues: <String, Object>{
        'settings.locale': 'ko',
        'settings.onboarding_completed': true,
      },
    );

    await tester.pumpWidget(AppPlayerApp(ctx: ctx));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale?.languageCode, 'ko');
  });

  // TC-APP-004: SKIPPED — AppLifecycleObserver is created internally in
  // _AppPlayerAppState and cannot be easily intercepted in a widget test.

  // TC-APP-005: AppSettings change triggers rebuild
  testWidgets('TC-APP-005 setThemeMode triggers rebuild with new themeMode',
      (tester) async {
    final ctx = await _buildCtx(
      prefsValues: <String, Object>{
        'settings.onboarding_completed': true,
      },
    );

    await tester.pumpWidget(AppPlayerApp(ctx: ctx));
    await tester.pumpAndSettle();

    // Initial themeMode is system (default)
    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);

    // Mutate settings
    await ctx.settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    // After rebuild, themeMode should be dark
    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
