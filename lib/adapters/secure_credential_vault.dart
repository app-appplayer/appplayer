import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// MOD-ADAPT-002 — platform secure storage backed CredentialVault.
class SecureCredentialVault implements CredentialVault {
  SecureCredentialVault(this._s);

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);

  /// Product extension — used by Settings "reset all data".
  Future<void> clearAll() => _s.deleteAll();
}
