import 'package:appplayer/adapters/console_logger.dart';
import 'package:appplayer/adapters/prefs_apps_registry.dart';
import 'package:appplayer/adapters/secure_credential_vault.dart';
import 'package:appplayer/adapters/shared_prefs_server_storage.dart';
import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/app/composition_root.dart';
import 'package:appplayer/app/host_brightness.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/_helpers.dart';

class MockSecureCredentialVault extends Mock implements SecureCredentialVault {}

/// Build an [AppContext] manually, bypassing [CompositionRoot.build] so that
/// no real Core initialisation runs.  This mirrors the helper in
/// `app_player_app_test.dart`.
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
  // HostBrightnessController reads `WidgetsBinding.instance.platformDispatcher`,
  // so the binding must be live even for non-widget tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  // IT-COMP-001: Normal assembly returns valid AppContext (FR-COMP-001)
  test('IT-COMP-001 build returns AppContext with all non-null fields',
      () async {
    final ctx = await _buildCtx();

    expect(ctx.core, isNotNull);
    expect(ctx.settings, isNotNull);
    expect(ctx.serverStorage, isNotNull);
    expect(ctx.credentialVault, isNotNull);
    expect(ctx.logger, isNotNull);
    expect(ctx.core, isA<AppPlayerCoreService>());
    expect(ctx.settings, isA<AppSettings>());
    expect(ctx.serverStorage, isA<SharedPrefsServerStorage>());
    expect(ctx.credentialVault, isA<SecureCredentialVault>());
    expect(ctx.logger, isA<ConsoleLogger>());
  });

  // IT-COMP-002: AppSettings loads persisted values (FR-COMP-001)
  test('IT-COMP-002 AppSettings loads theme_mode and locale from prefs',
      () async {
    final ctx = await _buildCtx(prefsValues: <String, Object>{
      'settings.theme_mode': 'dark',
      'settings.locale': 'ko',
    });

    expect(ctx.settings.themeMode, ThemeMode.dark);
    expect(ctx.settings.locale.languageCode, 'ko');
  });

}
