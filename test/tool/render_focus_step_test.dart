// `--focus <id>` moves the keyboard focus to any node that can take it (a
// button, a press target), not only a text field: the next `--key` goes
// there. A node that cannot take the focus is an error naming the nearest
// one that can.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _pick(String id) => {
      'trigger': {'type': 'click'},
      'actions': [
        {'type': 'setVariable', 'variable': 'picked', 'value': id},
      ],
    };

final _doc = {
  'schema': 3,
  'id': 'page',
  'roots': ['page'],
  'variables': {
    'page': [
      {'name': 'picked', 'type': 'text', 'value': 'none'},
    ],
  },
  'nodes': {
    'page': {
      'type': 'canvas',
      'slots': {'body': 'col'},
      'layout': {'width': 390, 'height': 700},
      'decoration': {
        'fills': [
          {'color': '#FFFFFFFF'},
        ],
      },
    },
    'col': {
      'type': 'column',
      'children': ['label', 'first', 'second', 'tile', 'note'],
      'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
      'props': {'spacing': 8},
    },
    'label': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': r'picked ${picked}',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    'first': {
      'type': 'filledButton',
      'layout': {'width': 120, 'height': 40},
      'props': {'label': 'First'},
      'actions': [_pick('first')],
    },
    'second': {
      'type': 'filledButton',
      'layout': {'width': 120, 'height': 40},
      'props': {'label': 'Second'},
      'actions': [_pick('second')],
    },
    // A box with a tap reaction (a row, a card): a press target, focusable.
    'tile': {
      'type': 'box',
      'layout': {'width': 200, 'height': 40},
      'decoration': {
        'fills': [
          {'color': '#FFDDDDDD'},
        ],
      },
      'actions': [_pick('tile')],
    },
    'note': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': 'Just words',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
  },
};

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_focus_step_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(RenderReport, String)> run(WidgetTester tester, List<Step> steps) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc));
    final report = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true));
    final boxes = jsonDecode(File('${out.path}/o/page@390x700.layout.json').readAsStringSync()) as List;
    return (report, '${boxes.cast<Map>().firstWhere((b) => b['id'] == 'label')['text']}');
  }

  testWidgets('--focus on a button: the focus is on it and Enter presses it', (tester) async {
    final (report, label) = await run(tester, const [Step('focus', 'second'), Step('key', 'Enter')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(label, 'picked second');
    expect(report.focus.single['id'], 'second');
  });

  testWidgets('--focus on a node with a tap reaction, then Tab moves on from it', (tester) async {
    final (report, label) = await run(tester, const [Step('focus', 'first'), Step('key', 'Tab'), Step('key', 'Enter')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(label, 'picked second');
    final (tile, tileLabel) = await run(tester, const [Step('focus', 'tile'), Step('key', 'Space')]);
    expect(tile.errors, 0, reason: '${tile.diagnostics}');
    expect(tileLabel, 'picked tile');
  });

  testWidgets('a node that cannot take the focus: the error names the nearest that can', (tester) async {
    final (report, _) = await run(tester, const [Step('focus', 'note')]);
    final message = report.diagnostics.firstWhere((d) => d['code'] == 'interaction_failed')['message'] as String;
    expect(message, allOf(contains('cannot take the keyboard focus'), contains('tile')));
  });
}
