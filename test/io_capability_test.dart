/// AppPlayer Standard — desktop io capability registration.
///
/// Verifies that `registerIoCapability` exposes the `io.*` tool surface on
/// the booted core's in-process dispatcher (desktop). Actual process
/// execution + sandbox/policy behaviour is covered by mcp_io_process's own
/// suite; this checks the host wiring only.
library;

import 'dart:io';

import 'package:appplayer/adapters/io_capability.dart';
import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('registerIoCapability exposes io.* tools on the dispatcher (desktop)',
      () async {
    final core = AppPlayerCoreService.forTesting(
      connector: (_) async => throw UnimplementedError(),
    );
    await core.initialize(
      storage: _EmptyStorage(),
      bundleInstallRoot:
          '${Directory.systemTemp.path}${Platform.pathSeparator}appplayer-io-test',
    );
    expect(core.isKernelBooted, isTrue);

    registerIoCapability(
      core,
      allowedRoots: [Directory.systemTemp.path],
      executableAllowlist: const ['echo'],
    );

    final names = core.inProcessToolNames;
    expect(names, contains('io.execute'));
    expect(names, contains('io.plan_execute'));
    expect(names, contains('io.commit_execute'));
    expect(names, contains('io.emergency_stop'));
    // Connection-driver lifecycle tools from the shared io_drivers recipe.
    expect(names, contains('io.connect_device'));
    expect(names, contains('io.disconnect_device'));
    // Standard surface still present alongside the new capability.
    expect(names.any((n) => n.startsWith('bk.')), isTrue);

    await core.dispose();
  });
}
