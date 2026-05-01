/// Dialog widgets showcase: alertDialog, snackBar, bottomSheet.
Map<String, dynamic> dialogPage() => {
      'type': 'page',
      'metadata': {'title': 'Dialog', 'description': 'Dialog widget showcase'},
      'state': {
        'initial': {'dialogResult': ''},
      },
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 16,
          'children': [
            _section('alertDialog'),
            {
              'type': 'button',
              'label': 'Show Alert Dialog',
              'variant': 'filled',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'alertDialog',
                  'title': 'Alert',
                  'content': 'This is an alert dialog example.',
                  'actions': [
                    {
                      'label': 'Cancel',
                      'onTap': {'type': 'state', 'action': 'set', 'binding': 'dialogResult', 'value': 'Cancelled'},
                    },
                    {
                      'label': 'OK',
                      'onTap': {'type': 'state', 'action': 'set', 'binding': 'dialogResult', 'value': 'Confirmed'},
                    },
                  ],
                },
              },
            },
            {'type': 'text', 'text': 'Result: {{dialogResult}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('snackBar'),
            {
              'type': 'button',
              'label': 'Show SnackBar',
              'variant': 'outlined',
              'onTap': {
                'type': 'notification',
                'message': 'This is a snackbar message!',
              },
            },

            _section('bottomSheet'),
            {
              'type': 'button',
              'label': 'Show Bottom Sheet',
              'variant': 'outlined',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'bottomSheet',
                  'child': {
                    'type': 'box',
                    'padding': {'all': 24},
                    'child': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'spacing': 12,
                      'children': [
                        {'type': 'text', 'text': 'Bottom Sheet', 'style': {'fontSize': 20, 'fontWeight': 'bold'}},
                        {'type': 'text', 'text': 'This is a bottom sheet with custom content.'},
                        {'type': 'divider'},
                        {
                          'type': 'listItem',
                          'leading': {'type': 'icon', 'icon': 'share'},
                          'title': {'type': 'text', 'text': 'Share'},
                        },
                        {
                          'type': 'listItem',
                          'leading': {'type': 'icon', 'icon': 'link'},
                          'title': {'type': 'text', 'text': 'Copy link'},
                        },
                        {
                          'type': 'listItem',
                          'leading': {'type': 'icon', 'icon': 'delete'},
                          'title': {'type': 'text', 'text': 'Delete'},
                        },
                      ],
                    },
                  },
                },
              },
            },

            _section('simpleDialog'),
            {
              'type': 'button',
              'label': 'Show Simple Dialog',
              'variant': 'outlined',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'simpleDialog',
                  'title': 'Select option',
                  'options': [
                    {'label': 'Option A', 'value': 'a'},
                    {'label': 'Option B', 'value': 'b'},
                    {'label': 'Option C', 'value': 'c'},
                  ],
                  'onSelect': {'type': 'state', 'action': 'set', 'binding': 'dialogResult', 'value': '{{event.value}}'},
                },
              },
            },
            {'type': 'text', 'text': 'Selected: {{dialogResult}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('customDialog'),
            {
              'type': 'button',
              'label': 'Show Custom Dialog',
              'variant': 'outlined',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'customDialog',
                  'child': {
                    'type': 'box',
                    'padding': {'all': 20},
                    'decoration': {'color': 'surfaceContainerHigh', 'borderRadius': 12},
                    'child': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'spacing': 12,
                      'children': [
                        {'type': 'icon', 'icon': 'info', 'size': 40, 'color': 'primary'},
                        {'type': 'text', 'text': 'Custom dialog', 'style': {'fontSize': 18, 'fontWeight': 'bold'}},
                        {'type': 'text', 'text': 'Completely custom content.'},
                      ],
                    },
                  },
                },
              },
            },

            _section('snackBar'),
            {
              'type': 'button',
              'label': 'Show SnackBar widget',
              'variant': 'outlined',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'snackBar',
                  'content': 'SnackBar via widget definition',
                  'duration': 3000,
                },
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
