// FR-ENTRY-STD-010 — the add-app form opened from a scanned address.
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

  setUp(() {
    core = MockCore();
    when(() => core.listServers()).thenAnswer((_) async => <ServerConfig>[]);
  });

  Future<void> pumpFormAt(WidgetTester tester, String location) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'settings.onboarding_completed': true});
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
        path: '/apps/new',
        builder: (_, state) => AppFormScreen(
          mode: AppFormMode.create,
          initialType: switch (state.uri.queryParameters['type']) {
            'bundle' => AppType.bundle,
            'server' => AppType.server,
            _ => null,
          },
          initialUrl: state.uri.queryParameters['url'],
        ),
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
    router.push(location);
    await tester.pumpAndSettle();
  }

  String urlField(WidgetTester tester) => tester
      .widget<TextFormField>(find.widgetWithText(TextFormField, 'URL *'))
      .controller!
      .text;

  TransportType transport(WidgetTester tester) => tester
      .widget<DropdownButtonFormField<TransportType>>(
          find.byType(DropdownButtonFormField<TransportType>))
      .initialValue!;

  testWidgets('a server address fills the server form on Streamable HTTP',
      (tester) async {
    await pumpFormAt(tester,
        '/apps/new?type=server&url=${Uri.encodeQueryComponent('https://e.example/mcp?a=1')}');
    expect(urlField(tester), 'https://e.example/mcp?a=1');
    expect(transport(tester), TransportType.streamableHttp);
    // Nothing is saved by arriving.
    expect(registry.value, isEmpty);
  });

  testWidgets('an address ending in /sse picks SSE', (tester) async {
    await pumpFormAt(tester,
        '/apps/new?type=server&url=${Uri.encodeQueryComponent('http://10.0.0.5:3001/sse')}');
    expect(urlField(tester), 'http://10.0.0.5:3001/sse');
    expect(transport(tester), TransportType.sse);
  });

  testWidgets('a bundle address opens the bundle form on its URL',
      (tester) async {
    await pumpFormAt(tester,
        '/apps/new?type=bundle&url=${Uri.encodeQueryComponent('https://e.example/a.mcpb')}');
    expect(find.text('https://e.example/a.mcpb'), findsOneWidget);
    expect(registry.value, isEmpty);
  });

  testWidgets('opened with no address it is the empty form as before',
      (tester) async {
    await pumpFormAt(tester, '/apps/new');
    expect(find.text('Server'), findsWidgets);
    expect(registry.value, isEmpty);
  });
}
