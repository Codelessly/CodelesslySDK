// Line chart reference-line labels, the line chart's tooltip (selectedX,
// hover with scrubEnabled) and the tooltips' text styles.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicator_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  const size = Size(400, 200);
  // plotPadding [34, 10, 0, 24]: the plot spans y 10..176, x 34..400.
  double py(double v) => 176 - v / 100 * 166;

  test('line chart reference lines draw their labels at the right end, above or below', () {
    final plain = _paint(
        _linePainter({
          'referenceLines': [
            {'y': 80, 'color': '#FFFF4B3E'},
            {'y': 50, 'color': '#FF9C9CA6'},
          ],
        }),
        size);
    final labelled = _paint(
        _linePainter({
          'referenceLines': [
            {'y': 80, 'color': '#FFFF4B3E', 'label': 'CAPACITY 80'},
            {'y': 50, 'color': '#FF9C9CA6', 'label': 'EXPECTED 50', 'labelBelow': true},
          ],
        }),
        size);
    expect(plain, isEmpty);
    expect(labelled, hasLength(2));
    final (above, aboveP) = labelled[0];
    final (below, _) = labelled[1];
    expect(above.dy + aboveP.height, lessThanOrEqualTo(py(80)));
    expect(above.dy + aboveP.height, greaterThan(py(80) - 6));
    expect(below.dy, greaterThanOrEqualTo(py(50)));
    expect(below.dy, lessThan(py(50) + 8));
    // Right-aligned to the plot's right edge.
    expect(above.dx + aboveP.maxIntrinsicWidth, closeTo(400, 1));
  });

  test('line chart draws a tooltip at selectedX, styled by tooltipLabelStyle/tooltipValueStyle', () {
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

  test('xAt maps the pointer to the nearest point', () {
    final painter = _linePainter({});
    expect(painter.xAt(const Offset(34 + 366 * 0.45, 100), size), 60);
    expect(painter.xAt(const Offset(398, 100), size), 120);
    expect(painter.xAt(const Offset(-40, 100), size), isNull);
  });

  testWidgets('hovering a line chart with scrubEnabled selects the nearest point', (tester) async {
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

  test('bar chart tooltip takes tooltipTitleStyle, tooltipLabelStyle and tooltipValueStyle', () {
    Map<String, Object?> chart(Map<String, Object?> extra) => {
          'type': 'chart',
          'layout': {'width': 400, 'height': 240},
          'props': {
            'chartType': 'bar',
            'showXAxis': false,
            'showYAxis': false,
            'gridLines': 0,
            'selectedIndex': 0,
            'tooltip': true,
            'data': [
              {'label': '7A', 'a': 3, 'b': 1},
            ],
            'series': [
              {'field': 'a', 'name': 'General', 'stack': 's'},
              {'field': 'b', 'name': 'VIP', 'stack': 's'},
            ],
            ...extra,
          },
        };
    const s = Size(400, 240);
    final plain = _paint(ChartSeriesPainter(Node.fromJson(chart({}), id: 'c')!), s);
    // Title, then a name and a value per series.
    expect(plain, hasLength(5));
    final styled = _paint(
        ChartSeriesPainter(Node.fromJson(
            chart({
              'tooltipTitleStyle': {'fontSize': 9, 'height': 1},
              'tooltipLabelStyle': {'fontSize': 18},
              'tooltipValueStyle': {'fontSize': 26, 'fontWeight': 800},
            }),
            id: 'c')!),
        s);
    expect(styled, hasLength(5));
    expect(styled[0].$2.height, lessThan(plain[0].$2.height));
    expect(styled[1].$2.height, greaterThan(plain[1].$2.height));
    expect(styled[2].$2.height, greaterThan(styled[1].$2.height));
  });
}
