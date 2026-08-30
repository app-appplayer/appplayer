/// Link delivery behaviour (platform spec 19 §9.1, §9.2).
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:appplayer/entry/entry_controller.dart';
import 'package:appplayer/entry/entry_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLinks implements AppLinks {
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void emit(Uri uri) => _controller.add(uri);
  void fail(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EntryController _controller({required String body}) => buildEntryController(
      fetch: (url, {headers = const <String, String>{}}) async => body,
    );

const String _okBody = '''
{"status":"ok","issuer":{"name":"Fleet Co","verified":true},
 "target":{"kind":"server","ref":"https://fleet.example.test/mcp","route":"/contact"},
 "identityPolicy":"open"}
''';

void main() {
  test('an incoming claimed link produces an open outcome', () async {
    final links = _FakeLinks();
    final outcomes = <EntryOutcome>[];
    final service = EntryLinkService(
      controller: _controller(body: _okBody),
      locale: () => 'en',
      links: links,
    );
    await service.start(outcomes.add);

    links.emit(Uri.parse('https://demo.appplayer.app/e/ABC123'));
    await Future<void>.delayed(Duration.zero);

    expect(outcomes.single, isA<EntryOpen>());
    await service.dispose();
    await links.close();
  });

  test('a link we do not claim reaches no outcome', () async {
    final links = _FakeLinks();
    final outcomes = <EntryOutcome>[];
    final service = EntryLinkService(
      controller: _controller(body: _okBody),
      locale: () => 'en',
      links: links,
    );
    await service.start(outcomes.add);

    links.emit(Uri.parse('https://elsewhere.test/e/ABC123'));
    await Future<void>.delayed(Duration.zero);

    // Not ours is not the viewer's problem: nothing is put on screen.
    expect(outcomes, isEmpty);
    await service.dispose();
    await links.close();
  });

  test('a resolver failure blocks with a gate rather than throwing', () async {
    final links = _FakeLinks();
    final outcomes = <EntryOutcome>[];
    final service = EntryLinkService(
      controller: buildEntryController(
          fetch: (url, {headers = const <String, String>{}}) async =>
            throw StateError('offline'),
      ),
      locale: () => 'en',
      links: links,
    );
    await service.start(outcomes.add);

    links.emit(Uri.parse('https://demo.appplayer.app/e/ABC123'));
    await Future<void>.delayed(Duration.zero);

    expect(outcomes.single, isA<EntryBlocked>());
    await service.dispose();
    await links.close();
  });

  test('a stream error does not tear down the subscription', () async {
    final links = _FakeLinks();
    final outcomes = <EntryOutcome>[];
    final service = EntryLinkService(
      controller: _controller(body: _okBody),
      locale: () => 'en',
      links: links,
    );
    await service.start(outcomes.add);

    links.fail(StateError('platform hiccup'));
    await Future<void>.delayed(Duration.zero);
    links.emit(Uri.parse('https://demo.appplayer.app/e/ABC123'));
    await Future<void>.delayed(Duration.zero);

    // One bad event must not cost every later scan.
    expect(outcomes.single, isA<EntryOpen>());
    await service.dispose();
    await links.close();
  });

  test('dispose stops delivery', () async {
    final links = _FakeLinks();
    final outcomes = <EntryOutcome>[];
    final service = EntryLinkService(
      controller: _controller(body: _okBody),
      locale: () => 'en',
      links: links,
    );
    await service.start(outcomes.add);
    await service.dispose();

    links.emit(Uri.parse('https://demo.appplayer.app/e/ABC123'));
    await Future<void>.delayed(Duration.zero);

    expect(outcomes, isEmpty);
    await links.close();
  });
}
