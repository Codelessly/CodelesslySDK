// A site that overrides its design system's accent (test/tool/fixtures/
// rebrand: Cards with an amber primary): the colors Cards makes from its
// accent follow the site's, in light and in dark, and a theme key written
// beside "theme" in site.json is reported instead of ignored in silence.
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

const _site = 'test/tool/fixtures/rebrand';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('site_theme_override_test'));
  tearDown(() => out.deleteSync(recursive: true));

  // The color (0xRRGGBB) in the middle of each 60 px band, top to bottom:
  // primary, accent, activeTint (over white), info, ink.
  Future<List<int>> bands(WidgetTester tester, RenderReport report) async {
    final p = (await tester.runAsync(() => decodePng(File(report.images.single).readAsBytesSync())))!;
    int at(int y) {
      final i = (y * p.width + 200) * 4;
      return (p.rgba[i] << 16) | (p.rgba[i + 1] << 8) | p.rgba[i + 2];
    }

    return [for (var b = 0; b < 5; b++) at(30 + 60 * b)];
  }

  // [rgb] at [alpha] over white.
  int overWhite(int rgb, int alpha) {
    int ch(int shift) => (((rgb >> shift) & 0xff) * alpha + 255 * (255 - alpha)) ~/ 255;
    return (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }

  bool near(int a, int b) => [16, 8, 0].every((s) => (((a >> s) & 0xff) - ((b >> s) & 0xff)).abs() <= 2);

  testWidgets('light: the selected tint and the info color are the site\'s accent, not Cards\' blue', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: [_site], out: out.path, sizes: const [Size(400, 400)]));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final c = await bands(tester, report);
    expect(c[0].toRadixString(16), 'b45309');
    expect(c[1].toRadixString(16), 'b45309');
    expect(near(c[2], overWhite(0xB45309, 0x24)), isTrue, reason: 'activeTint is ${c[2].toRadixString(16)}');
    expect(c[3].toRadixString(16), 'b45309', reason: 'info follows the accent');
    expect(c[4].toRadixString(16), '111827', reason: 'the ink is Cards\'');
  });

  testWidgets('dark: the accent is made from the override', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: [_site], out: out.path, sizes: const [Size(400, 400)], theme: 'dark'));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final c = await bands(tester, report);
    expect(c[0].toRadixString(16), isNot('3b82f6'), reason: 'not Cards\' dark blue');
    expect((c[0] >> 16) & 0xff, greaterThan(c[0] & 0xff), reason: 'amber: ${c[0].toRadixString(16)}');
    expect(c[1], c[0]);
    expect(c[3], c[0]);
    expect(c[4].toRadixString(16), 'ffffff');
  });

  testWidgets('"primary" beside "theme" in site.json is a warning that says where it goes', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: [_site], out: out.path, sizes: const [Size(400, 400)], validateOnly: true));
    final d = report.diagnostics.where((d) => d['code'] == 'site_key_ignored').single;
    expect(d['severity'], 'warning');
    expect(d['file'], 'site.json');
    expect(d['message'], contains('"theme": {"primary": "#FFB45309"}'));
  });
}
