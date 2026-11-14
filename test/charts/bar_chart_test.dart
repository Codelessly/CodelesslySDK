import 'dart:ui' as ui;
import 'dart:ui' show PictureRecorder;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicator_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A bar chart's plot geometry: bars can keep headroom above a full bar while
// the grid spans the plot, the label band and the plot's top inset can be set.

/// Whether the bar's color is at (50, [y]) of a 100 x 100 chart.
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

// A series chart under the pointer selects the hovered category (its
// dimming, totals and tooltip follow), and grows in when it first shows.

Map<String, Object?> _chart({bool hover = true, bool animateIn = false}) => {
      'type': 'chart',
      'layout': {'width': 400, 'height': 200},
      'props': {
        'chartType': 'bar',
        'data': [
          {'label': '7A', 'a': 3, 'b': 1},
          {'label': '8A', 'a': 10, 'b': 4},
          {'label': '9A', 'a': 6, 'b': 2},
          {'label': '10A', 'a': 2, 'b': 0},
        ],
        'series': [
          {'field': 'a', 'name': 'General', 'color': '#FFFFD400', 'stack': 's'},
          {'field': 'b', 'name': 'VIP', 'color': '#FFFF2E93', 'stack': 's'},
        ],
        'selectOnHover': hover,
        'dimUnselected': true,
        'tooltip': true,
        'showTotals': true,
        'stackGap': 1.5,
        'highlightIndex': 2,
        'highlightColor': '#FF19E57A',
        'xAxisLabelColor': '#FF9C9CA6',
        'referenceLines': [
          {'value': 12, 'color': '#FFFF4B3E', 'label': 'CAPACITY 12'},
        ],
        'animateIn': animateIn,
        'animationDuration': 400,
      },
    };

Iterable<RenderObject> _all(RenderObject o) sync* {
  yield o;
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield* _all(k);
  }
}

Future<RenderIndicatorTransition> _show(WidgetTester tester, Map<String, Object?> chart) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['c'],
    'nodes': {'c': chart},
  })), environment: const IslandEnvironment(interactive: true));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'c', interactive: true))));
  return _all(tree.boxOf('c')!).whereType<RenderIndicatorTransition>().single;
}

int _selected(RenderIndicatorTransition r) => (r.painter! as ChartSeriesPainter).selectedIndex;

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

void main() {
  {
    TestWidgetsFlutterBinding.ensureInitialized();
    test('a bar at the maximum fills the plot, and with headroom stops that far below the top', () async {
      expect(await barAt({}, 10), isTrue);
      // 99 tall plot, 40 kept above: the bar runs from 40 down.
      expect(await barAt({'barHeadroom': 40}, 30), isFalse);
      expect(await barAt({'barHeadroom': 40}, 50), isTrue);
    });

    group('colors', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      test(
        'bars take their colors from the palette, or a single color without one',
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
    });

    group('labels', () {
      test('a bar\'s value label shows decimals and a suffix when given, else a bare whole number', () {
        expect(barValueText(35.8, 1, '%'), '35.8%');
        expect(barValueText(12, 1, '%'), '12.0%');
        expect(barValueText(12, null, ''), '12');
        expect(barValueText(12.34, null, ''), '12.3');
        expect(barValueText(3.14159, 2, ' pts'), '3.14 pts');
      });
    });

    group('hover and entrance', () {
      testWidgets('hovering a bar selects its category, and leaving clears it', (tester) async {
        final r = await _show(tester, _chart());
        await tester.pumpAndSettle();
        expect(_selected(r), -1);
        final topLeft = r.localToGlobal(Offset.zero);
        final plot = (r.painter! as ChartSeriesPainter).plotRect(r.size);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(topLeft + Offset(plot.left + plot.width / 4 * 1.5, 100));
        await tester.pump();
        expect(_selected(r), 1);
        await mouse.moveTo(topLeft + Offset(plot.left + plot.width / 4 * 2.5, 100));
        await tester.pump();
        expect(_selected(r), 2);
        await mouse.moveTo(const Offset(700, 500));
        await tester.pump();
        expect(_selected(r), -1);
        // The painter draws the tooltip, totals, gaps and labels without error.
        final recorder = PictureRecorder();
        (r.painter! as ChartSeriesPainter)
            .paint(Canvas(recorder), r.size);
        recorder.endRecording().dispose();
      });

      testWidgets('bars grow from zero when the chart first shows', (tester) async {
        final r = await _show(tester, _chart(animateIn: true));
        await tester.pump(const Duration(milliseconds: 1));
        double total() => (r.painter! as ChartSeriesPainter).data.fold(0.0, (a, row) => a + ((row['a'] as num?) ?? 0));
        expect(total(), lessThan(21));
        await tester.pumpAndSettle();
        expect(total(), 21);
      });
    });
  }

  group('hover and entrance', () {
    // plotPadding [34, 10, 0, 24]: the plot spans y 10..176, x 34..400.
    test('a bar chart draws its tooltip in its title, label and value styles', () {
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
  });
}
