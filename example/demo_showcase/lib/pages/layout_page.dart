/// Layout widgets showcase. Covers every layout widget in spec §2.4:
/// box, linear, stack, center, align, padding, margin, expanded, flexible,
/// spacer, wrap, positioned, safeArea, sizedBox, aspectRatio, constrained,
/// fractionallySized, intrinsicHeight, intrinsicWidth, visibility,
/// conditional, indexedStack.
Map<String, dynamic> layoutPage() => {
      'type': 'page',
      'metadata': {'title': 'Layout', 'description': 'Layout widget showcase'},
      'state': {
        'initial': {
          'darkMode': false,
          'showSecret': false,
          'tabIndex': 0,
        },
      },
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            _section('linear (horizontal + vertical)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 8,
              'children': [
                _colorBox('primary', 'A', 60),
                _colorBox('secondary', 'B', 60),
                _colorBox('#4CAF50', 'C', 60),
              ],
            },
            _gap(16),

            _section('center'),
            {
              'type': 'box',
              'height': 80,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'center',
                'child': {'type': 'text', 'text': 'Centered content'},
              },
            },
            _gap(16),

            _section('align (bottomRight)'),
            {
              'type': 'box',
              'height': 80,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'align',
                'alignment': 'bottomRight',
                'child': _colorBox('secondary', 'BR', 40),
              },
            },
            _gap(16),

            _section('padding'),
            {
              'type': 'box',
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'padding',
                'padding': {'all': 20},
                'child': {'type': 'text', 'text': 'Padded 20'},
              },
            },
            _gap(16),

            _section('margin'),
            {
              'type': 'box',
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'margin',
                'margin': {'all': 16},
                'child': {'type': 'text', 'text': 'Margin 16 (inside amber card)'},
              },
            },
            _gap(16),

            _section('sizedBox'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                _colorBox('primary', 'L', 40),
                {'type': 'sizedBox', 'width': 40},
                _colorBox('#4CAF50', 'R', 40),
              ],
            },
            _gap(16),

            _section('stack + positioned'),
            {
              'type': 'box',
              'height': 120,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'stack',
                'children': [
                  {
                    'type': 'positioned',
                    'top': 8,
                    'left': 8,
                    'child': _colorBox('primary', '1', 40),
                  },
                  {
                    'type': 'positioned',
                    'top': 30,
                    'left': 30,
                    'child': _colorBox('secondary', '2', 40),
                  },
                  {
                    'type': 'positioned',
                    'bottom': 8,
                    'right': 8,
                    'child': _colorBox('#4CAF50', '3', 40),
                  },
                ],
              },
            },
            _gap(16),

            _section('wrap'),
            {
              'type': 'wrap',
              'spacing': 8,
              'runSpacing': 8,
              'children': List.generate(
                  8,
                  (i) => {
                        'type': 'chip',
                        'label': 'Tag ${i + 1}',
                      }),
            },
            _gap(16),

            _section('expanded + flexible + spacer'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {
                  'type': 'expanded',
                  'flex': 2,
                  'child': _colorBox('primary', 'flex:2', 40),
                },
                {'type': 'sizedBox', 'width': 8},
                {
                  'type': 'flexible',
                  'flex': 1,
                  'child': _colorBox('secondary', 'flexible', 40),
                },
                {'type': 'spacer'},
                _colorBox('#4CAF50', 'end', 40),
              ],
            },
            _gap(16),

            _section('aspectRatio (16:9)'),
            {
              'type': 'aspectRatio',
              'aspectRatio': 1.777,
              'child': {
                'type': 'box',
                'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
                'child': {
                  'type': 'center',
                  'child': {'type': 'text', 'text': '16:9'},
                },
              },
            },
            _gap(16),

            _section('constrained (minHeight 60)'),
            {
              'type': 'constrained',
              'minHeight': 60,
              'maxWidth': 240,
              'child': {
                'type': 'box',
                'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
                'child': {
                  'type': 'center',
                  'child': {'type': 'text', 'text': 'Constrained'},
                },
              },
            },
            _gap(16),

            _section('fractionallySized (60% width)'),
            {
              'type': 'box',
              'height': 48,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'fractionallySized',
                'widthFactor': 0.6,
                'child': {
                  'type': 'box',
                  'decoration': {'color': 'primary', 'borderRadius': 8},
                  'child': {
                    'type': 'center',
                    'child': {
                      'type': 'text',
                      'text': '60%',
                      'style': {'color': '#FFFFFF'},
                    },
                  },
                },
              },
            },
            _gap(16),

            _section('intrinsicHeight + intrinsicWidth'),
            {
              'type': 'intrinsicHeight',
              'child': {
                'type': 'linear',
                'direction': 'horizontal',
                'spacing': 8,
                'children': [
                  {
                    'type': 'box',
                    'width': 80,
                    'decoration': {'color': 'primary', 'borderRadius': 6},
                    'child': {
                      'type': 'padding',
                      'padding': {'all': 8},
                      'child': {
                        'type': 'text',
                        'text': 'short',
                        'style': {'color': '#FFFFFF'},
                      },
                    },
                  },
                  {
                    'type': 'intrinsicWidth',
                    'child': {
                      'type': 'box',
                      'decoration': {'color': 'secondary', 'borderRadius': 6},
                      'child': {
                        'type': 'padding',
                        'padding': {'all': 8},
                        'child': {
                          'type': 'text',
                          'text': 'taller content\ntwo lines',
                          'style': {'color': '#FFFFFF'},
                        },
                      },
                    },
                  },
                ],
              },
            },
            _gap(16),

            _section('safeArea'),
            {
              'type': 'safeArea',
              'child': {
                'type': 'box',
                'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
                'child': {
                  'type': 'padding',
                  'padding': {'all': 12},
                  'child': {
                    'type': 'text',
                    'text': 'safeArea padding respects notches/insets',
                  },
                },
              },
            },
            _gap(16),

            _section('visibility (toggle below)'),
            {
              'type': 'visibility',
              'visible': '{{showSecret}}',
              'maintainState': true,
              'replacement': {
                'type': 'box',
                'height': 40,
                'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
                'child': {
                  'type': 'center',
                  'child': {'type': 'text', 'text': '(hidden — replacement shown)'},
                },
              },
              'child': {
                'type': 'box',
                'height': 40,
                'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
                'child': {
                  'type': 'center',
                  'child': {'type': 'text', 'text': 'Secret content'},
                },
              },
            },
            {'type': 'sizedBox', 'height': 8},
            {
              'type': 'button',
              'label': 'Toggle secret',
              'variant': 'outlined',
              'onTap': {'type': 'state', 'action': 'toggle', 'binding': 'showSecret'},
            },
            _gap(16),

            _section('conditional'),
            {
              'type': 'conditional',
              'condition': '{{darkMode}}',
              'then': {
                'type': 'text',
                'text': 'Dark mode is ON',
                'style': {'color': 'secondary', 'fontWeight': 'bold'},
              },
              'else': {
                'type': 'text',
                'text': 'Dark mode is OFF',
                'style': {'color': 'primary'},
              },
            },
            {'type': 'sizedBox', 'height': 8},
            {
              'type': 'button',
              'label': 'Toggle dark mode',
              'variant': 'outlined',
              'onTap': {'type': 'state', 'action': 'toggle', 'binding': 'darkMode'},
            },
            _gap(16),

            _section('indexedStack (child ${'{{tabIndex}}'} visible)'),
            {
              'type': 'indexedStack',
              'index': '{{tabIndex}}',
              'children': [
                _tabSlide('primary', 'Tab 0 — Home'),
                _tabSlide('secondary', 'Tab 1 — Details'),
                _tabSlide('#4CAF50', 'Tab 2 — Settings'),
              ],
            },
            {'type': 'sizedBox', 'height': 8},
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 8,
              'children': [
                _tabButton('0', 0),
                _tabButton('1', 1),
                _tabButton('2', 2),
              ],
            },
            _gap(24),
          ],
        },
      },
    };

