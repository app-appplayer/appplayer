import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'ble_link.dart';
import 'ble_uuids.dart';

/// [BleLink] over universal_ble (BSD-3-Clause) — the only file in this
/// recipe that touches the radio plugin. Resolves the fixed MCP Serving
/// GATT service on the connected
/// device. universal_ble covers Android / iOS / macOS / Windows / Linux /
/// Web with one API.
class UniversalBleLink implements BleLink {
  /// [deviceId] is the platform device identifier, e.g.
  /// `BleBoardCandidate.deviceId` from a scan.
  UniversalBleLink({
    required String deviceId,
    Duration connectTimeout = const Duration(seconds: 15),
  })  : _deviceId = deviceId,
        _connectTimeout = connectTimeout;

  final String _deviceId;
  final Duration _connectTimeout;
  final _disconnected = Completer<void>();

  StreamSubscription<bool>? _connectionSub;
  bool _resolved = false;
  bool _writeWithoutResponse = false;

  @override
  Future<void> connect() async {
    await UniversalBle.connect(_deviceId, timeout: _connectTimeout);

    _connectionSub = UniversalBle.connectionStream(_deviceId)
        .where((connected) => !connected)
        .listen((_) => _completeDisconnected());

    final services = await UniversalBle.discoverServices(_deviceId);
    final serviceUuid = BleUuidParser.string(mcpBleServiceUuid);
    final matches = services.where((s) => s.uuid == serviceUuid);
    if (matches.isEmpty) {
      await disconnect();
      throw StateError(
        'MCP Serving service $mcpBleServiceUuid not found on '
        '$_deviceId — not an MCP-serving board?',
      );
    }

    final characteristics = matches.first.characteristics;
    final rx = _findCharacteristic(characteristics, mcpBleRxCharUuid);
    final tx = _findCharacteristic(characteristics, mcpBleTxCharUuid);
    if (rx == null || tx == null) {
      await disconnect();
      throw StateError(
        'MCP Serving service on $_deviceId is missing its RX/TX '
        'characteristics (conformance failure)',
      );
    }
    // The server accepts both write modes; Write Without Response
    // is preferred for throughput when the characteristic offers it.
    _writeWithoutResponse =
        rx.properties.contains(CharacteristicProperty.writeWithoutResponse);
    _resolved = true;
  }

  BleCharacteristic? _findCharacteristic(
    List<BleCharacteristic> characteristics,
    String uuid,
  ) {
    final normalized = BleUuidParser.string(uuid);
    for (final c in characteristics) {
      if (c.uuid == normalized) return c;
    }
    return null;
  }

  @override
  Future<int> requestMtu(int desired) {
    // Best-effort per platform (Android honors the request; iOS/macOS/
    // Windows/Linux auto-negotiate and only report). Returns the effective
    // MTU; if the platform cannot even report one this throws and the
    // transport falls back to the default ATT MTU 23.
    return UniversalBle.requestMtu(_deviceId, desired);
  }

  @override
  Future<Stream<List<int>>> subscribeTxNotifications() async {
    if (!_resolved) {
      throw StateError('not connected — call connect() first');
    }
    // CCCD write (the server sends nothing before this).
    await UniversalBle.subscribeNotifications(
      _deviceId,
      mcpBleServiceUuid,
      mcpBleTxCharUuid,
    );
    return UniversalBle.characteristicValueStream(
      _deviceId,
      mcpBleTxCharUuid,
    );
  }

  @override
  Future<void> writeRxChunk(List<int> chunk) async {
    if (!_resolved) {
      throw StateError('not connected — call connect() first');
    }
    await UniversalBle.write(
      _deviceId,
      mcpBleServiceUuid,
      mcpBleRxCharUuid,
      chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
      withoutResponse: _writeWithoutResponse,
    );
  }

  @override
  Future<void> get onDisconnected => _disconnected.future;

  @override
  Future<void> disconnect() async {
    try {
      await UniversalBle.disconnect(_deviceId);
    } finally {
      _completeDisconnected();
    }
  }

  void _completeDisconnected() {
    if (!_disconnected.isCompleted) _disconnected.complete();
    _connectionSub?.cancel();
    _connectionSub = null;
  }
}
