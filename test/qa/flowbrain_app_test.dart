// The FlowBrain app — the bundle a FlowBrain server serves — drawn and driven
// by this app's UI runtime, against a server that answers like the real one:
// the shell at two widths, each screen, the line written down, a candidate
// confirmed, a conversation held.
//
// The definition is read from the server's own source, so what is drawn here
// is what the server serves.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Map<String, dynamic> _app() {
  var dir = Directory.current;
  for (var i = 0; i < 12; i++) {
    final f = File(p.join(dir.path, 'os', 'flowbrain', 'flowbrain_server',
        'dart', 'lib', 'src', 'app', 'default_app', 'ui', 'app.json'));
    if (f.existsSync()) {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }
    dir = dir.parent;
  }
  throw StateError('the app was not found from ${Directory.current.path}');
}

/// A server that answers the way the real one does, and remembers the calls.
class _Server {
  final calls = <String>[];
  final args = <String, List<Map<String, dynamic>>>{};
  final candidates = <Map<String, dynamic>>[
    {
      'id': 'c1',
      'type': 'decision',
      'confidence': 0.8,
      'evidenceIds': ['e1'],
      'fields': {'text': 'Use the east supplier'},
    },
  ];
  final turns = <Map<String, dynamic>>[];
  bool modelFails = false;

  /// Tools that refuse the way the real server does for a caller who may not.
  final refused = <String>{};

  void register(MCPUIRuntime runtime) {
    void on(String tool, Future<dynamic> Function(Map<String, dynamic>) f) {
      runtime.registerToolExecutor(tool, (params) async {
        calls.add(tool);
        if (refused.contains(tool)) {
          throw StateError('not available to this caller');
        }
        final a = Map<String, dynamic>.from((params as Map?) ?? const {});
        args.putIfAbsent(tool, () => []).add(a);
        return f(a);
      });
    }

    on('org.workspace.mine', (a) async => {
          'ok': true,
          'workspaces': [
            {'id': 'acme', 'title': 'Acme', 'value': 'acme', 'label': 'Acme'},
            {'id': 'sales', 'title': 'Sales', 'value': 'sales', 'label': 'Sales'},
          ],
        });
    on('bk.knowledge.compose', (a) async => {
          'ok': true,
          'tokens': 600,
          'budgetTokens': 1500,
          'omitted': ['kb://fact/x', 'kb://fact/y'],
          'items': [
            {'layer': 'fixed', 'text': 'You are the quoting agent'},
            {'layer': 'state', 'kind': 'task', 'text': 'Finish the Q3 quote'},
            {'layer': 'state', 'kind': 'question', 'text': 'Is freight included?'},
            {'layer': 'facts', 'kind': 'fact', 'text': 'East supplier is cheaper'},
          ],
        });
    on('bk.knowledge.pending', (a) async => {'ok': true, 'candidates': List.of(candidates)});
    on('bk.proposal.list', (a) async => {
          'ok': true,
          'proposals': [
            {
              'id': 'p1',
              'ethosId': 'e',
              'type': 'reinforce',
              'description': 'Value honesty more',
              'rationale': 'Two reviews flagged it',
              'confidence': 0.7,
              'status': 'open',
            },
          ],
        });
    on('bk.knowledge.trace', (a) async => {
          'ok': true,
          'count': 1,
          'records': [
            {
              'evidenceId': 'ev1',
              'kind': 'action',
              'who': {'kind': 'person', 'id': 'u-kim'},
              'at': '2026-11-01T10:20:00Z',
              'factIds': ['f1', 'f2'],
              'lens': {},
            },
          ],
        });
    on('chat.history', (a) async => {'ok': true, 'turns': List.of(turns)});
    on('chat.send', (a) async {
      if (modelFails) return {'ok': false, 'error': 'model unavailable'};
      turns
        ..add({'role': 'user', 'text': a['text'], 'at': '2026-11-01T10:00:00Z'})
        ..add({'role': 'assistant', 'text': 'done', 'at': '2026-11-01T10:00:01Z'});
      return {'ok': true, 'reply': 'done', 'toolResults': 1, 'toolsUsed': ['bk.knowledge.query']};
    });
    on('chat.clear', (a) async {
      turns.clear();
      return {'ok': true};
    });
    on('bk.knowledge.absorb', (a) async => {
          'ok': true,
          'evidenceId': 'e2',
          'candidateIds': ['c2'],
          'factIds': [],
          'pendingCandidateIds': ['c2'],
        });
    on('bk.knowledge.confirm', (a) async {
      candidates.removeWhere((c) => c['id'] == a['candidateId']);
      return {'ok': true};
    });
    on('bk.agent.list', (a) async => {
          'ok': true,
          'agents': [
            {
              'id': 'bot',
              'workspaceId': 'acme',
              'displayName': 'Quote bot',
              'role': 'worker',
              'model': {'provider': 'anthropic', 'model': 'm'},
            },
          ],
        });
    on('org.workspace.list', (a) async => {
          'ok': true,
          'workspaces': [
            {'id': 'acme', 'title': 'Acme', 'kind': 'organisation'},
            {'id': 'sales', 'title': 'Sales', 'kind': 'unit', 'parentId': 'acme', 'leadMemberId': 'u-kim'},
          ],
        });
    on('org.member.list', (a) async => {
          'ok': true,
          'members': [
            {'id': 'u-kim', 'kind': 'person', 'displayName': 'Kim', 'units': ['sales']},
          ],
        });
    on('bk.knowledge.export', (a) async => {
          'ok': true,
          'statements': 1,
          'bundle': {
            'facts': {
              'facts': [
                {
                  'id': 'f1',
                  'subject': 'acme',
                  'predicate': 'decision',
                  'object': 'Use the east supplier',
                  'metadata': {'actor': 'u-kim', 'recordedAt': '2026-11-01T09:00:00Z'},
                },
              ],
            },
          },
        });
    on('system.status', (a) async => {
          'workspaceId': 'acme',
          'dataFolder': '/data',
          'layers': {'factGraph': true, 'skill': true, 'profile': true, 'philosophy': true, 'ops': true},
        });
    on('system.config.read', (a) async => {'provider': 'anthropic', 'model': 'claude'});
    on('system.bundle.list', (a) async => {
          'ok': true,
          'bundles': [
            {'name': 'flowbrain', 'active': true},
          ],
        });
  }
}

