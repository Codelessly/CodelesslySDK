import 'dart:ui' as ui;
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<List<int>>> samples(Map<String, Object?> props) async {
  final node = api.Node.fromJson({
    'type': 'barChart',
    'props': {
      'values': [1, 1],
      'labels': <String>[],
      'gridLines': 0,
      'barGap': 0,
      'barRadius': 0,
      'max': 1,
      ...props,
    },
  }, id: 'bars')!;
  final recorder = ui.PictureRecorder();
  BarChartPainter(node).paint(Canvas(recorder), const Size(100, 100));
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final result = [
    for (final x in [25, 75])
      bytes.sublist((50 * 100 + x) * 4, (50 * 100 + x) * 4 + 4),
  ];
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bar pixels use distinct party colours with a single-colour fallback',
    () async {
      final palette = await samples({
        'colors': ['#FFFF0000', '#FF0000FF'],
      });
      expect(palette[0], [255, 0, 0, 255]);
      expect(palette[1], [0, 0, 255, 255]);
      final fallback = await samples({
        'colors': ['#FFFF0000'],
        'color': '#FF00FF00',
      });
      expect(fallback[1], [0, 255, 0, 255]);
    },
  );
  test('highlight dimming preserves each bar hue', () async {
    final palette = await samples({
      'colors': ['#FFFF0000', '#FF0000FF'],
      'highlight': 0,
      'dimmedOpacity': .5,
    });
    expect(palette[0], [255, 0, 0, 255]);
    expect(palette[1][0], 0);
    expect(palette[1][3], 128);
    expect(palette[1][2], greaterThan(0));
  });
}
