import 'dart:convert';

import 'package:appplayer_core/appplayer_core.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MOD-ADAPT-001 — ServerStorage backed by SharedPreferences.
class SharedPrefsServerStorage implements ServerStorage {
  SharedPrefsServerStorage(this._prefs, {Logger? logger})
      : _logger = logger ?? NoopLogger();

  static const String storageKey = 'servers.v1';

  final SharedPreferences _prefs;
  final Logger _logger;
  List<ServerConfig>? _cache;

  @override
  Future<List<ServerConfig>> getServers() async {
    final cache = _cache;
    if (cache != null) return List.unmodifiable(cache);
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      _cache = <ServerConfig>[];
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((e) =>
              ServerConfig.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _cache = list;
      return List.unmodifiable(list);
    } catch (e, st) {
      _logger.logError('server_storage.parse_failed', e, st);
      _cache = <ServerConfig>[];
      return const [];
    }
  }

  @override
  Future<ServerConfig?> getById(String id) async {
    final list = await getServers();
    return list.firstWhereOrNull((c) => c.id == id);
  }

  @override
  Future<void> saveServer(ServerConfig server) async {
    final list = List<ServerConfig>.from(await getServers());
    final idx = list.indexWhere((c) => c.id == server.id);
    if (idx < 0) {
      list.add(server);
    } else {
      list[idx] = server;
    }
    await _persist(list);
  }

  @override
  Future<void> deleteServer(String id) async {
    final list = List<ServerConfig>.from(await getServers());
    list.removeWhere((c) => c.id == id);
    await _persist(list);
  }

  @override
  Future<void> updateLastConnected(String id, DateTime at) async {
    final list = List<ServerConfig>.from(await getServers());
    final idx = list.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(lastConnectedAt: at);
    await _persist(list);
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final list = List<ServerConfig>.from(await getServers());
    final idx = list.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(isFavorite: !list[idx].isFavorite);
    await _persist(list);
  }

  /// Product extension — used by Settings "reset all data".
  Future<void> clearAll() async {
    final removed = await _prefs.remove(storageKey);
    if (!removed) {
      throw StateError('server_storage.persist_failed');
    }
    _cache = <ServerConfig>[];
  }

  Future<void> _persist(List<ServerConfig> list) async {
    final raw = jsonEncode(list.map((c) => c.toJson()).toList());
    final ok = await _prefs.setString(storageKey, raw);
    if (!ok) {
      throw StateError('server_storage.persist_failed');
    }
    _cache = list;
  }
}
