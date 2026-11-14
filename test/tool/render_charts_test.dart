// The nonprofit impact page (brief 3): a line chart's tick labels, and
// counters that count up one after another in a load reaction.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_charts'));
  tearDown(() => out.deleteSync(recursive: true));

  Future<(RenderReport, Pixels, List<Map>)> render(WidgetTester tester) async {
    final report = await runRender(tester,
        RenderArgs(inputs: ['test/tool/fixtures/charts'], out: out.path, sizes: const [Size(390, 400)], dumpLayout: true));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final png = report.images.single;
    final pixels = (await tester.runAsync(() => decodePng(File(png).readAsBytesSync())))!;
    final boxes = (jsonDecode(File(png.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List).cast<Map>();
    return (report, pixels, boxes);
  }

  testWidgets('a line chart with no axisLabelStyle draws its tick labels in a visible color', (tester) async {
    final (_, p, boxes) = await render(tester);
    final chart = boxes.firstWhere((b) => b['id'] == 'lineChart');
    // Left of the plot (the y labels) and under it (the x labels): ink.
    var ink = 0;
    final left = chart['x'] as int, top = chart['y'] as int, h = (chart['h'] as num).toInt();
    for (var y = top; y < top + h; y++) {
      for (var x = left; x < left + 36; x++) {
        final i = (y * p.width + x) * 4;
        if (p.rgba[i] < 200 && p.rgba[i + 1] < 200 && p.rgba[i + 2] < 200) ink++;
      }
    }
    expect(ink, greaterThan(40), reason: 'the y tick labels 80%, 90%, 100% are drawn');
  });

  testWidgets('counters animated one after another in a load reaction are captured where they end', (tester) async {
    final (_, _, boxes) = await render(tester);
    // Bars as wide as the second and third counters (people / 40, goal * 2):
    // the capture waited for the whole chain, not its first timeline.
    expect(boxes.firstWhere((b) => b['id'] == 'peopleBar')['w'], 92);
    expect(boxes.firstWhere((b) => b['id'] == 'goalBar')['w'], 144);
  });
}
