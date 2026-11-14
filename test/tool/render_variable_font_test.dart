// A variable font declared once in site.json (restaurant, brief 3: Roboto
// Slab's variable TTF): every weight of its axis is drawn from it, at that
// weight, with no font_fallback.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

void main() {
  testWidgets('a variable font declared once draws 400 and 700 from its weight axis, without a fallback warning', (tester) async {
    final out = Directory.systemTemp.createTempSync('render_variable_font');
    addTearDown(() => out.deleteSync(recursive: true));
    final report = await runRender(tester,
        RenderArgs(inputs: ['test/tool/fixtures/varfont'], out: out.path, sizes: const [Size(390, 200)], dumpLayout: true));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    final png = report.images.single;
    final p = (await tester.runAsync(() => decodePng(File(png).readAsBytesSync())))!;
    final boxes = (jsonDecode(File(png.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List).cast<Map>();
    int ink(String id) {
      final b = boxes.firstWhere((b) => b['id'] == id);
      var n = 0;
      for (var y = b['y'] as int; y < (b['y'] as int) + (b['h'] as num); y++) {
        for (var x = b['x'] as int; x < (b['x'] as int) + (b['w'] as num); x++) {
          if (p.rgba[(y * p.width + x) * 4] < 128) n++;
        }
      }
      return n;
    }

    // The engine draws a variable font's weight on its wght axis: the 700
    // is the font's bold, with clearly more ink than the 400.
    final regular = ink('regular'), bold = ink('bold');
    expect(bold / regular, greaterThan(1.3), reason: 'regular $regular, bold $bold');
  });
}
