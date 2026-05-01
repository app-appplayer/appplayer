/// Advanced widgets showcase: canvas, animatedContainer, chart, dataTable.
Map<String, dynamic> advancedPage() => {
      'type': 'page',
      'metadata': {'title': 'Advanced', 'description': 'Advanced widget showcase'},
      'state': {
        'initial': {
          'expanded': false,
          'progress': 0.65,
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
            _section('canvas (v1.3)'),
            {
              'type': 'canvas',
              'width': 280,
              'height': 150,
              'backgroundColor': 'surface',
              'commands': [
                {'op': 'rect', 'x': 10, 'y': 10, 'width': 80, 'height': 60, 'fill': 'primary', 'cornerRadius': 8},
                {'op': 'circle', 'cx': 160, 'cy': 40, 'radius': 30, 'fill': 'secondary'},
                {'op': 'line', 'x1': 10, 'y1': 90, 'x2': 270, 'y2': 90, 'stroke': 'outlineVariant', 'strokeWidth': 2},
                {'op': 'text', 'text': 'Canvas drawing', 'x': 10, 'y': 120, 'fontSize': 14, 'color': 'onSurface'},
                {'op': 'arc', 'cx': 240, 'cy': 40, 'radius': 25, 'startAngle': 0, 'endAngle': 4.2, 'stroke': '#4CAF50', 'strokeWidth': 4, 'strokeCap': 'round'},
              ],
            },

            _section('animatedContainer'),
            {
              'type': 'animatedContainer',
              'duration': 300,
              'curve': 'easeInOut',
              'width': '{{expanded ? 280 : 140}}',
              'height': '{{expanded ? 100 : 50}}',
              'decoration': {
                'color': '{{expanded ? "secondary" : "primary"}}',
                'borderRadius': 8,
              },
              'child': {
                'type': 'center',
                'child': {
                  'type': 'text',
                  'text': '{{expanded ? "Expanded!" : "Tap to expand"}}',
                  'style': {'color': '#FFFFFF', 'fontWeight': 'bold'},
                },
              },
            },
            {
              'type': 'button',
              'label': 'Toggle size',
              'variant': 'outlined',
              'onTap': {'type': 'state', 'action': 'toggle', 'binding': 'expanded'},
            },

            _section('opacity (v1.3)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 16,
              'children': [
                {
                  'type': 'opacity',
                  'opacity': 1.0,
                  'child': _colorBox('primary', '100%'),
                },
                {
                  'type': 'opacity',
                  'opacity': 0.6,
                  'child': _colorBox('primary', '60%'),
                },
                {
                  'type': 'opacity',
                  'opacity': 0.3,
                  'child': _colorBox('primary', '30%'),
                },
              ],
            },

            _section('transform (v1.3)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 24,
              'children': [
                {
                  'type': 'transform',
                  'rotate': 0.3,
                  'child': _colorBox('secondary', 'Rot'),
                },
                {
                  'type': 'transform',
                  'scale': 1.2,
                  'child': _colorBox('#4CAF50', 'Scale'),
                },
              ],
            },

            _section('markdown'),
            {
              'type': 'card',
              'child': {
                'type': 'box',
                'padding': {'all': 12},
                'child': {
                  'type': 'markdown',
                  'text': '# Heading\n\n**Bold** and *italic* text.\n\n- Item 1\n- Item 2\n\n`inline code`',
                },
              },
            },

            _section('dataTable'),
            {
              'type': 'dataTable',
              'columns': [
                {'key': 'name', 'label': 'Name'},
                {'key': 'type', 'label': 'Type'},
                {'key': 'version', 'label': 'Version'},
              ],
              'rows': [
                {'name': 'Flutter', 'type': 'Framework', 'version': '3.10'},
                {'name': 'Dart', 'type': 'Language', 'version': '3.0'},
                {'name': 'MCP UI DSL', 'type': 'Spec', 'version': '1.3'},
              ],
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

Map<String, dynamic> _colorBox(String color, String label) => {
      'type': 'box',
      'width': 60,
      'height': 60,
      'decoration': {'color': color, 'borderRadius': 8},
      'child': {
        'type': 'center',
        'child': {
          'type': 'text',
          'text': label,
          'style': {'color': '#FFFFFF', 'fontSize': 12, 'fontWeight': 'bold'},
        },
      },
    };
