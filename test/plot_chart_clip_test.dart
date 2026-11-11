// A plotChart with clip off draws past its box, as a CustomPaint does: a
// line along the top edge shows its stroke's outer half above it.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Uint8List> paint(WidgetTester tester, bool clip) async {
    final n = Node.fromJson({
      'id': 'g', 'type': 'plotChart', 'layout': {'width': 100, 'height': 100},
      'props': {
        'xMin': 0, 'xMax': 1, 'yMin': -1, 'yMax': 1, 'plotInset': 0, 'labelHeight': 0, 'gridColor': '#00000000',
        'points': [1, 1, 1], 'lineColor': '#FFFF0000', 'lineWidth': 6, 'animate': false, 'clip': clip,
      },
    })!;
    late Uint8List bytes;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawRect(const Rect.fromLTWH(0, 0, 200, 200), Paint()..color = const Color(0xFFFFFFFF));
      canvas.translate(50, 50);
      PlotChartPainter(n).paint(canvas, const Size(100, 100));
      final image = await recorder.endRecording().toImage(200, 200);
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    });
    return bytes;
  }

  bool redAt(Uint8List px, int x, int y) {
    final i = (y * 200 + x) * 4;
    return px[i] > 200 && px[i + 1] < 80 && px[i + 2] < 80;
  }

  testWidgets('clipped by default; with clip off the stroke overhangs the box', (tester) async {
    final clipped = await paint(tester, true);
    final open = await paint(tester, false);
    // Inside the box, both draw the line.
    expect(redAt(clipped, 100, 51), isTrue);
    expect(redAt(open, 100, 51), isTrue);
    // 2px above the box: only the unclipped chart.
    expect(redAt(clipped, 100, 48), isFalse);
    expect(redAt(open, 100, 48), isTrue);
  });
}
