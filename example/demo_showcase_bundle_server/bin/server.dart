/// Reference MCP server backed by a `.mbd/` bundle directory.
///
/// Demonstrates the canonical bundle-consumer flow:
///
/// 1. Load the bundle via `McpBundleLoader.loadDirectory` — manifest +
///    integrity checked once.
/// 2. Walk the `ui/` reserved folder via `bundle.uiResources` —
///    `mcp_bundle` owns disk I/O, this server only forwards bytes.
/// 3. Map each `ui/<rel>.json` to the `ui://<rel>` resource URI and
///    register a handler that returns the file's raw text.
/// 4. Synthesise `ui://app/info` from the manifest when the bundle
///    does not ship one.
///
/// `dart:io` is used only for the bootstrap path-probe (locating the
/// `.mbd/` directory before the bundle loader is invoked) and the
/// stdio transport. Every bundle file read goes through
/// `bundle.uiResources` so this sample shows the lean, canonical
/// pattern — production consumers may add caching or fallbacks above
/// this surface, but the demo stays one-line per concern.
///
/// Usage:
///   `dart run demo_showcase_bundle_server:server --bundle <path-to-.mbd>`
///   `./server`   (looks for a sibling `.mbd/` next to the binary)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mcp_bundle/mcp_bundle.dart' hide ResourceContent;
import 'package:mcp_server/mcp_server.dart';

Future<void> main(List<String> args) async {
  final bundlePath = _parseBundlePath(args);
  if (bundlePath == null) {
    stderr.writeln(
        'Usage: dart run demo_showcase_bundle_server:server --bundle <path>');
    exit(64);
  }

  final McpBundle bundle;
  try {
    bundle = await McpBundleLoader.loadDirectory(bundlePath);
  } on BundleLoadException catch (e) {
    stderr.writeln('Failed to load bundle at $bundlePath: $e');
    exit(66);
  }

  // Enumerate UI resources via mcp_bundle. `ui/app.json` is sorted
  // first by BundleResources so the launcher's URI selector finds the
  // entry-point resource on the first iteration.
  final uiFiles = await bundle.uiResources.list(extension: '.json');
  if (uiFiles.isEmpty) {
    stderr.writeln('Bundle has no ui/*.json resources at $bundlePath');
    exit(66);
  }

  final config = McpServerConfig(
    name: bundle.manifest.name.isNotEmpty
        ? bundle.manifest.name
        : 'Bundle Server',
    version: bundle.manifest.version,
    capabilities: const ServerCapabilities(
      // `subscribe: true` so the realtime page's resource-stream demo
      // (`data://streamTemperature` notifications) reaches the client.
      resources: ResourcesCapability(listChanged: false, subscribe: true),
      tools: ToolsCapability(listChanged: false),
    ),
    enableDebugLogging: false,
  );
  final server = McpServer.createServer(config);
  final transport = McpServer.createStdioTransport().get();

  final registeredUris = <String>{};
  for (final rel in uiFiles) {
    final uri = _relPathToUri(rel);
    registeredUris.add(uri);
    server.addResource(
      uri: uri,
      // Last path segment is a safe display label — `name: uri` would
      // put "ui://app/info" in the name field, whose "app" substring
      // trips the launcher's name-based fallback heuristic.
      name: _safeName(uri),
      description: 'Bundle-backed UI resource: $uri',
      mimeType: 'application/json',
      handler: (_, __) async {
        final text = await bundle.uiResources.read(rel);
        return _rawJson(uri, text);
      },
    );
  }

  // Fallback: if the bundle does not provide ui/app/info.json, synthesise
  // ui://app/info from manifest.json manifest fields so launchers can read
  // metadata (name / description / icon / publisher) without the bundle
  // author having to mirror the manifest under ui/.
  if (!registeredUris.contains('ui://app/info')) {
    final infoPayload = _appInfoFromManifest(bundle.manifest);
    server.addResource(
      uri: 'ui://app/info',
      name: _safeName('ui://app/info'),
      description: 'Synthesised from manifest.json manifest',
      mimeType: 'application/json',
      handler: (_, __) async => _rawJson('ui://app/info', infoPayload),
    );
  }

  // Realtime primitives — wire the same `getToolTemperature` tool and
  // `data://streamTemperature` resource the native demo_showcase server
  // ships, so the realtime showcase page (`ui/pages/realtime.json`)
  // works through this bundle-backed transport too. The names mirror
  // demo_showcase exactly; the runtime page binds to those URIs.
  final realtime = _RealtimeManager(server);
  realtime.registerResources();
  realtime.registerTools();

  server.connect(transport);

  // Kick the stream timer AFTER the transport is up so the first
  // notifyResourceUpdated frame travels through a connected sink
  // (and arrives after the initialize response).
  realtime.startSimulation();
  try {
    await transport.onClose;
  } finally {
    realtime.dispose();
  }
}

