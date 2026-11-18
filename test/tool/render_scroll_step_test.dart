// `--scroll`: one offset, or `x,y` (`--scroll reading=0,650`); a page that
// does not scroll is a warning that the step did nothing, not a failed step.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

Map<String, Object?> _band(String color) => {
      'type': 'box',
      'layout': {'width': {'fill': 390}, 'height': 400},
      'decoration': {
        'fills': [
          {'color': color},
        ],
      },
    };

Map<String, Object?> _doc({required bool long}) => {
      'schema': 3,
      'id': 'page',
      'roots': ['page'],
      'nodes': {
        'page': {
          'type': 'canvas',
          'slots': {'body': 'reading'},
          'layout': {'width': 390, 'height': 700},
          'decoration': {
            'fills': [
              {'color': '#FFFFFFFF'},
            ],
          },
        },
        'reading': {
          'type': 'column',
          'children': [if (long) ...['a', 'b', 'c'] else 'a'],
          'layout': {'width': {'fill': 390}, 'height': {'fill': 700}},
          'props': {'scrollable': true},
        },
        'a': _band('#FFFF0000'),
        'b': _band('#FF00FF00'),
        'c': _band('#FF0000FF'),
      },
    };

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_scroll_step_test'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(RenderReport, int)> run(WidgetTester tester, Step step, {bool long = true}) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc(long: long)));
    final report = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: [step], dumpLayout: true));
    final boxes = jsonDecode(File('${out.path}/o/page@390x700.layout.json').readAsStringSync()) as List;
    return (report, boxes.cast<Map>().firstWhere((b) => b['id'] == 'b')['y'] as int);
  }

  testWidgets('x,y scrolls a vertical scroll view by y', (tester) async {
    final (report, y) = await run(tester, const Step('scroll', 'reading', '0,300'));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    expect(y, 100);
  });

  testWidgets('one offset as before', (tester) async {
    final (report, y) = await run(tester, const Step('scroll', 'reading', '250'));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    expect(y, 150);
  });

  testWidgets('--scroll screen on a page that does not scroll: a warning, the step did nothing', (tester) async {
    final file = File('${out.path}/page.json')..writeAsStringSync(jsonEncode(_doc(long: false)));
    final report = await runRender(
        tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 700)], steps: const [Step('scroll', 'screen', '400')]));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(report.diagnostics.single['code'], 'scroll_nothing');
  });
}
