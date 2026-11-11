// Series and line chart layout options for matching a hand-built Flutter
// chart: y labels left-aligned in the gutter, an x-label gap below the
// bars, grid lines on whole pixel rows, an unclipped line chart, and x
// labels placed at a fixed offset from their tick.
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records each paragraph's offset and width as it is drawn (the painters
/// dispose them right after).
class _Canvas extends TestRecordingCanvas {
  final paragraphs = <(Offset, double)>[];

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    paragraphs.add((offset, paragraph.longestLine));
    super.drawParagraph(paragraph, offset);
  }
}

_Canvas _barChart(Map<String, Object?> props) {
  final node = Node.fromJson({
    'id': 'c',
    'type': 'chart',
    'props': {
      'chartType': 'bar',
      'animate': false,
      'gridLines': 4,
      'maxY': 100,
      'yAxisWidth': 26,
      'series': [
        {'field': 'v'},
      ],
      'data': [
        {'label': 'A', 'v': 40},
        {'label': 'B', 'v': 80},
      ],
      ...props,
    },
  })!;
  final canvas = _Canvas();
  ChartSeriesPainter(node).paint(canvas, const Size(200, 123));
  return canvas;
}

_Canvas _lineChart(Map<String, Object?> props) {
  final node = Node.fromJson({
    'id': 'l',
    'type': 'lineChart',
    'props': {
      'animate': false,
      'xMin': 0, 'xMax': 100, 'yMin': 0, 'yMax': 10,
      'plotPadding': [34, 10, 0, 24],
      'data': [
        {'x': 0, 'y': 1},
        {'x': 100, 'y': 5},
      ],
      'xTicks': [
        {'x': 0, 'label': '7P'},
        {'x': 50, 'label': '8P'},
        {'x': 100, 'label': '9P'},
      ],
      ...props,
    },
  })!;
  final canvas = _Canvas();
  LineChartPainter(node).paint(canvas, const Size(234, 134));
  return canvas;
}

Iterable<RecordedInvocation> _calls(TestRecordingCanvas c, Symbol name) =>
    c.invocations.where((i) => i.invocation.memberName == name);

List<(Offset, double)> _paragraphs(_Canvas c) => c.paragraphs;

/// The y of each horizontal grid line.
List<double> _gridYs(TestRecordingCanvas c) => [
      for (final i in _calls(c, #drawLine))
        if ((i.invocation.positionalArguments[0] as Offset).dy == (i.invocation.positionalArguments[1] as Offset).dy)
          (i.invocation.positionalArguments[0] as Offset).dy,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bar chart', () {
    // 200 x 123, x band 22: the plot is 0..101 tall, 34..200 wide.
    test('y labels end 8 px left of the plot by default; start puts them at x = 0', () {
      final ends = _paragraphs(_barChart({})).take(5).toList();
      for (final (o, w) in ends) {
        expect(o.dx + w, closeTo(34 - 8, 0.01));
      }
      final starts = _paragraphs(_barChart({'yLabelAlign': 'start'})).take(5).toList();
      for (final (o, _) in starts) {
        expect(o.dx, 0);
      }
      // Same rows either way.
      expect([for (final (o, _) in starts) o.dy], [for (final (o, _) in ends) o.dy]);
    });

    test('x labels centre in a 22 px band by default; xLabelGap puts their top below the bars', () {
      // The last two paragraphs are the category labels A and B.
      final classic = _paragraphs(_barChart({})).skip(5).toList();
      expect(classic, hasLength(2));
      // Centred 2 px below the band's middle: top = 101 + 13 - height / 2,
      // for a plausible 10 px label's line height.
      final textHeight = 2 * (101 + 13 - classic.first.$1.dy);
      expect(textHeight, inInclusiveRange(10, 16));
      final gap = _paragraphs(_barChart({'xLabelGap': 8, 'xAxisHeight': 26})).skip(5).toList();
      // xAxisHeight 26: the plot ends at 123 - 26 = 97.
      for (final (o, _) in gap) {
        expect(o.dy, closeTo(97 + 8, 0.001));
      }
    });

    test('grid lines: crisp by default (whole rows), centered and exact on request', () {
      // y(v) = 101 - 101 * k / 4: 101, 75.75, 50.5, 25.25, 0.
      expect(_gridYs(_barChart({'gridLineMode': 'centered'})), [100.5, 76, 51, 25, 0]);
      final crisp = _gridYs(_barChart({}));
      expect(crisp, [100.5, 76.5, 51.5, 25.5, 0.5]);
      for (final y in crisp) {
        expect(y - y.floorToDouble(), 0.5, reason: 'a 1 px line on a pixel centre fills one row');
      }
      expect(_gridYs(_barChart({'gridLineMode': 'exact'})), [100.5, 75.25, 50.0, 24.75, -0.5]);
    });

    test('a 1 px reference line follows the grid mode (centered: on its value)', () {
      List<double> refY(String mode) {
        final c = _barChart({
          'gridLines': 0,
          'gridLineMode': mode,
          'referenceLines': [
            {'value': 0, 'color': '#FFFF0000', 'strokeWidth': 1, 'dashed': false},
          ],
        });
        return _gridYs(c);
      }

      expect(refY('centered'), [101]);
      expect(refY('crisp'), [100.5]);
      expect(refY('exact'), [100.5]);
    });
  });

  group('line chart', () {
    test('clips to its box by default; clip false draws past it', () {
      final clipped = _lineChart({});
      expect(_calls(clipped, #clipRect).first.invocation.positionalArguments[0], const Rect.fromLTWH(0, 0, 234, 134));
      final open = _lineChart({'clip': false});
      expect(
        _calls(open, #clipRect).where((i) => i.invocation.positionalArguments[0] == const Rect.fromLTWH(0, 0, 234, 134)),
        isEmpty,
      );
    });

    test('x labels: edge-clamped by default; start with an offset sits each at x - 8', () {
      // plot 34..234: ticks at 34, 134, 234; labels at plot.bottom + 8 = 118.
      final classic = _paragraphs(_lineChart({}));
      expect(classic, hasLength(3));
      expect(classic[0].$1.dx, 34);
      expect(classic[1].$1.dx, closeTo(134 - classic[1].$2 / 2, 0.001));
      expect(classic[2].$1.dx, closeTo(234 - classic[2].$2, 0.001));
      final offset = _paragraphs(_lineChart({'xLabelAnchor': 'start', 'xLabelOffset': -8}));
      expect([for (final (o, _) in offset) o], const [Offset(26, 118), Offset(126, 118), Offset(226, 118)]);
      final centered = _paragraphs(_lineChart({'xLabelAnchor': 'center'}));
      expect(centered[0].$1.dx, closeTo(34 - centered[0].$2 / 2, 0.001));
    });
  });
}
