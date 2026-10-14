// FR-HOME-013 — blocked server addresses.
import 'package:appplayer/adapters/blocked_servers.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ServerConfig server(TransportType type, Map<String, dynamic> config) =>
    ServerConfig(
      id: 's',
      name: 'S',
      description: '',
      transportType: type,
      transportConfig: config,
    );

void main() {
  Future<BlockedServers> open([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return BlockedServers(await SharedPreferences.getInstance());
  }

  group('normalize', () {
    test('scheme and host lower-case, trailing slash and query ignored', () {
      expect(BlockedServers.normalize('HTTPS://Example.COM/mcp/'),
          'https://example.com/mcp');
      expect(BlockedServers.normalize('https://example.com/mcp?x=1#frag'),
          'https://example.com/mcp');
      expect(BlockedServers.normalize(' https://example.com '),
          'https://example.com');
    });

    test('the port is part of the address', () {
      expect(BlockedServers.normalize('http://example.com:3001/sse'),
          'http://example.com:3001/sse');
      expect(BlockedServers.normalize('http://example.com/sse'),
          isNot(BlockedServers.normalize('http://example.com:3001/sse')));
    });

    test('text without a host has no address', () {
      expect(BlockedServers.normalize(''), isNull);
      expect(BlockedServers.normalize('not a url'), isNull);
      expect(BlockedServers.normalize('/just/a/path'), isNull);
    });
  });

  group('addressOf', () {
    test('network transports have one, a local process does not', () {
      expect(
          BlockedServers.addressOf(
              server(TransportType.sse, {'serverUrl': 'https://a.example/sse'})),
          'https://a.example/sse');
      expect(
          BlockedServers.addressOf(server(
              TransportType.streamableHttp, {'baseUrl': 'https://a.example/mcp'})),
          'https://a.example/mcp');
      expect(
          BlockedServers.addressOf(server(TransportType.stdio, {'command': 'x'})),
          isNull);
    });

    test('the dashboard dialog keeps its address under `url`', () {
      expect(
          BlockedServers.addressOf(
              server(TransportType.sse, {'url': 'https://d.example/sse'})),
          'https://d.example/sse');
    });

    test('a blank address is none', () {
      expect(BlockedServers.addressOf(server(TransportType.sse, {'serverUrl': '  '})),
          isNull);
    });
  });

  group('block list', () {
    test('a blocked address is found under any spelling of it', () async {
      final store = await open();
      await store.block('https://Example.com/mcp/', name: 'Bad');
      expect(store.isBlocked('https://example.com/mcp'), isTrue);
      expect(store.isBlocked('HTTPS://EXAMPLE.COM/mcp?a=b'), isTrue);
      expect(store.isBlocked('https://example.com/other'), isFalse);
    });

    test('blocking twice keeps one entry, with the latest name', () async {
      final store = await open();
      await store.block('https://example.com/mcp', name: 'One');
      await store.block('https://example.com/mcp/', name: 'Two');
      expect(store.all.map((b) => b.name), ['Two']);
    });

    test('unblocking removes only that address', () async {
      final store = await open();
      await store.block('https://a.example/x', name: 'A');
      await store.block('https://b.example/x', name: 'B');
      await store.unblock('https://A.example/x/');
      expect(store.all.map((b) => b.name), ['B']);
      expect(store.isBlocked('https://a.example/x'), isFalse);
    });

    test('a server with no address is never blocked', () async {
      final store = await open();
      await store.block('https://example.com/mcp', name: 'A');
      expect(
          store.isServerBlocked(server(TransportType.stdio, {'command': 'x'})),
          isFalse);
      expect(
          store.isServerBlocked(
              server(TransportType.sse, {'serverUrl': 'https://example.com/mcp'})),
          isTrue);
    });

    test('the list survives a new instance on the same preferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await BlockedServers(prefs).block('https://example.com/mcp', name: 'A');
      expect(BlockedServers(prefs).isBlocked('https://example.com/mcp'), isTrue);
    });

    test('unreadable stored text is an empty list', () async {
      final store =
          await open(<String, Object>{BlockedServers.storageKey: '{not json'});
      expect(store.all, isEmpty);
      expect(store.isBlocked('https://example.com/mcp'), isFalse);
    });

    test('an address that cannot be compared is not stored', () async {
      final store = await open();
      await store.block('not a url', name: 'X');
      expect(store.all, isEmpty);
    });
  });
}
