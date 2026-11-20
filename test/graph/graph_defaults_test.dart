import 'dart:ui' as ui;

import 'package:codelessly_sdk/graph.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/util/path.dart' show getCubicControls, getMonotoneControls;
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// What a graph does for itself (the labels that fit under it, the colors of
// marks that write none, a smooth line that keeps to its values, where its
// tooltip is), and what it does when its spec asks: a legend, a scale
// rounded out to its ticks, dots, the total in an arc's hole.

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

    test('where they would touch, every n-th from the first, evenly apart, and no two touch', () {
      List<int> places(GraphEngine e) => [for (final l in e.xLabels) l.$1.toInt()];
      void even(GraphEngine e) {
        final labels = e.xLabels, at = places(e);
        expect(at.first, 0);
        expect(at.length, greaterThan(2));
        for (var i = 1; i < labels.length; i++) {
          final before = labels[i - 1];
          final end = before.$3 + e.textWidth(before.$2, e.spec.style.fontSize);
          expect(labels[i].$3, greaterThanOrEqualTo(end + 8), reason: '${before.$2} runs into ${labels[i].$2}');
          // Every step is the first one: never an odd gap, before the last or anywhere.
          expect(at[i] - at[i - 1], at[1] - at[0]);
        }
        expect(labels.first.$3, greaterThanOrEqualTo(0));
        expect(labels.last.$3 + e.textWidth(labels.last.$2, e.spec.style.fontSize), lessThanOrEqualTo(400));
      }

      // 25 rows: a step near the smallest that fits ends on the last label, and is the one taken.
      final ends = engine(plot(), rowsOf(25));
      even(ends);
      expect(places(ends).last, 24);
      // 24 rows: no step does (23 has no divisor), so the last is left out and the row of labels stays even.
      final odd = engine(plot(), rowsOf(24));
      even(odd);
      expect(places(odd).last, lessThan(23));
      expect(23 - places(odd).last, lessThan(places(odd)[1]));
    });

    test('long labels are cut to their room before more than half are thinned away', () {
      const names = ['Pancakes', 'Omelette', 'Granola bowl', 'Roast chicken', 'Mushroom risotto', 'Fish tacos', 'Chocolate cake', 'Lemon sorbet'];
      final rows = [
        for (final (i, n) in names.indexed) {'k': n, 'a': 10 + i},
      ];
      final e = engine(plot(), rows);
      final labels = e.xLabels;
      // Thinning alone would write two or three of the eight: every second
      // is written instead, the long ones cut to the room between two.
      expect([for (final l in labels) l.$2], ['Pancakes', 'Granola bowl', 'Mushroom risotto', 'Chocolate cake']);
      final room = e.xOf(2) - e.xOf(0) - 8;
      for (var i = 0; i < labels.length; i++) {
        final whole = e.textWidth(labels[i].$2, e.spec.style.fontSize);
        expect(labels[i].$4, whole <= room ? double.infinity : closeTo(room, 0.001), reason: labels[i].$2);
        if (i > 0) {
          final before = labels[i - 1];
          final width = e.textWidth(before.$2, e.spec.style.fontSize, maxWidth: before.$4.isFinite ? before.$4 : null);
          expect(labels[i].$3, greaterThanOrEqualTo(before.$3 + width + 8 - 0.001));
        }
      }
      expect(labels.where((l) => l.$4.isFinite), isNotEmpty);
      // Room for a letter or two only: they are thinned, whole, as before.
      final tight = engine(plot(), rows, const Size(200, 200));
      expect(tight.xLabels.every((l) => l.$4 == double.infinity), isTrue);
      expect(tight.xLabels.length, lessThan(4));
    });

    test('thousands of rows: few are measured, and the labels written are evenly apart from the first', () {
      final e = engine(plot(x: {'fit': 'points'}, marks: [{'type': 'line', 'y': 'a'}]), rowsOf(5000));
      final watch = Stopwatch()..start();
      final labels = e.xLabels;
      expect(watch.elapsedMilliseconds, lessThan(500));
      expect(labels.first.$2, 'row 1');
      expect(labels.length, inInclusiveRange(2, 12));
      final at = [for (final l in labels) l.$1.toInt()];
      for (var i = 2; i < at.length; i++) {
        expect(at[i] - at[i - 1], at[1] - at[0]);
      }
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
    const auto = {'show': 'auto'};

    final two = [
      {'type': 'bar', 'y': 'a', 'name': 'Web'},
      {'type': 'bar', 'y': 'b', 'name': 'Store'},
    ];

    test('two named marks: a key for each under the plot, which gives it the room', () {
      final e = engine(plot(marks: two, legend: auto), rowsOf(4), const Size(600, 300));
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

    test('not asked for, nothing to tell apart, or told not to: none, and the plot keeps the whole graph', () {
      // A graph has no legend unless its spec asks for one.
      final unasked = engine(plot(marks: two), rowsOf(4), const Size(600, 300));
      expect(unasked.spec.legend.show, 'none');
      expect(unasked.legend, isNull);
      expect(unasked.xAxisRect.bottom, 300);
      expect(engine(ring(), shares(), const Size(600, 200)).legend, isNull);
      final one = engine(plot(marks: [two[0]], legend: auto), rowsOf(4), const Size(600, 300));
      expect(one.legend, isNull);
      expect(one.xAxisRect.bottom, 300);
      final unnamed = engine(plot(legend: auto, marks: [
        {'type': 'bar', 'y': 'a'},
        {'type': 'bar', 'y': 'b'},
      ]), rowsOf(4), const Size(600, 300));
      expect(unnamed.legend, isNull);
      for (final off in [false, {'show': 'none'}]) {
        expect(engine(plot(marks: two, legend: off), rowsOf(4), const Size(600, 300)).legend, isNull);
      }
      // An area and the line along its top are one key.
      final filled = engine(plot(legend: auto, marks: [
        {'type': 'area', 'y': 'a', 'name': 'Web'},
        {'type': 'line', 'y': 'a', 'name': 'Web'},
      ]), rowsOf(4), const Size(600, 300));
      expect(filled.legendKeys, hasLength(1));
      expect(filled.legend, isNull);
      expect(engine(plot(marks: [two[0]], legend: {'show': 'always'}), rowsOf(4), const Size(600, 300)).legend, isNotNull);
    });

    test('top and right are where the spec says', () {
      final top = engine(plot(marks: two, legend: {'show': 'auto', 'position': 'top'}), rowsOf(4), const Size(600, 300));
      expect(top.legend!.position, 'top');
      expect(top.plotRect(0).top, closeTo(top.legend!.top, 0.001));
      expect(top.xAxisRect.bottom, 300);
      final right = engine(plot(marks: two, legend: {'show': 'auto', 'position': 'right'}), rowsOf(4), const Size(600, 300));
      expect(right.legend!.position, 'right');
      expect(right.bodyRight, lessThan(600));
      expect(right.plotRight, closeTo(right.bodyRight, 0.001));
      expect(right.legend!.keys.first.box.left, greaterThan(right.bodyRight));
      expect(right.legend!.keys[1].box.top, greaterThan(right.legend!.keys[0].box.top));
    });

    test('slices: their labels and shares beside them where the ring keeps the graph\'s height', () {
      final e = engine(ring(legend: auto), shares(), const Size(600, 200));
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
      expect(engine(ring(legend: {'show': 'auto', 'values': false}), shares(), const Size(600, 200)).legend!.keys.first.value, '');
    });

    test('slices in a graph no wider than high keep all of it: no legend unless the spec says one', () {
      final e = engine(ring(legend: auto), shares(), const Size(200, 200));
      expect(e.legend, isNull);
      expect(e.arcGeometry(0, e.spec.panes.single.marks.single).$1, const Offset(100, 100));
      final always = engine(ring(legend: {'show': 'always'}), shares(), const Size(200, 300));
      expect(always.legend!.position, 'bottom');
      expect(always.arcGeometry(0, always.spec.panes.single.marks.single).$1.dy, lessThan(150));
      // A little wider than high: beside, the ring keeping three quarters
      // of the height or more.
      final near = engine(ring(legend: auto), shares(), const Size(330, 220));
      expect(near.legend!.position, 'right');
      final outer = near.arcGeometry(0, near.spec.panes.single.marks.single).$2;
      expect(outer * 2, inInclusiveRange(165, 220));
      expect(near.legend!.keys.first.box.left, greaterThan(outer * 2));
      // Slices with no labels have nothing to list.
      expect(engine(ring(legend: {'show': 'always'}), [for (final r in shares()) {'value': r['value']}], const Size(600, 200)).legend, isNull);
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
      expect((lo, hi), (10.0, 35.0));
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

    test('never more than a third of the plot is left empty over the highest value', () {
      for (final ticks in [3, 4, 5]) {
        for (var top = 1.0; top < 60000; top = top < 200 ? top + 1 : top * 1.07) {
          final e = engine(plot(y: {'domain': 'data', 'nice': true, 'ticks': ticks}), [
            {'k': 'a', 'a': top * 0.4},
            {'k': 'b', 'a': top},
          ]);
          final (lo, hi) = e.yDomain(0);
          expect(lo, 0);
          expect(hi, greaterThanOrEqualTo(top));
          expect((hi - top) / hi, lessThanOrEqualTo(1 / 3 + 1e-6), reason: 'top $top of $hi with $ticks ticks');
          // Every line of the scale is a tick, the first and the last among them.
          final lines = e.yTicks(0);
          expect((lines.first, lines.last), (lo, hi), reason: 'top $top');
          expect(lines.length, inInclusiveRange(3, 8), reason: 'top $top with $ticks ticks: $lines');
        }
      }
      // 101 at four lines is 0 to 125 by 25, not 0 to 150.
      final e = engine(plot(y: {'domain': 'data', 'nice': true, 'ticks': 4}), [
        {'k': 'a', 'a': 101},
      ]);
      expect(e.yDomain(0), (0.0, 125.0));
      expect(e.yTicks(0), [0, 25, 50, 75, 100, 125]);
    });

    test('a thousand and more is written with its separator, on a rounded scale and for a share of a whole', () {
      expect(graphGrouped('1234'), '1,234');
      expect(graphGrouped('-1234567.5'), '-1,234,567.5');
      expect(graphGrouped('999'), '999');
      final rounded = engine(plot(y: {'domain': 'data', 'nice': true, 'ticks': 4}), [
        {'k': 'a', 'a': 1200},
        {'k': 'b', 'a': 7400},
      ]);
      expect([for (final t in rounded.yTicks(0)) rounded.yLabel(0, t)], ['0', '2,000', '4,000', '6,000', '8,000']);
      expect(rounded.yLabel(0, 7400), '7,400');
      // A scale that is not the graph's to round writes its values as they are.
      final plain = engine(plot(y: {'domain': 'data'}), [
        {'k': 'a', 'a': 7400},
      ]);
      expect(plain.yLabel(0, 7400), '7400');
      final share = engine(ring(), [
        {'label': 'Rent', 'value': 2600},
        {'label': 'Food', 'value': 1400},
      ]);
      expect(share.yLabel(0, 2600), '2,600');
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
        ...plot(legend: const {'show': 'auto'}, marks: [
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

    testWidgets('a tooltip is a surface with a line round it, in the style\'s colors', (tester) async {
      final spec = {
        ...plot(),
        'selection': {'on': 'hover'},
        'style': {
          'background': '#FFFFFFFF',
          'tooltip': '#FF123456',
          'tooltipText': '#FF123456',
          'tooltipBorder': '#FFFF0000',
          'tag': '#FF00FF00',
          'grid': '#00000000',
        },
      };
      final graph = await show(tester, spec, rowsOf(3), const Size(400, 200));
      graph.engine.select({'index': 0});
      await tester.pump();
      final anchor = graph.engine.selectionAnchor!;
      // The box hangs under and right of the pinned row's top: its ground
      // inside, its line along its left edge.
      expect(await pixel(tester, graph, anchor + const Offset(24, 16)), const Color(0xFF123456));
      expect(await pixel(tester, graph, anchor + const Offset(14, 20)), const Color(0xFFFF0000));
    });

    testWidgets('a tooltip stays over the panes: never over the legend or the labels under the plot', (tester) async {
      final spec = {
        ...plot(legend: const {'show': 'auto'}, marks: [
          {'type': 'bar', 'y': 'a', 'name': 'A', 'color': '#FFFF0000'},
          {'type': 'bar', 'y': 'b', 'name': 'B', 'color': '#FF00FF00'},
        ]),
        'selection': {'on': 'hover'},
        'style': {'background': '#FFFFFFFF', 'tooltip': '#FF123456', 'tooltipText': '#FF123456', 'tooltipBorder': '#FF123456'},
      };
      // A short graph: its tooltip is nearly as high as its panes.
      final graph = await show(tester, spec, rowsOf(3), const Size(600, 150));
      final e = graph.engine;
      final legend = e.legend!;
      expect(e.tooltipBounds.bottom, e.plotRect(0).bottom);
      expect(e.tooltipBounds.bottom, lessThan(legend.keys.first.box.top));
      // The pointer low in the plot, at the last row: the box would hang
      // over the labels and the legend, and past the right edge.
      e.hover(Offset(e.xOfRow(2), e.plotRect(0).bottom - 2));
      await tester.pump();
      expect(e.selection?.index, 2);
      Offset dot(Rect box) => Offset(box.left + 4, box.center.dy);
      expect(await pixel(tester, graph, dot(legend.keys[0].box)), const Color(0xFFFF0000));
      expect(await pixel(tester, graph, dot(legend.keys[1].box)), const Color(0xFF00FF00));
      // Nothing of it under the panes or outside the graph: the row under
      // the plot's foot holds none of its ground.
      for (var x = 2.0; x < 600; x += 7) {
        expect(await pixel(tester, graph, Offset(x, e.plotRect(0).bottom + 3)), isNot(const Color(0xFF123456)), reason: 'x $x');
      }
      // It is drawn, inside the panes.
      var seen = false;
      for (var x = 2.0; x < 600 && !seen; x += 5) {
        seen = await pixel(tester, graph, Offset(x, e.plotRect(0).bottom - 30)) == const Color(0xFF123456);
      }
      expect(seen, isTrue);
    });
  });
}
