import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../ui/app/app_renderer_screen.dart';
import '../ui/app_form/app_form_screen.dart';
import '../ui/dashboard/dashboard_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/logs/log_screen.dart';
import '../ui/onboarding/onboarding_screen.dart';
import '../ui/settings/settings_screen.dart';

/// MOD-SHELL-002 — declarative GoRouter config.
class AppRouter {
  const AppRouter._();

  static GoRouter build({required bool onboardingCompleted}) {
    return GoRouter(
      initialLocation: onboardingCompleted ? '/' : '/onboarding',
      redirect: (BuildContext ctx, GoRouterState state) {
        final location = state.uri.path;
        if (!onboardingCompleted && location != '/onboarding') {
          return '/onboarding';
        }
        if (onboardingCompleted && location == '/onboarding') {
          return '/';
        }
        return null;
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/apps/new',
          builder: (_, __) => const AppFormScreen(mode: AppFormMode.create),
        ),
        GoRoute(
          path: '/apps/:id/edit',
          builder: (_, state) => AppFormScreen(
            mode: AppFormMode.edit,
            appId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: '/app/:id',
          builder: (_, state) => AppRendererScreen(
            serverId: state.pathParameters['id']!,
            preloadedSession: state.extra is AppSession
                ? state.extra! as AppSession
                : null,
          ),
        ),
        GoRoute(
          path: '/dashboard/:id',
          builder: (_, state) =>
              DashboardScreen(dashboardId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/logs',
          builder: (_, __) => const LogScreen(),
        ),
        GoRoute(
          path: '/apps/:id/logs',
          builder: (_, state) => LogScreen(
            scopeKey: 'serverId',
            scopeValue: state.pathParameters['id'],
            title: state.pathParameters['id'],
          ),
        ),
      ],
      errorBuilder: (_, state) => const HomeScreen(),
    );
  }

  /// Translate `openApp://...` deep link URIs into app routes.
  static String? translateDeepLink(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.toLowerCase() != 'openapp') return null;
    if (uri.host == 'server') {
      final id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
      if (id == null || id.isEmpty) return null;
      return '/app/$id';
    }
    if (uri.host == 'bundle') {
      return '/apps/new';
    }
    return null;
  }
}
