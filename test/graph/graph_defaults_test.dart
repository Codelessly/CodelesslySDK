import 'dart:ui' as ui;

import 'package:codelessly_sdk/graph.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/util/path.dart' show getCubicControls, getMonotoneControls;
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// What a graph does for itself when its spec says nothing: the labels that
// fit under it, the colors of marks that write none, its legend, a scale
// rounded out to its ticks, a smooth line that keeps to its values.

List<Json> rowsOf(int n) => [
      for (var i = 0; i < n; i++) {'k': 'row ${i + 1}', 'a': 10 + i, 'b': 5 + i},
    ];

Json plot({
  List<Json>? marks,
  Json x = const {},
  Json y = const {},
  Object? legend,
  Json style = const {},
}) =>
    {
      'key': 'k',
      'x': {'label': 'k', 'format': '', 'fit': 'bars', 'axisHeight': 24, ...x},
      'crosshair': {'enabled': false},
      'legend': ?legend,
      'style': style,
      'panes': [
        {
          'y': {'width': 40, 'side': 'left', 'decimals': 0, ...y},
          'marks': marks ??
              [
                {'type': 'bar', 'y': 'a'},
              ],
        },
      ],
    };

List<Json> shares() => [
      {'label': 'Rent', 'value': 60},
      {'label': 'Food', 'value': 25},
      {'label': 'Other', 'value': 15},
    ];

Json ring({Object? legend, Json mark = const {}}) => {
      'key': 'label',
      'x': {'label': 'label', 'format': '', 'axisHeight': 0},
      'crosshair': {'enabled': false},
      'legend': ?legend,
      'panes': [
        {
          'coord': 'polar',
          'y': {'width': 0, 'decimals': 0},
          'marks': [
            {'type': 'arc', 'y': 'value', 'inner': 0.6, ...mark},
          ],
        },
      ],
    };

GraphEngine engine(Json spec, List<Json> data, [Size size = const Size(400, 200)]) =>
    GraphEngine(GraphSpec.fromJson(spec), data: data)..resize(size);

Future<Color> pixel(WidgetTester tester, RenderGraph graph, Offset at) async {
  late Color color;
  await tester.runAsync(() async {
    final layer = graph.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & graph.size);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (at.dy.round() * image.width + at.dx.round()) * 4;
    color = Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
  });
  return color;
}

