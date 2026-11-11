// plotChart as a Cartesian graph: curves with gaps, a zero-anchored grid
// with minor lines, origin axes with labels, marker shapes and a selection
// with guides to the axes. Pixels are read from the painted picture.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter_test/flutter_test.dart';

const w = 200, h = 200;

/// A 200×200 graph of x and y from −10 to 10 (10px per unit).
Node graph(Map<String, Object?> props) => Node.fromJson({
      'id': 'g',
      'type': 'plotChart',
      'layout': {'width': w, 'height': h},
      'props': {
        'xMin': -10,
        'xMax': 10,
        'yMin': -10,
        'yMax': 10,
        'plotInset': 0,
        'labelHeight': 0,
        'lineWidth': 0,
        'gridColor': '#00000000',
        ...props,
      },
    })!;

Future<Uint8List> paint(WidgetTester tester, Node n) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 200), Paint()..color = const Color(0xFFFFFFFF));
    PlotChartPainter(n).paint(canvas, const Size(200, 200));
    final image = await recorder.endRecording().toImage(w, h);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  });
  return bytes;
}

Color at(Uint8List px, int x, int y) {
  final i = (y * w + x) * 4;
  return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
}

bool near(Color a, Color b, [int tolerance = 40]) =>
    ((a.r - b.r) * 255).abs() <= tolerance &&
    ((a.g - b.g) * 255).abs() <= tolerance &&
    ((a.b - b.b) * 255).abs() <= tolerance;

const red = Color(0xFFFF0000), blue = Color(0xFF0000FF), white = Color(0xFFFFFFFF), black = Color(0xFF000000);

