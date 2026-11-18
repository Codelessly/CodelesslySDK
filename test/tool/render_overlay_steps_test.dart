// Steps and actions around a menu open over the page (support desk, test 11):
// a menu's line is tapped by the text it shows (`--tap "Leo Marsh"`); a
// `scrollTo` run from the menu moves the page under it; a step on a list's
// row whose list is hidden at this size is skipped there, not an error.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _text(String text) => {
      'type': 'text',
      'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
      'props': {'text': text},
    };

Map<String, Object?> _line(List<String> children, List<Map<String, Object?>> actions) => {
      'type': 'row',
      'layout': {'width': {'fill': 0}, 'height': 32},
      'children': children,
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
    };

Map<String, Object?> _doc() => {
      'schema': 3,
      'id': 'm',
      'roots': ['m', 'menu'],
      'nodes': {
        'm': {
          'type': 'canvas',
          'slots': {'body': 'page'},
          'layout': {'width': 800, 'height': 500},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'page': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'padding': 24},
          'props': {'scrollable': true, 'spacing': 12},
          'children': ['shown', 'more', 'wide', 'filler', 'end'],
        },
        'shown': _text(r'picked ${picked} hit ${hit}'),
        'more': {
          'type': 'filledButton',
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'props': {'label': 'More'},
          'actions': [
            {
              'trigger': {'type': 'click'},
              'actions': [
                {'type': 'openModal', 'to': 'menu', 'presentation': 'popover', 'anchor': 'trigger'},
              ],
            },
          ],
        },
        // Hidden on a phone: its rows are not made there.
        'wide': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'children': ['rows'],
          'media': [
            {'maxWidth': 699, 'patch': {'visible': false}},
          ],
        },
        'rows': {
          'type': 'listView',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'scrollable': false},
          'bind': {'data': r'${= ["a","b"]}'},
          'children': ['rowItem'],
        },
        'rowItem': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'children': ['row'],
        },
        'row': _line(['rowText'], [
          {'type': 'setVariable', 'variable': 'hit', 'value': r'${= hit+1}'},
        ]),
        'rowText': _text(r'${item}'),
        'filler': {
          'type': 'box',
          'layout': {'width': {'fill': 0}, 'height': 1200},
        },
        'end': _text('The end'),
        'menu': {
          'type': 'canvas',
          'slots': {'body': 'menuBody'},
          'layout': {'width': 220, 'height': {'hug': 0}},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'menuBody': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}, 'padding': 6},
          'props': {'focusGroup': true},
          'children': ['dana', 'leo', 'goEnd'],
        },
        'dana': _line(['danaText'], [
          {'type': 'setVariable', 'variable': 'picked', 'value': 'Dana Okafor'},
          {'type': 'closeModal'},
        ]),
        'danaText': _text('Dana Okafor'),
        'leo': _line(['leoText'], [
          {'type': 'setVariable', 'variable': 'picked', 'value': 'Leo Marsh'},
          {'type': 'closeModal'},
        ]),
        'leoText': _text('Leo Marsh'),
        'goEnd': _line(['goEndText'], [
          {'type': 'closeModal'},
          {'type': 'scrollTo', 'node': 'end'},
        ]),
        'goEndText': _text('Go to the end'),
      },
      'variables': {
        'page_variables': [
          {'name': 'picked', 'type': 'text', 'value': ''},
          {'name': 'hit', 'type': 'integer', 'value': 0},
        ],
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_overlay_steps_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(RenderReport, Map)> run(WidgetTester tester, List<Step> steps, {Size size = const Size(800, 500)}) async {
    final file = File('${out.path}/m.json')..writeAsStringSync(jsonEncode(_doc()));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: [size], steps: steps, dumpLayout: true, screens: const ['m']));
    final name = '${size.width.toInt()}x${size.height.toInt()}';
    final boxes = jsonDecode(File('${out.path}/o/m@$name.layout.json').readAsStringSync()) as List;
    return (report, boxes.cast<Map>().firstWhere((b) => b['id'] == 'shown'));
  }

  testWidgets('a menu\'s line is tapped by the text it shows', (tester) async {
    final (report, shown) = await run(tester, const [Step('tap', 'more'), Step('tap', 'Leo Marsh')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(shown['text'], 'picked Leo Marsh hit 0');
  });

  testWidgets('a scrollTo from the menu moves the page under it', (tester) async {
    final (report, shown) = await run(tester, const [Step('tap', 'more'), Step('tap', 'goEnd')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(shown['y'] as num, lessThan(0));
  });

  testWidgets('a step on a row whose list is hidden at this size is skipped there', (tester) async {
    final (report, shown) = await run(tester, const [Step('tap', 'row#0')], size: const Size(390, 600));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect([for (final d in report.diagnostics) d['code']], contains('step_skipped'));
  });

  testWidgets('where the list shows, the step taps the row', (tester) async {
    final (wide, wideShown) = await run(tester, const [Step('tap', 'row#0')]);
    expect(wide.errors, 0, reason: '${wide.diagnostics}');
    expect(wideShown['text'], 'picked  hit 1', reason: '${wide.diagnostics}');
  });
}
