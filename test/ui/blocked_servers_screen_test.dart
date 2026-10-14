// FR-SET-008 — the blocked servers list and unblocking.
import 'package:appplayer/adapters/blocked_servers.dart';
import 'package:appplayer/ui/settings/blocked_servers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(const MaterialApp(home: BlockedServersScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty list says so', (tester) async {
    await pumpScreen(tester, <String, Object>{});
    expect(find.byKey(const Key('blocked.empty')), findsOneWidget);
  });

  testWidgets('each blocked server shows its name and address', (tester) async {
    await pumpScreen(tester, <String, Object>{
      BlockedServers.storageKey:
          '[{"address":"https://a.example/sse","name":"Alpha"},'
              '{"address":"https://b.example/sse","name":""}]',
    });
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('https://a.example/sse'), findsOneWidget);
    // Without a name the address is the title.
    expect(find.text('https://b.example/sse'), findsOneWidget);
  });

  testWidgets('unblocking removes the entry and frees the address',
      (tester) async {
    await pumpScreen(tester, <String, Object>{
      BlockedServers.storageKey:
          '[{"address":"https://a.example/sse","name":"Alpha"}]',
    });
    await tester.tap(
        find.byKey(const Key('blocked.unblock.https://a.example/sse')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('blocked.empty')), findsOneWidget);
    expect((await BlockedServers.open()).isBlocked('https://a.example/sse'),
        isFalse);
  });
}
