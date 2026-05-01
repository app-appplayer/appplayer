/// Chart-family widgets showcase (§10): chart (bar/line/pie), gauge,
/// timeline, calendar, heatmap.
Map<String, dynamic> chartsPage() => {
      'type': 'page',
      'metadata': {'title': 'Charts', 'description': 'Chart and data-viz widgets'},
      'state': {
        'initial': {
          'selectedDate': '2026-04-15',
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
            _section('chart (bar)'),
            {
              'type': 'box',
              'height': 200,
              'child': {
                'type': 'chart',
                'backgroundColor': 'surface',
                'chartType': 'bar',
                'data': {
                  'labels': ['Jan', 'Feb', 'Mar', 'Apr', 'May'],
                  'datasets': [
                    {
                      'label': 'Sales',
                      'data': [12, 19, 8, 15, 22],
                      'color': 'primary',
                    }
                  ],
                },
              },
            },

            _section('chart (line)'),
            {
              'type': 'box',
              'height': 200,
              'child': {
                'type': 'chart',
                'backgroundColor': 'surface',
                'chartType': 'line',
                'data': {
                  'labels': ['M', 'T', 'W', 'T', 'F'],
                  'datasets': [
                    {
                      'label': 'Visitors',
                      'data': [120, 180, 150, 210, 260],
                      'color': '#4CAF50',
                    }
                  ],
                },
              },
            },

            _section('chart (pie)'),
            {
              'type': 'box',
              'height': 240,
              'child': {
                'type': 'chart',
                'backgroundColor': 'surface',
                'chartType': 'pie',
                'colors': ['error', 'primary', '#4CAF50', '#FFC107'],
                'data': {
                  'labels': ['Red', 'Blue', 'Green', 'Amber'],
                  'datasets': [
                    {
                      'label': 'Share',
                      'data': [30, 25, 20, 25],
                    }
                  ],
                },
              },
            },

            _section('gauge'),
            {
              'type': 'box',
              'height': 180,
              'child': {
                'type': 'gauge',
                'backgroundColor': 'surface',
                'value': 72,
                'min': 0,
                'max': 100,
                'label': 'CPU',
                'showValue': true,
              },
            },

            _section('timeline'),
            {
              'type': 'timeline',
              'items': [
                {'time': '09:00', 'title': 'Standup', 'subtitle': 'Daily sync'},
                {'time': '11:30', 'title': 'Review', 'subtitle': 'PR review session'},
                {'time': '14:00', 'title': 'Ship', 'subtitle': 'Deploy to prod'},
              ],
            },

            _section('calendar'),
            {
              'type': 'calendar',
              'backgroundColor': 'surface',
              'selectedDate': '{{selectedDate}}',
              'firstDate': '2026-01-01',
              'lastDate': '2026-12-31',
              'onChange': {
                'type': 'state', 'action': 'set',
                'binding': 'selectedDate', 'value': '{{event.date}}',
              },
            },
            {'type': 'text', 'text': 'Selected: {{selectedDate}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('heatmap'),
            {
              'type': 'box',
              'height': 180,
              'child': {
                'type': 'heatmap',
                'backgroundColor': 'surface',
                'data': [
                  [0.1, 0.4, 0.8, 0.3, 0.6],
                  [0.5, 0.9, 0.2, 0.7, 0.4],
                  [0.3, 0.6, 0.8, 0.1, 0.9],
                  [0.7, 0.2, 0.5, 0.8, 0.3],
                ],
                'colorRange': {'low': '#E3F2FD', 'high': '#0D47A1'},
                'showValues': true,
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
