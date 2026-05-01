import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/ui/app_form/app_form_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
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

  // ---------------------------------------------------------------------------
  // TC-FORM-010 - Transport switch changes visible fields
  // ---------------------------------------------------------------------------

  group('TC-FORM-010 transport switch changes fields', () {
    testWidgets('switching from STDIO to SSE shows URL field instead of command',
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

  // TC-FORM-002 ~ 008 deferred — they require extensive Core API mocking
  // (saveServer / loadBundleManifest / listServers / deleteServer) and
  // FilePicker platform stubbing. End-to-end coverage lives in manual
  // AppPlayer QA until a mock harness is in place.
}