/// Mirror of `RealtimeManager` from
/// `demo_showcase/lib/pages/realtime_page.dart`. Inlined here so the
/// bundle-backed transport delivers the same realtime behaviour as the
/// native server without taking a path dependency on demo_showcase.
class _RealtimeManager {
  _RealtimeManager(this._server);

  final Server _server;
  double _toolTemperature = 20.0;
  double _streamTemperature = 22.0;
  final Random _rng = Random();
  Timer? _streamTimer;

  void registerResources() {
    _server.addResource(
      uri: 'data://streamTemperature',
      name: 'Temperature (stream)',
      description:
          'Push temperature source. JSON: {"streamTemperature": <value>}. '
          'Emits Extended-mode notifications.',
      mimeType: 'application/json',
      handler: (uri, params) async => _readStream(),
    );
  }

  void registerTools() {
    _server.addTool(
      name: 'getToolTemperature',
      description:
          'Read one temperature sample. Response auto-merges into state.',
      inputSchema: const {
        'type': 'object',
        'properties': <String, Object>{},
      },
      handler: (args) async {
        _toolTemperature = _sample();
        return CallToolResult(
          content: [
            TextContent(
              text: jsonEncode({'toolTemperature': _toolTemperature}),
            ),
          ],
        );
      },
    );
  }

  void startSimulation() {
    _streamTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _streamTemperature = _sample();
      _server.notifyResourceUpdated(
        'data://streamTemperature',
        content: ResourceContent(
          uri: 'data://streamTemperature',
          text: '{"streamTemperature": $_streamTemperature}',
          mimeType: 'application/json',
        ),
      );
    });
  }

  void dispose() {
    _streamTimer?.cancel();
  }

  double _sample() {
    final v = 15.0 + _rng.nextDouble() * 20.0;
    return double.parse(v.toStringAsFixed(1));
  }

  ReadResourceResult _readStream() => ReadResourceResult(
        contents: [
          ResourceContentInfo(
            uri: 'data://streamTemperature',
            mimeType: 'application/json',
            text: '{"streamTemperature": $_streamTemperature}',
          ),
        ],
      );
}

/// Synthesise the `ui://app/info` payload from the bundle manifest using
/// the same field shape as the runtime-served demo apps (id / name /
/// version / description / icon / category / publisher).
String _appInfoFromManifest(BundleManifest m) {
  final publisher = m.publisher;
  final info = <String, dynamic>{
    'id': m.id,
    'name': m.name,
    'version': m.version,
    if (m.description != null) 'description': m.description,
    if (m.icon != null) 'icon': m.icon,
    if (m.category != null) 'category': m.category!.name,
    if (publisher != null)
      'publisher': <String, dynamic>{
        'name': publisher.name,
        if (publisher.url != null) 'website': publisher.url,
        if (publisher.email != null) 'email': publisher.email,
      },
  };
  return jsonEncode(info);
}

String? _parseBundlePath(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--bundle' && i + 1 < args.length) return args[i + 1];
    if (a.startsWith('--bundle=')) return a.substring('--bundle='.length);
  }
  // Bootstrap path-probe — the bundle loader needs an absolute path,
  // so we resolve a candidate against a few well-known layouts. This
  // is the ONE place the demo touches `dart:io` for filesystem
  // queries; everything past `loadDirectory` goes through
  // `bundle.uiResources`.
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>[
    '$exeDir/demo_showcase.mbd',
    '${Directory(exeDir).parent.path}/demo_showcase.mbd',
    'os/appplayer/appplayer/dart/example/demo_showcase.mbd',
  ];
  for (final p in candidates) {
    if (Directory(p).existsSync()) return p;
  }
  return null;
}

/// Display-only resource name. Returns the URI's last path segment so
/// the launcher's app-URI selector (`_pickAppUri` in appplayer_core)
/// never sees "app" or "main" inside a non-app resource's `name` field.
/// Example: `ui://app/info` -> `"info"`, `ui://pages/layout` -> `"layout"`.
String _safeName(String uri) {
  final parsed = Uri.tryParse(uri);
  if (parsed == null) return uri;
  if (parsed.pathSegments.isNotEmpty) return parsed.pathSegments.last;
  return parsed.host.isNotEmpty ? parsed.host : uri;
}

/// Convert a `BundleResources.list()` relative path (e.g. `pages/layout.json`)
/// into the `ui://<path>` URI the MCP server advertises. The `.json`
/// suffix is stripped so the URI mirrors the runtime's resource naming.
String _relPathToUri(String relativePath) {
  final stripped = relativePath.endsWith('.json')
      ? relativePath.substring(0, relativePath.length - '.json'.length)
      : relativePath;
  return 'ui://$stripped';
}

ReadResourceResult _rawJson(String uri, String content) {
  // Validate JSON so malformed files surface as a parse error before
  // the client sees garbage — but deliver the original text to
  // preserve formatting / ordering.
  jsonDecode(content);
  return ReadResourceResult(
    contents: [
      ResourceContentInfo(
        uri: uri,
        mimeType: 'application/json',
        text: content,
      ),
    ],
  );
}
