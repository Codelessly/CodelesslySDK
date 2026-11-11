import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _paint({
  bool? roundCaps,
  int segments = 0,
  double value = 50,
}) async {
  final node = api.Node.fromJson({
    'type': 'radialGauge',
    'props': {
      'value': value,
      'startAngle': 0,
      'sweepAngle': 180,
      'thickness': 20,
      'segments': segments,
      'majorTicks': 0,
      'labels': <double>[],
      'showTarget': false,
      'showNeedle': false,
      'trackColor': '#FF0000FF',
      'valueColor': '#FFFF0000',
      'roundCaps': ?roundCaps,
    },
  })!;
  final recorder = ui.PictureRecorder();
  RadialGaugePainter(node).paint(Canvas(recorder), const Size(200, 200));
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 200);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

List<int> _pixel(Uint8List image, int x, int y) =>
    image.sublist((y * 200 + x) * 4, (y * 200 + x) * 4 + 4);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'only continuous value ends become round; track keeps flat ends',
    () async {
      final flat = await _paint();
      final rounded = await _paint(roundCaps: true);
      // Radius 82: the value ends at (100, 182), over the remaining blue track.
      expect(_pixel(flat, 94, 182), [0, 0, 255, 255]);
      expect(_pixel(rounded, 94, 182), [255, 0, 0, 255]);
      // The value start extends beyond its flat track start.
      expect(_pixel(flat, 182, 94), [0, 0, 0, 0]);
      expect(_pixel(rounded, 182, 94), [255, 0, 0, 255]);
      // The blue track's far end does not gain a cap.
      expect(_pixel(flat, 18, 94), [0, 0, 0, 0]);
      expect(_pixel(rounded, 18, 94), [0, 0, 0, 0]);
      expect(await _paint(roundCaps: false), orderedEquals(flat));
    },
  );

  test('segmented gauges and empty values preserve their pixels', () async {
    expect(
      await _paint(roundCaps: true, segments: 12),
      orderedEquals(await _paint(segments: 12)),
    );
    expect(
      await _paint(roundCaps: true, value: 0),
      orderedEquals(await _paint(value: 0)),
    );
  });
}
