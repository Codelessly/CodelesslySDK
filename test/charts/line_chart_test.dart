import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/chart_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicator_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart' show NodePainter;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RenderCustomPaint> _paintOf(WidgetTester tester, List<Map<String, Object?>> data) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {'type': 'column', 'children': ['c'], 'layout': {'width': 400, 'height': 300}},
      'c': {
        'type': 'chart',
        'layout': {'width': 400, 'height': 200},
        'props': {
          'chartType': 'line', 'xField': 'm', 'domainMin': 0, 'domainMax': 120, 'animate': false,
          'gridLines': 0, 'showYAxis': false,
          'xLabels': [{'x': 0, 'label': '22:00'}, {'x': 60, 'label': '23:00'}, {'x': 120, 'label': '00:00'}],
          'series': [{'field': 'v', 'kind': 'line'}],
          'data': data,
        },
      },
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
  await tester.pump();
  RenderCustomPaint? paint;
  void visit(RenderObject o) {
    if (o is RenderCustomPaint && o.painter is NodePainter) paint = o;
    o.visitChildren(visit);
  }
  visit(tree.boxOf('c')!);
  return paint!;
}

// Line chart reference-line labels, the line chart's tooltip (selectedX,
// hover with scrubEnabled) and the tooltips' text styles.

/// A drawn paragraph's size.
class _Size {
  const _Size(this.height, this.maxIntrinsicWidth);
  final double height, maxIntrinsicWidth;
}

/// Records the paragraphs a painter draws (where, and how big).
class _Canvas implements Canvas {
  final paragraphs = <(Offset, _Size)>[];

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      paragraphs.add((offset, _Size(paragraph.height, paragraph.maxIntrinsicWidth)));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

List<(Offset, _Size)> _paint(CustomPainter painter, Size size) {
  final canvas = _Canvas();
  painter.paint(canvas, size);
  return canvas.paragraphs;
}

Map<String, Object?> _line(Map<String, Object?> props) => {
      'type': 'lineChart',
      'layout': {'width': 400, 'height': 200},
      'props': {
        'xField': 't',
        'yField': 'count',
        'yMin': 0,
        'yMax': 100,
        'plotPadding': [34, 10, 0, 24],
        'data': [
          {'t': 0, 'count': 10, 'label': '9:00 AM'},
          {'t': 60, 'count': 40, 'label': '10:00 AM'},
          {'t': 120, 'count': 70, 'label': '11:00 AM'},
        ],
        ...props,
      },
    };

LineChartPainter _linePainter(Map<String, Object?> props) => LineChartPainter(Node.fromJson(_line(props), id: 'l')!);

Iterable<RenderObject> _all(RenderObject o) sync* {
  yield o;
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield* _all(k);
  }
}

Future<RenderCustomPaint> _referencePaintOf(WidgetTester tester, Map<String, Object?> line) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {'type': 'column', 'children': ['line'], 'layout': {'width': 300, 'height': 200}},
      'line': {
        'type': 'lineChart',
        'layout': {'width': 300, 'height': 110},
        'props': {
          'xMin': 0, 'xMax': 3, 'yMin': 55, 'yMax': 75, 'animate': false,
          'data': [{'x': 1, 'y': 60}, {'x': 2, 'y': 66}],
          'referenceLines': [line],
        },
      },
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
  await tester.pump();
  RenderCustomPaint? paint;
  void visit(RenderObject o) {
    if (o is RenderCustomPaint && o.painter is NodePainter) paint = o;
    o.visitChildren(visit);
  }
  visit(tree.boxOf('line')!);
  return paint!;
}

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

