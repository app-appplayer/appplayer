/// Input widgets showcase: button, textInput, select, toggle, slider,
/// checkbox, radio, form.
Map<String, dynamic> inputPage() => {
      'type': 'page',
      'metadata': {'title': 'Input', 'description': 'Input widget showcase'},
      'state': {
        'initial': {
          'counter': 0,
          'sliderValue': 50,
          'toggleValue': false,
          'agreeTerms': false,
          'selectedOption': 'option1',
          'radioChoice': 'a',
          'rangeValue': {'start': 20, 'end': 80},
          'pickedDate': '',
          'pickedTime': '',
          'rangeStart': '',
          'rangeEnd': '',
          'pickedColor': 'primary',
          'stepperIndex': 0,
          'numberStepperValue': 5,
          'ratingValue': 3,
          'formName': '',
          'formEmail': '',
          'formResult': '',
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
            _section('button variants'),
            {
              'type': 'wrap',
              'spacing': 8,
              'runSpacing': 8,
              'children': [
                {'type': 'button', 'label': 'Filled', 'variant': 'filled', 'onTap': {'type': 'state', 'action': 'increment', 'binding': 'counter'}},
                {'type': 'button', 'label': 'Elevated', 'variant': 'elevated', 'onTap': {'type': 'state', 'action': 'increment', 'binding': 'counter'}},
                {'type': 'button', 'label': 'Outlined', 'variant': 'outlined', 'onTap': {'type': 'state', 'action': 'increment', 'binding': 'counter'}},
                {'type': 'button', 'label': 'Text', 'variant': 'text', 'onTap': {'type': 'state', 'action': 'increment', 'binding': 'counter'}},
              ],
            },
            {'type': 'text', 'text': 'Counter: {{counter}}', 'style': {'fontSize': 14}},

            _section('counter (+/- buttons)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 8,
              'alignment': 'center',
              'children': [
                {'type': 'button', 'label': ' - ', 'variant': 'filled', 'onTap': {'type': 'state', 'action': 'decrement', 'binding': 'counter'}},
                {'type': 'text', 'text': '{{counter}}', 'style': {'fontSize': 32, 'fontWeight': 'bold'}},
                {'type': 'button', 'label': ' + ', 'variant': 'filled', 'onTap': {'type': 'state', 'action': 'increment', 'binding': 'counter'}},
                {'type': 'button', 'label': 'Reset', 'variant': 'outlined', 'onTap': {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 0}},
              ],
            },

            _section('textInput'),
            {
              'type': 'textInput',
              'label': 'Name',
              'placeholder': 'Enter your name',
              'binding': 'formName',
            },
            {
              'type': 'textInput',
              'label': 'Email',
              'placeholder': 'user@example.com',
              'inputType': 'email',
              'binding': 'formEmail',
            },

            _section('select (dropdown)'),
            {
              'type': 'select',
              'label': 'Choose option',
              'binding': 'selectedOption',
              'options': [
                {'value': 'option1', 'label': 'Option A'},
                {'value': 'option2', 'label': 'Option B'},
                {'value': 'option3', 'label': 'Option C'},
              ],
            },
            {'type': 'text', 'text': 'Selected: {{selectedOption}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('toggle'),
            {
              'type': 'toggle',
              'label': 'Enable notifications',
              'binding': 'toggleValue',
            },
            {'type': 'text', 'text': 'Toggle: {{toggleValue}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('slider'),
            {
              'type': 'slider',
              'min': 0,
              'max': 100,
              'value': '{{sliderValue}}',
              'binding': 'sliderValue',
            },
            {'type': 'text', 'text': 'Value: {{sliderValue}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('checkbox'),
            {
              'type': 'checkbox',
              'label': 'I agree to the terms',
              'binding': 'agreeTerms',
            },
            {'type': 'text', 'text': 'Agreed: {{agreeTerms}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('iconButton'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 16,
              'children': [
                {
                  'type': 'iconButton',
                  'icon': 'add',
                  'size': 28,
                  'color': 'primary',
                  'onTap': {'type': 'state', 'action': 'increment', 'binding': 'counter'},
                },
                {
                  'type': 'iconButton',
                  'icon': 'delete',
                  'size': 28,
                  'color': 'error',
                  'onTap': {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 0},
                },
                {
                  'type': 'iconButton',
                  'icon': 'favorite',
                  'size': 28,
                  'color': 'secondary',
                  'onTap': {'type': 'state', 'action': 'toggle', 'binding': 'agreeTerms'},
                },
              ],
            },

            _section('radio (standalone + via radioGroup)'),
            {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'radio',
                  'value': 'a',
                  'groupValue': '{{radioChoice}}',
                  'label': 'Option A',
                  'bindTo': 'radioChoice',
                  'onChange': {'type': 'state', 'action': 'set', 'binding': 'radioChoice', 'value': 'a'},
                },
                {
                  'type': 'radio',
                  'value': 'b',
                  'groupValue': '{{radioChoice}}',
                  'label': 'Option B',
                  'bindTo': 'radioChoice',
                  'onChange': {'type': 'state', 'action': 'set', 'binding': 'radioChoice', 'value': 'b'},
                },
              ],
            },
            {'type': 'text', 'text': 'Radio: {{radioChoice}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('rangeSlider'),
            {
              'type': 'rangeSlider',
              'binding': 'rangeValue',
              'min': 0,
              'max': 100,
              'divisions': 20,
            },
            {'type': 'text', 'text': 'Range: {{rangeValue.start}} – {{rangeValue.end}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('datePicker (button variant)'),
            {
              'type': 'datePicker',
              'label': 'Pick a date',
              'binding': 'pickedDate',
              'variant': 'outlined',
            },
            {'type': 'text', 'text': 'Date: {{pickedDate}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('timePicker (button variant)'),
            {
              'type': 'timePicker',
              'label': 'Pick a time',
              'binding': 'pickedTime',
              'variant': 'outlined',
            },
            {'type': 'text', 'text': 'Time: {{pickedTime}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('dateRangePicker'),
            {
              'type': 'dateRangePicker',
              'label': 'Pick a range',
              'startDate': 'rangeStart',
              'endDate': 'rangeEnd',
              'firstDate': '2026-01-01',
              'lastDate': '2026-12-31',
            },
            {'type': 'text', 'text': 'Range: {{rangeStart}} → {{rangeEnd}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('colorPicker'),
            {
              'type': 'colorPicker',
              'binding': 'pickedColor',
              'showLabel': true,
              'pickerType': 'palette',
            },
            {'type': 'text', 'text': 'Color: {{pickedColor}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('stepper (wizard)'),
            {
              'type': 'stepper',
              'binding': 'stepperIndex',
              'steps': [
                {
                  'titleText': 'Account',
                  'content': {'type': 'text', 'text': 'Create an account'},
                },
                {
                  'titleText': 'Profile',
                  'content': {'type': 'text', 'text': 'Complete your profile'},
                },
                {
                  'titleText': 'Review',
                  'content': {'type': 'text', 'text': 'Review your info'},
                },
              ],
            },

            _section('numberStepper (+/-)'),
            {
              'type': 'numberStepper',
              'label': 'Quantity',
              'binding': 'numberStepperValue',
              'min': 0,
              'max': 20,
              'step': 1,
            },
            {'type': 'text', 'text': 'Count: {{numberStepperValue}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('rating'),
            {
              'type': 'rating',
              'binding': 'ratingValue',
              'max': 5,
              'icon': 'star',
              'color': '#FFC107',
            },
            {'type': 'text', 'text': 'Rating: {{ratingValue}}', 'style': {'fontSize': 12, 'color': 'onSurface'}},

            _section('form submit'),
            {
              'type': 'button',
              'label': 'Submit form',
              'variant': 'filled',
              'onTap': {
                'type': 'tool',
                'tool': 'submitForm',
                'params': {
                  'name': '{{formName}}',
                  'email': '{{formEmail}}',
                },
                'onSuccess': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'formResult',
                  'value': '{{response.formResult}}',
                },
              },
            },
            {
              'type': 'text',
              'text': '{{formResult}}',
              'style': {'fontSize': 14, 'color': '#4CAF50'},
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
