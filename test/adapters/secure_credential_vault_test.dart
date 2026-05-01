import 'package:appplayer/adapters/secure_credential_vault.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory FlutterSecureStorage via MethodChannel override.
/// Avoids plugin mock dependency.
class _MemorySecureStorageChannel {
  _MemorySecureStorageChannel() {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
  }

  final Map<String, String> _store = {};
  final List<String> calls = [];

  Future<dynamic> _handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'read':
        return _store[call.arguments['key'] as String];
      case 'write':
        _store[call.arguments['key'] as String] =
            call.arguments['value'] as String;
        return null;
      case 'delete':
        _store.remove(call.arguments['key'] as String);
        return null;
      case 'deleteAll':
        _store.clear();
        return null;
      case 'containsKey':
        return _store.containsKey(call.arguments['key'] as String);
      case 'readAll':
        return Map<String, String>.from(_store);
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemorySecureStorageChannel mock;
  late SecureCredentialVault vault;

  setUp(() {
    mock = _MemorySecureStorageChannel();
    vault = SecureCredentialVault(const FlutterSecureStorage());
  });

  test('TC-VAULT-001 write then read', () async {
    await vault.write('k', 'v');
    expect(await vault.read('k'), 'v');
    expect(mock.calls, contains('write'));
    expect(mock.calls, contains('read'));
  });

  test('TC-VAULT-002 read missing returns null', () async {
    expect(await vault.read('missing'), isNull);
  });

  test('TC-VAULT-003 delete removes', () async {
    await vault.write('k', 'v');
    await vault.delete('k');
    expect(await vault.read('k'), isNull);
  });

  test('TC-VAULT-004 clearAll delegates deleteAll', () async {
    await vault.write('k1', 'v1');
    await vault.write('k2', 'v2');
    await vault.clearAll();
    expect(await vault.read('k1'), isNull);
    expect(await vault.read('k2'), isNull);
    expect(mock.calls, contains('deleteAll'));
  });
}
