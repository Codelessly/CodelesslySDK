// A replay goes on after a step navigates away from a focused field: type
// into a page whose title field autofocuses, tap a Save that navigates, then
// act on the page navigated to. The leaving page's field must not autofocus
// again as the navigator moves its render objects (an `attached` assertion
// that broke the widget tree: later steps acted on nothing, and a render
// server drew every later run on the broken tree). Run as one run alone
// (cold) and as several runs on one tester (as the render server serves
// them), with the tree checked sound after each. (NOCD friction register:
// "Continue replay after navigation replaces a focused or tapped widget";
// 28-tools-and-looptape entries 2 and 3.)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _box(String id, List<Map<String, Object?>> actions) => {
      'type': 'box',
      'layout': {'width': 200, 'height': 48},
      'decoration': {
        'fills': [
          {'color': '#FFDDDDDD'},
        ],
      },
      'actions': actions,
    };

Map<String, Object?> _page(String id, Map<String, Object?> nodes, List<String> children, [List<Map<String, Object?>> variables = const []]) => {
      'schema': 3,
      'id': id,
      'roots': [id],
      'nodes': {
        id: {
          'type': 'canvas',
          'slots': {'body': '${id}Col'},
          'layout': {'width': 390, 'height': 600},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        '${id}Col': {'type': 'column', 'children': children, 'layout': {'width': {'fill': 390}, 'height': {'fill': 600}}},
        ...nodes,
      },
      if (variables.isNotEmpty) 'variables': {id: variables},
    };

void main() {
  late Directory out;
  late String site;
  setUp(() {
    out = Directory.systemTemp.createTempSync('render_navigate_focused_test');
    final dir = Directory('${out.path}/site')..createSync();
    site = dir.path;
    File('$site/site.json').writeAsStringSync(jsonEncode({
      'pages': ['script.json', 'home.json'],
    }));
    File('$site/script.json').writeAsStringSync(jsonEncode(_page('script', {
      'title': {
        'type': 'textField',
        'layout': {'width': {'fill': 390}, 'height': 48},
        'props': {'initialValue': '', 'autofocus': true},
      },
      'body': {
        'type': 'textField',
        'layout': {'width': {'fill': 390}, 'height': 48},
        'props': {'initialValue': ''},
      },
      'save': _box('save', [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'delay', 'ms': 100},
            {'type': 'navigate', 'to': 'home'},
          ],
        },
      ]),
    }, ['title', 'body', 'save'])));
    File('$site/home.json').writeAsStringSync(jsonEncode(_page('home', {
      'count': {
        'type': 'text',
        'layout': {'width': {'fill': 390}, 'height': {'hug': 20}},
        'props': {'text': r'home ${n}', 'style': {'fontSize': 14, 'color': '#FF000000'}},
      },
      'go': _box('go', [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'setVariable', 'variable': 'n', 'value': r'${= n+1}'},
          ],
        },
      ]),
    }, ['count', 'go'], [
      {'name': 'n', 'type': 'integer', 'value': 0},
    ])));
  });
  tearDown(() => out.deleteSync(recursive: true));

  const steps = [Step('type', 'title', 'Practice script'), Step('type', 'body', 'Read this aloud.'), Step('tap', 'save'), Step('tap', 'go')];

  Future<void> replay(WidgetTester tester, String label) async {
    final report = await runRender(tester, RenderArgs(
        inputs: [site], out: '${out.path}/o', screens: const ['script'], sizes: const [Size(390, 600)],
        steps: steps, label: label, dumpLayout: true, googleFonts: false));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final layout = File('${out.path}/o/home@390x600-$label.layout.json');
    expect(layout.existsSync(), isTrue, reason: 'the capture is of the page navigated to: ${report.images}');
    final boxes = (jsonDecode(layout.readAsStringSync()) as List).cast<Map>();
    expect(boxes.firstWhere((b) => b['id'] == 'count')['text'], 'home 1', reason: 'the tap after the navigation acted on the new page');
  }

  testWidgets('type, then a Save that navigates, then a tap on the new page: one run (cold)', (tester) async {
    await replay(tester, 'cold');
    expect(await renderTreeSound(tester), isTrue);
  });

  testWidgets('the same in one harness three times (as the render server serves runs): each from a sound tree', (tester) async {
    for (final label in ['warm1', 'warm2', 'warm3']) {
      await replay(tester, label);
      expect(await renderTreeSound(tester), isTrue, reason: 'after $label');
    }
  });
}
