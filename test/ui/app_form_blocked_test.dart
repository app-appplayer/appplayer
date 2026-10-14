// FR-HOME-013 a blocked address is not registered.
import 'package:appplayer/adapters/blocked_servers.dart';
import 'package:appplayer/adapters/prefs_apps_registry.dart';
import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/models/apps_list_notifier.dart';
import 'package:appplayer/ui/app_form/app_form_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  late MockCore core;
  late PrefsAppsRegistry<AppConfig> registry;

  setUpAll(() {
    registerFallbackValue(ServerConfig(
      id: 'f',
      name: 'f',
      description: '',
      transportType: TransportType.sse,
      transportConfig: const <String, dynamic>{},
    ));
    registerFallbackValue(const AppHandle.server('fallback'));
  });

  setUp(() {
    core = MockCore();
    when(() => core.listServers()).thenAnswer((_) async => <ServerConfig>[]);
    when(() => core.saveServer(any())).thenAnswer((_) async {});
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.onboarding_completed': true,
      ...prefsValues,
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = await AppSettings.load(prefs);
    registry = PrefsAppsRegistry<AppConfig>(
      prefs: prefs,
      storageKey: 'apps.v1',
      decode: AppConfig.decodeList,
      encode: AppConfig.encodeList,
      idOf: (a) => a.id,
      onChanged: AppsListNotifier.markDirty,
    );
    final router = GoRouter(routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/form',
        builder: (_, __) => const AppFormScreen(mode: AppFormMode.create),
      ),
    ]);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<AppPlayerCoreService>.value(value: core),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ListenableProvider<AppsRegistry<AppConfig>>.value(value: registry),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    router.push('/form');
    await tester.pumpAndSettle();
  }

  Future<void> chooseSse(WidgetTester tester, String url) async {
    await tester.tap(find.text('STDIO (Process)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSE (Server-Sent Events)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'URL *'), url);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    final saveFinder = find.byKey(const Key('app_form.save'));
    await tester.ensureVisible(saveFinder);
    await tester.pumpAndSettle();
    await tester.tap(saveFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a blocked address is refused and nothing is saved',
      (tester) async {
    await pumpForm(tester, prefsValues: <String, Object>{
      BlockedServers.storageKey:
          '[{"address":"https://blocked.example/sse","name":"Bad"}]',
    });
    await chooseSse(tester, 'HTTPS://Blocked.example/sse/');
    await save(tester);

    expect(find.textContaining('server address is blocked'), findsOneWidget);
    expect(registry.value, isEmpty);
    verifyNever(() => core.saveServer(any()));
  });

  testWidgets('after unblocking the same address is accepted', (tester) async {
    await pumpForm(tester, prefsValues: <String, Object>{
      BlockedServers.storageKey:
          '[{"address":"https://blocked.example/sse","name":"Bad"}]',
    });
    final store = await BlockedServers.open();
    await store.unblock('https://blocked.example/sse');
    await chooseSse(tester, 'https://blocked.example/sse');
    await save(tester);

    expect(registry.value, hasLength(1));
  });
}
