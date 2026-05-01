/// Dashboard entry point showcase (v1.3).
/// Demonstrates compact rendering for multi-app contexts.
Map<String, dynamic> dashboardDefinition() => {
      'content': {
        'type': 'linear',
        'direction': 'vertical',
        'spacing': 4,
        'children': [
          {
            'type': 'text',
            'text': '{{app.title}}',
            'style': {'fontSize': 14, 'fontWeight': 'bold'},
          },
          {
            'type': 'linear',
            'direction': 'horizontal',
            'spacing': 8,
            'children': [
              {
                'type': 'icon',
                'icon': 'thermostat',
                'size': 16,
                'color': 'primary',
              },
              {
                'type': 'text',
                'text': '{{app.temperature}}°C',
                'style': {'fontSize': 12},
              },
            ],
          },
          {
            'type': 'chip',
            'label': '{{app.status}}',
          },
        ],
      },
      'onTap': {
        'type': 'navigation',
        'action': 'openApp',
      },
    };
