/// Scroll & utility widgets showcase: scrollView, singleChildScrollView,
/// scrollBar, pageView, lazy, fittedBox, clipOval, clipRRect.
Map<String, dynamic> scrollPage() => {
      'type': 'page',
      'metadata': {'title': 'Scroll & Utility', 'description': 'Scroll and utility widget showcase'},
      'state': {
        'initial': {
          'currentPage': 0,
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
            _section('scrollView (horizontal) — 40 boxes, scroll with trackpad / shift+wheel'),
            {
              'type': 'box',
              'height': 80,
              'child': {
                'type': 'scrollView',
                'direction': 'horizontal',
                'child': {
                  'type': 'linear',
                  'direction': 'horizontal',
                  'spacing': 8,
                  'children': List.generate(
                      40,
                      (i) => {
                            'type': 'box',
                            'width': 72,
                            'height': 72,
                            'decoration': {
                              'color': _palette[i % _palette.length],
                              'borderRadius': 8,
                            },
                            'child': {
                              'type': 'center',
                              'child': {
                                'type': 'text',
                                'text': '$i',
                                'style': {'color': '#FFFFFF', 'fontWeight': 'bold'},
                              },
                            },
                          }),
                },
              },
            },

            _section('scrollBar (visible)'),
            {
              'type': 'box',
              'height': 120,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'scrollBar',
                'thumbVisibility': true,
                'child': {
                  'type': 'singleChildScrollView',
                  'child': {
                    'type': 'linear',
                    'direction': 'vertical',
                    'children': List.generate(
                        20,
                        (i) => {
                              'type': 'padding',
                              'padding': {'all': 8},
                              'child': {'type': 'text', 'text': 'Line ${i + 1}'},
                            }),
                  },
                },
              },
            },

            _section('pageView (swipe horizontally)'),
            {
              'type': 'box',
              'height': 120,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'pageView',
                'scrollDirection': 'horizontal',
                'onChange': {
                  'type': 'state', 'action': 'set',
                  'binding': 'currentPage', 'value': '{{event.page}}',
                },
                'children': [
                  _page('primary', 'Page 1'),
                  _page('secondary', 'Page 2'),
                  _page('#4CAF50', 'Page 3'),
                ],
              },
            },
            {'type': 'text', 'text': 'Current page: {{currentPage}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('lazy'),
            {
              'type': 'lazy',
              'placeholder': {
                'type': 'text',
                'text': 'Loading lazy widget…',
                'style': {'color': 'onSurface'},
              },
              'child': {
                'type': 'box',
                'padding': {'all': 12},
                'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
                'child': {'type': 'text', 'text': 'Lazily-built content'},
              },
            },

            _section('fittedBox (scale to fit)'),
            {
              'type': 'box',
              'width': 160,
              'height': 60,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'fittedBox',
                'fit': 'contain',
                'child': {
                  'type': 'text',
                  'text': 'Fit',
                  'style': {'fontSize': 48, 'fontWeight': 'bold', 'color': 'primary'},
                },
              },
            },

            _section('clipOval'),
            {
              'type': 'clipOval',
              'child': {
                'type': 'box',
                'width': 80,
                'height': 80,
                'decoration': {'color': 'secondary'},
                'child': {
                  'type': 'center',
                  'child': {'type': 'text', 'text': 'oval', 'style': {'color': '#FFFFFF'}},
                },
              },
            },

            _section('clipRRect (rounded)'),
            {
              'type': 'clipRRect',
              'borderRadius': 16,
              'child': {
                'type': 'box',
                'width': 160,
                'height': 60,
                'decoration': {'color': '#4CAF50'},
                'child': {
                  'type': 'center',
                  'child': {'type': 'text', 'text': 'clipped', 'style': {'color': '#FFFFFF'}},
                },
              },
            },

            {'type': 'sizedBox', 'height': 24},
          ],
        },
      },
    };

const _palette = ['primary', 'secondary', '#4CAF50', '#FFC107', '#9C27B0', '#FF5722'];

Map<String, dynamic> _page(String color, String label) => {
      'type': 'box',
      'decoration': {'color': color, 'borderRadius': 8},
      'child': {
        'type': 'center',
        'child': {
          'type': 'text',
          'text': label,
          'style': {'color': '#FFFFFF', 'fontSize': 22, 'fontWeight': 'bold'},
        },
      },
    };

Map<String, dynamic> _section(String title) => {
      'type': 'text',
      'text': title,
      'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': 'primary'},
    };
