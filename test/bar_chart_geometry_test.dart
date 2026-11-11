// A bar chart's plot geometry: bars can keep headroom above a full bar while
// the grid spans the plot, the label band and the plot's top inset can be set.
import 'dart:ui' as ui;
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the bar's colour is at (50, [y]) of a 100 x 100 chart.
Future<bool> barAt(Map<String, Object?> props, int y) async {
  final node = api.Node.fromJson({
    'type': 'barChart',
    'props': {'values': [1], 'labels': <String>[], 'gridLines': 0, 'barGap': 0, 'barRadius': 0, 'max': 1,
      'color': '#FFFF0000', 'baselineColor': '#00000000', ...props},
  }, id: 'bars')!;
  final recorder = ui.PictureRecorder();
  BarChartPainter(node).paint(Canvas(recorder), const Size(100, 100));
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  final px = bytes.sublist((y * 100 + 50) * 4, (y * 100 + 50) * 4 + 4);
  image.dispose();
  picture.dispose();
  return px[0] == 255 && px[3] == 255;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a full bar fills the plot; with headroom it stops that far below the top', () async {
    expect(await barAt({}, 10), isTrue);
    // 99 tall plot, 40 kept above: the bar runs from 40 down.
    expect(await barAt({'barHeadroom': 40}, 30), isFalse);
    expect(await barAt({'barHeadroom': 40}, 50), isTrue);
  });
  test('the label band and the top inset size the plot', () async {
    // A 30 band under the plot: nothing below 69.
    expect(await barAt({'labelAreaHeight': 30}, 80), isFalse);
    expect(await barAt({'labelAreaHeight': 30}, 60), isTrue);
    // 20 above the top line: a full bar starts at 20.
    expect(await barAt({'plotTopInset': 20}, 10), isFalse);
    expect(await barAt({'plotTopInset': 20}, 30), isTrue);
  });
}
