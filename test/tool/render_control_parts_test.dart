// The parts of built-in controls a step names with `@`: a number field's
// minus and plus (`@decrement`, `@increment`, or `@0` and `@2` as drawn), a
// slider's thumb (`@thumb`), a dropdown's option by its label
// (`@option:<label>`, or the label alone once it is open); `--dump-layout`
// lists each control's parts.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _changes(String variable) => {
      'trigger': {'type': 'changed'},
      'actions': [
        {'type': 'setVariable', 'variable': variable, 'value': r'${result}'},
      ],
    };

final _doc = {
  'schema': 3,
  'id': 'page',
  'roots': ['page'],
  'variables': {
    'page': [
      {'name': 'qty', 'type': 'integer', 'value': 2},
      {'name': 'volume', 'type': 'integer', 'value': 50},
      {'name': 'region', 'type': 'text', 'value': 'Alps'},
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
      'children': ['label', 'quantity', 'vol', 'regionPick'],
      'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
      'props': {'spacing': 12},
    },
    'label': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': r'qty ${qty} volume ${volume} region ${region}',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    'quantity': {
      'type': 'textField',
      'layout': {'width': 140, 'height': 44},
      'props': {'min': 1, 'max': 9, 'keyboardType': 'number', 'steppers': true, 'textAlign': 'center'},
      'bind': {'props.initialValue': r'${qty}'},
      'actions': [_changes('qty')],
    },
    'vol': {
      'type': 'slider',
      'layout': {'width': 300, 'height': 40},
      'props': {'min': 0, 'max': 100},
      'bind': {'props.value': r'${volume}'},
      'actions': [_changes('volume')],
    },
    'regionPick': {
      'type': 'dropdown',
      'layout': {'width': 200, 'height': 48},
      'props': {
        'items': ['Alps', 'Alaska', 'Andes'],
      },
      'bind': {'props.value': r'${region}'},
      'actions': [_changes('region')],
    },
  },
};

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_control_parts_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(RenderReport, List<Map>)> run(WidgetTester tester, List<Step> steps) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc));
    final report = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: steps, dumpLayout: true));
    final boxes = (jsonDecode(File('${out.path}/o/page@390x700.layout.json').readAsStringSync()) as List).cast<Map>();
    return (report, boxes);
  }

  String labelOf(List<Map> boxes) => '${boxes.firstWhere((b) => b['id'] == 'label')['text']}';

  testWidgets('a number field\'s minus and plus, by name or as drawn', (tester) async {
    final (report, boxes) = await run(tester, const [
      Step('tap', 'quantity@increment'),
      Step('tap', 'quantity@increment'),
      Step('tap', 'quantity@decrement'),
      Step('tap', 'quantity@2'),
    ]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(labelOf(boxes), startsWith('qty 4 '));
  });

  testWidgets('a slider\'s thumb: a drag from it moves the value by the distance', (tester) async {
    final (report, boxes) = await run(tester, const [Step('drag', 'vol@thumb', '-60,0')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final volume = int.parse(RegExp(r'volume (\d+)').firstMatch(labelOf(boxes))![1]!);
    expect(volume, inInclusiveRange(25, 35));
  });

  testWidgets('a dropdown\'s option by its label: opened first, then chosen', (tester) async {
    final (report, boxes) = await run(tester, const [Step('tap', 'regionPick@option:Alaska')]);
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(labelOf(boxes), endsWith('region Alaska'));
    // Open, its option is reached by its label alone too.
    final (again, after) = await run(tester, const [Step('tap', 'regionPick'), Step('tap', 'Andes')]);
    expect(again.errors, 0, reason: '${again.diagnostics}');
    expect(labelOf(after), endsWith('region Andes'));
  });

  testWidgets('--dump-layout lists each control\'s parts; a part it has not is an error naming them', (tester) async {
    final (report, boxes) = await run(tester, const [Step('tap', 'quantity@thumb')]);
    Object? parts(String id) => boxes.firstWhere((b) => b['id'] == id)['parts'];
    expect(parts('quantity'), ['@decrement', '@increment']);
    expect(parts('vol'), ['@thumb']);
    expect(parts('regionPick'), ['@option:Alps', '@option:Alaska', '@option:Andes']);
    final message = report.diagnostics.firstWhere((d) => d['code'] == 'interaction_failed')['message'] as String;
    expect(message, contains('its parts: @decrement, @increment'));
  });
}
