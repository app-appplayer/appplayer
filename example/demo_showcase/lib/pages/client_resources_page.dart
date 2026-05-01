/// Client resources showcase — demonstrates the server → client trust
/// boundary (MCP UI DSL v1.1, FR-V11-*). Every section issues a
/// `client.*` action from the server's DSL; the client runtime gates
/// each on the page-level `permissions` block and binds the result
/// back into state. All chrome uses theme slots so the page reads
/// cleanly in both light and dark modes.
Map<String, dynamic> clientResourcesPage() => {
      'type': 'page',
      'version': '1.1',
      'metadata': {
        'title': 'Client Resources',
        'description':
            'Server-initiated use of client-side capabilities (v1.1)',
      },
      // Permissions are declared at the application root (see
      // `_appDefinition` in `bin/server.dart`). The runtime parses
      // that into the `PermissionsConfig` shared across every page;
      // this page inherits it without a local declaration.
      'state': {
        'initial': {
          // System info
          'sysInfo': <String, dynamic>{},
          'sysStatus': 'Not fetched',
          // Clipboard
          'clipInput': '',
          'clipReadback': '',
          'clipStatus': 'Idle',
          // HTTP request
          'httpResponse': '',
          'httpStatus': 'Not called',
          // File picker / read
          'pickedFilePath': '',
          'fileContent': '',
          'fileStatus': 'No file',
          // Client-side storage
          'storageKey': 'demo.note',
          'storageValue': '',
          'storageReadback': '',
          'storageStatus': 'Idle',
          // Notification
          'notifyMessage': 'Hello from the server',
          'notifyStatus': 'Idle',
        },
      },
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 20,
          'children': [
            _intro(),
            _systemInfoCard(),
            _clipboardCard(),
            _httpCard(),
            _fileCard(),
            _storageCard(),
            _notificationCard(),
            {'type': 'sizedBox', 'height': 24},
          ],
        },
      },
    };

Map<String, dynamic> _intro() => _cardShell(
      title: 'About this page',
      titleColor: 'primary',
      children: [
        {
          'type': 'text',
          'text':
              'Each section below fires a `client.*` action. The runtime checks '
                  'the permission declared on this page, then prompts for '
                  'consent before touching your machine. Results are bound back '
                  'into this page\'s state so every capability is visible as a '
                  'pure data flow.',
          'style': {'fontSize': 13, 'color': 'onSurface'},
        },
      ],
    );

// ── System info ────────────────────────────────────────────────────────────

Map<String, dynamic> _systemInfoCard() => _cardShell(
      title: 'client.getSystemInfo',
      children: [
        {
          'type': 'text',
          'text':
              'Reads platform, architecture, memory, and CPU count from the host.',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'linear',
          'direction': 'horizontal',
          'spacing': 8,
          'children': [
            {
              'type': 'button',
              'label': 'Fetch system info',
              'variant': 'filled',
              'onTap': {
                'type': 'client.getSystemInfo',
                // Empty / omitted `properties` → executor returns the
                // full info map (platform, arch, device, model,
                // osVersion, locale). Filtering is optional and
                // platform-aware.
                'params': {},
                'onSuccess': {
                  'type': 'batch',
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'sysInfo',
                      'value': '{{response}}',
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'sysStatus',
                      'value': 'Received',
                    },
                  ],
                },
                'onError': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'sysStatus',
                  'value': 'Error: {{error.message}}',
                },
              },
            },
          ],
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'text',
          'text': 'Status: {{sysStatus}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
        },
        {
          'type': 'text',
          'text':
              'Platform: {{sysInfo.platform}}\nArch: {{sysInfo.arch}}\n'
                  'Device: {{sysInfo.device}}\nModel: {{sysInfo.model}}\n'
                  'OS: {{sysInfo.osVersion}}\nLocale: {{sysInfo.locale}}',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
      ],
    );

// ── Clipboard ──────────────────────────────────────────────────────────────

