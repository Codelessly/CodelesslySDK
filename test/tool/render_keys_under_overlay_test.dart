// What is under an open overlay takes no key: a page's shortcuts (a canvas's
// keyDown, a node's onKeyDown such as an App's) wait while a dialog is open
// over it, and the dialog's own keys run (round 10, R13: a page's Enter ran
// while a chooser was open).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _text(String text) => {
      'type': 'text',
      'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
      'props': {'text': text},
    };

Map<String, Object?> _keys(String variable) => {
      'trigger': {'type': 'keyDown', 'key': 'j'},
      'actions': [
        {'type': 'setVariable', 'variable': variable, 'value': '\${= $variable+1}'},
      ],
    };

Map<String, Object?> _doc() => {
      'schema': 3,
      'id': 'keys',
      'roots': ['keys', 'dlg'],
      'nodes': {
        'keys': {
          'type': 'canvas',
          'slots': {'body': 'app'},
          'layout': {'width': 600, 'height': 400},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
          'actions': [_keys('page')],
        },
        // An App's onKeyDown: a keyDown on a node of the page, any key.
        'app': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'padding': 24},
          'children': ['shown', 'open'],
          'actions': [
            {
              'trigger': {'type': 'keyDown'},
              'actions': [
                {'type': 'setVariable', 'variable': 'any', 'value': r'${= any+1}'},
              ],
            },
          ],
        },
        'shown': _text(r'${page} ${any} ${inDialog}'),
        'open': {
          'type': 'filledButton',
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'props': {'label': 'Open'},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'openModal', 'to': 'dlg', 'presentation': 'dialog'},
              ],
            },
          ],
        },
        'dlg': {
          'type': 'canvas',
          'slots': {'body': 'dlgBody'},
          'layout': {'width': 320, 'height': 160},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
          'actions': [_keys('inDialog')],
        },
        'dlgBody': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'padding': 16},
          'children': ['dlgText'],
        },
        'dlgText': _text('In the dialog'),
      },
      'variables': {
        'page_variables': [
          {'name': 'page', 'type': 'integer', 'value': 0},
          {'name': 'any', 'type': 'integer', 'value': 0},
          {'name': 'inDialog', 'type': 'integer', 'value': 0},
        ],
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_keys_under_overlay_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<String> run(WidgetTester tester, List<Step> steps) async {
    final file = File('${out.path}/keys.json')..writeAsStringSync(jsonEncode(_doc()));
    final report = await runRender(tester,
        RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(600, 400)], steps: steps, dumpLayout: true, screens: const ['keys']));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/o/keys@600x400.layout.json').readAsStringSync()) as List;
    return boxes.cast<Map>().firstWhere((b) => b['id'] == 'shown')['text'] as String;
  }

  testWidgets('with nothing open the page takes the key', (tester) async {
    expect(await run(tester, const [Step('key', 'j')]), '1 1 0');
  });

  testWidgets('with a dialog open only the dialog does', (tester) async {
    expect(await run(tester, const [Step('tap', 'open'), Step('key', 'j')]), '0 0 1');
  });
}
