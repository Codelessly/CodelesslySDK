// A dashed stroke path is one path drawn once, as a painter draws its dashed
// path: a pixel two dash ends share is inked once, not twice (drawn dash by
// dash it came out darker than the reference's).
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/render/behaviors.dart' show StrokePathPainter;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _paint(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas);
  final image = await recorder.endRecording().toImage(40, 10);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  return [for (var i = 0; i < 400; i++) data.getUint8(i * 4 + 3)];
}

void main() {
  test('dashes are drawn as one path', () async {
    // Dashes 1.2 apart with round caps 0.75 out: their ends share pixels.
    const sp = api.StrokePath(
      points: [api.Offset(2.3, 5.4), api.Offset(37.7, 5.4)],
      xUnit: api.PathUnit.pixels,
      yUnit: api.PathUnit.pixels,
      color: api.Color.black,
      width: 1.5,
      dashPattern: [3, 1.2],
    );
    final sdk = await _paint((c) => StrokePathPainter(sp).paint(c, const Size(40, 10)));
    final ref = await _paint((c) {
      final p = Path()
        ..moveTo(2.3, 5.4)
        ..lineTo(37.7, 5.4);
      final out = Path();
      for (final m in p.computeMetrics()) {
        var d = 0.0;
        while (d < m.length) {
          out.addPath(m.extractPath(d, d + 3 < m.length ? d + 3 : m.length), Offset.zero);
          d += 4.2;
        }
      }
      c.drawPath(out, Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    });
    var worst = 0;
    for (var i = 0; i < sdk.length; i++) {
      final d = (sdk[i] - ref[i]).abs();
      if (d > worst) worst = d;
    }
    expect(worst, 0);
  });
}