void main() {
  group('the labels under a plot', () {
    test('all of them where they stand apart', () {
      final e = engine(plot(), rowsOf(3));
      expect([for (final l in e.xLabels) l.$2], ['row 1', 'row 2', 'row 3']);
    });

    test('where they would touch, every n-th: the first and the last are kept and no two touch', () {
      final e = engine(plot(), rowsOf(24));
      final labels = e.xLabels;
      expect(labels.length, lessThan(24));
      expect(labels.length, greaterThan(2));
      expect(labels.first.$2, 'row 1');
      expect(labels.last.$2, 'row 24');
      for (var i = 1; i < labels.length; i++) {
        final before = labels[i - 1];
        final end = before.$3 + e.textWidth(before.$2, e.spec.style.fontSize);
        expect(labels[i].$3, greaterThanOrEqualTo(end + 8), reason: '${before.$2} runs into ${labels[i].$2}');
      }
      // The ones between are a whole step apart (the last may stand nearer).
      final places = [for (final l in labels) l.$1.toInt()];
      final step = places[1] - places[0];
      for (var i = 2; i < places.length - 1; i++) {
        expect(places[i] - places[i - 1], step);
      }
      // None is cut by the graph's edges.
      expect(labels.first.$3, greaterThanOrEqualTo(0));
      expect(labels.last.$3 + e.textWidth(labels.last.$2, e.spec.style.fontSize), lessThanOrEqualTo(400));
    });

    test('thousands of rows: the first and the last are still written, and few are measured', () {
      final e = engine(plot(x: {'fit': 'points'}, marks: [{'type': 'line', 'y': 'a'}]), rowsOf(5000));
      final watch = Stopwatch()..start();
      final labels = e.xLabels;
      expect(watch.elapsedMilliseconds, lessThan(500));
      expect(labels.first.$2, 'row 1');
      expect(labels.last.$2, 'row 5000');
      expect(labels.length, inInclusiveRange(2, 12));
    });

    test('a fitted view with a step of its own keeps its first label where it is whole, or where the view keeps room at its ends', () {
      // An axis left of the plot gives the first label room.
      final left = engine(plot(x: {'fit': 'points', 'tickEvery': 1}, marks: [{'type': 'line', 'y': 'a'}]), rowsOf(4));
      expect(left.xTicks.first, 0);
      // None: hard against the edge it would be cut, so it is left out.
      final bare = engine(plot(x: {'fit': 'points', 'tickEvery': 1}, y: {'width': 0}, marks: [{'type': 'line', 'y': 'a'}]), rowsOf(4));
      expect(bare.xTicks.first, 1);
      // Room at the ends: kept, and written inside the graph.
      final inset = engine(plot(x: {'fit': 'points', 'tickEvery': 1, 'inset': 6}, y: {'width': 0}, marks: [{'type': 'line', 'y': 'a'}]), rowsOf(4));
      expect(inset.xTicks.first, 0);
      expect(inset.xLabels.first.$3, 0);
    });

    test('inset keeps the first and the last row inside a fitted plot', () {
      final e = engine(plot(x: {'fit': 'points', 'inset': 6}, marks: [{'type': 'line', 'y': 'a'}]), rowsOf(5));
      expect(e.xOfRow(0), closeTo(e.plotLeft + 6, 0.001));
      expect(e.xOfRow(4), closeTo(e.plotRight - 6, 0.001));
      final flush = engine(plot(x: {'fit': 'points'}, marks: [{'type': 'line', 'y': 'a'}]), rowsOf(5));
      expect(flush.xOfRow(0), closeTo(flush.plotLeft, 0.001));
    });
  });

  group('the palette', () {
    test('marks that write no color take its colors in turn; a written color is the mark\'s', () {
      final spec = GraphSpec.fromJson(plot(marks: [
        {'type': 'line', 'y': 'a'},
        {'type': 'line', 'y': 'b'},
        {'type': 'line', 'y': 'c', 'color': '#FF112233'},
      ]));
      final marks = spec.panes.single.marks;
      expect(marks[0].color, graphPalette[0]);
      expect(marks[1].color, graphPalette[1]);
      expect(marks[0].color, isNot(marks[1].color));
      expect(marks[2].color, const Color(0xFF112233));
      expect([for (final m in marks) m.colored], [false, false, true]);
    });

    test('an area and the line along its top are one color', () {
      final marks = GraphSpec.fromJson(plot(marks: [
        {'type': 'area', 'y': 'a'},
        {'type': 'area', 'y': 'b'},
        {'type': 'line', 'y': 'a'},
        {'type': 'line', 'y': 'b'},
      ])).panes.single.marks;
      expect(marks[2].color, marks[0].color);
      expect(marks[3].color, marks[1].color);
      expect(marks[0].color, isNot(marks[1].color));
    });

    test('the style\'s palette is the one used', () {
      final marks = GraphSpec.fromJson(plot(
        style: {
          'palette': ['#FFAA0000', '#FF00AA00'],
        },
        marks: [
          {'type': 'bar', 'y': 'a'},
          {'type': 'bar', 'y': 'b'},
          {'type': 'bar', 'y': 'c'},
        ],
      )).panes.single.marks;
      expect([for (final m in marks) m.color], const [Color(0xFFAA0000), Color(0xFF00AA00), Color(0xFFAA0000)]);
    });

    test('slices that give no color take it row by row; a row\'s own color and the mark\'s win', () {
      final e = engine(ring(), shares());
      final mark = e.spec.panes.single.marks.single;
      expect([for (final s in e.slices(mark)) s.color], graphPalette.sublist(0, 3));
      final own = engine(ring(mark: {'colorField': 'color'}), [
        {'label': 'Rent', 'value': 60, 'color': '#FF101010'},
        {'label': 'Food', 'value': 40},
      ]);
      final slices = own.slices(own.spec.panes.single.marks.single);
      expect(slices[0].color, const Color(0xFF101010));
      expect(slices[1].color, graphPalette[1]);
      final one = engine(ring(mark: {'color': '#FF445566'}), shares());
      expect({for (final s in one.slices(one.spec.panes.single.marks.single)) s.color}, {const Color(0xFF445566)});
    });
  });

  group('the legend', () {
    final two = [
      {'type': 'bar', 'y': 'a', 'name': 'Web'},
      {'type': 'bar', 'y': 'b', 'name': 'Store'},
    ];

    test('two named marks: a key for each under the plot, which gives it the room', () {
      final e = engine(plot(marks: two), rowsOf(4), const Size(600, 300));
      final legend = e.legend!;
      expect(legend.position, 'bottom');
      expect([for (final k in legend.keys) (k.label, k.color)], [('Web', graphPalette[0]), ('Store', graphPalette[1])]);
      expect(legend.bottom, greaterThan(0));
      // The axis and the plot end over it.
      expect(e.xAxisRect.bottom, closeTo(300 - legend.bottom, 0.001));
      expect(e.plotRect(0).bottom, closeTo(300 - legend.bottom - 24, 0.001));
      for (final k in legend.keys) {
        expect(k.box.top, greaterThanOrEqualTo(e.xAxisRect.bottom));
        expect(k.box.bottom, lessThanOrEqualTo(300));
      }
      // Side by side in the middle, not touching.
      expect(legend.keys[0].box.right, lessThan(legend.keys[1].box.left));
      expect((legend.keys[0].box.left + legend.keys[1].box.right) / 2, closeTo(300, 0.5));
    });

    test('nothing to tell apart, or told not to: none, and the plot keeps the whole graph', () {
      final one = engine(plot(marks: [two[0]]), rowsOf(4), const Size(600, 300));
      expect(one.legend, isNull);
      expect(one.xAxisRect.bottom, 300);
      final unnamed = engine(plot(marks: [
        {'type': 'bar', 'y': 'a'},
        {'type': 'bar', 'y': 'b'},
      ]), rowsOf(4), const Size(600, 300));
      expect(unnamed.legend, isNull);
      for (final off in [false, {'show': 'none'}]) {
        expect(engine(plot(marks: two, legend: off), rowsOf(4), const Size(600, 300)).legend, isNull);
      }
      // An area and the line along its top are one key.
      final filled = engine(plot(marks: [
        {'type': 'area', 'y': 'a', 'name': 'Web'},
        {'type': 'line', 'y': 'a', 'name': 'Web'},
      ]), rowsOf(4), const Size(600, 300));
      expect(filled.legendKeys, hasLength(1));
      expect(filled.legend, isNull);
      expect(engine(plot(marks: [two[0]], legend: {'show': 'always'}), rowsOf(4), const Size(600, 300)).legend, isNotNull);
    });

    test('top and right are where the spec says', () {
      final top = engine(plot(marks: two, legend: {'position': 'top'}), rowsOf(4), const Size(600, 300));
      expect(top.legend!.position, 'top');
      expect(top.plotRect(0).top, closeTo(top.legend!.top, 0.001));
      expect(top.xAxisRect.bottom, 300);
      final right = engine(plot(marks: two, legend: {'position': 'right'}), rowsOf(4), const Size(600, 300));
      expect(right.legend!.position, 'right');
      expect(right.bodyRight, lessThan(600));
      expect(right.plotRight, closeTo(right.bodyRight, 0.001));
      expect(right.legend!.keys.first.box.left, greaterThan(right.bodyRight));
      expect(right.legend!.keys[1].box.top, greaterThan(right.legend!.keys[0].box.top));
    });

    test('slices: their labels and shares beside them where the ring keeps the graph\'s height', () {
      final e = engine(ring(), shares(), const Size(600, 200));
      final legend = e.legend!;
      expect(legend.position, 'right');
      expect([for (final k in legend.keys) (k.label, k.value)], [('Rent', '60%'), ('Food', '25%'), ('Other', '15%')]);
      expect([for (final k in legend.keys) k.color], graphPalette.sublist(0, 3));
      final (center, outer, _) = e.arcGeometry(0, e.spec.panes.single.marks.single);
      // The ring is a square at the left, as high as the graph.
      expect(center, const Offset(100, 100));
      expect(outer, 100);
      for (final k in legend.keys) {
        expect(k.box.left, greaterThan(200));
        expect(k.box.right, lessThanOrEqualTo(600));
      }
      expect(engine(ring(legend: {'values': false}), shares(), const Size(600, 200)).legend!.keys.first.value, '');
    });

    test('slices in a graph no wider than high keep all of it: no legend unless the spec says one', () {
      final e = engine(ring(), shares(), const Size(200, 200));
      expect(e.legend, isNull);
      expect(e.arcGeometry(0, e.spec.panes.single.marks.single).$1, const Offset(100, 100));
      final always = engine(ring(legend: {'show': 'always'}), shares(), const Size(200, 300));
      expect(always.legend!.position, 'bottom');
      expect(always.arcGeometry(0, always.spec.panes.single.marks.single).$1.dy, lessThan(150));
      // A little wider than high: beside, the ring keeping three quarters
      // of the height or more.
      final near = engine(ring(), shares(), const Size(330, 220));
      expect(near.legend!.position, 'right');
      final outer = near.arcGeometry(0, near.spec.panes.single.marks.single).$2;
      expect(outer * 2, inInclusiveRange(165, 220));
      expect(near.legend!.keys.first.box.left, greaterThan(outer * 2));
      // Slices with no labels have nothing to list.
      expect(engine(ring(), [for (final r in shares()) {'value': r['value']}], const Size(600, 200)).legend, isNull);
    });
  });

  group('a scale rounded out to its ticks', () {
    test('nice: the plot starts and ends on a labeled line', () {
      final rows = [
        for (final v in [12, 18, 14, 22, 19, 27, 24, 31]) {'k': '$v', 'a': v},
      ];
      final line = [
        {'type': 'line', 'y': 'a'},
      ];
      final e = engine(plot(marks: line, y: {'domain': 'data', 'nice': true, 'ticks': 4}), rows);
      final (lo, hi) = e.yDomain(0);
      expect((lo, hi), (10.0, 40.0));
      expect(e.yTicks(0).first, lo);
      expect(e.yTicks(0).last, hi);
      // Without it the fitted values and their margins.
      final plain = engine(plot(marks: line, y: {'domain': 'data', 'ticks': 4}), rows);
      expect(plain.yDomain(0).$1, isNot(10.0));
      expect(plain.yTicks(0).first, greaterThan(plain.yDomain(0).$1));
    });

    test('its labels have the decimals its step has, and large values are short', () {
      final small = engine(
          plot(marks: [{'type': 'line', 'y': 'a'}], y: {'domain': 'data', 'nice': true, 'ticks': 4}),
          [
            {'k': 'a', 'a': 0.2},
            {'k': 'b', 'a': 1.9},
          ]);
      expect([for (final t in small.yTicks(0)) small.yLabel(0, t)], ['0.0', '0.5', '1.0', '1.5', '2.0']);
      final large = engine(
          plot(y: {'domain': 'data', 'nice': true, 'ticks': 3}),
          [
            {'k': 'a', 'a': 12400},
            {'k': 'b', 'a': 27300},
          ]);
      expect([for (final t in large.yTicks(0)) large.yLabel(0, t)], ['0', '10K', '20K', '30K']);
    });

    test('bars with nothing to show yet stand on zero', () {
      final e = engine(plot(y: {'domain': 'data', 'nice': true}), [
        {'k': 'a', 'a': 0},
      ]);
      expect(e.yDomain(0), (0.0, 1.0));
    });
  });

  group('bars', () {
    test('side by side, each is at most the widest a bar is drawn', () {
      final e = engine(
          plot(x: {'maxBarWidth': 10}, marks: [
            {'type': 'bar', 'y': 'a'},
            {'type': 'bar', 'y': 'b'},
          ]),
          rowsOf(3));
      final rects = e.barRects(0, 1);
      expect(rects[0].$2.width, closeTo(10, 0.001));
      expect(rects[1].$2.width, closeTo(10, 0.001));
      expect((rects[0].$2.left + rects[1].$2.right) / 2, closeTo(e.xOf(1), 0.001));
    });
  });

  group('a smooth line', () {
    test('never passes above or below the values it joins', () {
      const points = [Offset(0, 50), Offset(40, 60), Offset(80, 90), Offset(120, 85), Offset(160, 20), Offset(200, 100)];
      final curve = getMonotoneControls(points);
      expect(curve, hasLength(points.length - 1));
      for (var i = 0; i < curve.length; i++) {
        final a = points[i].dy, b = points[i + 1].dy;
        final lo = a < b ? a : b, hi = a < b ? b : a;
        expect(curve[i][2], points[i + 1]);
        for (final control in curve[i].take(2)) {
          expect(control.dy, inInclusiveRange(lo - 1e-9, hi + 1e-9), reason: 'segment $i');
        }
      }
      // The spline it takes the place of did.
      final before = getCubicControls(points, false, true);
      var outside = false;
      for (var i = 0; i < before.length; i++) {
        final a = points[i].dy, b = points[i + 1].dy;
        if (before[i].take(2).any((c) => c.dy < (a < b ? a : b) - 0.5 || c.dy > (a < b ? b : a) + 0.5)) outside = true;
      }
      expect(outside, isTrue);
    });
  });

  group('drawn', () {
    Future<RenderGraph> show(WidgetTester tester, Json spec, List<Json> data, Size size) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(size: size, child: CodelesslyGraph(spec: spec, data: data)),
        ),
      ));
      return tester.renderObject<RenderGraph>(find.byType(CodelesslyGraph));
    }

    testWidgets('an arc\'s total is written in its hole when it asks for it', (tester) async {
      const size = Size(200, 200);
      Json spec(Json mark) => {
            ...ring(mark: mark),
            'style': {'background': '#FFFFFFFF', 'ink': '#FF0000FF'},
          };
      final bare = await show(tester, spec(const {}), shares(), size);
      expect(await pixel(tester, bare, const Offset(100, 100)), const Color(0xFFFFFFFF));
      final total = await show(tester, spec(const {'center': 'total'}), shares(), size);
      // The test font draws each character as a box: the figure's ink.
      expect(await pixel(tester, total, const Offset(100, 100)), const Color(0xFF0000FF));
    });

    testWidgets('a legend\'s keys are dots in their marks\' colors', (tester) async {
      final spec = {
        ...plot(marks: [
          {'type': 'bar', 'y': 'a', 'name': 'A', 'color': '#FFFF0000'},
          {'type': 'bar', 'y': 'b', 'name': 'B', 'color': '#FF00FF00'},
        ]),
        'style': {'background': '#FFFFFFFF'},
      };
      final graph = await show(tester, spec, rowsOf(3), const Size(600, 300));
      final keys = graph.engine.legend!.keys;
      Offset dot(Rect box) => Offset(box.left + 4, box.center.dy);
      expect(await pixel(tester, graph, dot(keys[0].box)), const Color(0xFFFF0000));
      expect(await pixel(tester, graph, dot(keys[1].box)), const Color(0xFF00FF00));
    });

    testWidgets('a line\'s dots are drawn on its rows', (tester) async {
      Json spec(Json mark) => {
            ...plot(
              x: {'fit': 'points', 'inset': 10},
              y: {'domain': 'fixed', 'min': 0, 'max': 100},
              marks: [
                {'type': 'line', 'y': 'a', 'color': '#FFFF0000', 'width': 1, ...mark},
              ],
            ),
            'style': {'background': '#FFFFFFFF', 'grid': '#00000000'},
          };
      final rows = [
        {'k': 'a', 'a': 50},
        {'k': 'b', 'a': 50},
        {'k': 'c', 'a': 50},
      ];
      final dotted = await show(tester, spec(const {'dots': 5}), rows, const Size(400, 200));
      final at = Offset(dotted.engine.xOfRow(1), dotted.engine.yOf(0, 50) - 3.5);
      expect(await pixel(tester, dotted, at), const Color(0xFFFF0000));
      final plain = await show(tester, spec(const {}), rows, const Size(400, 200));
      expect(await pixel(tester, plain, at), const Color(0xFFFFFFFF));
    });

    testWidgets('a tooltip with no colors of its own is the style\'s tag', (tester) async {
      final spec = {
        ...plot(),
        'selection': {'on': 'hover'},
        'style': {'background': '#FFFFFFFF', 'tag': '#FF123456', 'tagText': '#FF123456', 'grid': '#00000000'},
      };
      final graph = await show(tester, spec, rowsOf(3), const Size(400, 200));
      graph.engine.select({'index': 0});
      await tester.pump();
      final anchor = graph.engine.selectionAnchor!;
      // The box hangs under and right of the pinned row's top.
      expect(await pixel(tester, graph, anchor + const Offset(24, 16)), const Color(0xFF123456));
    });
  });
}
