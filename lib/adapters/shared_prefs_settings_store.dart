import 'dart:convert';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SettingsStore` implementation backed by SharedPreferences. Persists
/// the bundle's `settings.sections[].fields[]` values as a per-bundle
/// JSON object.
///
/// Storage layout: `settings.<bundleId>` → `{<fieldName>: <value>, ...}`.
/// Single-field read / write also touches the same JSON object — writes
/// are a read-modify-write cycle, which is not free but matches the
/// natural shape of `SharedPreferences`.
class SharedPrefsSettingsStore implements SettingsStore {
  SharedPrefsSettingsStore(this._prefs, {Logger? logger})
      : _logger = logger ?? NoopLogger();

  static const String _keyPrefix = 'settings.';

  final SharedPreferences _prefs;
  final Logger _logger;

  String _key(String bundleId) => '$_keyPrefix$bundleId';

  Map<String, Object?> _loadRaw(String bundleId) {
    final raw = _prefs.getString(_key(bundleId));
    if (raw == null) return <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (e, st) {
      _logger.logError(
        'settings_store.parse_failed',
        e,
        st,
        <String, Object?>{'bundleId': bundleId},
      );
    }
    return <String, Object?>{};
  }

  Future<void> _persist(String bundleId, Map<String, Object?> values) {
    return _prefs.setString(_key(bundleId), jsonEncode(values));
  }

  @override
  Future<Map<String, dynamic>> readAll(String bundleId) async {
    return Map<String, dynamic>.from(_loadRaw(bundleId));
  }

  @override
  Future<void> writeAll(
    String bundleId,
    Map<String, dynamic> values,
  ) async {
    await _persist(bundleId, Map<String, Object?>.from(values));
  }

  @override
  Future<Object?> read(String bundleId, String fieldName) async {
    return _loadRaw(bundleId)[fieldName];
  }

  @override
  Future<void> write(
    String bundleId,
    String fieldName,
    Object? value,
  ) async {
    final m = _loadRaw(bundleId);
    m[fieldName] = value;
    await _persist(bundleId, m);
  }

  @override
  Future<void> clear(String bundleId) async {
    await _prefs.remove(_key(bundleId));
  }
}
