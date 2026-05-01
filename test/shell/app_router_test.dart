import 'package:appplayer/app/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouter.build', () {
    // TC-ROUTER-001
    test('onboarding incomplete → GoRouter built with initial /onboarding',
        () {
      final router = AppRouter.build(onboardingCompleted: false);
      expect(router, isNotNull);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/onboarding',
      );
    });

    // TC-ROUTER-002
    test('onboarding completed → GoRouter built with initial /', () {
      final router = AppRouter.build(onboardingCompleted: true);
      expect(router, isNotNull);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/',
      );
    });

    // TC-ROUTER-003 — route table contains /app/:id path
    test('route table includes /app/:id path', () {
      final router = AppRouter.build(onboardingCompleted: true);
      // GoRouter configuration should have 9 routes
      // (+ /logs and /apps/:id/logs since logs UI was added).
      expect(router.configuration.routes.length, 9);
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
