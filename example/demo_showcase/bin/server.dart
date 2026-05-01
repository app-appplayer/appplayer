import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

import '../lib/theme/showcase_theme.dart';
import '../lib/tools/showcase_tools.dart';
import '../lib/pages/layout_page.dart';
import '../lib/pages/display_page.dart';
import '../lib/pages/input_page.dart';
import '../lib/pages/list_page.dart';
import '../lib/pages/advanced_page.dart';
import '../lib/pages/realtime_page.dart';
import '../lib/pages/dialog_page.dart';
import '../lib/pages/form_page.dart';
import '../lib/pages/interactive_page.dart';
import '../lib/pages/dashboard_page.dart';
import '../lib/pages/scroll_page.dart';
import '../lib/pages/navigation_page.dart';
import '../lib/pages/charts_page.dart';
import '../lib/pages/dev_page.dart';
import '../lib/pages/media_page.dart';
import '../lib/pages/client_resources_page.dart';

void main() async {
  try {
    const config = McpServerConfig(
      name: 'MCP UI Showcase',
      version: '1.0.0',
      capabilities: ServerCapabilities(
        tools: ToolsCapability(listChanged: true),
        resources: ResourcesCapability(listChanged: true, subscribe: true),
        logging: LoggingCapability(),
      ),
      enableDebugLogging: false,
    );

    final server = McpServer.createServer(config);

    final state = ShowcaseState();
    final realtime = RealtimeManager(server);

    // Register tools and resources BEFORE connecting the stdio
    // transport. With `tools.listChanged` / `resources.listChanged` set
    // in capabilities, every `addResource` / `addTool` emits a
    // `notifications/*/list_changed` JSON-RPC frame. If the transport
    // is connected first, those frames flood stdout before the client's
    // initialize response — corrupting the handshake (clients reject
    // the connection or treat partial frames as errors).
    registerShowcaseTools(server, state);
    _registerPages(server, state, realtime);
    realtime.registerResources();
    realtime.registerTools();

    final transport = McpServer.createStdioTransport().get();
    server.connect(transport);

    // Kick the stream timer AFTER the transport is up so the first
    // notifyResourceUpdated frame travels through a connected sink
    // (and arrives after the initialize response).
    realtime.startSimulation();

    // Exit when the stdio transport closes (stdin EOF = client
    // disconnected). Waiting on a bare Completer would leak the
    // subprocess forever.
    await transport.onClose;
  } catch (e, st) {
    stderr.writeln('Error: $e\n$st');
    exit(1);
  }
}

void _registerPages(Server server, ShowcaseState state, RealtimeManager realtime) {
  // Application definition
  server.addResource(
    uri: 'ui://app',
    name: 'UI Showcase',
    description: 'MCP UI DSL widget showcase',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, _appDefinition(realtime)),
  );

  // Well-known app metadata (spec §11.6). Launchers read this before
  // (or alongside) ui://app to render icon / description / publisher
  // without having to materialise the full application definition.
  server.addResource(
    uri: 'ui://app/info',
    name: 'App Info',
    description: 'Lightweight application metadata (§11.6)',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, _appInfo()),
  );

  // Individual pages
  server.addResource(
    uri: 'ui://pages/layout',
    name: 'Layout',
    description: 'Layout widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, layoutPage()),
  );

  server.addResource(
    uri: 'ui://pages/display',
    name: 'Display',
    description: 'Display widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, displayPage()),
  );

  server.addResource(
    uri: 'ui://pages/input',
    name: 'Input',
    description: 'Input widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, inputPage()),
  );

  server.addResource(
    uri: 'ui://pages/list',
    name: 'List & Grid',
    description: 'List and grid widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, listPage()),
  );

  server.addResource(
    uri: 'ui://pages/advanced',
    name: 'Advanced',
    description: 'Advanced widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, advancedPage()),
  );

  server.addResource(
    uri: 'ui://pages/dialog',
    name: 'Dialog',
    description: 'Dialog widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, dialogPage()),
  );

  server.addResource(
    uri: 'ui://pages/form',
    name: 'Form',
    description: 'Form widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, formPage()),
  );

  server.addResource(
    uri: 'ui://pages/interactive',
    name: 'Interactive',
    description: 'Interactive widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, interactivePage()),
  );

  server.addResource(
    uri: 'ui://pages/realtime',
    name: 'Realtime',
    description: 'Realtime subscription showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(
        uri, realtimePage(realtime.toolTemperature, realtime.streamTemperature)),
  );

  server.addResource(
    uri: 'ui://pages/scroll',
    name: 'Scroll & Utility',
    description: 'Scroll and utility widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, scrollPage()),
  );

  server.addResource(
    uri: 'ui://pages/navigation',
    name: 'Navigation',
    description: 'Navigation widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, navigationPage()),
  );

  server.addResource(
    uri: 'ui://pages/charts',
    name: 'Charts',
    description: 'Chart and data-viz widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, chartsPage()),
  );

  server.addResource(
    uri: 'ui://pages/dev',
    name: 'Dev Tools',
    description: 'Developer widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, devPage()),
  );

  server.addResource(
    uri: 'ui://pages/media',
    name: 'Media',
    description: 'Media and misc widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, mediaPage()),
  );

  server.addResource(
    uri: 'ui://pages/client-resources',
    name: 'Client Resources',
    description: 'Server-initiated use of client capabilities (v1.1)',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, clientResourcesPage()),
  );
}

