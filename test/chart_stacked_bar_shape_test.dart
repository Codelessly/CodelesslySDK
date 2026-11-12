// A stacked bar's top corners are round whichever series are empty (the
// whole bar is clipped), and stackGapEdge: top puts each segment's gap
// over it, the top one included, as a column of boxes with top margins.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _chart(String edge, {double? totalsGap, bool baseline = false}) => {
      'type': 'chart',
      'layout': {'width': 300, 'height': 200},
      'props': {
        'chartType': 'bar',
        // The last series is empty: the top segment is the first series'.
        'data': [
          {'label': 'A', 'a': 6, 'b': 3, 'c': 0},
        ],
        'series': [
          {'field': 'a', 'name': 'A', 'color': '#FF0000FF', 'stack': 's'},
          {'field': 'b', 'name': 'B', 'color': '#FF00FF00', 'stack': 's'},
          {'field': 'c', 'name': 'C', 'color': '#FFFF0000', 'stack': 's'},
        ],
        'maxY': 10,
        'barRadius': 8,
        'barWidthFraction': 0.5,
        'stackGap': 2,
        'stackGapEdge': edge,
        // Room above the bar for its total.
        if (totalsGap != null) ...{'showTotals': true, 'totalsGap': totalsGap, 'maxY': 30},
        'gridColor': '#00000000',
        if (baseline) 'baselineColor': '#FFFF0000',
        'axisColor': '#00000000',
      },
    };

/// The first row from the top, in column [x], that isn't white.
Future<(int Function(int x), Rect)> _render(WidgetTester tester, String edge,
    {double? totalsGap, bool baseline = false, void Function(bool Function(int x, int y) red)? redAt}) async {
  final painter = ChartSeriesPainter(Node.fromJson(_chart(edge, totalsGap: totalsGap, baseline: baseline), id: 'c')!);
  const size = Size(300, 200);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
  painter.paint(canvas, size);
  late ByteData bytes;
  await tester.runAsync(() async {
    final image = await recorder.endRecording().toImage(300, 200);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  int firstInk(int x) {
    for (var y = 0; y < 200; y++) {
      final i = (y * 300 + x) * 4;
      if (bytes.getUint8(i) < 200 || bytes.getUint8(i + 1) < 200 || bytes.getUint8(i + 2) < 200) return y;
    }
    return 200;
  }

  redAt?.call((x, y) {
    final i = (y * 300 + x) * 4;
    return bytes.getUint8(i) > 200 && bytes.getUint8(i + 1) < 80 && bytes.getUint8(i + 2) < 80;
  });
  return (firstInk, painter.plotRect(size));
}

void main() {
  testWidgets('the bar is round on top though its last series is empty', (tester) async {
    final (firstInk, plot) = await _render(tester, 'between');
    final cx = plot.center.dx.round();
    // Find the bar's left edge on a row through its middle.
    var left = cx;
    while (firstInk(left - 1) < 200) {
      left--;
    }
    // At the very edge the round corner starts lower than at the centre.
    expect(firstInk(left + 1), greaterThan(firstInk(cx) + 2));
  });

  testWidgets('stackGapEdge top: the gap sits over every segment, the top one too', (tester) async {
    final (between, plot) = await _render(tester, 'between');
    final (top, _) = await _render(tester, 'top');
    final cx = plot.center.dx.round();
    // The bar's top row moves down by the gap.
    expect(top(cx) - between(cx), inInclusiveRange(1, 2));
  });

  testWidgets('totalsGap sets the space between a bar and its total', (tester) async {
    final (near, plot) = await _render(tester, 'between', totalsGap: 4);
    final (far, _) = await _render(tester, 'between', totalsGap: 12);
    final cx = plot.center.dx.round();
    // The label's top row moves up by the difference.
    expect(near(cx) - far(cx), 8);
  });

  testWidgets('baselineColor colours the grid\'s bottom line, under the bars', (tester) async {
    late bool Function(int x, int y) red;
    final (_, plot) = await _render(tester, 'between', baseline: true, redAt: (f) => red = f);
    bool anyRed(int x) => [for (var y = 0; y < 200; y++) y].any((y) => red(x, y));
    // Beside the bar the baseline shows; under the bar it is covered.
    expect(anyRed(plot.left.round() + 3), isTrue);
    expect(anyRed(plot.center.dx.round()), isFalse);
  });
}
