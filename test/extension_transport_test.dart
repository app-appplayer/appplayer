/// Integration smoke — AppPlayer Standard boots appplayer_core and drives the
/// kernel extension-transport seam (`connectExtensionTransport`) with an
/// mcp_bridge transport. Verifies the wiring the unit/recipe tests do not:
/// that the booted service holds a client host and the method reaches a real
/// remote server.
library;

import 'dart:io';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_bridge/mcp_bridge.dart' as br;
import 'package:mcp_server/mcp_server.dart' as srv;

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

void main() {
  test('connectExtensionTransport drives the seam through a booted service',
      () async {
    // A free port for the client/server rendezvous.
    final probe = await ServerSocket.bind('localhost', 0);
    final port = probe.port;
    await probe.close();

    // Simulated board: a real mcp_server over mcp_bridge's tcp transport.
    final server = srv.Server(
      name: 'board-sim',
      version: '1.0.0',
      capabilities: srv.ServerCapabilities.simple(tools: true),
    );
    server.addTool(
      name: 'led.set',
      description: 'set the on-board LED',
      inputSchema: const {'type': 'object'},
      handler: (args) async =>
          const srv.CallToolResult(content: [srv.TextContent(text: 'ok')]),
    );
    final serverTransport =
        br.TcpServerTransport({'host': 'localhost', 'port': port});
    await serverTransport.start();
    server.connect(serverTransport);

    // Boot AppPlayer Standard's core service (connector unused by this path).
    final core = AppPlayerCoreService.forTesting(
      connector: (_) async => throw UnimplementedError(),
    );
    await core.initialize(
      storage: _EmptyStorage(),
      bundleInstallRoot: '/tmp/appplayer-ext-transport-test',
    );
    expect(core.isKernelBooted, isTrue);

    // Inject an mcp_bridge extension transport through the AppPlayer method.
    final clientTransport =
        br.TcpClientTransport({'host': 'localhost', 'port': port});
    await clientTransport.start();
    final conn = await core.connectExtensionTransport(
      id: 'board-1',
      transport: clientTransport,
    );

    final tools = await conn.listTools();
    expect(tools.map((t) => t.name), contains('led.set'));

    final result = await conn.callTool('led.set', const {'on': true});
    expect(result.isError ?? false, isFalse);
    expect(result.content, isNotEmpty);

    await core.dispose();
    serverTransport.close();
  });
}