void main() {
  testWidgets('series draw with gaps over the shared domain', (tester) async {
    // y = 5 from x = −10 to 10 in 21 points, with a gap from x = −1 to 1.
    final points = <double?>[for (var i = 0; i <= 20; i++) (i >= 9 && i <= 11) ? null : 5];
    final px = await paint(tester, graph({
      'series': [
        {'id': 'a', 'points': points, 'color': '#FFFF0000', 'width': 3},
      ],
    }));
    expect(near(at(px, 40, 50), red), isTrue, reason: 'the line at x = −6, y = 5');
    expect(near(at(px, 160, 50), red), isTrue, reason: 'the line at x = 6');
    expect(near(at(px, 100, 50), white), isTrue, reason: 'no line across the gap at x = 0');
  });

  testWidgets('a zero-anchored grid draws at multiples of the step, minor lines between', (tester) async {
    final px = await paint(tester, graph({
      'xMin': -9.5, 'xMax': 10.5, // x = 0 at 95px
      'gridAnchor': 'zero', 'gridStepX': 5, 'gridStepY': 5,
      'gridColor': '#FF0000FF', 'minorDivisions': 5, 'minorGridColor': '#FFFF0000',
    }));
    // Major vertical lines at x = −5, 0, 5, 10 → 45, 95, 145, 195 (+0.5).
    expect(near(at(px, 95, 30), blue), isTrue, reason: 'major at x = 0');
    expect(near(at(px, 145, 30), blue), isTrue, reason: 'major at x = 5');
    expect(near(at(px, 105, 30), red), isTrue, reason: 'minor at x = 1');
    expect(near(at(px, 100, 33), white), isTrue, reason: 'nothing at x = 0.5');
    // Horizontal majors at y = 5 → 50px.
    expect(near(at(px, 30, 50), blue), isTrue, reason: 'major at y = 5');
  });

  testWidgets('origin axes, ticks and an arrowhead', (tester) async {
    final px = await paint(tester, graph({
      'originAxes': true, 'axisArrows': true, 'axisColor': '#FF000000', 'axisWidth': 2,
      'gridAnchor': 'zero', 'gridStepX': 5, 'gridStepY': 5,
    }));
    expect(near(at(px, 30, 100), black), isTrue, reason: 'x axis at y = 0');
    expect(near(at(px, 100, 170), black), isTrue, reason: 'y axis at x = 0');
    expect(near(at(px, 192, 102), black, 120), isTrue, reason: 'arrowhead at the right end');
  });

  testWidgets('axis labels stick to the edge when the axis is off the plot', (tester) async {
    // y from 2 to 22: the x axis is below the plot; its labels sit at the bottom.
    final px = await paint(tester, graph({
      'yMin': 2, 'yMax': 22, 'originAxes': true, 'axisColor': '#FF000000',
      'gridAnchor': 'zero', 'gridStepX': 5,
      'labelStyle': {'fontSize': 12, 'color': '#FF0000FF'},
    }));
    var blueRows = 0;
    for (var y = 150; y < 200; y++) {
      for (var x = 140; x < 160; x++) {
        if (near(at(px, x, y), blue, 90)) {
          blueRows++;
          break;
        }
      }
    }
    expect(blueRows, greaterThan(3), reason: 'the "5" label drawn near the bottom edge');
  });

  testWidgets('marker shapes: a ring is hollow, a dot is filled', (tester) async {
    final px = await paint(tester, graph({
      'markers': [
        {'x': -5, 'y': 0, 'shape': 'ring', 'color': '#FFFF0000', 'radius': 6},
        {'x': 5, 'y': 0, 'shape': 'dot', 'color': '#FF0000FF', 'radius': 6},
        {'x': 0, 'y': 5, 'shape': 'diamond', 'strokeColor': '#FF000000', 'radius': 7},
      ],
    }));
    expect(near(at(px, 50, 100), white), isTrue, reason: 'ring centre is its fill');
    expect(near(at(px, 56, 100), red, 90), isTrue, reason: 'ring outline');
    expect(near(at(px, 150, 100), blue), isTrue, reason: 'dot centre filled');
    expect(near(at(px, 100, 50), white), isTrue, reason: 'diamond centre is its fill');
  });

  testWidgets('a selection on a series draws guides to both axes and a ringed dot', (tester) async {
    final px = await paint(tester, graph({
      'series': [
        {'id': 'line', 'points': [-10, 10], 'color': '#00000000'}, // y = x
      ],
      'selectedX': 5, 'selectionSeries': 'line', 'selectionGuides': 'axes',
      'selectionLineColor': '#FFFF0000', 'selectionLineWidth': 2,
      'selectionDotRadius': 5, 'selectionDotColor': '#FFFFFFFF', 'selectionDotStrokeColor': '#FF0000FF',
      'selectionDotStrokeWidth': 2, 'selectionXLabel': '5.0000', 'selectionTagColor': '#FF000000',
    }));
    // The point is (5, 5) → (150, 50). Dashes run down to y = 0 (100px) and left to x = 0.
    var dashed = 0;
    for (var y = 60; y < 96; y++) {
      if (near(at(px, 150, y), red, 90)) dashed++;
    }
    expect(dashed, inInclusiveRange(10, 26), reason: 'a dashed vertical guide');
    expect(near(at(px, 150, 50), white), isTrue, reason: 'the dot centre');
    expect(near(at(px, 155, 50), blue, 90), isTrue, reason: 'the dot ring');
    // The test font draws each glyph as a solid box, so the tag shows as its
    // black padding around white text.
    var tag = 0;
    for (var x = 100; x < 200; x++) {
      if (near(at(px, x, 120), black)) tag++;
    }
    expect(tag, greaterThan(40), reason: 'the x tag under the axis');
  });

  test('a series value interpolates and skips gaps', () {
    final p = PlotChartPainter(graph({
      'series': [
        {'id': 's', 'points': [0, 10, null, 30]},
      ],
    }));
    expect(p.seriesValueAt('s', -10), 0);
    expect(p.seriesValueAt('s', -10 + 20 / 6), closeTo(5, 1e-9));
    expect(p.seriesValueAt('missing', 0), isNull);
  });
}