Map<String, dynamic> _appInfo() => {
      'id': 'com.mcp.demo_ui',
      'name': 'UI Showcase',
      'version': '1.0.0',
      'description':
          'MCP UI DSL widget showcase — layout, input, forms, charts, '
              'realtime streams, and dev tools.',
      'icon':
          'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg',
      'category': 'developer',
      'publisher': {
        'name': 'MCP Demo',
        'website': 'https://modelcontextprotocol.io',
      },
      'timestamps': {
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-04-20T00:00:00Z',
      },
    };

Map<String, dynamic> _appDefinition(RealtimeManager realtime) => {
      'type': 'application',
      'title': 'UI Showcase',
      'version': '1.0.0',
      'initialRoute': '/layout',
      'theme': showcaseTheme(),
      // Runtime parses `permissions` only at the application root
      // today (runtime_engine.dart wires `PermissionsConfig` from
      // `_parsedUIDefinition.permissions`). Declare the superset any
      // showcase page might need here. The Client Resources page
      // exercises each surface.
      'permissions': {
        'file.read': {
          'allowedPaths': ['*'],
        },
        'file.write': {
          'allowedPaths': ['*'],
          'requireConfirmation': true,
        },
        'network.http': {
          'allowedDomains': ['*'],
        },
        'system.clipboard': true,
        'system.info': true,
        'notification': true,
      },
      // 'dashboard' intentionally omitted to exercise the spec §11.9.1
      // fallback path in launchers (icon-only tile in dashboard slots).
      'navigation': {
        'type': 'drawer',
        'items': [
          {'title': 'Layout', 'icon': 'dashboard', 'route': '/layout'},
          {'title': 'Display', 'icon': 'text_fields', 'route': '/display'},
          {'title': 'Input', 'icon': 'touch_app', 'route': '/input'},
          {'title': 'Form', 'icon': 'assignment', 'route': '/form'},
          {'title': 'List & Grid', 'icon': 'list', 'route': '/list'},
          {'title': 'Dialog', 'icon': 'chat_bubble', 'route': '/dialog'},
          {'title': 'Interactive', 'icon': 'pan_tool', 'route': '/interactive'},
          {'title': 'Scroll & Utility', 'icon': 'swap_vert', 'route': '/scroll'},
          {'title': 'Navigation', 'icon': 'menu', 'route': '/navigation'},
          {'title': 'Charts', 'icon': 'bar_chart', 'route': '/charts'},
          {'title': 'Dev Tools', 'icon': 'code', 'route': '/dev'},
          {'title': 'Media', 'icon': 'play_circle', 'route': '/media'},
          {'title': 'Advanced', 'icon': 'auto_awesome', 'route': '/advanced'},
          {'title': 'Realtime', 'icon': 'sensors', 'route': '/realtime'},
          {
            'title': 'Client Resources',
            'icon': 'extension',
            'route': '/client-resources'
          },
        ],
      },
      'routes': {
        '/layout': 'ui://pages/layout',
        '/display': 'ui://pages/display',
        '/input': 'ui://pages/input',
        '/form': 'ui://pages/form',
        '/list': 'ui://pages/list',
        '/dialog': 'ui://pages/dialog',
        '/interactive': 'ui://pages/interactive',
        '/scroll': 'ui://pages/scroll',
        '/navigation': 'ui://pages/navigation',
        '/charts': 'ui://pages/charts',
        '/dev': 'ui://pages/dev',
        '/media': 'ui://pages/media',
        '/advanced': 'ui://pages/advanced',
        '/realtime': 'ui://pages/realtime',
        '/client-resources': 'ui://pages/client-resources',
      },
      'state': {
        'initial': {
          'appName': 'MCP UI Showcase',
          'temperature': realtime.streamTemperature,
          'status': 'Online',
        },
      },
    };

ReadResourceResult _json(String uri, Map<String, dynamic> data) =>
    ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode(data),
        ),
      ],
    );
