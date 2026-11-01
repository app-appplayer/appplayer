// The FlowBrain server's chat screen, drawn and driven by this app's UI
// runtime: opened, typed into, sent, and the history shown again.
//
// The definition is read from the server's own source, so what is drawn here
// is what the server serves.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Map<String, dynamic> _serverChatScreen() {
  var dir = Directory.current;
  for (var i = 0; i < 12; i++) {
    final f = File(p.join(dir.path, 'os', 'flowbrain', 'flowbrain_server',
        'dart', 'lib', 'src', 'ui', 'builtin', 'builtin_views.dart'));
    if (f.existsSync()) {
      final src = f.readAsStringSync();
      final start = src.indexOf("const String _chat = r'''");
      final from = src.indexOf("'''", start) + 3;
      final to = src.indexOf("'''", from);
      return jsonDecode(src.substring(from, to)) as Map<String, dynamic>;
    }
    dir = dir.parent;
  }
  throw StateError('server source not found from ${Directory.current.path}');
}

void main() {
  testWidgets('the chat screen opens, sends what was typed and shows the '
      'history again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final turns = <Map<String, dynamic>>[];
    final calls = <String>[];
    Map<String, dynamic>? sent;

    final runtime = MCPUIRuntime();
    await runtime.initialize(_serverChatScreen(), useCache: false);
    runtime.registerToolExecutor('chat.history', (params) async {
      calls.add('chat.history');
      return <String, dynamic>{'ok': true, 'turns': List.of(turns)};
    });
    runtime.registerToolExecutor('chat.send', (params) async {
      calls.add('chat.send');
      sent = Map<String, dynamic>.from(params as Map);
      turns
        ..add({'role': 'user', 'text': sent!['text']})
        ..add({'role': 'assistant', 'text': 'done'});
      return <String, dynamic>{'ok': true, 'reply': 'done'};
    });

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pumpAndSettle();

    expect(find.text('Send'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(calls, contains('chat.history'), reason: 'opening loads history');

    await tester.enterText(find.byType(TextField), 'hello server');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull, reason: 'Send calls chat.send');
    expect(sent!['text'], 'hello server');
    expect(find.textContaining('user: hello server'), findsOneWidget);
    expect(find.textContaining('assistant: done'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
        reason: 'the input is emptied after sending');

    await runtime.dispose();
  });

  testWidgets('a send the server refuses keeps what was typed and says why',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final runtime = MCPUIRuntime();
    await runtime.initialize(_serverChatScreen(), useCache: false);
    runtime.registerToolExecutor('chat.history', (params) async =>
        <String, dynamic>{'ok': true, 'turns': <Object>[]});
    // The server answers a failure as a normal result with ok:false.
    runtime.registerToolExecutor('chat.send', (params) async =>
        <String, dynamic>{'ok': false, 'error': 'model unavailable'});

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'try again later');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.textContaining('model unavailable'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'try again later',
        reason: 'a failed send must not throw away the message');

    await runtime.dispose();
  });
}
