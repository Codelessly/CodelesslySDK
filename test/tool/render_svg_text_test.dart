// Text inside an SVG image: drawn in the site's fonts, not as solid blocks,
// and a family no font is had for is named in a diagnostic.
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const _site = 'test/tool/fixtures/svgtext';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_svg_text'));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('SVG text in a generic, an unavailable or no family is drawn in the site font, and the missing family is named',
      (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: [_site], out: out.path, sizes: const [Size(400, 180)]));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    // Three lines of "illicit lilt" (thin letters): drawn in a real font,
    // a band holds little ink; drawn as blocks, most of it is black.
    final (data, w, _) = (await tester.runAsync(() async {
      final bytes = File('${out.path}/home@400x180.png').readAsBytesSync();
      final frame = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
      return (await frame.image.toByteData(), frame.image.width, frame.image.height);
    }))!;
    double ink(int top, int bottom) {
      var dark = 0, all = 0;
      for (var y = top; y < bottom; y++) {
        for (var x = 10; x < 260; x++) {
          all++;
          if (data!.getUint8((y * w + x) * 4) < 128) dark++;
        }
      }
      return dark / all;
    }

    for (final (name, top) in [('sans-serif', 18), ('DejaVu Sans, sans-serif', 78), ('no family', 138)]) {
      expect(ink(top, top + 28), lessThan(0.35), reason: 'the line in $name is drawn as blocks');
    }
    final fallback = report.diagnostics.where((d) => d['code'] == 'font_fallback').map((d) => d['message'] as String).toList();
    expect(fallback, [contains('"DejaVu Sans"')], reason: 'only the family nothing has is reported; generic families are the site font');
    expect(fallback.single, contains('images/labels.svg'), reason: 'the message names the SVG that asks for it');
  });
}
