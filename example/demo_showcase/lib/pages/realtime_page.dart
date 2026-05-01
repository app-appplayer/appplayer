import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:mcp_server/mcp_server.dart';

/// Real-time data page — contrasts the two primitives MCP UI DSL exposes
/// for moving live values into state:
///
///   1. **Tool call (§4.4)** — client invokes an MCP tool; the tool's
///      response is auto-merged into state by top-level key (§3.10). The
///      call is synchronous and client-driven (one-shot button, or
///      periodic via `client.poll`).
///   2. **Resource notification stream (§4.5 + §6.4)** — client subscribes
///      to a resource URI; the server emits
///      `notifications/resources/updated` on every change. The runtime
///      extracts the binding-named key from the notification payload and
///      writes it into state.
///
/// This mirrors the two distinct MCP primitives the spec sanctions:
/// `tools/call` (pull) vs `resources/subscribe` (push).
Map<String, dynamic> realtimePage(double toolInit, double streamInit) => {
      'type': 'page',
      'metadata': {
        'title': 'Realtime',
        'description': 'Tool call vs. resource notification stream',
      },
      'state': {
        'initial': {
          // Tool-call path — populated by `getToolTemperature` response.
          'toolTemperature': toolInit,
          'toolStatus': 'Idle',
          // Subscription path — populated by notification payload.
          'streamTemperature': streamInit,
          'streamStatus': 'Not subscribed',
        },
      },
      // client.poll channel — standard MCP "pseudo-stream" primitive.
      // Every tick, the runtime fires `onData`, which calls the tool;
      // the tool response auto-merges into state (§3.10), simulating a
      // stream of reads on a fixed cadence.
      'channels': {
        'tempPoll': {
          'type': 'client.poll',
          'params': {'interval': 1000},
          'onData': {
            'type': 'tool',
            'tool': 'getToolTemperature',
          },
        },
      },
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 24},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 20,
          'children': [
            {
              'type': 'text',
              'text': 'Realtime primitives',
              'style': {'fontSize': 22, 'fontWeight': 'bold'},
            },
            _toolCard(),
            _streamCard(),
          ],
        },
      },
    };

Map<String, dynamic> _toolCard() => _card(
      title: 'Tool call polling (pseudo-stream)',
      description:
          'Standard MCP has no native streaming — the canonical workaround is client-side periodic tool calls (spec §8.6 client.poll channel). Start polling makes the runtime fire getToolTemperature every 1s; the response `{"toolTemperature": X}` auto-merges into state (§3.10), so the value updates as if it were a stream.',
      valueBinding: 'toolTemperature',
      statusBinding: 'toolStatus',
      primaryLabel: 'Start polling',
      primaryAction: _batchSet(
        {
          'type': 'channel',
          'action': 'start',
          'channel': 'tempPoll',
        },
        'toolStatus',
        'Polling every 1s',
      ),
      secondaryLabel: 'Stop polling',
      secondaryAction: _batchSet(
        {
          'type': 'channel',
          'action': 'stop',
          'channel': 'tempPoll',
        },
        'toolStatus',
        'Idle',
      ),
    );

Map<String, dynamic> _streamCard() => _card(
      title: 'Notification stream (makemind extension)',
      description:
          'Real server-push stream via the mcp_client notifications extension. Subscribe to data://streamTemperature — server emits notifications/resources/updated with URI + content every second. Runtime writes parsed["streamTemperature"] into the streamTemperature binding without polling.',
      valueBinding: 'streamTemperature',
      statusBinding: 'streamStatus',
      primaryLabel: 'Subscribe',
      primaryAction: _batchSet(
        {
          'type': 'resource',
          'action': 'subscribe',
          'uri': 'data://streamTemperature',
          'binding': 'streamTemperature',
        },
        'streamStatus',
        'Subscribed',
      ),
      secondaryLabel: 'Unsubscribe',
      secondaryAction: _batchSet(
        {
          'type': 'resource',
          'action': 'unsubscribe',
          'uri': 'data://streamTemperature',
        },
        'streamStatus',
        'Not subscribed',
      ),
    );

