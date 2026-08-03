// A scoped log view still shows the diagnostics that have no scope.
//
// The per-app log screen filters on `context['serverId']`. Entries carrying no
// value for that key were dropped, and the runtime's diagnostics carry none —
// they come from a static logger that does not know which session spoke. The
// global view would have shown them, except the app has no way to reach it.
// So they were visible nowhere: konpi opened this screen looking for a runtime
// warning, saw `runtime` listed in the source filter, and zero entries under
// it.
//
// An entry with no scope is not an entry belonging to another scope.

import 'package:appplayer/ui/logs/log_screen.dart';
import 'package:appplayer_core/appplayer_core.dart'
    show LogBuffer, LogEntry, LogSource, McpLogLevel;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _pump(
  WidgetTester tester,
  LogBuffer buffer, {
  String? scopeKey,
  String? scopeValue,
}) async {
  await tester.pumpWidget(
    ListenableProvider<LogBuffer>.value(
      value: buffer,
      child: MaterialApp(
        home: LogScreen(scopeKey: scopeKey, scopeValue: scopeValue),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late LogBuffer buffer;

  setUp(() {
    buffer = LogBuffer()
      ..add(LogEntry(
        source: LogSource.core,
        level: McpLogLevel.info,
        message: 'MINE',
        context: const <String, Object?>{'serverId': 's1'},
      ))
      ..add(LogEntry(
        source: LogSource.core,
        level: McpLogLevel.info,
        message: 'SOMEONE-ELSE',
        context: const <String, Object?>{'serverId': 's2'},
      ))
      ..add(LogEntry.fromRuntime(
        level: 'WARN',
        logger: 'ThemeManager',
        message: 'UNSCOPED-RUNTIME-WARNING',
      ));
  });

  testWidgets('a scoped view keeps its own scope and drops other scopes',
      (tester) async {
    await _pump(tester, buffer, scopeKey: 'serverId', scopeValue: 's1');
    expect(find.textContaining('MINE'), findsOneWidget);
    expect(find.textContaining('SOMEONE-ELSE'), findsNothing);
  });

  testWidgets('a scoped view still shows unscoped diagnostics',
      (tester) async {
    await _pump(tester, buffer, scopeKey: 'serverId', scopeValue: 's1');
    expect(
      find.textContaining('UNSCOPED-RUNTIME-WARNING'),
      findsOneWidget,
      reason: 'a runtime warning belongs to no server and must not be hidden '
          'by every per-server view',
    );
  });

  testWidgets('the unscoped view shows everything', (tester) async {
    await _pump(tester, buffer);
    expect(find.textContaining('MINE'), findsOneWidget);
    expect(find.textContaining('SOMEONE-ELSE'), findsOneWidget);
    expect(find.textContaining('UNSCOPED-RUNTIME-WARNING'), findsOneWidget);
  });
}