/// The app has timers and indicators running, so it never "settles": time is
/// let to pass instead, enough for the answers to come back and show.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _errorMarkers = <String>[
  'Unknown widget type:',
  'Error rendering',
  'Widget type is required',
];

Future<_Server> _open(WidgetTester tester, double width,
    {bool modelFails = false, Set<String> refused = const {}}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server()
    ..modelFails = modelFails
    ..refused.addAll(refused);
  final runtime = MCPUIRuntime();
  await runtime.initialize(
    _app(),
    useCache: false,
    // The app keeps its pages inline in `routes`; a host that is asked for a
    // page by address finds none, and says so.
    pageLoader: (uri) async =>
        throw StateError('the app asked for $uri, but its pages are inline'),
  );
  server.register(runtime);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
  await settle(tester);
  return server;
}

/// What is on the screen, for the reason a failed expectation gives.
String shown(WidgetTester tester) => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .join(' | ');

void _noErrorWidgets(WidgetTester tester) {
  for (final m in _errorMarkers) {
    expect(find.textContaining(m), findsNothing, reason: m);
  }
}

void main() {
  testWidgets('wide: a rail with six places, today shows the work and what '
      'waits', (tester) async {
    final s = await _open(tester, 1200);
    _noErrorWidgets(tester);

    expect(find.byType(BottomNavigationBar), findsNothing,
        reason: 'wide has the rail, not the bottom bar');
    expect(find.text('Today'), findsWidgets, reason: shown(tester));
    expect(find.text('System'), findsWidgets, reason: 'a rail has all six');

    // What the server answered is on the screen.
    expect(find.text('Finish the Q3 quote'), findsOneWidget);
    expect(find.text('Is freight included?'), findsOneWidget);
    expect(find.textContaining('600 / 1500'), findsOneWidget);
    expect(find.textContaining('Candidates 1'), findsWidgets);
    expect(find.textContaining('Proposals 1'), findsWidgets);
    expect(s.calls, containsAll(<String>[
      'bk.knowledge.compose',
      'bk.knowledge.pending',
      'bk.proposal.list',
      'bk.knowledge.trace',
    ]));
  });

  testWidgets('compact: the same app with a bar of five at the bottom',
      (tester) async {
    await _open(tester, 420);
    _noErrorWidgets(tester);
    expect(find.text('System'), findsNothing,
        reason: 'five places on a phone; system is the gear in the header');
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Finish the Q3 quote'), findsOneWidget,
        reason: shown(tester));
  });

  testWidgets('a line written down is taken in, and what needs a person is '
      'told', (tester) async {
    final s = await _open(tester, 1200);
    await tester.enterText(find.byType(TextField).first, 'Freight is included');
    await tester.pump();
    await tester.tap(find.text('Send').first);
    await settle(tester);

    expect(s.args['bk.knowledge.absorb']!.single['text'], 'Freight is included');
    expect(s.args['bk.knowledge.absorb']!.single['origin'], 'human');
    expect(find.textContaining('Taken in'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty);
  });

  testWidgets('the knowledge place shows the facts and lets a person confirm '
      'a candidate', (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Knowledge').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.text('Use the east supplier'), findsWidgets);
    expect(s.calls, contains('bk.knowledge.export'));

    await tester.tap(find.text('To confirm').first);
    await settle(tester);
    expect(find.text('Use the east supplier'), findsWidgets);
    await tester.tap(find.text('Confirm').first);
    await settle(tester);
    expect(s.args['bk.knowledge.confirm']!.single['candidateId'], 'c1');
    expect(s.candidates, isEmpty);
  });

  testWidgets('people: the agent list and the organisation', (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('People').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.text('Quote bot'), findsOneWidget);
    expect(find.text('Sales'), findsWidgets);
    expect(find.text('Kim'), findsWidgets);
    expect(s.calls, containsAll(<String>['bk.agent.list', 'org.workspace.list']));
  });

  testWidgets('the conversation: sent, answered, shown with the tools used',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.byType(IconButton).last);
    await settle(tester);
    expect(find.text('Conversation'), findsWidgets);

    final input = find.byType(TextField).last;
    await tester.enterText(input, 'where is the quote?');
    await tester.pump();
    await tester.tap(find.text('Send').last);
    await settle(tester);
    expect(s.args['chat.send']!.single['text'], 'where is the quote?');
    expect(find.text('where is the quote?'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('a conversation the model fails keeps what was typed and says '
      'why', (tester) async {
    await _open(tester, 1200, modelFails: true);
    await tester.tap(find.byType(IconButton).last);
    await settle(tester);
    final input = find.byType(TextField).last;
    await tester.enterText(input, 'hello');
    await tester.pump();
    await tester.tap(find.text('Send').last);
    await settle(tester);
    expect(find.textContaining('model unavailable'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller?.text, 'hello');
  });

  testWidgets('the system place shows the model, the layers and the bundles',
      (tester) async {
    await _open(tester, 1200);
    await tester.tap(find.text('System').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.textContaining('anthropic'), findsWidgets);
    expect(find.text('flowbrain'), findsOneWidget);
  });

  testWidgets('the app asks again when something changes, not forever',
      (tester) async {
    final s = await _open(tester, 1200);
    final first = s.calls.where((c) => c == 'bk.knowledge.compose').length;
    expect(first, inInclusiveRange(1, 3),
        reason: 'once on start (and what the start itself changed)');
    await settle(tester);
    await settle(tester);
    expect(s.calls.where((c) => c == 'bk.knowledge.compose').length, first,
        reason: 'nothing changed, nothing was asked again');
  });

  testWidgets('a tool that fails shows why, in its own place, and the rest '
      'of the screen still works', (tester) async {
    final s = await _open(tester, 1200, refused: {'bk.knowledge.pending'});
    _noErrorWidgets(tester);
    expect(find.text('Finish the Q3 quote'), findsOneWidget,
        reason: 'the work is not taken down by a failing neighbour');
    await tester.tap(find.text('Knowledge').first);
    await settle(tester);
    await tester.tap(find.text('To confirm').first);
    await settle(tester);
    expect(find.textContaining('not available to this caller'), findsWidgets,
        reason: shown(tester));
    expect(s.calls, contains('bk.knowledge.pending'));
  });

  testWidgets('what only an administrator may see says so', (tester) async {
    await _open(tester, 1200,
        refused: {'org.workspace.list', 'org.member.list'});
    await tester.tap(find.text('People').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.text('This tool is for administrators only.'), findsOneWidget,
        reason: shown(tester));
    expect(find.text('Quote bot'), findsOneWidget,
        reason: 'the agents are still there');
  });
}
