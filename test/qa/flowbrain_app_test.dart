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

  /// A server that knows nothing yet answers with no sections at all.
  bool empty = false;

  /// Tools that refuse the way the real server does for a caller who may not.
  final refused = <String>{};

  /// What the app subscribed to (address → the state it is bound to), and the
  /// runtime to put what the server says into — the way the player's
  /// subscriber does: the first read, and a read at every notice.
  final subs = <String, String>{};
  late MCPUIRuntime runtime;
  final _handlers = <String, Future<dynamic> Function(Map<String, dynamic>)>{};

  static final _read = RegExp(
      r'(\.|_)(list|get|read|pending|trace|export|history|compose|status|mine|'
      r'template_schema|list_templates|issue_list)$');

  /// The read tool a data address is the answer of, and its arguments (the
  /// server's data resources, platform spec 32 §4.4).
  (String, Map<String, dynamic>)? _route(String uri) {
    if (!uri.startsWith('fb://')) return null;
    final seg = uri.substring(5).split('/');
    Map<String, dynamic> ws(String w) => w == 'own' ? {} : {'workspaceId': w};
    String? at(String a) => a == 'now' ? null : a;
    switch (seg) {
      case ['me', 'workspaces']:
        return ('org.workspace.mine', {});
      case ['skills']:
        return ('bk.skill.list', {});
      case ['profiles']:
        return ('bk.profile.list', {});
      case ['philosophies']:
        return ('bk.philosophy.list', {});
      case ['proposals']:
        return ('bk.proposal.list', {});
      case ['agents']:
        return ('bk.agent.list', {});
      case ['processes']:
        return ('bk.behavior.list', {});
      case ['runs']:
        return ('work.run.list', {});
      case ['tasks']:
        return ('work.task.list', {});
      case ['org', 'workspaces']:
        return ('org.workspace.list', {});
      case ['org', 'members']:
        return ('org.member.list', {});
      case ['system', 'status']:
        return ('system.status', {});
      case ['system', 'llm']:
        return ('system.config.read', {'path': 'llm'});
      case ['system', 'bundles']:
        return ('system.bundle.list', {});
      case ['system', 'access']:
        return ('system.access.list', {});
      case ['system', 'events']:
        return ('system.events.snapshot', {'limit': 40});
      case ['system', 'cost']:
        return ('system.cost.totals', {});
      case ['chat', 'history']:
        return ('chat.history', {});
      case [final w, 'work', final a]:
        return ('bk.knowledge.compose', {
          'task': 'current state of the work',
          'budgetTokens': 1500,
          ...ws(w),
          if (at(a) != null) 'asOf': a,
        });
      case [final w, 'facts', final a]:
        return ('bk.knowledge.export', {...ws(w), if (at(a) != null) 'asOf': a});
      case [final w, 'pending']:
        return ('bk.knowledge.pending', ws(w));
      case [final w, 'trace']:
        return ('bk.knowledge.trace', ws(w));
      case [final w, 'trace', final who]:
        return ('bk.knowledge.trace', {...ws(w), 'actor': who});
      case [final w, 'templates']:
        return ('form.list_templates', ws(w));
      case [final w, 'issues']:
        return ('form_builder.issue_list', ws(w));
    }
    return null;
  }

  Future<dynamic> _answer(String uri) async {
    final route = _route(uri);
    if (route == null) throw StateError('no such resource: $uri');
    final (tool, a) = route;
    calls.add(tool);
    // A tool that refuses answers a read as the real server does: with the
    // refusal in the answer.
    if (refused.contains(tool)) {
      return {'ok': false, 'error': 'not available to this caller'};
    }
    return _handlers[tool]!(a);
  }

  Future<void> subscribe(String uri, String binding) async {
    subs[uri] = binding;
    runtime.stateManager.set(binding, await _answer(uri));
  }

  void unsubscribe(String uri) => subs.remove(uri);

  /// What the server does when something changed: every subscriber is told and
  /// reads again.
  Future<void> notifyAll() async {
    for (final e in Map<String, String>.of(subs).entries) {
      runtime.stateManager.set(e.value, await _answer(e.key));
    }
  }

  void register(MCPUIRuntime runtime) {
    this.runtime = runtime;
    void on(String tool, Future<dynamic> Function(Map<String, dynamic>) f) {
      _handlers[tool] = f;
      runtime.registerToolExecutor(tool, (params) async {
        calls.add(tool);
        if (refused.contains(tool)) {
          throw StateError('not available to this caller');
        }
        final a = Map<String, dynamic>.from((params as Map?) ?? const {});
        args.putIfAbsent(tool, () => []).add(a);
        final answer = await f(a);
        if (!_read.hasMatch(tool)) Future<void>.microtask(notifyAll);
        return answer;
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
    on('form_builder.issue_list', (a) async => {
          'ok': true,
          'issues': [
            {
              'issueId': 'issue-1',
              'issueNumber': '2026-001',
              'templateId': 'weekly-report',
              'issuedBy': 'kim',
              'issuedAt': '2026-11-01T10:30:00.000',
            },
          ],
        });
    on('form.list_templates', (a) async => {
          'templates': [
            {'templateId': 'weekly', 'name': 'Weekly report', 'version': '1.0.0', 'value': 'weekly', 'label': 'Weekly report'},
          ],
        });
    on('form.template_schema', (a) async => {
          'templateId': a['templateId'],
          'fields': [
            {'value': 'title', 'label': 'title'},
            {'value': 'summary', 'label': 'summary'},
          ],
        });
    on('form_builder.fill', (a) async => {
          'ok': true,
          'documentId': 'doc-1',
          'filled': {'summary': 'Closed the Acme deal.'},
          'filledFields': [
            {'field': 'summary', 'text': 'Closed the Acme deal.'},
          ],
          'unfilled': [
            {'field': 'title', 'reason': 'no facts match', 'required': false},
          ],
        });
    on('form_builder.issue', (a) async => {'ok': true, 'issueId': 'issue-2', 'issueNumber': '2026-002'});
    on('bk.knowledge.pending', (a) async => {'ok': true, 'candidates': List.of(candidates)});
    on('bk.skill.list', (a) async => {
          'ok': true,
          'skills': [
            {'id': 'sk1', 'name': 'Quote review', 'version': '1.0.0'},
          ],
        });
    on('bk.profile.list', (a) async => {'ok': true, 'profiles': []});
    on('bk.philosophy.list', (a) async => {
          'ok': true,
          'ethos': [
            {'id': 'default_ethos', 'name': 'Default Ethos', 'version': '1.0.0', 'active': true},
            {'id': 'strict', 'name': 'Strict Ethos', 'version': '1.0.0', 'active': false},
          ],
        });
    on('bk.philosophy.activate', (a) async => {'ok': true});
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
    final runs = <Map<String, dynamic>>[
      if (!empty)
        {
          'runId': 'acme.review:1',
          'processId': 'acme.review',
          'status': 'suspended',
          'waiting': true,
          'stepId': 'sign',
          'kind': 'approval',
        },
      if (!empty)
        {
          'runId': 'acme.chore:2',
          'processId': 'acme.chore',
          'status': 'suspended',
          'waiting': true,
          'stepId': 'do',
          'kind': 'human',
        },
    ];
    final tasks = <Map<String, dynamic>>[
      if (!empty)
        {
          'taskId': 'quote',
          'title': 'Send the quote',
          'kind': 'oneOff',
          'workspaceId': 'acme',
          'status': 'pending',
          'moves': ['cancelled', 'inProgress'],
        },
    ];
    on('work.task.list', (a) async => {'ok': true, 'tasks': tasks});
    on('work.task.move', (a) async {
      final t = tasks.firstWhere((t) => t['taskId'] == a['taskId']);
      t['status'] = a['to'];
      return {'ok': true, 'status': a['to']};
    });
    on('work.run.list', (a) async => {'ok': true, 'runs': runs});
    on('work.run.submit', (a) async {
      runs.removeWhere((r) => r['runId'] == a['runId']);
      return {'ok': true, 'status': 'completed'};
    });
    on('work.run.decide', (a) async {
      runs.removeWhere((r) => r['runId'] == a['runId']);
      return {'ok': true, 'status': 'completed'};
    });
    on('bk.behavior.list', (a) async => {
          'ok': true,
          'behaviors': empty ? <String>[] : ['weekly-report'],
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
    on('org.workspace.create', (a) async => {'ok': true});
    on('org.workspace.update', (a) async => {'ok': true});
    on('org.export', (a) async => {
          'ok': true,
          'organization': {'workspaces': []},
          'text': '{"workspaces":[]}',
        });
    on('org.import', (a) async => {
          'ok': true,
          'created': {'workspaces': ['a', 'b'], 'members': ['m']},
          'skipped': {'workspaces': ['c'], 'members': []},
        });
    on('org.workspace.archive', (a) async => {'ok': true});
    final members = <Map<String, dynamic>>[
      {'id': 'u-kim', 'kind': 'person', 'displayName': 'Kim', 'units': ['sales']},
    ];
    on('org.member.list', (a) async => {'ok': true, 'members': members});
    on('org.member.add', (a) async {
      members.add({
        'id': a['id'],
        'kind': a['kind'],
        'displayName': a['displayName'],
        'units': a['units'],
      });
      return {'ok': true};
    });
    on('org.member.remove', (a) async {
      members.removeWhere((m) => m['id'] == a['id']);
      return {'ok': true};
    });
    on('org.document.issue', (a) async =>
        {'ok': true, 'document': 'doc-for-${a['memberId']}.signature', 'text': 'doc-for-${a['memberId']}.signature'});
    final stopped = <String>['u-lee'];
    on('system.access.list', (a) async => {'ok': true, 'revoked': stopped});
    on('system.access.restore', (a) async {
      stopped.remove(a['memberId']);
      return {'ok': true};
    });
    on('system.shutdown', (a) async => {'ok': true});
    on('system.config.set', (a) async => {'ok': true});
    on('system.secret.set', (a) async => {'ok': true});
    on('bk.agent.create', (a) async => {'ok': true});
    on('bk.agent.delete', (a) async => {'ok': true});
    on('bk.knowledge.correct', (a) async => {'ok': true, 'factId': 'f2'});
    on('bk.fact.retract', (a) async => {'ok': true});
    on('bk.knowledge.checkpoint', (a) async => {'ok': true});
    on('bk.knowledge.history', (a) async => {
          'ok': true,
          'versions': [
            {
              'seq': 1,
              'ts': '2026-11-02T15:17:12Z',
              'actor': 'u-a',
              'via': 'confirm',
              'removed': false,
              'data': {'payload': {'text': 'First wording'}},
            },
          ],
        });
    on('bk.behavior.run', (a) async => {'ok': true, 'runId': 'r1'});
    on('bk.knowledge.export', (a) async => empty ? {'ok': true, 'statements': 0, 'bundle': {}} : {
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
    on('system.events.snapshot', (a) async => {
          'events': [
            {'event': 'run.finished', 'timestamp': '2026-11-03T09:00:00', 'summary': 'Run finished', 'payload': {}},
          ],
        });
    on('system.events.clear', (a) async => {'ok': true});
    on('system.config.validate', (a) async => {
          'ok': false,
          'issues': [
            {'severity': 'error', 'path': 'llm.model', 'message': 'model is empty'},
          ],
        });
    on('system.cost.totals', (a) async => {
          'rows': [
            {'provider': 'anthropic', 'inputTokens': 120, 'outputTokens': 45, 'callCount': 3},
          ],
        });
    on('system.bundle.deactivate', (a) async => {'ok': true});
    on('system.bundle.activate', (a) async => {'ok': true});
    on('system.config.read', (a) async => {'provider': 'anthropic', 'model': 'claude'});
    on('system.bundle.list', (a) async => {
          'ok': true,
          'bundles': [
            {'name': 'flowbrain', 'active': true},
            {'name': 'extra', 'active': false},
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
  // A string the runtime could not resolve is on the screen as it was written.
  '{{',
  '!!',
  'i18n.',
];

Future<_Server> _open(WidgetTester tester, double width,
    {bool modelFails = false,
    bool empty = false,
    Set<String> refused = const {}}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server()
    ..modelFails = modelFails
    ..empty = empty
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

  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: runtime.buildUI(
    onResourceSubscribe: (uri, binding) => server.subscribe(uri, binding),
    onResourceUnsubscribe: (uri) => server.unsubscribe(uri),
  ))));
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
    expect(find.textContaining('2026-11-01 09:00'), findsOneWidget,
        reason: 'the time of a statement, as the spec writes a date format: '
            '${shown(tester)}');

    await tester.tap(find.text('To confirm').first);
    await settle(tester);
    expect(find.text('Use the east supplier'), findsWidgets);
    await tester.tap(find.text('Confirm').first);
    await settle(tester);
    expect(s.args['bk.knowledge.confirm']!.single['candidateId'], 'c1');
    expect(s.candidates, isEmpty);

    await tester.tap(find.text('Documents').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(s.calls, contains('form_builder.issue_list'));
    expect(find.textContaining('2026-001 · weekly-report'), findsOneWidget,
        reason: shown(tester));
    expect(find.textContaining('kim · 2026-11-01 10:30'), findsOneWidget);
  });

  testWidgets('a document is made from the facts, looked at, and issued',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Knowledge').first);
    await settle(tester);
    await tester.tap(find.text('Documents').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(s.calls, contains('form.list_templates'));

    expect(find.text('Pick a template'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<int>).at(1));
    await settle(tester);
    await tester.tap(find.text('Weekly report').last);
    await settle(tester);
    expect(s.args['form.template_schema']!.single['templateId'], 'weekly');

    await tester.tap(find.byType(PopupMenuButton<int>).at(2));
    await settle(tester);
    await tester.tap(find.text('summary').last);
    await settle(tester);
    // Any kind first: no kinds in the binding.
    await tester.tap(find.text('Add'));
    await settle(tester);
    expect(find.textContaining('summary ← Any kind'), findsOneWidget,
        reason: shown(tester));
    await tester.tap(find.text('Clear'));
    await settle(tester);
    // Then one kind.
    await tester.tap(find.byType(PopupMenuButton<int>).at(3));
    await settle(tester);
    await tester.tap(find.text('decision').last);
    await settle(tester);
    await tester.tap(find.text('Add'));
    await settle(tester);
    expect(find.textContaining('summary ← decision'), findsOneWidget,
        reason: shown(tester));

    await tester.tap(find.text('Fill from facts'));
    await settle(tester);
    final fill = s.args['form_builder.fill']!.single;
    expect(fill['templateId'], 'weekly');
    expect((fill['bindings'] as List).single['field'], 'summary');
    expect((fill['bindings'] as List).single['params']['kinds'], ['decision']);
    expect(find.text('Closed the Acme deal.'), findsOneWidget,
        reason: shown(tester));
    expect(find.text('no facts match'), findsOneWidget);

    await tester.tap(find.text('Issue'));
    await settle(tester);
    expect(s.args['form_builder.issue']!.single['documentId'], 'doc-1');
    expect(find.text('Closed the Acme deal.'), findsNothing,
        reason: 'the made document is put away once issued');
  });

  testWidgets('a server that knows nothing yet shows empty places, not errors',
      (tester) async {
    await _open(tester, 1200, empty: true);
    for (final place in ['Knowledge', 'People', 'Work', 'Trace', 'System']) {
      await tester.tap(find.text(place).first);
      await settle(tester);
      _noErrorWidgets(tester);
    }
    await tester.tap(find.text('Knowledge').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.text('No statements at this point in time.'), findsOneWidget,
        reason: shown(tester));
  });

  testWidgets('work: the processes the server holds are listed',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Work').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.text('weekly-report'), findsOneWidget, reason: shown(tester));
    expect(s.calls, contains('bk.behavior.list'));

    // A run waits at a gate: a person approves it, and it is no longer there.
    expect(find.text('acme.review'), findsOneWidget, reason: shown(tester));
    await tester.tap(find.text('Approve').first);
    await settle(tester);
    expect(s.args['work.run.decide']!.single,
        {'runId': 'acme.review:1', 'decision': 'approve'});
    expect(find.text('acme.review'), findsNothing, reason: shown(tester));
    // A task handed to the member: they say it is done.
    expect(find.text('Nothing waits for an approval.'), findsNothing);
    expect(find.text('acme.chore'), findsOneWidget, reason: shown(tester));
    expect(find.text('Approve'), findsNothing,
        reason: 'a task is not an approval');
    await tester.tap(find.text('Done').first);
    await settle(tester);
    expect(s.args['work.run.submit']!.single,
        {'runId': 'acme.chore:2', 'text': ''});
    expect(find.text('Nothing waits for an approval.'), findsOneWidget,
        reason: shown(tester));
  });

  testWidgets('work: a task handed to the member is started and finished',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Work').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.text('Send the quote'), findsOneWidget, reason: shown(tester));
    await tester.tap(find.text('Start').first);
    await settle(tester);
    expect(s.args['work.task.move']!.last,
        {'taskId': 'quote', 'to': 'inProgress', 'note': ''});
    // It is blocked with a reason, picked up again, and finished.
    await tester.enterText(find.byType(TextField).first, 'Waiting for prices');
    await tester.tap(find.text('Blocked').first);
    await settle(tester);
    expect(s.args['work.task.move']!.last,
        {'taskId': 'quote', 'to': 'blocked', 'note': 'Waiting for prices'});
    expect(find.text('Blocked'), findsNothing,
        reason: 'a blocked task offers to resume, not to block again');
    await tester.tap(find.text('Resume').first);
    await settle(tester);
    expect(s.args['work.task.move']!.last,
        {'taskId': 'quote', 'to': 'inProgress', 'note': ''},
        reason: 'the note was put away once it was sent');
    await tester.tap(find.text('Done').last);
    await settle(tester);
    expect(s.args['work.task.move']!.last,
        {'taskId': 'quote', 'to': 'completed', 'note': ''});
    expect(find.text('Start'), findsNothing);
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

    // An administrator puts a workspace in, and away.
    expect(find.text('Create'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), 'east');
    await tester.enterText(find.byType(TextField).at(3), 'East region');
    await tester.pump();
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(s.args['org.workspace.create'], isNotNull,
        reason: 'fields: ${find.byType(TextField).evaluate().length} ${shown(tester)}');
    expect(s.args['org.workspace.create']!.single,
        {'id': 'east', 'title': 'East region'});

    await tester.tap(find.byTooltip('Archive').first);
    await settle(tester);
    expect(find.text('The workspace is put away. Everything stays and it can come back.'),
        findsOneWidget,
        reason: 'the question before putting away: ${shown(tester)}');
    await tester.tap(find.text('Cancel').first);
    await settle(tester);
    expect(s.args['org.workspace.archive'], isNull);
    await tester.tap(find.byTooltip('Archive').first);
    await settle(tester);
    await tester.tap(find.text('Archive').first);
    await settle(tester);
    expect(s.args['org.workspace.archive'], isNotNull,
        reason: shown(tester));
    expect(s.args['org.workspace.archive']!.single['id'], 'acme');
  });

  testWidgets('the conversation: sent, answered, shown with the tools used',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.byTooltip('Conversation').first);
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

  testWidgets('starting the conversation over asks first, then forgets it',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.byTooltip('Conversation').first);
    await settle(tester);
    await tester.tap(find.byTooltip('Start over').first);
    await settle(tester);
    expect(find.textContaining('Knowledge is not deleted'), findsOneWidget,
        reason: shown(tester));
    await tester.tap(find.text('Cancel').first);
    await settle(tester);
    expect(s.calls, isNot(contains('chat.clear')));
    expect(find.textContaining('Knowledge is not deleted'), findsNothing);

    await tester.tap(find.byTooltip('Start over').first);
    await settle(tester);
    await tester.tap(find.text('Start over').first);
    await settle(tester);
    expect(s.calls, contains('chat.clear'));
    expect(find.textContaining('Knowledge is not deleted'), findsNothing);
  });

  testWidgets('a conversation the model fails keeps what was typed and says '
      'why', (tester) async {
    await _open(tester, 1200, modelFails: true);
    await tester.tap(find.byTooltip('Conversation').first);
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
    final s = await _open(tester, 1200);
    await tester.tap(find.text('System').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.textContaining('anthropic'), findsWidgets);
    expect(find.text('flowbrain'), findsOneWidget);
    expect(find.text('factGraph ✓'), findsOneWidget, reason: shown(tester));
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Not active'), findsOneWidget);

    // Checking the settings lists what is wrong with them.
    await tester.ensureVisible(find.text('Check the settings'));
    await tester.tap(find.text('Check the settings'));
    await settle(tester);
    expect(s.calls, contains('system.config.validate'));
    expect(find.text('model is empty'), findsOneWidget, reason: shown(tester));

    // The model's use and the recent events are listed; events can be cleared.
    expect(find.textContaining('3 calls · 120 / 45'), findsOneWidget,
        reason: shown(tester));
    expect(find.text('Run finished'), findsOneWidget, reason: shown(tester));
    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(s.calls, contains('system.events.clear'));

    // Turning a bundle off asks first, and Cancel leaves it.
    await tester.tap(find.text('Deactivate'));
    await settle(tester);
    expect(find.textContaining('turning one off takes its screens away'),
        findsOneWidget, reason: shown(tester));
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(s.calls, isNot(contains('system.bundle.deactivate')));
    await tester.tap(find.text('Deactivate'));
    await settle(tester);
    await tester.tap(find.text('Deactivate'));
    await settle(tester);
    expect(s.args['system.bundle.deactivate']!.single['name'], 'flowbrain');

    // Turning one on does not ask.
    await tester.tap(find.text('Activate'));
    await settle(tester);
    expect(s.args['system.bundle.activate']!.single['name'], 'extra');
  });

  testWidgets('the screen subscribes to what it shows and is told, rather '
      'than asking again', (tester) async {
    final s = await _open(tester, 1200);
    // Everything it shows is subscribed (read once, then told).
    expect(s.subs.keys, containsAll(<String>[
      'fb://own/pending',
      'fb://own/work/now',
      'fb://own/facts/now',
      'fb://own/trace',
      'fb://me/workspaces',
      'fb://chat/history',
    ]));
    final first = s.calls.where((c) => c == 'bk.knowledge.pending').length;
    await settle(tester);
    await settle(tester);
    expect(s.calls.where((c) => c == 'bk.knowledge.pending').length, first,
        reason: 'nothing changed, nothing was asked again');

    // Something changes on the server: what it shows follows, unasked.
    expect(find.textContaining('Candidates 1'), findsWidgets);
    s.candidates.clear();
    await s.notifyAll();
    await settle(tester);
    expect(find.textContaining('Candidates 0'), findsWidgets,
        reason: shown(tester));
  });

  testWidgets('another workspace is another set of subscriptions',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.byType(PopupMenuButton<int>).first);
    await settle(tester);
    await tester.tap(find.text('Sales').last);
    await settle(tester);
    expect(s.subs.keys, contains('fb://sales/pending'));
    expect(s.subs.keys, contains('fb://sales/work/now'));
    expect(s.subs.keys, isNot(contains('fb://own/pending')),
        reason: 'the old workspace is let go');
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

  testWidgets('people: a member is added, given a document, and removed',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('People').first);
    await settle(tester);
    final fields = find.byType(TextField);
    final base = fields.evaluate().length;
    await tester.enterText(fields.at(base - 3), 'u-han');
    await tester.enterText(fields.at(base - 2), 'Han');
    await tester.enterText(fields.at(base - 1), 'sales');
    await tester.pump();
    await tester.ensureVisible(find.text('Add member'));
    await tester.tap(find.text('Add member'));
    await settle(tester);
    expect(s.args['org.member.add']!.single, {
      'id': 'u-han',
      'kind': 'person',
      'displayName': 'Han',
      'units': ['sales'],
    });
    expect(find.text('Han'), findsWidgets, reason: shown(tester));

    await tester.ensureVisible(find.byTooltip('Issue a member document').last);
    await tester.tap(find.byTooltip('Issue a member document').last);
    await settle(tester);
    expect(s.args['org.document.issue']!.single, {'memberId': 'u-han'});
    expect(find.text('doc-for-u-han.signature'), findsOneWidget,
        reason: shown(tester));
    await tester.ensureVisible(find.text('Done').last);
    await tester.tap(find.text('Done').last);
    await settle(tester);
    expect(find.text('doc-for-u-han.signature'), findsNothing,
        reason: shown(tester));

    await tester.tap(find.byTooltip('Remove').last);
    await settle(tester);
    expect(s.args['org.member.remove'], isNull, reason: 'it asks first');
    await tester.tap(find.text('Remove').last);
    await settle(tester);
    expect(s.args['org.member.remove']!.single, {'id': 'u-han'});
    expect(find.text('Han'), findsNothing, reason: shown(tester));
  });

  testWidgets('people: a workspace is moved and given a lead, the organisation '
      'is exported and taken in', (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('People').first);
    await settle(tester);

    Finder field(String hint) => find.widgetWithText(TextField, hint);
    await tester.ensureVisible(field('Workspace to change'));
    await tester.enterText(field('Workspace to change'), 'sales');
    await tester.enterText(
        field('Parent workspace or member id'), 'u-han');
    await tester.pump();
    await tester.ensureVisible(find.text('Set lead'));
    await tester.tap(find.text('Set lead'));
    await settle(tester);
    expect(s.args['org.workspace.update']!.single,
        {'id': 'sales', 'leadMemberId': 'u-han'});
    await tester.enterText(field('Parent workspace or member id'), 'acme');
    await tester.pump();
    await tester.tap(find.text('Move under'));
    await settle(tester);
    expect(s.args['org.workspace.update']!.last,
        {'id': 'sales', 'parentId': 'acme'});

    await tester.enterText(field('Parent workspace or member id'), 'acme');
    await tester.pump();
    await tester.ensureVisible(find.text('Share with'));
    await tester.tap(find.text('Share with'));
    await settle(tester);
    expect(s.args['org.workspace.update']!.last,
        {'id': 'sales', 'shareTo': 'acme'});
    await tester.enterText(field('Parent workspace or member id'), 'acme');
    await tester.pump();
    await tester.tap(find.text('Stop sharing'));
    await settle(tester);
    expect(s.args['org.workspace.update']!.last,
        {'id': 'sales', 'unshareTo': 'acme'});

    await tester.ensureVisible(find.text('Export the organisation'));
    await tester.tap(find.text('Export the organisation'));
    await settle(tester);
    expect(find.text('{"workspaces":[]}'), findsOneWidget,
        reason: shown(tester));

    await tester.enterText(
        field('Paste an exported organisation here'), '{"workspaces":[]}');
    await tester.pump();
    await tester.ensureVisible(find.text('Check'));
    await tester.tap(find.text('Check'));
    await settle(tester);
    expect(s.args['org.import']!.single,
        {'text': '{"workspaces":[]}', 'dryRun': true});
    expect(find.textContaining('new: 2 / 1'), findsOneWidget,
        reason: shown(tester));
    await tester.tap(find.text('Take in'));
    await settle(tester);
    expect(s.args['org.import']!.last['dryRun'], false);
  });

  testWidgets('system: a stopped member is restored, the server is shut down '
      'after asking', (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('System').first);
    await settle(tester);
    _noErrorWidgets(tester);
    expect(find.text('u-lee'), findsOneWidget, reason: shown(tester));
    await tester.ensureVisible(find.text('Restore'));
    await tester.tap(find.text('Restore'));
    await settle(tester);
    expect(s.args['system.access.restore']!.single, {'memberId': 'u-lee'});
    expect(find.text('No member is stopped.'), findsOneWidget,
        reason: shown(tester));

    await tester.ensureVisible(find.text('Shut down').last);
    await tester.tap(find.text('Shut down').last);
    await settle(tester);
    expect(s.calls, isNot(contains('system.shutdown')));
    await tester.tap(find.text('Cancel').last);
    await settle(tester);
    expect(s.calls, isNot(contains('system.shutdown')));
    await tester.ensureVisible(find.text('Shut down').last);
    await tester.tap(find.text('Shut down').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Shut down').last);
    await tester.tap(find.text('Shut down').last);
    await settle(tester);
    expect(s.calls, contains('system.shutdown'));
  });

  testWidgets('work: a process is started by a person', (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Work').first);
    await settle(tester);
    await tester.ensureVisible(find.text('Run'));
    await tester.tap(find.text('Run'));
    await settle(tester);
    expect(s.args['bk.behavior.run']!.single, {'behaviorId': 'weekly-report'});
  });

  testWidgets('today: the work so far is put down as knowledge', (tester) async {
    final s = await _open(tester, 1200);
    final hint = find.widgetWithText(TextField, 'What is to be kept (one line)');
    await tester.ensureVisible(hint);
    await tester.enterText(hint, 'Ship on Friday');
    await tester.pump();
    await tester.tap(find.text('Put down'));
    await settle(tester);
    final a = s.args['bk.knowledge.checkpoint']!.single;
    expect(a['statements'], [
      {'kind': 'decision', 'text': 'Ship on Friday'}
    ], reason: '$a');
    expect(a['origin'], 'human');
    expect(find.text('Put down as knowledge.'), findsOneWidget,
        reason: shown(tester));
  });

  testWidgets('trace: one member\'s work is asked for, and all again',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Trace').first);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Member id'), 'u-kim');
    await tester.pump();
    await tester.tap(find.text('Filter'));
    await settle(tester);
    expect(s.subs.keys, contains('fb://own/trace/u-kim'));
    expect(s.subs.keys, isNot(contains('fb://own/trace')));
    await tester.tap(find.text('Show all'));
    await settle(tester);
    expect(s.subs.keys, contains('fb://own/trace'));
    expect(s.subs.keys, isNot(contains('fb://own/trace/u-kim')));
  });

  testWidgets('knowledge: the skills, profiles and philosophies are listed',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Knowledge').first);
    await settle(tester);
    await tester.tap(find.text('Skills, profiles, philosophies'));
    await settle(tester);
    expect(find.text('Quote review'), findsOneWidget, reason: shown(tester));
    expect(find.text('Default Ethos'), findsOneWidget, reason: shown(tester));
    expect(find.textContaining('In use'), findsOneWidget, reason: shown(tester));
    await tester.tap(find.text('Activate'));
    await settle(tester);
    expect(s.args['bk.philosophy.activate']!.single, {'id': 'strict'});
  });

  testWidgets('knowledge: a fact is corrected, and retracted after asking',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('Knowledge').first);
    await settle(tester);
    await tester.tap(find.byTooltip('Correct').first);
    await settle(tester);
    expect(find.text('The earlier version stays; the correction is the one '
        'that counts now.'), findsOneWidget, reason: shown(tester));
    await tester.enterText(find.byType(TextField).last, 'Use the west supplier');
    await tester.pump();
    await tester.tap(find.text('Save the correction'));
    await settle(tester);
    expect(s.args['bk.knowledge.correct']!.single['factId'], 'f1');
    expect(s.args['bk.knowledge.correct']!.single['text'],
        'Use the west supplier');

    await tester.tap(find.byTooltip('History').first);
    await settle(tester);
    expect(s.args['bk.knowledge.history']!.single,
        {'collection': 'facts', 'id': 'f1'});
    expect(find.text('First wording'), findsOneWidget, reason: shown(tester));
    await tester.ensureVisible(find.text('Close history'));
    await tester.tap(find.text('Close history'));
    await settle(tester);
    expect(find.text('First wording'), findsNothing);

    await tester.tap(find.byTooltip('Retract').first);
    await settle(tester);
    expect(s.args['bk.fact.retract'], isNull, reason: 'it asks first');
    await tester.tap(find.text('Retract').last);
    await settle(tester);
    expect(s.args['bk.fact.retract']!.single['id'], 'f1');
  });

  testWidgets('people: an agent is made, and taken away after asking',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('People').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'scribe');
    await tester.enterText(find.byType(TextField).at(1), 'Scribe');
    await tester.pump();
    await tester.tap(find.text('reviewer'));
    await settle(tester);
    await tester.tap(find.text('Add agent'));
    await settle(tester);
    expect(s.args['bk.agent.create']!.single, {
      'id': 'scribe',
      'displayName': 'Scribe',
      'role': 'reviewer',
      'workspaceId': null,
    });
    await tester.tap(find.byTooltip('Remove').first);
    await settle(tester);
    expect(s.args['bk.agent.delete'], isNull, reason: 'it asks first');
    await tester.tap(find.text('Remove').first);
    await settle(tester);
    expect(s.args['bk.agent.delete']!.single, {'agentId': 'bot'});
  });

  testWidgets('system: the model and the key are set, and the key is not shown',
      (tester) async {
    final s = await _open(tester, 1200);
    await tester.tap(find.text('System').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'claude-sonnet-5-5');
    await tester.enterText(find.byType(TextField).at(1), 'sk-test-secret');
    await tester.pump();
    await tester.tap(find.text('Save model'));
    await settle(tester);
    expect(s.args['system.config.set']!.single,
        {'path': 'llm.model', 'value': 'claude-sonnet-5-5'});
    await tester.enterText(find.byType(TextField).at(1), 'sk-test-secret');
    await tester.pump();
    await tester.tap(find.text('Save key'));
    await settle(tester);
    expect(s.args['system.secret.set']!.single, {
      'name': 'llm_api_key',
      'value': 'sk-test-secret',
      'bindTo': 'llm.apiKeyRef',
    });
    expect(find.text('sk-test-secret'), findsNothing,
        reason: 'the key is cleared once kept, and was never shown');
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