Map<String, dynamic> _clipboardCard() => _cardShell(
      title: 'client.clipboard',
      children: [
        {
          'type': 'text',
          'text':
              'Write the input text to the OS clipboard, then read it back.',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'textInput',
          'label': 'Text to copy',
          'placeholder': 'Type something',
          'binding': 'clipInput',
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'linear',
          'direction': 'horizontal',
          'spacing': 8,
          'children': [
            {
              'type': 'button',
              'label': 'Copy to clipboard',
              'variant': 'filled',
              'onTap': {
                'type': 'client.clipboard',
                'params': {'action': 'write', 'content': '{{clipInput}}'},
                'onSuccess': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'clipStatus',
                  'value': 'Copied',
                },
              },
            },
            {
              'type': 'button',
              'label': 'Read back',
              'variant': 'outlined',
              'onTap': {
                'type': 'client.clipboard',
                'params': {'action': 'read'},
                'onSuccess': {
                  'type': 'batch',
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'clipReadback',
                      'value': '{{response.content}}',
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'clipStatus',
                      'value': 'Read',
                    },
                  ],
                },
              },
            },
          ],
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'text',
          'text': 'Status: {{clipStatus}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
        },
        {
          'type': 'text',
          'text': 'Readback: {{clipReadback}}',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
      ],
    );

// ── HTTP request ───────────────────────────────────────────────────────────

Map<String, dynamic> _httpCard() => _cardShell(
      title: 'client.httpRequest',
      children: [
        {
          'type': 'text',
          'text':
              'Client executes the HTTP call and streams the body back into state.',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'button',
          'label': 'GET httpbin.org/get',
          'variant': 'filled',
          'onTap': {
            'type': 'client.httpRequest',
            'params': {
              'url': 'https://httpbin.org/get',
              'method': 'GET',
              'headers': {'Accept': 'application/json'},
            },
            'onSuccess': {
              'type': 'batch',
              'actions': [
                {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'httpResponse',
                  'value': '{{response.data}}',
                },
                {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'httpStatus',
                  'value': 'HTTP {{response.status}} {{response.statusText}}',
                },
              ],
            },
            'onError': {
              'type': 'state',
              'action': 'set',
              'binding': 'httpStatus',
              'value': 'Error: {{error.message}}',
            },
          },
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'text',
          'text': 'Status: {{httpStatus}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
        },
        {
          'type': 'text',
          'text': 'Body: {{httpResponse}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
          'maxLines': 6,
        },
      ],
    );

// ── File picker + read ─────────────────────────────────────────────────────

Map<String, dynamic> _fileCard() => _cardShell(
      title: 'client.selectFile + client.readFile',
      children: [
        {
          'type': 'text',
          'text':
              'Open a system file picker, then read the chosen file as UTF-8.',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'button',
          'label': 'Pick & read file',
          'variant': 'filled',
          'onTap': {
            'type': 'client.selectFile',
            'params': {
              'title': 'Pick any small text file',
              'multiple': false,
            },
            'onSuccess': {
              'type': 'batch',
              'actions': [
                {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'pickedFilePath',
                  'value': '{{response.path}}',
                },
                {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'fileStatus',
                  'value': 'Picked',
                },
                {
                  'type': 'client.readFile',
                  'params': {
                    'path': '{{response.path}}',
                    'encoding': 'utf-8',
                  },
                  'onSuccess': {
                    'type': 'batch',
                    'actions': [
                      {
                        'type': 'state',
                        'action': 'set',
                        'binding': 'fileContent',
                        'value': '{{response.content}}',
                      },
                      {
                        'type': 'state',
                        'action': 'set',
                        'binding': 'fileStatus',
                        'value': 'Read {{response.size}} bytes',
                      },
                    ],
                  },
                },
              ],
            },
            'onError': {
              'type': 'state',
              'action': 'set',
              'binding': 'fileStatus',
              'value': 'Cancelled or error',
            },
          },
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'text',
          'text': 'Path: {{pickedFilePath}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
        },
        {
          'type': 'text',
          'text': 'Status: {{fileStatus}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
        },
        {
          'type': 'text',
          'text': 'Content: {{fileContent}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
          'maxLines': 8,
        },
      ],
    );

