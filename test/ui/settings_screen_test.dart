import 'package:appplayer/adapters/secure_credential_vault.dart';
import 'package:appplayer/adapters/shared_prefs_server_storage.dart';
import 'package:appplayer/l10n/app_strings.dart';
import 'package:appplayer/ui/settings/settings_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockServerStorage extends Mock implements SharedPrefsServerStorage {}

class MockCredentialVault extends Mock implements SecureCredentialVault {}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  late MockCore core;
  late MockServerStorage storage;
  late MockCredentialVault vault;

  setUp(() {
    core = MockCore();
    storage = MockServerStorage();
    vault = MockCredentialVault();
  });

  /// Pumps SettingsScreen with all required providers.
  Future<void> pumpSettings(WidgetTester tester) async {
    // Use fresh prefs for each test to avoid cross-test pollution.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.onboarding_completed': true,
    });
    final settings = await makeSettings();

    final List<SingleChildWidget> extra = [
      Provider<SharedPrefsServerStorage>.value(value: storage),
      Provider<SecureCredentialVault>.value(value: vault),
    ];

    await tester.pumpWidget(
      wrapScreenWithGoRouter(
        child: const SettingsScreen(),
        core: core,
        settings: settings,
        extraProviders: extra,
      ),
    );
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------------
  // TC-SET-001 — Theme change
  // -------------------------------------------------------------------------

  group('TC-SET-001 theme segmented button', () {
    testWidgets(
      'tapping "dark" segment on Key("settings.theme") calls settings.setThemeMode(ThemeMode.dark)',
      (tester) async {
        // We need access to the AppSettings instance that the widget tree uses
        // so we can verify the side-effect. Build the settings manually first,
        // then inject it alongside the screen.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'settings.onboarding_completed': true,
        });
        final settings = await makeSettings();

        final List<SingleChildWidget> extra = [
          Provider<SharedPrefsServerStorage>.value(value: storage),
          Provider<SecureCredentialVault>.value(value: vault),
        ];

        await tester.pumpWidget(
          wrapScreenWithGoRouter(
            child: const SettingsScreen(),
            core: core,
            settings: settings,
            extraProviders: extra,
          ),
        );
        await tester.pumpAndSettle();

        // The default theme is ThemeMode.system — tap 'dark' to change it.
        final darkSegment = find.descendant(
          of: find.byKey(const Key('settings.theme')),
          matching: find.text('dark'),
        );
        expect(darkSegment, findsOneWidget);
        await tester.tap(darkSegment);
        await tester.pumpAndSettle();

        expect(settings.themeMode, ThemeMode.dark);
      },
    );
  });

  // -------------------------------------------------------------------------
  // TC-SET-002 — Locale change
  // -------------------------------------------------------------------------

  group('TC-SET-002 locale dropdown', () {
    testWidgets(
      'selecting English from Key("settings.locale") dropdown changes locale to en',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'settings.onboarding_completed': true,
        });
        final settings = await makeSettings();

        final List<SingleChildWidget> extra = [
          Provider<SharedPrefsServerStorage>.value(value: storage),
          Provider<SecureCredentialVault>.value(value: vault),
        ];

        await tester.pumpWidget(
          wrapScreenWithGoRouter(
            child: const SettingsScreen(),
            core: core,
            settings: settings,
            extraProviders: extra,
          ),
        );
        await tester.pumpAndSettle();

        // Open the dropdown.
        await tester.tap(find.byKey(const Key('settings.locale')));
        await tester.pumpAndSettle();

        // Tap the "English" option in the overlay. Multiple matches may
        // exist (dropdown button label + overlay item); take the last one.
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();

        expect(settings.locale, const Locale('en'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // TC-SET-003 — Log level change
  // -------------------------------------------------------------------------

  group('TC-SET-003 log level dropdown', () {
    testWidgets(
      'selecting debug from Key("settings.log_level") dropdown changes logLevel',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'settings.onboarding_completed': true,
        });
        final settings = await makeSettings();

        final List<SingleChildWidget> extra = [
          Provider<SharedPrefsServerStorage>.value(value: storage),
          Provider<SecureCredentialVault>.value(value: vault),
        ];

        await tester.pumpWidget(
          wrapScreenWithGoRouter(
            child: const SettingsScreen(),
            core: core,
            settings: settings,
            extraProviders: extra,
          ),
        );
        await tester.pumpAndSettle();

        // Open the dropdown.
        await tester.tap(find.byKey(const Key('settings.log_level')));
        await tester.pumpAndSettle();

        // Tap 'debug' option (shown in the overlay).
        await tester.tap(find.text('debug').last);
        await tester.pumpAndSettle();

        expect(settings.logLevel, LogLevel.debug);
      },
    );
  });

  // -------------------------------------------------------------------------
  // TC-SET-004 — Data reset calls clearAll on storage and vault
  // -------------------------------------------------------------------------

  group('TC-SET-004 data reset', () {
    testWidgets(
      'confirming dialog on Key("settings.reset_all") calls storage.clearAll and vault.clearAll',
      (tester) async {
        when(() => storage.clearAll()).thenAnswer((_) async {});
        when(() => vault.clearAll()).thenAnswer((_) async {});

        await pumpSettings(tester);

        // Tap the reset button to open the confirmation dialog.
        await tester.scrollUntilVisible(find.byKey(const Key('settings.reset_all')), 200);
        await tester.tap(find.byKey(const Key('settings.reset_all')));
        await tester.pumpAndSettle();

        // Resolve the confirm button label via the i18n table so the
        // test works regardless of which locale the launcher defaults to.
        final confirmBtn =
            find.widgetWithText(TextButton, S.get('settings.reset.confirm'));
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        verify(() => storage.clearAll()).called(1);
        verify(() => vault.clearAll()).called(1);
      },
    );

    testWidgets(
      'cancelling dialog does NOT call storage.clearAll or vault.clearAll',
      (tester) async {
        await pumpSettings(tester);

        await tester.scrollUntilVisible(find.byKey(const Key('settings.reset_all')), 200);
        await tester.tap(find.byKey(const Key('settings.reset_all')));
        await tester.pumpAndSettle();

        final cancelBtn =
            find.widgetWithText(TextButton, S.get('settings.reset.cancel'));
        expect(cancelBtn, findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        verifyNever(() => storage.clearAll());
        verifyNever(() => vault.clearAll());
      },
    );
  });

  // -------------------------------------------------------------------------
  // TC-SET-005 — Partial reset failure shows SnackBar
  // -------------------------------------------------------------------------

  group('TC-SET-005 partial reset failure', () {
    testWidgets(
      'storage.clearAll fails → SnackBar shows partial failure message',
      (tester) async {
        when(() => storage.clearAll())
            .thenThrow(StateError('persist failed'));
        when(() => vault.clearAll()).thenAnswer((_) async {});

        await pumpSettings(tester);

        await tester.scrollUntilVisible(find.byKey(const Key('settings.reset_all')), 200);
        await tester.tap(find.byKey(const Key('settings.reset_all')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(TextButton, S.get('settings.reset.confirm')),
        );
        await tester.pumpAndSettle();

        // SnackBar renders the localised "partial failure" template; match
        // on the stable prefix before the interpolated error list.
        final partialTemplate = S.get('settings.reset.partial');
        final partialPrefix =
            partialTemplate.split(r'${errors}').first.trim();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining(partialPrefix), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // TC-SET-006 — App info displays core version
  // -------------------------------------------------------------------------

  group('TC-SET-006 app info section', () {
    testWidgets(
      'Key("settings.core_version") widget is visible with runtime version text',
      (tester) async {
        await pumpSettings(tester);

        // Scroll down to make the core version widget visible.
        await tester.scrollUntilVisible(
          find.byKey(const Key('settings.core_version'), skipOffstage: false),
          200,
        );
        await tester.pumpAndSettle();

        final coreVersionFinder = find.byKey(const Key('settings.core_version'));
        expect(coreVersionFinder, findsOneWidget);

        // The widget must contain the DSL version constant.
        final widget = tester.widget<Text>(coreVersionFinder);
        expect(
          widget.data,
          contains(MCPUIDSLVersion.current),
        );
      },
    );
  });
}
