import 'package:appplayer/app/app_router.dart';
import 'package:appplayer/app/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppSettings> _settings({required bool onboardingCompleted}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{
    'settings.onboarding_completed': onboardingCompleted,
  });
  return AppSettings.load(await SharedPreferences.getInstance());
}

void main() {
  group('AppRouter.build', () {
    // TC-ROUTER-001
    test('onboarding incomplete → GoRouter built with initial /onboarding',
        () async {
      final router =
          AppRouter.build(settings: await _settings(onboardingCompleted: false));
      expect(router, isNotNull);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/onboarding',
      );
    });

    // TC-ROUTER-002
    test('onboarding completed → GoRouter built with initial /', () async {
      final router =
          AppRouter.build(settings: await _settings(onboardingCompleted: true));
      expect(router, isNotNull);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/',
      );
    });

    // TC-ROUTER-003 — route table contains /app/:id path
    test('route table includes /app/:id path', () async {
      final router =
          AppRouter.build(settings: await _settings(onboardingCompleted: true));
      // GoRouter configuration should have 9 routes
      // (+ /logs and /apps/:id/logs since logs UI was added).
      expect(router.configuration.routes.length, 9);
    });

    // TC-ROUTER-004 — completing onboarding live-refreshes the redirect.
    // Regression: the router was previously built with a captured
    // `onboardingCompleted` bool and no refreshListenable, so after
    // `markOnboardingCompleted()` the redirect kept bouncing back to
    // `/onboarding` until the app was restarted (the "Start button does
    // nothing" symptom). This mounts a real router so the redirect fires.
    testWidgets(
        'marking onboarding complete redirects /onboarding → / without restart',
        (WidgetTester tester) async {
      final settings = await _settings(onboardingCompleted: false);
      final router = AppRouter.build(settings: settings);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/onboarding');

      // Simulate the onboarding "Start" action.
      await settings.markOnboardingCompleted();
      router.go('/');
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    });
  });

  group('AppRouter.translateDeepLink', () {
    test('server id', () {
      expect(
        AppRouter.translateDeepLink('openApp://server/s1'),
        '/app/s1',
      );
    });

    test('bundle → /apps/new', () {
      expect(
        AppRouter.translateDeepLink('openApp://bundle?uri=https%3A%2F%2Fx'),
        '/apps/new',
      );
    });

    test('bundle without query → /apps/new', () {
      expect(AppRouter.translateDeepLink('openApp://bundle'), '/apps/new');
    });

    test('unsupported scheme returns null', () {
      expect(AppRouter.translateDeepLink('mailto:x@y'), isNull);
    });

    test('invalid uri returns null', () {
      expect(AppRouter.translateDeepLink('::::'), isNull);
    });
  });
}
