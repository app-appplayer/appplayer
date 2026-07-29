/// Integration smoke — AppPlayer Standard boots appplayer_core and connects
/// a BLE board through the app-layer entry (`connectBleBoard`): vendored
/// `ble_transport` recipe (layer ② impl) → kernel extension-transport seam
/// (`connectExtensionTransport`, layer ①). The board is simulated by a real
/// `mcp_server` Server speaking newline-delimited JSON-RPC over the recipe's
/// radio seam (FakeBleLink) at the ATT MTU floor of 23, so the whole BLE
/// path (framing + chunking + reassembly) is exercised end to end without
/// hardware.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:appplayer/adapters/ble_extension.dart';
import 'package:appplayer/adapters/ble_transport/ble_transport.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_server/mcp_server.dart' as srv;

import 'adapters/ble_transport/fake_ble_link.dart';

/// Minimal in-memory storage so the service can boot.
class _EmptyStorage implements ServerStorage {
  @override
  Future<List<ServerConfig>> getServers() async => const [];
  @override
  Future<ServerConfig?> getById(String id) async => null;
  @override
  Future<void> saveServer(ServerConfig server) async {}
  @override
  Future<void> deleteServer(String id) async {}
  @override
  Future<void> updateLastConnected(String id, DateTime at) async {}
  @override
  Future<void> toggleFavorite(String id) async {}
}

/// FakeBleLink that also surfaces every RX write to the simulated board.
class _BoardFakeBleLink extends FakeBleLink {
  void Function(List<int> chunk)? onWrite;

  @override
  Future<void> writeRxChunk(List<int> chunk) async {
    await super.writeRxChunk(chunk);
    onWrite?.call(List<int>.from(chunk));
  }
}

/// The board side of the fake radio: an mcp_server [srv.ServerTransport]
/// whose byte pipe is the FakeBleLink. RX writes are reassembled with the
/// recipe's newline framer; responses go back as TX notifications chunked
/// to the MTU-23 floor (boundaries carry no semantics).
class _FakeBleBoardTransport implements srv.ServerTransport {
  _FakeBleBoardTransport(this._link) {
    final framer = NewlineJsonFramer(
      onMessage: _messages.add,
      onError: _messages.addError,
    );
    _link.onWrite = framer.feed;
  }

  static const int _notifyChunkSize = bleDefaultAttMtu - bleAttHeaderOverhead;

  final _BoardFakeBleLink _link;
  final _messages = StreamController<dynamic>.broadcast();
  final _closed = Completer<void>();

  @override
  Stream<dynamic> get onMessage => _messages.stream;

  @override
  Future<void> get onClose => _closed.future;

  @override
  void send(dynamic message) {
    final frame = NewlineJsonFramer.encodeFrame(message);
    for (var offset = 0; offset < frame.length; offset += _notifyChunkSize) {
      final end = math.min(offset + _notifyChunkSize, frame.length);
      _link.notifyBytes(frame.sublist(offset, end));
    }
  }

  @override
  void close() {
    if (!_closed.isCompleted) _closed.complete();
    if (!_messages.isClosed) _messages.close();
    _link.dropConnection();
  }
}

void main() {
  test(
      'connectBleBoard reaches the kernel seam through a booted service: '
      'listTools / callTool / readResource round-trip over the BLE pipe',
      () async {
    // Simulated board: a real mcp_server behind the recipe's radio seam,
    // pinned at the default ATT MTU 23 (chunking absorbs).
    final link = _BoardFakeBleLink()..negotiatedMtu = bleDefaultAttMtu;
    final board = srv.Server(
      name: 'ble-board-sim',
      version: '1.0.0',
      capabilities: srv.ServerCapabilities.simple(tools: true, resources: true),
    );
    board.addTool(
      name: 'led.set',
      description: 'set the on-board LED',
      inputSchema: const {'type': 'object'},
      handler: (args) async =>
          const srv.CallToolResult(content: [srv.TextContent(text: 'ok')]),
    );
    board.addResource(
      uri: 'ui://app',
      name: 'app ui',
      description: 'served board UI definition',
      mimeType: 'application/json',
      handler: (uri, params) async => srv.ReadResourceResult(contents: [
        srv.ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: '{"type":"page"}',
        ),
      ]),
    );
    board.connect(_FakeBleBoardTransport(link));

    // Boot AppPlayer Standard's core service (connector unused by this path).
    final core = AppPlayerCoreService.forTesting(
      connector: (_) async => throw UnimplementedError(),
    );
    await core.initialize(
      storage: _EmptyStorage(),
      bundleInstallRoot: '/tmp/appplayer-ble-extension-test',
    );
    expect(core.isKernelBooted, isTrue);

    // App-layer entry: scan result's deviceId in, kernel connection out.
    final conn = await connectBleBoard(
      core,
      deviceId: 'fake-board',
      link: link,
    );
    expect(conn.id, 'ble:fake-board');

    // Sanity on the wire itself: the spec 16 connect sequence ran and the
    // handshake actually crossed the fake radio in MTU-floor chunks.
    expect(link.log.first, 'connect');
    expect(link.log, contains('subscribe'));
    expect(
      link.log.indexOf('subscribe'),
      lessThan(link.log.indexWhere((e) => e.startsWith('write'))),
    );
    for (final chunk in link.writes) {
      expect(chunk.length, lessThanOrEqualTo(20));
    }

    final tools = await conn.listTools();
    expect(tools.map((t) => t.name), contains('led.set'));

    final result = await conn.callTool('led.set', const {'on': true});
    expect(result.isError ?? false, isFalse);
    expect(result.content, isNotEmpty);

    final resource = await conn.readResource('ui://app');
    expect(resource.contents, isNotEmpty);
    expect(resource.contents.first.text, contains('"type"'));

    await core.dispose();
  });
}
