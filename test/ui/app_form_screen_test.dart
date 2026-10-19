import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/ui/app_form/app_form_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:appplayer/ui/app_form/transport_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

/// Runs [body] with the host platform forced to [platform]. The override must
/// be cleared before the test body ends, so it cannot go through addTearDown.
Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  late MockCore core;

  setUp(() {
    core = MockCore();
    // listServers is called during _initialize; return empty list.
    when(() => core.listServers()).thenAnswer((_) async => <ServerConfig>[]);
  });

  // ---------------------------------------------------------------------------
  // TC-FORM-001 - Type selector renders 3 options (FR-FORM-001)
  // ---------------------------------------------------------------------------

  group('TC-FORM-001 type selector renders 3 options', () {
    testWidgets('Server / Bundle / Dashboard segments are visible',
        (tester) async {
      final settings = await _setupPrefs();
      await tester.pumpWidget(
        wrapScreen(
          child: const AppFormScreen(mode: AppFormMode.create),
          core: core,
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();

      // SegmentedButton with the expected key exists.
      expect(find.byKey(const Key('app_form.type')), findsOneWidget);

      // All three segment labels are visible.
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Bundle'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-FORM-009 - Required fields empty -> save blocked
  // ---------------------------------------------------------------------------

  group('TC-FORM-009 required field validation blocks save', () {
    testWidgets('server type: empty name shows validation error on save tap',
        (tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final settings = await _setupPrefs();
        await tester.pumpWidget(
          wrapScreen(
            child: const AppFormScreen(mode: AppFormMode.create),
            core: core,
            settings: settings,
          ),
        );
        await tester.pumpAndSettle();

        // Default type is server; name field is empty. The form is
        // taller than the 800×600 test viewport once the trust-level
        // selector is rendered, so scroll the save button into view
        // before tapping.
        final saveFinder = find.byKey(const Key('app_form.save'));
        await tester.ensureVisible(saveFinder);
        await tester.pumpAndSettle();
        await tester.tap(saveFinder);
        await tester.pumpAndSettle();

        // Command is required (server name auto-assigns when empty).
        expect(find.text('Enter a command'), findsOneWidget);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // TC-FORM-010 - Transport switch changes visible fields
  // ---------------------------------------------------------------------------

  group('TC-FORM-010 transport switch changes fields', () {
    testWidgets(
        'switching from STDIO to SSE shows URL field instead of command',
        (tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final settings = await _setupPrefs();
        await tester.pumpWidget(
          wrapScreen(
            child: const AppFormScreen(mode: AppFormMode.create),
            core: core,
            settings: settings,
          ),
        );
        await tester.pumpAndSettle();

        // Default transport is STDIO; command field hint should be visible.
        expect(find.text('npx'), findsOneWidget);

        // Open the transport dropdown and select SSE.
        await tester.tap(find.text('STDIO (Process)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SSE (Server-Sent Events)').last);
        await tester.pumpAndSettle();

        // After switching: URL field should appear, command field should be gone.
        expect(find.text('npx'), findsNothing);
        expect(find.text('URL *'), findsOneWidget);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // TC-FORM-011 ~ 013 - STDIO is desktop-only (FR-FORM-009)
  // ---------------------------------------------------------------------------

  group('TC-FORM-011 mobile has no STDIO and defaults to HTTP', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      testWidgets('$platform: default Streamable HTTP, list without STDIO',
          (tester) async {
        await _onPlatform(platform, () async {
          final settings = await _setupPrefs();
          await tester.pumpWidget(
            wrapScreen(
              child: const AppFormScreen(mode: AppFormMode.create),
              core: core,
              settings: settings,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('HTTP (Streamable)'), findsOneWidget);
          expect(find.text('URL *'), findsOneWidget);
          expect(find.text('Command *'), findsNothing);

          await tester.tap(find.text('HTTP (Streamable)'));
          await tester.pumpAndSettle();
          expect(find.text('STDIO (Process)'), findsNothing);
          expect(find.text('SSE (Server-Sent Events)'), findsOneWidget);
        });
      });
    }
  });

  group('TC-FORM-012 desktop keeps STDIO', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      testWidgets('$platform: default STDIO, list with all three',
          (tester) async {
        await _onPlatform(platform, () async {
          final settings = await _setupPrefs();
          await tester.pumpWidget(
            wrapScreen(
              child: const AppFormScreen(mode: AppFormMode.create),
              core: core,
              settings: settings,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('STDIO (Process)'), findsOneWidget);
          await tester.tap(find.text('STDIO (Process)'));
          await tester.pumpAndSettle();
          expect(find.text('SSE (Server-Sent Events)'), findsOneWidget);
          expect(find.text('HTTP (Streamable)'), findsOneWidget);
        });
      });
    }
  });

  group('TC-FORM-013 a saved STDIO server stays editable on mobile', () {
    test('its own transport stays in the choices, others cannot add it', () {
      expect(
        transportChoices(TransportType.stdio, platform: TargetPlatform.android),
        contains(TransportType.stdio),
      );
      expect(
        transportChoices(
          TransportType.streamableHttp,
          platform: TargetPlatform.android,
        ),
        isNot(contains(TransportType.stdio)),
      );
      expect(
        availableTransports(platform: TargetPlatform.iOS, isWeb: false),
        <TransportType>[TransportType.sse, TransportType.streamableHttp],
      );
      expect(availableTransports(isWeb: true),
          isNot(contains(TransportType.stdio)));
    });
  });

  // TC-FORM-002 ~ 008 deferred — they require extensive Core API mocking
  // (saveServer / loadBundleManifest / listServers / deleteServer) and
  // FilePicker platform stubbing. End-to-end coverage lives in manual
  // AppPlayer QA until a mock harness is in place.
}
