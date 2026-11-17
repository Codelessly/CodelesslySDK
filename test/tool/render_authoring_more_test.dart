// The render command (tool/render): more fixes that came out of authoring
// with it (component paths, covered nodes, typing, what draws nothing,
// fills, component actions). Run in-process on the fixtures next to this file.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const fixtures = 'test/tool/fixtures';
const a0 = '$fixtures/authoring';

List<String> codes(RenderReport r, [String? severity]) => [
      for (final d in r.diagnostics)
        if (severity == null || d['severity'] == severity) d['code'] as String,
    ];

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_authoring_more_test'));
  tearDown(() => out.deleteSync(recursive: true));

  group('authoring fixes', () {
    const a = '$fixtures/authoring';
    List<Map> diag(RenderReport r, String code) => [for (final d in r.diagnostics) if (d['code'] == code) d];

    testWidgets('test 4 reproductions: a component root by its call path, scrollTo a repeated component call, a tab by its own id', (tester) async {
      for (final (site, step) in const [
        ('component_path', Step('tap', 'mobileNav/tabs@1')),
        ('component_scroll', Step('tap', 'next')),
        ('tab_id', Step('tap', 'stay')),
        // A node-level tooltip does not take the tap from its button.
        ('tooltip_click', Step('tap', 'open')),
      ]) {
        final report = await runRender(tester, RenderArgs(inputs: ['$a/test4/$site'], out: out.path, sizes: const [Size(390, 844)], steps: [step], label: site));
        expect(report.errors, 0, reason: '$site: ${report.diagnostics}');
      }
    });

    testWidgets('a click reaction written on a component call runs in the page\'s scope: it reads and sets the page\'s variables (the generated Sudoku\'s number pad)', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/test4/call_click'], out: out.path, sizes: const [Size(390, 300)],
          steps: const [Step('tap', 'tap')], label: 'call', dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final boxes = jsonDecode(File('${out.path}/s@390x300-call.layout.json').readAsStringSync()) as List;
      expect(boxes.any((b) => (b as Map)['id'] == 'shown'), isTrue, reason: 'count became 1');
    });

    testWidgets('a tap on a covered node names what covers it', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'last')]));
      final failed = diag(report, 'interaction_failed');
      expect(failed, hasLength(1), reason: '${report.diagnostics}');
      expect(failed.single['message'], contains('"veil"'));
      final through = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'spacer-top')]));
      expect(diag(through, 'interaction_failed').single['message'], contains('no fill and no reaction'));
    });

    testWidgets('a type step types into a text field, and its bound variable and the text showing it follow', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/checks.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('focus', 'field'), Step('type', 'field', 'cauliflower')], dumpLayout: true));
      expect(diag(report, 'interaction_failed'), isEmpty, reason: '${report.diagnostics}');
      final shown = [
        for (final d in report.diagnostics)
          if (d['nodeId'] == 'echo') d,
      ];
      expect(shown, isEmpty);
      final echo = (jsonDecode(File('${out.path}/checks@390x844.layout.json').readAsStringSync()) as List).firstWhere((b) => b['id'] == 'echo') as Map;
      expect(echo['w'] as num, greaterThan(100), reason: '"Query: cauliflower" is wider than "Query: "');
    });

    testWidgets('what draws nothing is reported: missing glyphs, unknown icons, unevaluated text, paths past their box', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/checks.json'], out: out.path, sizes: const [Size(390, 844)]));
      expect(diag(report, 'missing_glyph').single['nodeId'], 'star');
      expect(diag(report, 'missing_glyph').single['message'], contains('U+2726'));
      expect(diag(report, 'icon_not_drawn').single['nodeId'], 'bad-icon');
      expect(diag(report, 'expression_not_evaluated'), isEmpty, reason: 'bound runs style the evaluated text');
      expect(diag(report, 'path_overflow').single['nodeId'], 'mark');
      expect(diag(report, 'icon_not_drawn').where((d) => d['nodeId'] == 'field'), isEmpty, reason: 'the prefix icon by name draws');
    });

    testWidgets('a full-page capture takes the page\'s own scroll height, and a bar fixed to the window is drawn in the first window', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/fullpage.json'], out: out.path, sizes: const [Size(390, 844)], fullPage: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final bytes = File('${out.path}/long@390x844.png').readAsBytesSync();
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect(height, 2000, reason: 'hero 400 + rest 1600, not the inner list\'s 640');
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData();
        return (data!, frame.image.width);
      });
      int red(int x, int y) => image!.$1.getUint8((y * image.$2 + x) * 4);
      expect(red(195, 844 - 12 - 26), 255, reason: 'the bar where a user first sees it');
      expect(red(195, 2000 - 12 - 26), isNot(255), reason: 'not at the bottom of the page');
    });
  });

  group('more authoring fixes', () {
    const f = '$fixtures/fix3';
    testWidgets('a fill with no room to fill is reported; a page id and a component id never collide', (tester) async {
      final r = await runRender(tester, RenderArgs(inputs: [f], out: out.path, sizes: const [Size(390, 844)]));
      expect(codes(r), ['fill_fallback'], reason: '${r.diagnostics}');
      final d = r.diagnostics.single;
      expect(d['nodeId'], 'cardBody');
      expect(d['message'], contains('parent "card" (column) hugs its height'));
      expect(d['message'], contains('280 px'));
    });

    testWidgets('an action naming a node of a component acts on its own instance', (tester) async {
      final r = await runRender(tester, RenderArgs(inputs: [f], out: out.path, sizes: const [Size(390, 844)], dumpLayout: true,
          steps: const [Step('tap', 'p2/go'), Step('wait', '12000')]));
      expect(codes(r, 'error'), isEmpty, reason: '${r.diagnostics}');
      final boxes = (jsonDecode(File('${out.path}/home@390x844.layout.json').readAsStringSync()) as List).cast<Map>();
      Map at(String path) => boxes.singleWhere((b) => b['path'] == path);
      bool shows(String panel) {
        final list = at('$panel/list'), end = at('$panel/end');
        return (end['y'] as num) >= (list['y'] as num) && (end['y'] as num) + (end['h'] as num) <= (list['y'] as num) + (list['h'] as num) + 0.5;
      }
      expect(shows('p2'), isTrue, reason: 'the tapped instance scrolled its own list: $boxes');
      expect(shows('p1'), isFalse, reason: 'the other instance did not move');
    });
  });
}
