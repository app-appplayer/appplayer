// FR-HOME-011 — folders the person makes on the home.
import 'package:appplayer/adapters/prefs_apps_registry.dart';
import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/models/apps_list_notifier.dart';
import 'package:appplayer/ui/home/home_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  setUp(() {
    core = MockCore();
    stubCoreLifecycle(core);
  });

  AppConfig app(String id, {String? folder}) =>
      AppConfig(id: id, name: 'App $id', type: AppType.bundle, folder: folder);

  test('the folder is stored with the app and a blank one is none', () {
    final moved = app('a').withFolder('  Work ');
    expect(moved.folder, 'Work');
    expect(AppConfig.decodeList(AppConfig.encodeList([moved])).single.folder,
        'Work');
    expect(moved.withFolder(null).folder, isNull);
    expect(moved.withFolder('   ').folder, isNull);
    expect(moved.withFolder(null).toJson().containsKey('folder'), isFalse);
  });

  testWidgets('a folder shows as one tile and its apps leave the grid',
      (tester) async {
    await pumpHome(tester, [
      app('a', folder: 'Work'),
      app('b'),
      app('c', folder: 'Work'),
    ]);
    expect(find.byKey(const Key('home.folder.Work')), findsOneWidget);
    expect(find.byKey(const Key('home.app.b')), findsOneWidget);
    expect(find.byKey(const Key('home.app.a')), findsNothing);
    expect(find.byKey(const Key('home.app.c')), findsNothing);
  });

  testWidgets('opening a folder shows its apps; renaming moves them all',
      (tester) async {
    await pumpHome(tester, [app('a', folder: 'Work'), app('c', folder: 'Work')]);
    await tester.tap(find.byKey(const Key('home.folder.Work')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.app.a')), findsOneWidget);
    expect(find.byKey(const Key('home.app.c')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_folders.screen.rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('app_folders.rename.field')), 'Office');
    await tester.pump();
    await tester.tap(find.byKey(const Key('app_folders.rename.save')));
    await tester.pumpAndSettle();
    expect(registry.value.map((a) => a.folder), ['Office', 'Office']);
  });

  testWidgets('the app menu moves an app into a new folder and back out',
      (tester) async {
    await pumpHome(tester, [app('a'), app('b')]);
    await tester.longPress(find.byKey(const Key('home.app.a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('app_folders.move.new')), 'Games');
    await tester.pump();
    await tester.tap(find.byKey(const Key('app_folders.move.confirm')));
    await tester.pumpAndSettle();
    expect(registry.byId('a')!.folder, 'Games');
    expect(find.byKey(const Key('home.folder.Games')), findsOneWidget);
    expect(find.byKey(const Key('home.app.a')), findsNothing);

    // Out again from inside the folder; the emptied folder goes away.
    await tester.tap(find.byKey(const Key('home.folder.Games')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('home.app.a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app_folders.move.take_out')));
    await tester.pumpAndSettle();
    expect(registry.byId('a')!.folder, isNull);
    expect(find.byKey(const Key('home.folder.Games')), findsNothing);
    expect(find.byKey(const Key('home.app.a')), findsOneWidget);
  });
}
