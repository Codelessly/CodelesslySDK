// A render never dies or hangs on a document: a fitted Stack with no size of
// its own to scale from draws (its frame was not a number, and the layout
// dump died on it), and a screen that takes longer than the limit is an
// error of that screen, after which the run goes on.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _page(Map<String, Object?> nodes, {List<Object?> variables = const []}) => {
      'schema': 3,
      'id': 'page',
      'roots': ['page'],
      'nodes': {
        'page': {
          'type': 'canvas',
          'slots': {'body': 'col'},
          'layout': {'width': 800, 'height': 600},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        ...nodes,
      },
      if (variables.isNotEmpty) 'variables': {'page': variables},
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_limits_test'));
  tearDown(() => out.deleteSync(recursive: true));

  List<Map> boxes(String name) => (jsonDecode(File('${out.path}/o/$name.layout.json').readAsStringSync()) as List).cast<Map>();

  testWidgets('a Stack with fit=contain and a width that fills: its content\'s size is what it scales', (tester) async {
    final file = File('${out.path}/page.json')
      ..writeAsStringSync(jsonEncode(_page({
        'col': {
          'type': 'column',
          'children': ['map'],
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        },
        // `Stack w=fill h=440 fit=contain` over a 550 by 424 plan.
        'map': {
          'type': 'stack',
          'children': ['plan'],
          'layout': {'width': {'fill': 0}, 'height': 440},
          'props': {'fit': 'contain'},
        },
        'plan': {
          'type': 'stack',
          'layout': {'width': 550, 'height': 424},
          'decoration': {
            'fills': [
              {'color': '#FF151019'},
            ],
          },
        },
      })));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(800, 600)], dumpLayout: true));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final plan = boxes('page@800x600').firstWhere((b) => b['id'] == 'plan');
    // 550 by 440 contained in 800 by 440: at its own size, centred.
    expect(plan['w'], 550);
    expect(plan['h'], 424);
    expect(plan['x'], 125);
  });

  testWidgets('a box that fills, in a cell of a grid whose rows hug: measured with no bound, it has no size of its own and no error', (tester) async {
    final file = File('${out.path}/page.json')
      ..writeAsStringSync(jsonEncode(_page({
        'col': {
          'type': 'column',
          'children': ['grid'],
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        },
        'grid': {
          'type': 'gridView',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'crossAxisCount': 2, 'shrinkWrapRows': true, 'physics': 'never', 'mainAxisExtent': 120},
          'bind': {'data': r'${rows}'},
          'children': ['cell'],
        },
        'cell': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}},
          'children': ['art', 'label'],
        },
        // A decorated box with nothing in it that sizes it, growing in the cell.
        'art': {
          'type': 'stack',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}, 'flex': 1},
          'decoration': {
            'fills': [
              {'color': '#FF336699'},
            ],
          },
        },
        'label': {
          'type': 'text',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'text': r'${item.title}', 'style': {'color': '#FF000000'}},
        },
      }, variables: [
        {
          'name': 'rows',
          'type': 'list',
          'value': [
            {'title': 'a'},
            {'title': 'b'},
          ],
        },
      ])));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(800, 600)], dumpLayout: true));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final art = boxes('page@800x600').firstWhere((b) => b['id'] == 'art');
    expect(art['w'], 400);
    expect(art['h'], greaterThan(90));
  });

  testWidgets('a screen over --screen-timeout is an error of that screen (screen_timeout), and the run goes on', (tester) async {
    final file = File('${out.path}/page.json')
      ..writeAsStringSync(jsonEncode(_page({
        'col': {
          'type': 'column',
          'children': ['shown'],
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        },
        'shown': {
          'type': 'text',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'text': r'${= twice(4)}', 'style': {'color': '#FF000000'}},
        },
      }, variables: [
        const Variable(id: 'twice', name: 'twice', formula: 'n * 2', parameters: ['n']).toJson(),
      ])));
    final report = await runRender(
        tester,
        RenderArgs(
            inputs: [file.path],
            out: '${out.path}/o',
            sizes: const [Size(800, 600), Size(390, 600)],
            dumpLayout: true,
            screenTimeout: const Duration(microseconds: 1)));
    final timeouts = report.diagnostics.where((d) => d['code'] == 'screen_timeout').toList();
    expect(timeouts, hasLength(2));
    expect(timeouts.first['severity'], 'error');
    expect(timeouts.first['message'], contains('over the limit'));
    // Both sizes were captured: the run went on.
    expect(File('${out.path}/o/page@800x600.png').existsSync(), isTrue);
    expect(File('${out.path}/o/page@390x600.png').existsSync(), isTrue);
  });

  testWidgets('within the limit the screen draws its functions\' values and nothing is said', (tester) async {
    final file = File('${out.path}/page.json')
      ..writeAsStringSync(jsonEncode(_page({
        'col': {
          'type': 'column',
          'children': ['shown'],
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        },
        'shown': {
          'type': 'text',
          'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'text': r'${= twice(4)}', 'style': {'color': '#FF000000'}},
        },
      }, variables: [
        const Variable(id: 'twice', name: 'twice', formula: 'n * 2', parameters: ['n']).toJson(),
      ])));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(800, 600)], dumpLayout: true));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(boxes('page@800x600').firstWhere((b) => b['id'] == 'shown')['text'], '8');
  });
}
