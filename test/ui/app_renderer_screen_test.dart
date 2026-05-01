import 'package:appplayer/ui/app/app_renderer_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

class MockAppSession extends Mock implements AppSession {}

class _FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockCore core;

  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
  });

  setUp(() {
    core = MockCore();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.onboarding_completed': true,
    });
  });

  Future<void> pumpRenderer(WidgetTester tester, String serverId) async {
    final settings = await makeSettings();
    await tester.pumpWidget(
      wrapScreen(
        child: AppRendererScreen(serverId: serverId),
        core: core,
        settings: settings,
      ),
    );
  }

  group('TC-APPVW-001 session acquired renders content', () {
    testWidgets(
      'shows CircularProgressIndicator then session widget after openAppFromServer resolves',
      (tester) async {
        const serverId = 'srv-ok';
        final session = MockAppSession();

        when(() => session.buildWidget(
              context: any(named: 'context'),
              onExit: any(named: 'onExit'),
            )).thenReturn(const Text('runtime-content'));

        when(() => core.openAppFromServer(serverId)).thenAnswer((_) async {
          await Future<void>.delayed(Duration.zero);
          return session;
        });

        await pumpRenderer(tester, serverId);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('runtime-content'), findsNothing);

        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('runtime-content'), findsOneWidget);
      },
    );
  });

  group('TC-APPVW-002 ConnectionFailedException shows error banner', () {
    testWidgets(
      'Key("app_renderer.error_banner") visible when openAppFromServer throws ConnectionFailedException',
      (tester) async {
        const serverId = 'srv-conn-fail';

        when(() => core.openAppFromServer(serverId)).thenThrow(
          ConnectionFailedException(serverId, 'host unreachable'),
        );

        await pumpRenderer(tester, serverId);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('app_renderer.error_banner')),
          findsOneWidget,
        );
      },
    );
  });

  group('TC-APPVW-007 ServerNotFoundException shows error banner', () {
    testWidgets(
      'Key("app_renderer.error_banner") visible when openAppFromServer throws ServerNotFoundException',
      (tester) async {
        const serverId = 'srv-not-found';

        when(() => core.openAppFromServer(serverId)).thenThrow(
          ServerNotFoundException(serverId),
        );

        await pumpRenderer(tester, serverId);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('app_renderer.error_banner')),
          findsOneWidget,
        );
      },
    );
  });
}
