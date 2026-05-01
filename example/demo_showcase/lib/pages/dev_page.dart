/// Developer-focused widgets showcase: codeEditor, terminal, fileExplorer,
/// tree, graph, networkGraph, markdown (extended).
Map<String, dynamic> devPage() => {
      'type': 'page',
      'metadata': {'title': 'Dev Tools', 'description': 'Developer-oriented widgets'},
      'state': {
        'initial': {
          'codeSource': '// Edit me\nvoid main() {\n  print(\'hello\');\n}',
          'termHistory': ['\$ echo hello', 'hello', '\$ date', '2026-04-19'],
        },
      },
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 16,
          'children': [
            _section('markdown'),
            {
              'type': 'card',
              'child': {
                'type': 'box',
                'padding': {'all': 12},
                'child': {
                  'type': 'markdown',
                  'text': '# Heading\n\n**Bold** and *italic*.\n\n- Bullet A\n- Bullet B\n\n```dart\nvoid main() {}\n```',
                },
              },
            },

            _section('codeEditor'),
            {
              'type': 'box',
              'height': 180,
              'child': {
                'type': 'codeEditor',
                'binding': 'codeSource',
                'language': 'dart',
                'showLineNumbers': true,
              },
            },

            _section('terminal'),
            {
              'type': 'box',
              'height': 160,
              'child': {
                'type': 'terminal',
                'lines': '{{termHistory}}',
                'prompt': '\$ ',
              },
            },

            _section('fileExplorer'),
            {
              'type': 'box',
              'height': 200,
              'child': {
                'type': 'fileExplorer',
                'items': [
                  {
                    'name': 'src',
                    'type': 'folder',
                    'children': [
                      {'name': 'main.dart', 'type': 'file'},
                      {'name': 'utils.dart', 'type': 'file'},
                    ],
                  },
                  {
                    'name': 'test',
                    'type': 'folder',
                    'children': [
                      {'name': 'main_test.dart', 'type': 'file'},
                    ],
                  },
                  {'name': 'pubspec.yaml', 'type': 'file'},
                  {'name': 'README.md', 'type': 'file'},
                ],
                'showIcons': true,
              },
            },

            _section('tree'),
            {
              'type': 'box',
              'height': 220,
              'child': {
                'type': 'tree',
                'initiallyExpanded': true,
                'itemPadding': {'vertical': 1, 'right': 8},
                'data': [
                  {
                    'id': 'root',
                    'label': 'Project',
                    'children': [
                      {'id': 'a', 'label': 'app', 'children': [
                        {'id': 'a1', 'label': 'main.dart'},
                        {'id': 'a2', 'label': 'widgets'},
                      ]},
                      {'id': 'b', 'label': 'lib'},
                      {'id': 'c', 'label': 'test'},
                    ],
                  },
                ],
              },
            },

            _section('graph (time-series line chart)'),
            {
              'type': 'box',
              'height': 200,
              'child': {
                'type': 'graph',
                'chartType': 'line',
                'data': [
                  {'x': 0, 'y': 12},
                  {'x': 1, 'y': 19},
                  {'x': 2, 'y': 8},
                  {'x': 3, 'y': 24},
                  {'x': 4, 'y': 16},
                ],
                'lineColor': 'primary',
              },
            },

            _section('networkGraph (nodes + edges)'),
            {
              'type': 'box',
              'height': 200,
              'child': {
                'type': 'networkGraph',
                'backgroundColor': 'surface',
                'nodes': [
                  {'id': 'n1', 'label': 'A'},
                  {'id': 'n2', 'label': 'B'},
                  {'id': 'n3', 'label': 'C'},
                  {'id': 'n4', 'label': 'D'},
                ],
                'edges': [
                  {'source': 'n1', 'target': 'n2'},
                  {'source': 'n1', 'target': 'n3'},
                  {'source': 'n2', 'target': 'n4'},
                  {'source': 'n3', 'target': 'n4'},
                ],
              },
            },

            _section('networkGraph'),
            {
              'type': 'box',
              'height': 220,
              'child': {
                'type': 'networkGraph',
                'backgroundColor': 'surface',
                'nodes': [
                  {'id': 'srv', 'label': 'server'},
                  {'id': 'db', 'label': 'db'},
                  {'id': 'cache', 'label': 'cache'},
                  {'id': 'c1', 'label': 'client-1'},
                  {'id': 'c2', 'label': 'client-2'},
                ],
                'edges': [
                  {'source': 'c1', 'target': 'srv'},
                  {'source': 'c2', 'target': 'srv'},
                  {'source': 'srv', 'target': 'db'},
                  {'source': 'srv', 'target': 'cache'},
                ],
              },
            },

            {'type': 'sizedBox', 'height': 24},
          ],
        },
      },
    };

Map<String, dynamic> _section(String title) => {
      'type': 'text',
      'text': title,
      'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': 'primary'},
    };
