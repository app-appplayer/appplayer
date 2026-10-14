// FR-HOME-012 report · FR-HOME-013 block · FR-FORM-009 age rating on the home.
import 'package:appplayer/adapters/blocked_servers.dart';
import 'package:appplayer/adapters/prefs_apps_registry.dart';
import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/models/apps_list_notifier.dart';
import 'package:appplayer/ui/home/home_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  late MockCore core;
  late PrefsAppsRegistry<AppConfig> registry;
  late AppSettings settings;

  Future<void> pumpHome(WidgetTester tester, List<AppConfig> apps) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.onboarding_completed': true,
      'apps.v1': AppConfig.encodeList(apps),
    });
    final prefs = await SharedPreferences.getInstance();
    settings = await AppSettings.load(prefs);
    registry = PrefsAppsRegistry<AppConfig>(
      prefs: prefs,
      storageKey: 'apps.v1',
      decode: AppConfig.decodeList,
      encode: AppConfig.encodeList,
      idOf: (a) => a.id,
      onChanged: AppsListNotifier.markDirty,
    );
    await tester.pumpWidget(wrapScreenWithGoRouter(
      child: const HomeScreen(),
      core: core,
      settings: settings,
      extraProviders: [
        ListenableProvider<AppsRegistry<AppConfig>>.value(value: registry),
      ],
    ));
    await tester.pumpAndSettle();
  }

  ServerConfig sse(String id, String url) => ServerConfig(
        id: id,
        name: id,
        description: '',
        transportType: TransportType.sse,
        transportConfig: <String, dynamic>{'serverUrl': url},
      );

  AppConfig serverApp(String id, {AgeRating rating = AgeRating.unrated}) =>
      AppConfig(
        id: id,
        name: 'Server $id',
        type: AppType.server,
        serverConfigId: id,
        ageRating: rating,
      );

  setUpAll(() {
    registerFallbackValue(const AppHandle.server('fallback'));
  });

  setUp(() {
    core = MockCore();
    stubCoreLifecycle(core);
    when(() => core.closeApp(any())).thenAnswer((_) async {});
    when(() => core.deleteServer(any())).thenAnswer((_) async {});
  });

  group('age rating', () {
    test('is stored with the app; unrated writes no key', () {
      final rated = serverApp('a', rating: AgeRating.age12);
      expect(rated.toJson()['ageRating'], 'age12');
      expect(AppConfig.decodeList(AppConfig.encodeList([rated])).single.ageRating,
          AgeRating.age12);
      expect(serverApp('b').toJson().containsKey('ageRating'), isFalse);
    });

    test('an entry from before the field reads as unrated', () {
      final json = serverApp('a').toJson()..remove('ageRating');
      expect(AppConfig.fromJson(json).ageRating, AgeRating.unrated);
    });

    test('an unknown stored value reads as unrated', () {
      final json = serverApp('a').toJson()..['ageRating'] = 'age99';
      expect(AppConfig.fromJson(json).ageRating, AgeRating.unrated);
    });

    test('moving to a folder keeps it', () {
      final moved = serverApp('a', rating: AgeRating.age17).withFolder('Work');
      expect(moved.ageRating, AgeRating.age17);
    });

    testWidgets('a rated app shows its label under the name; unrated none',
        (tester) async {
      await pumpHome(tester, [
        serverApp('a', rating: AgeRating.age12),
        serverApp('b'),
      ]);
      expect(
        find.descendant(
            of: find.byKey(const Key('home.app.a')),
            matching: find.byKey(const Key('home.app.age'))),
        findsOneWidget,
      );
      expect(find.text('12+'), findsOneWidget);
      expect(
        find.descendant(
            of: find.byKey(const Key('home.app.b')),
            matching: find.byKey(const Key('home.app.age'))),
        findsNothing,
      );
    });
  });

  group('app menu', () {
    testWidgets('a network server offers report and block', (tester) async {
      when(() => core.getServer('a'))
          .thenAnswer((_) async => sse('a', 'https://a.example/sse'));
      await pumpHome(tester, [serverApp('a')]);
      await tester.longPress(find.byKey(const Key('home.app.a')));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
    });

    testWidgets('a local process and a bundle offer neither', (tester) async {
      when(() => core.getServer('p')).thenAnswer((_) async => ServerConfig(
            id: 'p',
            name: 'p',
            description: '',
            transportType: TransportType.stdio,
            transportConfig: const <String, dynamic>{'command': 'x'},
          ));
      await pumpHome(tester, [
        serverApp('p'),
        AppConfig(id: 'b', name: 'Bundle', type: AppType.bundle, bundleId: 'b'),
      ]);
      await tester.longPress(find.byKey(const Key('home.app.p')));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Block'), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('home.app.b')));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsNothing);
      expect(find.text('Block'), findsNothing);
    });

    testWidgets('report with no mail app says where to write', (tester) async {
      // The platform answers that nothing can open the mail address.
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          calls.add(call);
          return false;
        },
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'), null));
      when(() => core.getServer('a'))
          .thenAnswer((_) async => sse('a', 'https://a.example/sse'));
      await pumpHome(tester, [serverApp('a')]);
      await tester.longPress(find.byKey(const Key('home.app.a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      // Not settled: a snack bar is gone once the clock runs past it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('support@makemind.app'), findsOneWidget);
      final launched = calls.where((c) => c.method == 'launch').single;
      final url = (launched.arguments as Map)['url'] as String;
      expect(url, startsWith('mailto:support@makemind.app?'));
      expect(Uri.decodeComponent(url), contains('https://a.example/sse'));
      expect(Uri.decodeComponent(url), contains('Server a'));
    });

    testWidgets('block asks first, then removes the app and blocks its address',
        (tester) async {
      when(() => core.getServer('a'))
          .thenAnswer((_) async => sse('a', 'https://A.example/sse/'));
      await pumpHome(tester, [serverApp('a'), serverApp('b')]);
      await tester.longPress(find.byKey(const Key('home.app.a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('Block server'), findsOneWidget);

      // Cancel changes nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(registry.byId('a'), isNotNull);
      expect((await BlockedServers.open()).all, isEmpty);

      await tester.longPress(find.byKey(const Key('home.app.a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home.block.confirm')));
      await tester.pumpAndSettle();

      expect(registry.byId('a'), isNull);
      expect(registry.byId('b'), isNotNull);
      verify(() => core.deleteServer('a')).called(1);
      final blocked = await BlockedServers.open();
      expect(blocked.isBlocked('https://a.example/sse'), isTrue);
      expect(blocked.all.single.name, 'Server a');
    });
  });
}
