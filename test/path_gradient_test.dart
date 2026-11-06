import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A path's gradient fills and strokes are painted (Safecracker's gold bars
/// and the dial's brass index were drawn as bare outlines: only solid
/// colours were painted).
void main() {
  Future<List<int>> pixelsOf(PathNodePainter painter, List<Offset> at) async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(100, 100));
    final image = await recorder.endRecording().toImage(100, 100);
    final data = (await image.toByteData())!;
    return [
      for (final p in at) data.getUint32(((p.dy.toInt() * 100) + p.dx.toInt()) * 4),
    ];
  }

  test('a gradient fill paints the shape, graded across the box', () async {
    final painter = PathNodePainter(
      data: 'M0 0 L100 0 L100 100 L0 100 Z',
      gradients: const [
        LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF0000FF)]),
      ],
    );
    final px = await pixelsOf(painter, const [Offset(2, 50), Offset(97, 50)]);
    // RGBA: red on the left, blue on the right.
    expect(px[0] >> 24 & 0xFF, greaterThan(200));
    expect(px[1] >> 8 & 0xFF, greaterThan(200));
  });

  test('a gradient stroke paints the outline', () async {
    final painter = PathNodePainter(
      data: 'M0 50 L100 50',
      strokeWeight: 10,
      strokeGradients: const [
        LinearGradient(colors: [Color(0xFF00FF00), Color(0xFF00FF00)]),
      ],
    );
    final px = await pixelsOf(painter, const [Offset(50, 50), Offset(50, 10)]);
    expect(px[0] >> 16 & 0xFF, greaterThan(200)); // green on the line
    expect(px[1] & 0xFF, 0); // nothing off it
  });
}