Map<String, dynamic> _section(String title) => {
      'type': 'box',
      'padding': {'vertical': 8},
      'child': {
        'type': 'text',
        'text': title,
        'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': 'primary'},
      },
    };

Map<String, dynamic> _gap(double h) => {'type': 'sizedBox', 'height': h};

Map<String, dynamic> _colorBox(String color, String label, double size) => {
      'type': 'box',
      'width': size,
      'height': size,
      'decoration': {'color': color, 'borderRadius': 6},
      'child': {
        'type': 'center',
        'child': {
          'type': 'text',
          'text': label,
          'style': {'color': '#FFFFFF', 'fontWeight': 'bold', 'fontSize': 12},
        },
      },
    };

Map<String, dynamic> _tabSlide(String color, String text) => {
      'type': 'box',
      'height': 60,
      'decoration': {'color': color, 'borderRadius': 8},
      'child': {
        'type': 'center',
        'child': {
          'type': 'text',
          'text': text,
          'style': {'color': '#FFFFFF', 'fontWeight': 'bold'},
        },
      },
    };

Map<String, dynamic> _tabButton(String label, int index) => {
      'type': 'button',
      'label': label,
      'variant': 'outlined',
      'onTap': {'type': 'state', 'action': 'set', 'binding': 'tabIndex', 'value': index},
    };
