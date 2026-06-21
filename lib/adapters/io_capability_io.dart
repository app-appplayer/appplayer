/// Desktop / mobile io capability — consumes the shared `io_drivers` recipe.
///
/// One `IoRuntime` exposes the fixed `io.*` surface plus
/// `io.connect_device` / `io.disconnect_device` (from the recipe). Device
/// drivers register per the platform matrix in
/// `specs/platform/11-io-devices.md`:
///   - network drivers (modbus / mqtt / http / scpi) — available on mobile +
///     desktop, connected at runtime via `io.connect_device`;
///   - `process` — host-owned, desktop-only, registered at boot.
///
/// Both AppPlayer and Studio consume the *same* recipe, so the same bundle
/// sees the same surface. Excluded from web at compile time via the
/// conditional export in `io_capability.dart`.
library;

import 'dart:io';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:mcp_bundle/mcp_bundle.dart';
import 'package:mcp_io/mcp_io.dart';

import 'io_drivers/io_drivers.dart';

/// Wire the io capability onto [core]. No-op on platforms that are neither
/// desktop nor mobile.
///
/// [allowedRoots] / [executableAllowlist] / [roles] / [allowShell] configure
/// the desktop-only process adapter's sandbox and policy.
void registerIoCapability(
  AppPlayerCoreService core, {
  required List<String> allowedRoots,
  List<String> executableAllowlist = const ['git', 'dart', 'flutter', 'pub'],
  List<String> roles = const ['manager', 'operator'],
  bool allowShell = false,
}) {
  final platform = _currentPlatform();
  if (platform == null) return;

  final policy = InMemoryIoPolicyPort(
    initialRules: recommendedPolicyRules(roles: roles),
  );
  final runtime = IoRuntime(
    policyPort: policy,
    auditPort: const _NoopIoAuditPort(),
  );

  // Shared recipe registry — network drivers (mobile + desktop).
  final registry = IoDriverRegistry();
  registerNetworkDrivers(registry);

  // One-time init: initialize the runtime, register the recipe's boot
  // (target-less) drivers for this platform — `process` on desktop — then
  // discover. Lazy so booting the host is free.
  var started = false;
  Future<void> ensureStarted() async {
    if (started) return;
    started = true;
    await runtime.initialize();
    final boot = bootAdapters(
      platform: platform,
      process: ProcessOptions(
        executableAllowlist: executableAllowlist,
        allowedRoots: allowedRoots,
        allowShell: allowShell,
        roles: roles,
      ),
    );
    for (final adapter in boot) {
      await runtime.registry.registerAdapter(adapter.manifest, adapter);
    }
    await runtime.registry.discover();
  }

  // Recipe tool map: fixed io.* + connect/disconnect, platform-gated. Wrap
  // each so the runtime + boot adapters initialize on first use.
  final tools = ioDeviceTools(
    runtime: runtime,
    registry: registry,
    platform: platform,
  );
  final wrapped = <String, Future<Object?> Function(Map<String, dynamic>)>{};
  for (final entry in tools.entries) {
    final handler = entry.value;
    wrapped[entry.key] = (args) async {
      await ensureStarted();
      return handler(args);
    };
  }
  core.registerCapabilityTools(wrapped);
}

/// Map the host OS to a driver [DevicePlatform]. Web is excluded by the
/// conditional export (no `dart:io`), so it never reaches here.
DevicePlatform? _currentPlatform() {
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    return DevicePlatform.desktop;
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return DevicePlatform.mobile;
  }
  return null;
}

/// Drops audit records. Policy enforcement is unaffected. Replace with a
/// persistent [IoAuditPort] to retain an execution log.
class _NoopIoAuditPort implements IoAuditPort {
  const _NoopIoAuditPort();

  @override
  Future<void> record(IoAuditRecord record) async {}

  @override
  Future<List<IoAuditRecord>> query(IoAuditQuery query) async =>
      const <IoAuditRecord>[];

  @override
  Future<void> export(IoAuditExportConfig config) async {}
}
