// A publish bundle written by hand: one screen with a bound text, a screen
// variable, and a button whose reaction changes the variable and calls a
// function of the app. Publishes from the Codelessly Editor have this same
// shape (`"schema": 2`); see the codelessly_api package for the model.
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';

/// The id of the bundle's only layout.
const String helloLayoutId = 'hello';

/// The bundle, decoded. Decoding never throws: unknown keys are kept and
/// bad values fall back to their defaults.
PublishBundle helloBundle() => PublishBundle.fromJson(_json);

const Map<String, Object?> _json = {
  'model': {
    'schema': 2,
    'projectId': 'hello-project',
    'entryLayoutId': helloLayoutId,
    'layouts': {
      helloLayoutId: {
        'canvases': [
          {'id': 'home', 'name': 'Home'},
        ],
      },
    },
  },
  'layouts': {
    helloLayoutId: {
      'schema': 2,
      'id': helloLayoutId,
      'roots': ['home'],
      // The screen's variables, by canvas.
      'variables': {
        'home': [
          {'id': 'v_count', 'name': 'count', 'type': 'integer', 'value': 0},
        ],
      },
      'nodes': {
        // A canvas is a screen; its content is its `body` slot. This one
        // hugs its content's height, so it can sit inside a host's column.
        'home': {
          'type': 'canvas',
          'name': 'Home',
          'slots': {'body': 'column'},
          'layout': {
            'width': 390,
            'height': {'hug': 200},
          },
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'column': {
          'type': 'column',
          'children': ['title', 'counter', 'button'],
          'layout': {
            'width': {'fill': 390},
            'height': {'hug': 200},
            'padding': 24,
          },
          'props': {'crossAxisAlignment': 'start', 'spacing': 12},
        },
        'title': {
          'type': 'text',
          'layout': {
            'width': {'fill': 342},
            'height': {'hug': 32},
          },
          'props': {
            // `data.name` is what the app passes as `data: {'name': ...}`.
            'text': r'Hello, ${data.name}!',
            'style': {'fontSize': 24, 'fontWeight': 700, 'color': '#FF111111'},
          },
        },
        'counter': {
          'type': 'text',
          'layout': {
            'width': {'fill': 342},
            'height': {'hug': 20},
          },
          'props': {
            // `count` is the screen's variable; `route.source` a param the
            // screen was opened with.
            'text': r'Taps: ${count} (opened from ${route.source})',
            'style': {'fontSize': 14, 'color': '#FF555555'},
          },
        },
        'button': {
          'type': 'filledButton',
          'layout': {
            'width': {'hug': 120},
            'height': 44,
          },
          'props': {'label': 'Tap me'},
          'actions': [
            {
              'id': 'r1',
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'setVariable', 'variable': 'count', 'op': 'add', 'value': '1'},
                // Calls `CodelesslyConfig.functions['onTap']`.
                {
                  'type': 'callFunction',
                  'name': 'onTap',
                  'params': {'count': r'${count}'},
                },
              ],
            },
          ],
        },
      },
    },
  },
};
