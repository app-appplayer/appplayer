/// Media & misc widgets showcase: map, mediaPlayer, webView, signature,
/// table, lottieAnimation.
Map<String, dynamic> mediaPage() => {
      'type': 'page',
      'metadata': {'title': 'Media', 'description': 'Media and misc widgets'},
      'state': {
        'initial': {
          'signatureData': '',
          'signed': false,
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
            _section('table'),
            {
              'type': 'table',
              'border': {'color': 'outlineVariant', 'width': 1},
              'rows': [
                {'cells': [
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Name', 'style': {'fontWeight': 'bold'}}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Role', 'style': {'fontWeight': 'bold'}}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'City', 'style': {'fontWeight': 'bold'}}},
                ]},
                {'cells': [
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Ada'}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Engineer'}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'London'}},
                ]},
                {'cells': [
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Alan'}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Scientist'}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Manchester'}},
                ]},
                {'cells': [
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Grace'}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'Admiral'}},
                  {'type': 'padding', 'padding': {'all': 8}, 'child': {'type': 'text', 'text': 'New York'}},
                ]},
              ],
            },

            _section('map'),
            {
              'type': 'box',
              'height': 220,
              'child': {
                'type': 'map',
                'backgroundColor': 'surface',
                'latitude': 37.5665,
                'longitude': 126.9780,
                'zoom': 12,
                'markers': [
                  {'latitude': 37.5665, 'longitude': 126.9780, 'label': 'Seoul'},
                ],
              },
            },

            _section('mediaPlayer (audio sample)'),
            {
              'type': 'box',
              'height': 180,
              'child': {
                'type': 'mediaPlayer',
                'backgroundColor': 'surface',
                'source': 'https://www.w3schools.com/html/horse.mp3',
                'mediaType': 'audio',
                'showControls': true,
              },
            },

            _section('webView'),
            {
              'type': 'box',
              'height': 260,
              'child': {
                'type': 'webView',
                'backgroundColor': 'surface',
                'url': 'https://example.com',
              },
            },

            _section('signature'),
            {
              'type': 'box',
              'height': 220,
              'child': {
                'type': 'signature',
                'backgroundColor': 'surface',
                'binding': 'signatureData',
                'penColor': 'onSurface',
                'showClearButton': true,
                'onSignatureEnd': {
                  'type': 'state', 'action': 'set', 'binding': 'signed', 'value': true,
                },
              },
            },
            {'type': 'text', 'text': 'Signed: {{signed}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('lottieAnimation'),
            {
              'type': 'box',
              'height': 160,
              'child': {
                'type': 'lottieAnimation',
                'backgroundColor': 'surface',
                'source': 'https://lottie.host/4d42d9c1-7ee7-45a1-8f8d-9a1c7f2a9b4a/placeholder.json',
                'loop': true,
                'autoPlay': true,
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
