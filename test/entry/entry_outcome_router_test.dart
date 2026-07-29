/// One outcome switch for every acquisition source (platform spec 19 §9.2).
library;

import 'package:appplayer/entry/entry_controller.dart';
import 'package:appplayer/entry/entry_outcome_router.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

EntryOpen _open() => EntryOpen(
      target: EntryTargetRef(
        kind: EntryTargetKind.server,
        ref: 'https://fleet.example.test/mcp',
      ),
      entry: EntryContext(issuer: const EntryIssuer(name: 'Fleet Co')),
      identityRequired: false,
    );

EntryBlocked _blocked() => const EntryBlocked(
      target: EntryTarget(
        status: EntryStatus.revoked,
        issuer: EntryIssuer(name: 'Fleet Co'),
      ),
      rejection: EntryRejection.notOk,
    );

Future<GoRouter> _router(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, __) => const Text('home')),
      GoRoute(
        path: EntryRoutes.open,
        builder: (_, state) => Text('open:${(state.extra! as EntryOpen).target.ref}'),
      ),
      GoRoute(
        path: EntryRoutes.blocked,
        builder: (_, state) =>
            Text('gate:${(state.extra! as EntryBlocked).rejection.name}'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('an open outcome pushes the open screen', (tester) async {
    final router = await _router(tester);
    expect(routeEntryOutcome(router, _open()), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('open:https://fleet.example.test/mcp'), findsOneWidget);
  });

  testWidgets('a blocked outcome pushes the gate', (tester) async {
    final router = await _router(tester);
    expect(routeEntryOutcome(router, _blocked()), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('gate:notOk'), findsOneWidget);
  });

  testWidgets('a link that is not ours shows nothing', (tester) async {
    final router = await _router(tester);
    final shown = routeEntryOutcome(
      router,
      const EntryNotForUs(EntryLinkRejection.unclaimedHost),
    );
    await tester.pumpAndSettle();
    expect(shown, isFalse);
    // Still home: an unclaimed link is not the viewer's problem.
    expect(find.text('home'), findsOneWidget);
  });
}
