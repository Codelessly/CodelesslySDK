// The render command's --key Enter in a text field: a one-line field is
// submitted (its `submitted` reactions run), as the platform's text input
// does on a device; a multi-line field gets a new line.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

final _doc = {
  'schema': 3,
  'id': 'page',
  'roots': ['page'],
  'variables': {
    'page': [
      {'name': 'draft', 'type': 'text', 'value': ''},
      {'name': 'notes', 'type': 'text', 'value': ''},
      {'name': 'sent', 'type': 'list', 'value': []},
    ],
  },
  'nodes': {
    'page': {
      'type': 'canvas',
      'slots': {'body': 'col'},
      'layout': {'width': 390, 'height': 600},
      'decoration': {
        'fills': [
          {'color': '#FFFFFFFF'},
        ],
      },
    },
    'col': {
      'type': 'column',
      'children': ['label', 'title', 'body'],
      'layout': {'width': {'fill': 390}, 'height': {'fill': 600}},
      'props': {'spacing': 8},
    },
    'label': {
      'type': 'text',
      'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
      'props': {
        'text': r'${= length(sent)} sent: ${= join(sent, "|")}; draft "${draft}"; lines ${= length(split(notes, "\n"))}',
        'style': {'fontSize': 14, 'color': '#FF000000'},
      },
    },
    'title': {
      'type': 'textField',
      'layout': {'width': 300, 'height': 48},
      'bind': {'props.initialValue': r'${draft}'},
      'actions': [
        {
          'trigger': {'type': 'submitted'},
          'actions': [
            {'type': 'setVariable', 'variable': 'sent', 'value': r'${= append(sent, result)}'},
            {'type': 'setVariable', 'variable': 'draft', 'value': ''},
          ],
        },
      ],
    },
    'body': {
      'type': 'textField',
      'layout': {'width': 300, 'height': 120},
      'props': {'maxLines': 4},
      'bind': {'props.initialValue': r'${notes}'},
    },
  },
};

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_enter_submits_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<String> label(WidgetTester tester, List<Step> steps) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc));
    final report = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 600)], steps: steps, dumpLayout: true));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/o/page@390x600.layout.json').readAsStringSync()) as List;
    return '${boxes.cast<Map>().firstWhere((b) => b['id'] == 'label')['text']}';
  }

  testWidgets('Enter submits a one-line field: its reactions run and may clear it', (tester) async {
    expect(await label(tester, const [Step('type', 'title', 'Buy milk')]), startsWith('0 sent: ; draft "Buy milk"'));
    expect(await label(tester, const [Step('type', 'title', 'Buy milk'), Step('key', 'Enter')]), startsWith('1 sent: Buy milk; draft ""'));
    expect(
        await label(tester, const [Step('type', 'title', 'One'), Step('key', 'Enter'), Step('type', 'title', 'Two'), Step('key', 'Enter')]),
        startsWith('2 sent: One|Two; draft ""'));
  });

  testWidgets('Enter in a multi-line field is a new line', (tester) async {
    expect(await label(tester, const [Step('type', 'body', 'first'), Step('key', 'Enter')]), endsWith('lines 2'));
  });
}
