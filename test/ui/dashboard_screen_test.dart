import 'package:appplayer/app/app_settings.dart';
import 'package:appplayer/models/app_config.dart';
import 'package:appplayer/ui/dashboard/dashboard_screen.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

class MockAppSession extends Mock implements AppSession {}

class MockDashboardSession extends Mock implements DashboardSession {}

class _FakeBuildContext extends Fake implements BuildContext {}

Future<AppSettings> _setupPrefs({required List<AppConfig> apps}) async {
  final values = <String, Object>{
    'settings.onboarding_completed': true,
    'apps.v1': AppConfig.encodeList(apps),
  };
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return AppSettings.load(prefs);
}

Future<void> pumpDashboard(
  WidgetTester tester, {
  required String dashboardId,
  required MockCore core,
  required AppSettings settings,
}) async {
  // DashboardScreen resolves `GoRouter.of(context)` in _buildGrid /
  // _buildCardList (spec §4.3.1 openApp routes to '/app/:id'). A plain
  // MaterialApp would fail with "No GoRouter found in context", so the
  // tests mount the screen under a minimal GoRouter with stub routes.
  final router = GoRouter(
    initialLocation: '/dash',
    routes: <RouteBase>[
      GoRoute(
        path: '/dash',
        builder: (_, __) => DashboardScreen(dashboardId: dashboardId),
      ),
      GoRoute(
        path: '/app/:id',
        builder: (_, __) => const SizedBox.shrink(),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppPlayerCoreService>.value(value: core),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  late MockCore core;

  setUpAll(() {
    registerFallbackValue(
      const DashboardBundleRef(bundleId: '', source: BundleSource.synthesized),
    );
    registerFallbackValue(_FakeBuildContext());
  });

  setUp(() {
    core = MockCore();
  });

  group('TC-DASH-001 grid view slot rendering', () {
    testWidgets(
      'dashboard.slot.{id} Keys appear for each connection in grid layout',
      (tester) async {
        const dashboardId = 'dash-grid';
        final apps = <AppConfig>[
          AppConfig(
            id: dashboardId,
            name: 'Grid Dashboard',
            type: AppType.dashboard,
            dashboardConnectionIds: <String>['srv-1', 'srv-2', 'srv-3'],
            dashboardLayout: DashboardLayout.grid,
            dashboardSize: DashboardSize.twoByTwo,
          ),
        ];
        final settings = await _setupPrefs(apps: apps);

        final dashSession = MockDashboardSession();
        when(() => core.openDashboard(any(), any()))
            .thenAnswer((_) async => dashSession);

        for (final id in <String>['srv-1', 'srv-2', 'srv-3']) {
          final session = MockAppSession();
          when(() => session.buildDashboardWidget(
                context: any(named: 'context'),
                onExit: any(named: 'onExit'),
                onOpenApp: any(named: 'onOpenApp'),
              )).thenReturn(Text('slot-$id'));
          when(() => core.openAppFromServer(id))
              .thenAnswer((_) async => session);
        }

        await pumpDashboard(
          tester,
          dashboardId: dashboardId,
          core: core,
          settings: settings,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('dashboard.slot.srv-1')), findsOneWidget);
        expect(find.byKey(const Key('dashboard.slot.srv-2')), findsOneWidget);
        expect(find.byKey(const Key('dashboard.slot.srv-3')), findsOneWidget);

        expect(find.byType(GridView), findsOneWidget);
      },
    );
  });

  group('TC-DASH-002 card view slot rendering', () {
    testWidgets(
      'slot widgets visible in card layout',
      (tester) async {
        const dashboardId = 'dash-card';
        final apps = <AppConfig>[
          AppConfig(
            id: dashboardId,
            name: 'Card Dashboard',
            type: AppType.dashboard,
            dashboardConnectionIds: <String>['srv-a', 'srv-b'],
            dashboardLayout: DashboardLayout.card,
            dashboardSize: DashboardSize.twoByTwo,
          ),
        ];
        final settings = await _setupPrefs(apps: apps);

        final dashSession = MockDashboardSession();
        when(() => core.openDashboard(any(), any()))
            .thenAnswer((_) async => dashSession);

        for (final id in <String>['srv-a', 'srv-b']) {
          final session = MockAppSession();
          // Spec §11.9 — dashboard slots call buildDashboardWidget, not
          // buildWidget. Returning non-null means "this app provides a
          // dashboard view"; `null` would trigger the icon fallback.
          when(() => session.buildDashboardWidget(
                context: any(named: 'context'),
                onExit: any(named: 'onExit'),
                onOpenApp: any(named: 'onOpenApp'),
              )).thenReturn(Text('card-$id'));
          when(() => core.openAppFromServer(id))
              .thenAnswer((_) async => session);
        }

        await pumpDashboard(
          tester,
          dashboardId: dashboardId,
          core: core,
          settings: settings,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('dashboard.slot.srv-a')), findsOneWidget);
        expect(find.byKey(const Key('dashboard.slot.srv-b')), findsOneWidget);

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(GridView), findsNothing);

        expect(find.text('card-srv-a'), findsOneWidget);
        expect(find.text('card-srv-b'), findsOneWidget);
      },
    );
  });

  // TC-DASH-003 (slot tap navigates) / TC-DASH-004 (exit pops) left
  // unwritten — covered indirectly by router + AppRendererScreen tests.
  group('TC-DASH-005 slot connection failure shows per-slot error', () {
    testWidgets(
      'failing slot shows error while other slots still render',
      (tester) async {
        const dashboardId = 'dash-partial';
        final apps = <AppConfig>[
          AppConfig(
            id: dashboardId,
            name: 'Partial Dashboard',
            type: AppType.dashboard,
            dashboardConnectionIds: <String>['srv-ok', 'srv-fail'],
            dashboardLayout: DashboardLayout.grid,
            dashboardSize: DashboardSize.twoByTwo,
          ),
        ];
        final settings = await _setupPrefs(apps: apps);

        final dashSession = MockDashboardSession();
        when(() => core.openDashboard(any(), any()))
            .thenAnswer((_) async => dashSession);

        final okSession = MockAppSession();
        when(() => okSession.buildDashboardWidget(
              context: any(named: 'context'),
              onExit: any(named: 'onExit'),
              onOpenApp: any(named: 'onOpenApp'),
            )).thenReturn(const Text('ok-content'));
        when(() => core.openAppFromServer('srv-ok'))
            .thenAnswer((_) async => okSession);

        when(() => core.openAppFromServer('srv-fail')).thenThrow(
          ConnectionFailedException('srv-fail', 'host unreachable'),
        );

        await pumpDashboard(
          tester,
          dashboardId: dashboardId,
          core: core,
          settings: settings,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('dashboard.slot.srv-ok')), findsOneWidget);
        expect(
            find.byKey(const Key('dashboard.slot.srv-fail')), findsOneWidget);

        expect(find.text('ok-content'), findsOneWidget);

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      },
    );
  });

  // TC-DASH-006 (config-not-found) left unwritten — covered by
  // router/config lookup tests upstream.
}
