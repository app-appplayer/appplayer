/// Navigation widgets showcase: tabBar, tabBarView, bottomNavigation,
/// navigationRail, floatingActionButton. headerBar and drawer are
/// managed at the application-shell level and demonstrated there.
Map<String, dynamic> navigationPage() => {
      'type': 'page',
      'metadata': {'title': 'Navigation', 'description': 'Navigation widget showcase'},
      'state': {
        'initial': {
          'tabIndex': 0,
          'bottomIndex': 0,
          'railIndex': 0,
          'fabCount': 0,
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
            _section('tabBar + tabBarView'),
            {
              'type': 'tabBar',
              'currentIndex': '{{tabIndex}}',
              'tabs': [
                {'label': 'Home', 'icon': 'home'},
                {'label': 'Search', 'icon': 'search'},
                {'label': 'Profile', 'icon': 'person'},
              ],
              'onChange': {
                'type': 'state', 'action': 'set',
                'binding': 'tabIndex', 'value': '{{event.index}}',
              },
            },
            {
              'type': 'box',
              'height': 100,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'indexedStack',
                'index': '{{tabIndex}}',
                'children': [
                  _tabContent('primary', 'Home tab'),
                  _tabContent('secondary', 'Search tab'),
                  _tabContent('#4CAF50', 'Profile tab'),
                ],
              },
            },

            _section('bottomNavigation (inline demo)'),
            {
              'type': 'box',
              'height': 80,
              'child': {
                'type': 'bottomNavigation',
                'currentIndex': '{{bottomIndex}}',
                'items': [
                  {'icon': 'home', 'label': 'Home'},
                  {'icon': 'favorite', 'label': 'Favorites'},
                  {'icon': 'settings', 'label': 'Settings'},
                ],
                'onChange': {
                  'type': 'state', 'action': 'set',
                  'binding': 'bottomIndex', 'value': '{{event.index}}',
                },
              },
            },
            {'type': 'text', 'text': 'Selected: {{bottomIndex}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('navigationRail (inline demo)'),
            {
              'type': 'box',
              'height': 220,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'linear',
                'direction': 'horizontal',
                'children': [
                  {
                    'type': 'navigationRail',
                    'selectedIndex': '{{railIndex}}',
                    'items': [
                      {'label': 'Home', 'icon': 'home'},
                      {'label': 'Search', 'icon': 'search'},
                      {'label': 'Settings', 'icon': 'settings'},
                    ],
                    'onChange': {
                      'type': 'state', 'action': 'set',
                      'binding': 'railIndex', 'value': '{{event.index}}',
                    },
                  },
                  {
                    'type': 'expanded',
                    'child': {
                      'type': 'center',
                      'child': {'type': 'text', 'text': 'Rail index: {{railIndex}}'},
                    },
                  },
                ],
              },
            },

            _section('floatingActionButton (inline)'),
            {
              'type': 'box',
              'height': 80,
              'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 8},
              'child': {
                'type': 'stack',
                'children': [
                  {
                    'type': 'center',
                    'child': {'type': 'text', 'text': 'FAB tapped: {{fabCount}} times'},
                  },
                  {
                    'type': 'positioned',
                    'bottom': 12,
                    'right': 12,
                    'child': {
                      'type': 'floatingActionButton',
                      'icon': 'add',
                      'onTap': {
                        'type': 'state', 'action': 'increment', 'binding': 'fabCount',
                      },
                    },
                  },
                ],
              },
            },

            {'type': 'sizedBox', 'height': 24},
          ],
        },
      },
    };

Map<String, dynamic> _tabContent(String color, String label) => {
      'type': 'center',
      'child': {
        'type': 'text',
        'text': label,
        'style': {'color': color, 'fontSize': 20, 'fontWeight': 'bold'},
      },
    };

Map<String, dynamic> _section(String title) => {
      'type': 'text',
      'text': title,
      'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': 'primary'},
    };
