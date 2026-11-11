import 'dart:ui' as ui;
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/render/behaviours.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stroke progress follows geometric length, including curved paths', () {
    for (final curve in api.PathCurve.values) {
      StrokePathPainter painter(double p) => StrokePathPainter(
        api.StrokePath(
          points: const [
            api.Offset(0, 0),
            api.Offset(.3, 30),
            api.Offset(1, 10),
          ],
          curve: curve,
          progress: p,
        ),
      );
      final full = painter(1)
          .pathFor(const Size(100, 40))
          .computeMetrics()
          .fold(0.0, (double sum, m) => sum + m.length);
      final half = painter(.5)
          .visiblePathFor(const Size(100, 40))
          .computeMetrics()
          .fold(0.0, (double sum, m) => sum + m.length);
      expect(half, closeTo(full * .5, 0.3));
      expect(
        painter(0).visiblePathFor(const Size(100, 40)).computeMetrics(),
        isEmpty,
      );
    }
  });
  test(
    'partially drawn solid and dashed strokes paint no pixels past the reveal',
    () async {
      for (final dash in [
        <double>[],
        <double>[8, 4],
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        StrokePathPainter(
          api.StrokePath(
            points: const [api.Offset(0, 10), api.Offset(1, 10)],
            color: api.Color.white,
            width: 2,
            cap: api.StrokeCap.butt,
            progress: .5,
            dashPattern: dash,
          ),
        ).paint(canvas, const Size(100, 20));
        final picture = recorder.endRecording();
        final image = await picture.toImage(100, 20);
        final bytes = (await image.toByteData())!;
        expect(bytes.getUint8((10 * 100 + 4) * 4 + 3), greaterThan(0));
        expect(bytes.getUint8((10 * 100 + 75) * 4 + 3), 0);
        image.dispose();
        picture.dispose();
      }
    },
  );
}
