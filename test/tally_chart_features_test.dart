import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/chart_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Node _node(String type, Map<String, Object?> props) => Node.fromJson({
      'id': 'n',
      'type': type,
      'layout': {'width': 300, 'height': 180},
      'props': {'animationDuration': 1000, ...props},
    })!;

Node _lines(List<Map<String, Object?>> data, {String? xField}) => _node('chart', {
      'chartType': 'line',
      'series': [
        {'field': 'cu', 'name': 'CU', 'kind': 'line', 'endLabel': true},
      ],
      'labelField': 'label',
      'data': data,
      'xField': ?xField,
    });

/// Renders [n] at 300 × 180 on white and returns the image's pixels.
Future<(int, ByteDataReader)> _render(WidgetTester tester, Node n) async {
  final source = DocumentSource(LayoutDocument.fromJson({
    'roots': ['n'],
    'nodes': {'n': n.toJson()..remove('id')},
  }));
  final scope = VariableScope(const []);
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: ColoredBox(color: Colors.white, child: NodeView(tree: tree, rootId: 'n'))))));
  await tester.pumpAndSettle();
  late (int, ByteDataReader) out;
  await tester.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    out = (img.width, ByteDataReader((await img.toByteData(format: ui.ImageByteFormat.rawRgba))!));
    if (const String.fromEnvironment('DUMP').isNotEmpty) {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/claude-0/-home-user/f763d9f0-c89d-5336-a388-0d64014b2cca/scratchpad/chart_test_${n.type}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
  tree.dispose();
  scope.dispose();
  return out;
}

class ByteDataReader {
  ByteDataReader(this.data);
  final ByteData data;
  Color at(int width, int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  }
}

bool _inkInColumn(int width, ByteDataReader px, int x, {int from = 0, int to = 158}) {
  for (var y = from; y < to; y++) {
    final c = px.at(width, x, y);
    if (c.r < 0.9 || c.g < 0.9 || c.b < 0.9) return true;
  }
  return false;
}

