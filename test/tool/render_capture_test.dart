// The render command's captures and steps on multi-page sites: full-page
// captures with sticky and fixed content, modals and navigation; route
// parameters on --navigate; drag steps; downloads and the clipboard; steps
// that name a node ambiguously or one shown only at another size. Run
// in-process on test/tool/fixtures/capture.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

const capture = 'test/tool/fixtures/capture';

List<String> codes(RenderReport r, [String? severity]) => [
      for (final d in r.diagnostics)
        if (severity == null || d['severity'] == severity) d['code'] as String,
    ];

/// The PNG's pixels.
Future<Pixels> pixelsOf(WidgetTester tester, String png) async =>
    (await tester.runAsync(() => decodePng(File(png).readAsBytesSync())))!;

/// The colour (0xRRGGBB) at [x], [y].
int rgbAt(Pixels p, int x, int y) {
  final i = (y * p.width + x) * 4;
  return (p.rgba[i] << 16) | (p.rgba[i + 1] << 8) | p.rgba[i + 2];
}

/// The rows whose pixel at [x] is [rgb].
List<int> rowsOf(Pixels p, int x, int rgb) => [for (var y = 0; y < p.height; y++) if (rgbAt(p, x, y) == rgb) y];

/// The runs of consecutive rows in [rows]: (first, count).
List<(int, int)> runsOf(List<int> rows) {
  final out = <(int, int)>[];
  for (final r in rows) {
    if (out.isNotEmpty && out.last.$1 + out.last.$2 == r) {
      out[out.length - 1] = (out.last.$1, out.last.$2 + 1);
    } else {
      out.add((r, 1));
    }
  }
  return out;
}

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_capture_test'));
  tearDown(() => out.deleteSync(recursive: true));

  RenderArgs run(List<Step> steps, {List<String> screens = const ['long'], bool fullPage = true, String? label}) => RenderArgs(
        inputs: [capture],
        out: out.path,
        sizes: const [Size(390, 844)],
        screens: screens,
        steps: steps,
        fullPage: fullPage,
        label: label,
      );

  group('full-page captures', () {
    testWidgets('a sticky header is drawn once, where it is at the top of the page, not once per window', (tester) async {
      final report = await runRender(tester, run(const []));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      // The page: 60 (header) + 50 (bar) + 4 × 600, on a 844 window.
      expect(p.height, 60 + 50 + 2400);
      expect(runsOf(rowsOf(p, 300, 0xFF0000)), [(0, 60)]);
      // Each section once, whole, in its place.
      expect(runsOf(rowsOf(p, 300, 0x808080)), [(110 + 1800, 600)]);
      expect(runsOf(rowsOf(p, 300, 0x404040)), [(110 + 600, 600)]);
    });

    testWidgets('a sticky header scrolled to by a step is still drawn once, at the top', (tester) async {
      final report = await runRender(tester, run(const [Step('scroll', 'lcol', '1500')]));
      final p = await pixelsOf(tester, report.images.single);
      expect(runsOf(rowsOf(p, 300, 0xFF0000)), [(0, 60)]);
    });

    testWidgets('an open modal is drawn once, over the first window, and the page below it is not dimmed', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'open')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      expect(p.height, 60 + 50 + 2400);
      // The dialog (blue, 100 high) once, in the first window.
      final blue = runsOf(rowsOf(p, 195, 0x0000FF));
      expect(blue, hasLength(1));
      expect(blue.single.$2, 100);
      expect(blue.single.$1, lessThan(844));
      // Below the first window the page shows as it is, undimmed.
      expect(rgbAt(p, 195, 1200), 0x404040);
      expect(rgbAt(p, 195, 2400), 0x808080);
    });

    testWidgets('after a tap that navigates, the capture is the destination page at its own height', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'go')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      // Detail: 400 + 1000, not the long page's 2510.
      expect(p.height, 1400);
      expect(runsOf(rowsOf(p, 195, 0x00FF00)), [(0, 400)]);
      expect(runsOf(rowsOf(p, 195, 0xFF00FF)), [(400, 1000)]);
    });

    testWidgets('after --navigate the capture is the destination page once, at its own height', (tester) async {
      final report = await runRender(tester, run(const [Step('navigate', 'detail')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      expect(p.height, 1400);
      expect(runsOf(rowsOf(p, 195, 0x000000)), [(0, 400)]);
      expect(runsOf(rowsOf(p, 195, 0xFF00FF)), [(400, 1000)]);
    });
  });

  group('--navigate with route parameters', () {
    for (final target in ['detail?id=42', '/detail?id=42', 'Detail?id=42']) {
      testWidgets('--navigate $target opens the screen with id=42 as \${route.id}', (tester) async {
        final report = await runRender(tester, run([Step('navigate', target)], fullPage: false));
        expect(report.errors, 0, reason: '${report.diagnostics}');
        final p = await pixelsOf(tester, report.images.single);
        expect(rgbAt(p, 195, 200), 0x00FF00);
      });
    }

    testWidgets('--navigate to no screen is an error naming the screens', (tester) async {
      final report = await runRender(tester, run(const [Step('navigate', 'nowhere?id=1')], fullPage: false));
      final failed = report.diagnostics.where((d) => d['code'] == 'interaction_failed').single;
      expect(failed['message'], contains('detail'));
    });
  });

  group('platform services in a headless run', () {
    testWidgets('a downloadFile action succeeds: the file lands in the out dir and is listed in the diagnostics', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'dl')], screens: const ['tools'], fullPage: false, label: 'saved'));
      expect(codes(report, 'error'), isEmpty, reason: '${report.diagnostics}');
      final saved = File('${out.path}/downloads/tools@390x844-saved/brief.txt');
      expect(saved.readAsStringSync(), 'Day 1: Zurich');
      final json = jsonDecode(File('${out.path}/diagnostics-saved.json').readAsStringSync()) as Map;
      expect((json['downloads'] as List).single['fileName'], 'brief.txt');
      // The chain went on after it.
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 120), 0x00FF00);
      expect(formatReport(report), contains('downloaded '));
    });

    testWidgets('copyToClipboard copies in memory, the chain after it runs, and the text is listed', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'cp')], screens: const ['tools'], fullPage: false));
      expect(codes(report, 'error'), isEmpty, reason: '${report.diagnostics}');
      expect(report.clipboard.single['text'], '12 Rue Example');
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 170), 0x00FF00);
    });
  });

  group('clocks', () {
    testWidgets('--now pins now(): a clock a timer writes from it shows that time', (tester) async {
      final args = parseArgs([capture, '--out', out.path, '--sizes', '390x844', '--screen', 'tools', '--now', '2026-01-01T09:00:00Z', '--wait', '1500']);
      final report = await runRender(tester, args);
      expect(codes(report, 'error'), isEmpty, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 220), 0x00FF00);
    });

    testWidgets('a --set holds when a timer writes the variable after it, and the run says so', (tester) async {
      final report = await runRender(tester, run(const [Step('set', 'clock', '"2026-01-01T10:00:00Z"'), Step('wait', '2500')],
          screens: const ['tools'], fullPage: false));
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 220), 0x00FF00);
      expect(codes(report, 'warning'), contains('set_overwritten'));
    });
  });
}