// ── Client storage (key/value) ─────────────────────────────────────────────

Map<String, dynamic> _storageCard() => _cardShell(
      title: 'client.storage.{set,get}',
      children: [
        {
          'type': 'text',
          'text':
              'Persist a value on the client — survives page reloads until '
                  'the user clears local storage.',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'textInput',
          'label': 'Value to store',
          'placeholder': 'Anything',
          'binding': 'storageValue',
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'linear',
          'direction': 'horizontal',
          'spacing': 8,
          'children': [
            {
              'type': 'button',
              'label': 'Save',
              'variant': 'filled',
              'onTap': {
                'type': 'client.storage.set',
                'params': {
                  'key': '{{storageKey}}',
                  'value': '{{storageValue}}',
                },
                'onSuccess': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'storageStatus',
                  'value': 'Saved',
                },
              },
            },
            {
              'type': 'button',
              'label': 'Load',
              'variant': 'outlined',
              'onTap': {
                'type': 'client.storage.get',
                'params': {'key': '{{storageKey}}'},
                'onSuccess': {
                  'type': 'batch',
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'storageReadback',
                      'value': '{{response.value}}',
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'storageStatus',
                      'value': 'Loaded',
                    },
                  ],
                },
              },
            },
            {
              'type': 'button',
              'label': 'Remove',
              'variant': 'outlined',
              'onTap': {
                'type': 'client.storage.remove',
                'params': {'key': '{{storageKey}}'},
                'onSuccess': {
                  'type': 'batch',
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'storageReadback',
                      'value': '',
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'storageStatus',
                      'value': 'Removed',
                    },
                  ],
                },
              },
            },
          ],
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'text',
          'text': 'Key: {{storageKey}} — status: {{storageStatus}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
        },
        {
          'type': 'text',
          'text': 'Readback: {{storageReadback}}',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
      ],
    );

// ── System notification ────────────────────────────────────────────────────

Map<String, dynamic> _notificationCard() => _cardShell(
      title: 'client.notification',
      children: [
        {
          'type': 'text',
          'text':
              'Post an OS-level notification. Implementation routes to the '
                  'platform notification centre (macOS / Windows / Linux / Web).',
          'style': {'fontSize': 12, 'color': 'onSurface'},
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'textInput',
          'label': 'Message',
          'binding': 'notifyMessage',
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'button',
          'label': 'Send notification',
          'variant': 'filled',
          'onTap': {
            'type': 'client.notification',
            'params': {
              'title': 'MCP UI Showcase',
              'body': '{{notifyMessage}}',
            },
            'onSuccess': {
              'type': 'state',
              'action': 'set',
              'binding': 'notifyStatus',
              'value': 'Dispatched',
            },
            'onError': {
              'type': 'state',
              'action': 'set',
              'binding': 'notifyStatus',
              'value': 'Error: {{error.message}}',
            },
          },
        },
        {'type': 'sizedBox', 'height': 8},
        {
          'type': 'text',
          'text': 'Status: {{notifyStatus}}',
          'style': {'fontSize': 11, 'color': 'onSurface'},
        },
      ],
    );

// ── Shared card chrome ─────────────────────────────────────────────────────

Map<String, dynamic> _cardShell({
  required String title,
  required List<Map<String, dynamic>> children,
  String titleColor = 'primary',
}) =>
    {
      'type': 'card',
      'child': {
        'type': 'box',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 6,
          'alignment': 'start',
          'children': [
            {
              'type': 'text',
              'text': title,
              'style': {
                'fontSize': 16,
                'fontWeight': 'bold',
                'color': titleColor,
              },
            },
            {'type': 'divider'},
            ...children,
          ],
        },
      },
    };