void main() {
  test('a new line point grows out of the point before it, not from zero', () {
    final from = _lines([
      {'label': 'a', 'cu': 10},
      {'label': 'b', 'cu': 20},
    ]);
    final to = _lines([
      {'label': 'a', 'cu': 10},
      {'label': 'b', 'cu': 20},
      {'label': 'c', 'cu': 30},
    ]);
    final half = chartDataFrame(from, to, 0.5).prop(ChartProps.data);
    expect(half[2]['cu'], 25); // from b's 20 toward 30, not from 0
  });

  test('with an x field the new point slides out along x too', () {
    final from = _lines([
      {'label': 'a', 'cu': 10, 'm': 0},
      {'label': 'b', 'cu': 20, 'm': 60},
    ], xField: 'm');
    final to = _lines([
      {'label': 'a', 'cu': 10, 'm': 0},
      {'label': 'b', 'cu': 20, 'm': 60},
      {'label': 'c', 'cu': 30, 'm': 100},
    ], xField: 'm');
    final half = chartDataFrame(from, to, 0.5).prop(ChartProps.data);
    expect(half[2]['m'], 80);
  });

  test('the new chart and plot props round-trip through JSON', () {
    final chart = _node('chart', {
      'xField': 'm',
      'xLabels': [
        {'x': 0, 'label': '22:00'},
      ],
      'endLabelWidth': 64,
      'endLabelDecimals': 0,
      'series': [
        {'field': 'cu', 'endLabel': true},
      ],
    });
    final back = Node.fromJson(chart.toJson())!;
    expect(back.prop(ChartProps.xField), 'm');
    expect(back.prop(ChartProps.xLabels).single.label, '22:00');
    expect(back.prop(ChartProps.endLabelWidth), 64);
    expect(back.prop(ChartProps.series).single.endLabel, isTrue);
    final plot = _node('plotChart', {
      'yLines': [
        {'y': 31, 'dashed': true, 'label': 'MAJORITY 31', 'axisLabel': '31', 'labelBackground': '#FFF3EFE6'},
      ],
      'yAxisWidth': 30,
      'lineEndX': 260,
      'endDotRadius': 4.5,
      'markerHollow': true,
      'ranges': [
        {'from': 180, 'to': 340, 'label': 'ISLES COUNT HALTED'},
      ],
    });
    final p2 = Node.fromJson(plot.toJson())!;
    expect(p2.prop(PlotChartProps.yLines).single.label, 'MAJORITY 31');
    expect(p2.prop(PlotChartProps.yLines).single.dashed, isTrue);
    expect(p2.prop(PlotChartProps.lineEndX), 260);
    expect(p2.prop(PlotChartProps.markerHollow), isTrue);
    expect(p2.prop(PlotChartProps.ranges).single.label, 'ISLES COUNT HALTED');
  });

  testWidgets('a plot chart stops its curve at lineEndX', (tester) async {
    final plot = _node('plotChart', {
      'points': [0, 10, 20, 30, 40],
      'xMin': 0,
      'xMax': 400,
      'yMin': 0,
      'yMax': 40,
      'labelHeight': 0,
      'lineColor': '#FF000000',
      'lineWidth': 3,
      'lineEndX': 200,
      'selectable': false,
    });
    final (w, px) = await _render(tester, plot);
    expect(_inkInColumn(w, px, 75), isTrue); // before the end
    expect(_inkInColumn(w, px, 260), isFalse); // after it: nothing
  });

  testWidgets('a plot chart draws its horizontal lines across the plot', (tester) async {
    final plot = _node('plotChart', {
      'points': [0, 0],
      'xMin': 0,
      'xMax': 1,
      'yMin': 0,
      'yMax': 40,
      'labelHeight': 0,
      'lineWidth': 0,
      'plotInset': 0,
      'yAxisWidth': 30,
      'selectable': false,
      'yLines': [
        {'y': 20, 'color': '#FFFF0000', 'width': 2, 'axisLabel': '20'},
      ],
    });
    final (w, px) = await _render(tester, plot);
    final c = px.at(w, 200, 90);
    expect(c.r, greaterThan(0.9));
    expect(c.g, lessThan(0.2));
    expect(px.at(w, 10, 90).r > 0.9 && px.at(w, 10, 90).g < 0.2, isFalse); // not in the gutter
  });

  testWidgets('a value-placed line chart with end labels and a now line paints', (tester) async {
    final chart = _node('chart', {
      'chartType': 'line',
      'xField': 'm',
      'domainMin': 0,
      'domainMax': 420,
      'nowValue': 260,
      'endLabelWidth': 60,
      'xLabels': [
        {'x': 0, 'label': '22:00'},
        {'x': 420, 'label': '05:00'},
      ],
      'series': [
        {'field': 'cu', 'name': 'CU', 'kind': 'line', 'color': '#FF1F4E8C', 'endLabel': true},
        {'field': 'wa', 'name': 'WA', 'kind': 'line', 'color': '#FFC42B2B', 'endLabel': true},
      ],
      'data': [
        {'label': '23:00', 'm': 60, 'cu': 32, 'wa': 37},
        {'label': '02:20', 'm': 260, 'cu': 34.9, 'wa': 34.4},
      ],
      'minY': 0,
      'maxY': 50,
    });
    final (w, px) = await _render(tester, chart);
    expect(tester.takeException(), isNull);
    // The lines stop at the last point (02:20): no series colour further right
    // than the end labels.
    bool blue(int x) {
      for (var y = 5; y < 150; y++) {
        final c = px.at(w, x, y);
        if (c.b > 0.4 && c.r < 0.3) return true;
      }
      return false;
    }
    expect(blue(110), isTrue); // the CU line before now
    expect(blue(165), isFalse); // between its end and its label
  });
}
