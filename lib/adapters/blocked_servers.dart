import 'dart:convert';

import 'package:appplayer_core/appplayer_core.dart'
    show ServerConfig, TransportType;
import 'package:shared_preferences/shared_preferences.dart';

/// One blocked server address with the name the app had when it was blocked.
class BlockedServer {
  const BlockedServer({required this.address, required this.name});

  /// The normalized address (see [BlockedServers.normalize]).
  final String address;

  /// The app name at the time of blocking, kept so the list is readable.
  final String name;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'address': address, 'name': name};

  static BlockedServer? fromJson(Object? json) {
    if (json is! Map) return null;
    final address = json['address'];
    if (address is! String || address.isEmpty) return null;
    final name = json['name'];
    return BlockedServer(address: address, name: name is String ? name : '');
  }
}

/// Server addresses the person has blocked (FR-HOME-013).
///
/// The list lives on the device only. A blocked address cannot be registered
/// again until the person unblocks it (FR-SET-008). It is separate from the
/// app list on purpose: removing the app must not remove the block.
class BlockedServers {
  BlockedServers(this._prefs);

  /// Loads the list from the shared preferences instance.
  static Future<BlockedServers> open() async =>
      BlockedServers(await SharedPreferences.getInstance());

  /// SharedPreferences key holding the JSON list.
  static const String storageKey = 'blocked_servers.v1';

  final SharedPreferences _prefs;

  /// The blocked servers, oldest first.
  List<BlockedServer> get all {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const <BlockedServer>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <BlockedServer>[];
      return <BlockedServer>[
        for (final item in decoded)
          if (BlockedServer.fromJson(item) case final entry?) entry,
      ];
    } on FormatException {
      return const <BlockedServer>[];
    }
  }

  /// Whether [address] (any spelling of it) is blocked.
  bool isBlocked(String address) {
    final key = normalize(address);
    if (key == null) return false;
    return all.any((b) => b.address == key);
  }

  /// Whether the address of [server] is blocked. A server with no address
  /// (a local process) is never blocked.
  bool isServerBlocked(ServerConfig server) {
    final address = addressOf(server);
    return address != null && isBlocked(address);
  }

  /// Blocks [address]. Blocking an address twice keeps one entry.
  Future<void> block(String address, {required String name}) async {
    final key = normalize(address);
    if (key == null) return;
    final next = <BlockedServer>[
      for (final b in all)
        if (b.address != key) b,
      BlockedServer(address: key, name: name),
    ];
    await _write(next);
  }

  /// Removes the block on [address].
  Future<void> unblock(String address) async {
    final key = normalize(address);
    if (key == null) return;
    await _write(<BlockedServer>[
      for (final b in all)
        if (b.address != key) b,
    ]);
  }

  Future<void> _write(List<BlockedServer> list) async {
    await _prefs.setString(
      storageKey,
      jsonEncode(list.map((b) => b.toJson()).toList()),
    );
  }

  /// The address a server is reached at, or null when it has none (a local
  /// process). Only the network transports have one.
  static String? addressOf(ServerConfig server) {
    final config = server.transportConfig;
    final raw = switch (server.transportType) {
      TransportType.sse => config['serverUrl'] ?? config['url'],
      TransportType.streamableHttp => config['baseUrl'] ?? config['url'],
      TransportType.stdio => null,
    };
    return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  }

  /// The comparison form of an address: scheme and host in lower case, a
  /// trailing `/` ignored, query and fragment dropped. Null when [address]
  /// has no host.
  static String? normalize(String address) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}$port$path';
  }
}
