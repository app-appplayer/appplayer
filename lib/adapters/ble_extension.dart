/// BLE board connection — public entry of the app layer.
///
/// Wires the vendored `ble_transport` recipe (layer ② of the
/// extension-transport standard, `specs/platform/08-extension.md` §4,
/// realizing the BLE GATT binding of `specs/platform/16-ble-transport.md`)
/// onto appplayer_core's layer-① seam (`connectExtensionTransport`).
/// Layers ① and ③ stay unchanged: once connected, the board lands in the
/// kernel registry and is consumed through the standard `mcp.*` path like
/// any other server.
///
/// Platform boundary — unlike the `dart:io`-based io capability, no
/// conditional import is needed: universal_ble covers all six Flutter
/// targets (Android / iOS / macOS / Windows / Linux / Web) with one API.
/// Per-platform notes (manifest permissions, entitlements) are in the
/// recipe README. **Web**: Web Bluetooth requires HTTPS and the scan is
/// backed by `requestDevice`, which the browser only allows from a user
/// gesture — call [scanForBoards] from a tap/click handler there.
/// Runtime permission prompts are the host UI's concern (universal_ble
/// exposes `hasPermissions` / `requestPermissions`).
library;

import 'package:appplayer_core/appplayer_core.dart';
import 'package:brain_kernel/brain_kernel.dart' show KernelClientConnection;

import 'ble_transport/ble_transport.dart';

/// Discover nearby MCP-serving boards (spec 16 §6 — a single scan filter
/// on the fixed MCP Serving service UUID, no configuration).
///
/// The scan starts on listen and stops when the subscription is cancelled
/// or [timeout] elapses (the stream then closes). The same board may be
/// emitted repeatedly with updated RSSI; deduplicate by
/// [BleBoardCandidate.deviceId] if needed.
Stream<BleBoardCandidate> scanForBoards({
  Duration timeout = const Duration(seconds: 15),
}) =>
    BleBoardScanner().scan(timeout: timeout);

/// Connect [core] to the MCP-serving board [deviceId] (a
/// [BleBoardCandidate.deviceId] from [scanForBoards]).
///
/// Builds a [BleClientTransport] over the real radio, runs the spec 16
/// connection sequence (connect → MTU >= 247 attempt → CCCD subscribe),
/// and injects it through the kernel seam. The returned connection's
/// `listTools` / `callTool` / `readResource` reach the board; it is also
/// registered under [id] in the kernel's `mcp.*` registry.
///
/// [id] defaults to `ble:<deviceId>`. [link] is the radio seam — leave
/// null for the real radio ([UniversalBleLink]); tests inject a fake.
Future<KernelClientConnection> connectBleBoard(
  AppPlayerCoreService core, {
  required String deviceId,
  String? id,
  BleLink? link,
}) async {
  final transport = BleClientTransport(
    link: link ?? UniversalBleLink(deviceId: deviceId),
  );
  try {
    await transport.start();
    return await core.connectExtensionTransport(
      id: id ?? 'ble:$deviceId',
      transport: transport,
    );
  } catch (_) {
    transport.close();
    rethrow;
  }
}