Map<String, dynamic> _batchSet(
  Map<String, dynamic> primary,
  String statusBinding,
  String statusValue,
) =>
    {
      'type': 'batch',
      'actions': [
        primary,
        {
          'type': 'state',
          'action': 'set',
          'binding': statusBinding,
          'value': statusValue,
        },
      ],
    };

Map<String, dynamic> _card({
  required String title,
  required String description,
  required String valueBinding,
  required String statusBinding,
  required String primaryLabel,
  required Map<String, dynamic> primaryAction,
  required String secondaryLabel,
  required Map<String, dynamic> secondaryAction,
}) =>
    {
      'type': 'card',
      'child': {
        'type': 'box',
        'padding': {'all': 20},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 10,
          'alignment': 'start',
          'children': [
            {
              'type': 'text',
              'text': title,
              'style': {'fontSize': 16, 'fontWeight': 'bold'},
            },
            {
              'type': 'text',
              'text': description,
              'style': {'fontSize': 12, 'color': 'onSurface'},
            },
            {
              'type': 'text',
              'text': '{{$valueBinding}}°C',
              'style': {
                'fontSize': 36,
                'fontWeight': 'bold',
                'color': 'primary',
              },
            },
            {
              'type': 'text',
              'text': 'Status: {{$statusBinding}}',
              'style': {'fontSize': 12, 'color': 'onSurface'},
            },
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 8,
              'children': [
                {
                  'type': 'button',
                  'label': primaryLabel,
                  'variant': 'filled',
                  'onTap': primaryAction,
                },
                {
                  'type': 'button',
                  'label': secondaryLabel,
                  'variant': 'outlined',
                  'onTap': secondaryAction,
                },
              ],
            },
          ],
        },
      },
    };

/// Wires the two realtime primitives the page needs:
///
/// - **Tool path**: `getToolTemperature` tool. Each call samples a fresh
///   value and returns `{"toolTemperature": <value>}`. Auto-merge (§3.10)
///   writes `toolTemperature` into page state on success.
/// - **Stream path**: `data://streamTemperature` resource. A server-side
///   timer pushes Extended-mode notifications every second; the subscribe
///   action routes payloads into the `streamTemperature` state binding.
class RealtimeManager {
  RealtimeManager(this.server);
  final Server server;
  double toolTemperature = 20.0;
  double streamTemperature = 22.0;
  final Random _rng = Random();
  Timer? _streamTimer;

  void registerResources() {
    // Resource for the subscription / notification stream path.
    server.addResource(
      uri: 'data://streamTemperature',
      name: 'Temperature (stream)',
      description:
          'Push temperature source. JSON: {"streamTemperature": <value>}. Emits Extended-mode notifications.',
      mimeType: 'application/json',
      handler: (uri, params) async => _readStream(),
    );
  }

  void registerTools() {
    // Tool for the pull path. Resamples on every call so the client sees
    // a fresh value each invocation.
    server.addTool(
      name: 'getToolTemperature',
      description:
          'Read one temperature sample. Response auto-merges into state.',
      inputSchema: const {
        'type': 'object',
        'properties': <String, Object>{},
      },
      handler: (args) async {
        toolTemperature = _sample();
        return CallToolResult(
          content: [
            TextContent(
              text: jsonEncode({'toolTemperature': toolTemperature}),
            ),
          ],
        );
      },
    );
  }

  void startSimulation() {
    _streamTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      streamTemperature = _sample();
      server.notifyResourceUpdated(
        'data://streamTemperature',
        content: ResourceContent(
          uri: 'data://streamTemperature',
          text: '{"streamTemperature": $streamTemperature}',
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
            text: '{"streamTemperature": $streamTemperature}',
          ),
        ],
      );
}