void main() {
  testWidgets('a line chart with no data still draws its time axis', (tester) async {
    expect(await _paintOf(tester, const []), paintsExactlyCountTimes(#drawParagraph, 3));
  });

  group('selection', () {
    const size = Size(400, 200);
    // plotPadding [34, 10, 0, 24]: the plot spans y 10..176, x 34..400.
    double py(double v) => 176 - v / 100 * 166;

    test('a line chart draws a tooltip at its selected point', () {
      expect(_paint(_linePainter({}), size), isEmpty);
      final tip = _paint(_linePainter({'selectedX': 55, 'tooltipLabelField': 'label'}), size);
      expect(tip, hasLength(2));
      final big = _paint(
          _linePainter({
            'selectedX': 55,
            'tooltipLabelStyle': {'fontSize': 9},
            'tooltipValueStyle': {'fontSize': 30, 'fontWeight': 800},
          }),
          size);
      expect(big[1].$2.height, greaterThan(tip[1].$2.height + 10));
      expect(big[0].$2.height, lessThan(tip[0].$2.height));
      // The value sits under the label, above the selected point (t 60).
      expect(big[1].$1.dy, greaterThan(big[0].$1.dy));
      expect(big[1].$1.dy + big[1].$2.height, lessThan(py(40)));
    });

    testWidgets('hovering a line chart that scrubs selects the nearest point', (tester) async {
      final tree = NodeTree(
          DocumentSource(LayoutDocument.fromJson({
            'roots': ['l'],
            'nodes': {
              'l': _line({'scrubEnabled': true}),
            },
          })),
          environment: const IslandEnvironment(interactive: true));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
          home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'l', interactive: true))));
      final r = _all(tree.boxOf('l')!).whereType<RenderIndicatorTransition>().single;
      double? selected() => (r.painter! as LineChartPainter).p(LineChartProps.selectedX);
      expect(selected(), isNull);
      final origin = r.localToGlobal(Offset.zero);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(origin + const Offset(34 + 366 * 0.55, 100));
      await tester.pump();
      expect(selected(), 60);
      await mouse.moveTo(origin + const Offset(395, 100));
      await tester.pump();
      expect(selected(), 120);
      await mouse.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(selected(), isNull);
    });
  });

  testWidgets('a line chart with values below its minimum stays inside its box', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['line'], 'layout': {'width': 300, 'height': 400}},
        'line': {
          'type': 'lineChart',
          'layout': {'width': 300, 'height': 110},
          'props': {
            'xMin': 0, 'xMax': 3, 'yMin': 55, 'yMax': 75, 'animate': false,
            'data': [{'x': 1, 'y': 0}, {'x': 2, 'y': 0}, {'x': 3, 'y': 0}],
          },
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    await tester.pump();
    RenderCustomPaint? paint;
    void visit(RenderObject o) {
      if (o is RenderCustomPaint && o.painter is NodePainter) paint = o;
      o.visitChildren(visit);
    }
    visit(tree.boxOf('line')!);
    expect(paint, paints..clipRect(rect: const Rect.fromLTWH(0, 0, 300, 110)));
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  group('gaps and bad data', () {
    test('a missing or infinite sample splits the line instead of joining across it', () {
      expect(
        LineChartPainter.sampleSegments(
          [
            {'x': -2, 'y': -.5},
            {'x': -1, 'y': -1},
            {'x': 0, 'y': null},
            {'x': 1, 'y': 1},
            {'x': 2, 'y': .5},
            {'x': 3, 'y': double.infinity},
            {'x': 4, 'y': .25},
            {'x': 5, 'y': '.2'},
          ],
          'x',
          'y',
        ),
        [
          [const Offset(-2, -.5), const Offset(-1, -1)],
          [const Offset(1, 1), const Offset(2, .5)],
          [const Offset(4, .25), const Offset(5, .2)],
        ],
      );
    });
    test('a line chart with dates, no data or only invalid data still draws', () {
      expect(LineChartPainter.sampleSegments([], 'x', 'y'), isEmpty);
      expect(
        LineChartPainter.sampleSegments(
          [
            {'x': 0, 'y': 'NaN'},
          ],
          'x',
          'y',
        ),
        isEmpty,
      );
      expect(
        LineChartPainter.sampleSegments(
          [
            {'x': '2026-01-01', 'y': 2},
          ],
          'x',
          'y',
        ).single.single.dy,
        2,
      );
    });
  });

  group('reference lines', () {
    testWidgets('a reference line can carry a label', (tester) async {
      final plain = await _referencePaintOf(tester, {'y': 63.4, 'color': '#FFC0392B'});
      expect(plain, paintsExactlyCountTimes(#drawParagraph, 0));
      final labeled = await _referencePaintOf(tester, {'y': 63.4, 'color': '#FFC0392B', 'label': '2022 63.4%'});
      expect(labeled, paintsExactlyCountTimes(#drawParagraph, 1));
    });
  });

  group('growing data', () {
    test('a new point on a line grows out of the point before it, not up from zero', () {
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

    testWidgets('a line chart with labels placed by value, end labels and a now line paints', (tester) async {
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
      // The lines stop at the last point (02:20): no series color further right
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
  });
}
