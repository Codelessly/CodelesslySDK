// The render command's step targets: a step that names a block whose one
// tappable or typeable part is inside it reaches that part, and a step whose
// node is not found (or takes no tap) says which nodes it may have meant.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _press(String id) => {
      'type': 'box',
      'layout': {'width': 120, 'height': 40},
      'decoration': {
        'fills': [
          {'color': '#FFDDDDDD'},
        ],
      },
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'setVariable', 'variable': 'picked', 'value': id},
          ],
        },
      ],
    };

Map<String, Object?> _block(List<String> children) => {
      'type': 'column',
      'children': children,
      'layout': {'width': {'fill': 390}, 'height': {'hug': 0}, 'padding': 8},
      'props': {'spacing': 8, 'crossAxisAlignment': 'start'},
    };

final _doc = {
  'schema': 3,
  'id': 'page',
  'roots': ['page'],
  'variables': {
    'page': [
      {'name': 'picked', 'type': 'text', 'value': 'none'},
      {'name': 'typed', 'type': 'text', 'value': ''},
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
      'children': ['label', 'pair', 'one', 'form'],
      'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
      'props': {'spacing': 8},
    },
    'label': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': r'picked ${picked}, typed ${typed}',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    'pair': _block(['heading', 'first', 'second']),
    'heading': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': 'Stay',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    // Two fields (controls, no reaction of their own: the tap would not go
    // to either by itself).
    'first': {'type': 'textField', 'layout': {'width': 120, 'height': 48}},
    'second': {'type': 'textField', 'layout': {'width': 120, 'height': 48}},
    'one': _block(['caption', 'sorter']),
    'caption': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': 'Sort by',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    'sorter': _press('sorter'),
    'form': _block(['entry']),
    'entry': {
      'type': 'textField',
      'layout': {'width': 300, 'height': 48},
      'bind': {'props.initialValue': r'${typed}'},
    },
  },
};

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_step_targets_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(RenderReport, String)> run(WidgetTester tester, List<Step> steps) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc));
    final report = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true));
    final boxes = jsonDecode(File('${out.path}/o/page@390x700.layout.json').readAsStringSync()) as List;
    return (report, '${boxes.cast<Map>().firstWhere((b) => b['id'] == 'label')['text']}');
  }

  String messageOf(RenderReport r, String code) => r.diagnostics.firstWhere((d) => d['code'] == code)['message'] as String;

  testWidgets('a tap on a block reaches the one part of it that takes a tap', (tester) async {
    final (report, label) = await run(tester, const [Step('tap', 'one')]);
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    expect(label, startsWith('picked sorter,'));
  });

  testWidgets('a tap on a block with several such parts names them', (tester) async {
    final (report, _) = await run(tester, const [Step('tap', 'pair')]);
    expect(messageOf(report, 'tap_no_reaction'), contains('Perhaps: first, second.'));
  });

  testWidgets('a node not on screen names the nodes like it', (tester) async {
    final (report, _) = await run(tester, const [Step('tap', 'sortr')]);
    expect(messageOf(report, 'interaction_failed'), allOf(contains('no node "sortr"'), contains('Perhaps: sorter')));
  });

  testWidgets('a field named under its block is the block\'s one text field', (tester) async {
    final (report, label) = await run(tester, const [Step('type', 'form/field', 'Paris')]);
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    expect(label, endsWith('typed Paris'));
  });

  testWidgets('a part named under a block that has none names what is in it', (tester) async {
    final (report, _) = await run(tester, const [Step('tap', 'pair/third')]);
    expect(messageOf(report, 'interaction_failed'), allOf(contains('no node "third" is inside "pair"'), contains('Perhaps: first, second')));
  });
}
