import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCore extends Mock implements AppPlayerCoreService {}

/// Wires the default `lifecycleListenable` / `isServerConnected` /
/// `isBundleLoaded` stubs so home-screen widget tests don't need to
/// repeat the boilerplate. Tests that care about specific connection
/// states can call `when(...).thenReturn(true)` after this.
void stubCoreLifecycle(MockCore core) {
  when(() => core.lifecycleListenable).thenReturn(ChangeNotifier());
  when(() => core.isServerConnected(any())).thenReturn(false);
  when(() => core.isBundleLoaded(any())).thenReturn(false);
}

Future<AppSettings> makeSettings({
  bool onboardingCompleted = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'settings.onboarding_completed': onboardingCompleted,
  });
  final prefs = await SharedPreferences.getInstance();
  return AppSettings.load(prefs);
}

Widget wrapScreen({
  required Widget child,
  required AppPlayerCoreService core,
  required AppSettings settings,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<AppPlayerCoreService>.value(value: core),
      ChangeNotifierProvider<AppSettings>.value(value: settings),
    ],
    child: MaterialApp(home: child),
  );
}

Widget wrapScreenWithGoRouter({
  required Widget child,
  required AppPlayerCoreService core,
  required AppSettings settings,
  List<SingleChildWidget> extraProviders = const [],
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<AppPlayerCoreService>.value(value: core),
      ChangeNotifierProvider<AppSettings>.value(value: settings),
      ...extraProviders,
    ],
    child: MaterialApp(home: child),
  );
}

Future<void> pumpAndSettle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}
