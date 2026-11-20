import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The graph vocabulary a dashboard's charts are written in: bars that stack
// or stand side by side, slices round a center, and a selection (hover, tap)
// that the graph draws and publishes.

const months = ['Jan', 'Feb', 'Mar', 'Apr'];

List<Json> sales() => [
      {'month': 'Jan', 'web': 30, 'store': 10, 'goal': 35},
      {'month': 'Feb', 'web': 50, 'store': 20, 'goal': 60},
      {'month': 'Mar', 'web': 20, 'store': 40, 'goal': 55},
      {'month': 'Apr', 'web': 10, 'store': 5, 'goal': 30},
    ];

Json barsSpec({String? stack = 's', String by = 'row', String on = 'both', bool line = false}) => {
      'key': 'month',
      'x': {'label': 'month', 'fit': 'bars', 'axisHeight': 24},
      'crosshair': {'enabled': false},
      'interactions': {'dragPan': false, 'wheelZoom': false, 'pinchZoom': false, 'axisScale': false, 'doubleTapReset': false},
      'selection': {'on': on, 'by': by, 'band': '#14000000', 'total': true},
      'panes': [
        {
          'y': {'width': 40, 'decimals': 0},
          'marks': [
            {'type': 'bar', 'y': 'web', 'name': 'Web', 'color': '#FF2563EB', 'stack': stack, 'radius': 4},
            {'type': 'bar', 'y': 'store', 'name': 'Store', 'color': '#FF93C5FD', 'stack': stack, 'radius': 4},
            if (line) {'type': 'line', 'y': 'goal', 'name': 'Goal', 'color': '#FFEF4444'},
          ],
        },
      ],
    };

List<Json> budget() => [
      {'label': 'Rent', 'value': 60, 'color': '#FF2563EB'},
      {'label': 'Food', 'value': 25, 'color': '#FF719AF2'},
      {'label': 'Other', 'value': 15, 'color': '#FFA8C1F7'},
    ];

Json donutSpec({double inner = 0.6, String on = 'both'}) => {
      'key': 'label',
      'x': {'label': 'label', 'axisHeight': 0},
      'crosshair': {'enabled': false},
      'selection': {'on': on, 'by': 'mark', 'grow': 6},
      'panes': [
        {
          'coord': 'polar',
          'y': {'width': 0, 'decimals': 0},
          'marks': [
            {'type': 'arc', 'y': 'value', 'colorField': 'color', 'inner': inner},
          ],
        },
      ],
    };

GraphEngine engine(Json spec, List<Json> data, [Size size = const Size(440, 224)]) =>
    GraphEngine(GraphSpec.fromJson(spec), data: data)..resize(size);

Future<RenderGraph> show(WidgetTester tester, Json spec, List<Json> data,
    {Size size = const Size(440, 224), ValueChanged<Json>? onState}) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: size, child: CodelesslyGraph(spec: spec, data: data, onState: onState)),
    ),
  ));
  return tester.renderObject<RenderGraph>(find.byType(CodelesslyGraph));
}

/// The colour drawn at [at] of the graph.
Future<Color> pixel(WidgetTester tester, RenderGraph graph, Offset at) async {
  late Color color;
  await tester.runAsync(() async {
    final layer = graph.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & graph.size);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (at.dy.round() * image.width + at.dx.round()) * 4;
    color = Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    image.dispose();
  });
  return color;
}

void main() {
  group('bars', () {
    test('bars with one stack stand on one another, and the scale reaches their sum', () {
      final e = engine(barsSpec(), sales());
      expect(e.barGroups(0), [
        [0, 1],
      ]);
      // Feb: 50 + 20.
      expect(e.yDomain(0).$1, 0);
      expect(e.yDomain(0).$2, greaterThanOrEqualTo(70));
      final rects = e.barRects(0, 1);
      expect(rects, hasLength(2));
      final (webAt, web) = rects[0];
      final (storeAt, store) = rects[1];
      expect((webAt, storeAt), (0, 1));
      expect(web.bottom, closeTo(e.yOf(0, 0), 0.001));
      expect(store.bottom, closeTo(web.top, 0.001));
      expect(store.top, closeTo(e.yOf(0, 70), 0.001));
      expect(web.left, store.left);
      expect(web.center.dx, closeTo(e.xOf(1), 0.001));
    });

    test('bars with no stack stand side by side in the row\'s place', () {
      final e = engine(barsSpec(stack: null), sales());
      expect(e.barGroups(0), [
        [0],
        [1],
      ]);
      final rects = e.barRects(0, 2);
      final web = rects[0].$2, store = rects[1].$2;
      expect(web.right, lessThan(store.left));
      expect(web.bottom, store.bottom);
      expect((web.left + store.right) / 2, closeTo(e.xOf(2), 0.001));
      expect(store.right - web.left, closeTo(e.barWidth, 0.001));
      // The scale reaches the tallest bar, not a sum.
      expect(e.yDomain(0).$2, lessThan(70));
    });

    test('every row has its place across the plot, with a label under it', () {
      final e = engine(barsSpec(), sales());
      expect(e.plotWidth, 400);
      expect(e.viewport.barSpacing, 100);
      expect([for (var i = 0; i < 4; i++) e.xOf(i)], [50, 150, 250, 350]);
      expect([for (var i = 0; i < 4; i++) e.xLabel(i)], months);
    });

    test('the y ticks are round numbers', () {
      final e = engine(barsSpec(), sales());
      final ticks = e.yTicks(0);
      expect(ticks.first, 0);
      expect(ticks, containsAll([20, 40, 60]));
      for (final t in ticks) {
        expect(t % 10, 0);
      }
    });
  });

  group('selection', () {
    test('a point selects its row; with by=mark, the bar under it', () {
      final row = engine(barsSpec(), sales());
      expect(row.hitAt(const Offset(160, 20)), const GraphHit(pane: 0, index: 1));
      expect(row.hitAt(const Offset(399, 100)), const GraphHit(pane: 0, index: 3));
      // The axes are no row.
      expect(row.hitAt(const Offset(420, 100)), isNull);
      expect(row.hitAt(const Offset(160, 215)), isNull);

      final mark = engine(barsSpec(by: 'mark'), sales());
      final rects = mark.barRects(0, 1);
      expect(mark.hitAt(rects[0].$2.center), const GraphHit(pane: 0, index: 1, mark: 0));
      expect(mark.hitAt(rects[1].$2.center), const GraphHit(pane: 0, index: 1, mark: 1));
      // Above the stack: its top bar. Between two rows' bars: nothing.
      expect(mark.hitAt(Offset(rects[1].$2.center.dx, 2)), const GraphHit(pane: 0, index: 1, mark: 1));
      expect(mark.hitAt(Offset(rects[0].$2.right + 6, 100)), isNull);
    });

    test('hover selects and leaving clears; a tap pins, and a tap on it again lets go', () {
      final e = engine(barsSpec(), sales());
      var notified = 0;
      e.addListener(() => notified++);
      e.hover(const Offset(160, 50));
      expect(e.selection?.index, 1);
      expect(e.selectionState, containsPair('pinned', false));
      e.hover(const Offset(170, 60));
      expect(notified, 1, reason: 'the same row is no change');
      e.hover(null);
      expect(e.selection, isNull);
      expect(e.selectionState, isNull);

      e.tap(const Offset(260, 50));
      expect(e.selection?.index, 2);
      expect(e.selectionState, containsPair('pinned', true));
      // Hover shows another row while it is there, and the pin comes back.
      e.hover(const Offset(60, 50));
      expect(e.selection?.index, 0);
      e.hover(null);
      expect(e.selection?.index, 2);
      e.tap(const Offset(260, 50));
      expect(e.selection, isNull);
    });

    test('hover alone pins nothing, and none selects nothing', () {
      final hover = engine(barsSpec(on: 'hover'), sales());
      hover.tap(const Offset(160, 50));
      expect(hover.selection, isNull);
      final none = engine(barsSpec(on: 'none'), sales());
      none.hover(const Offset(160, 50));
      none.tap(const Offset(160, 50));
      expect(none.selection, isNull);
    });

    test('the selection is published: the row, and with by=mark its bar and value', () {
      final e = engine(barsSpec(by: 'mark'), sales());
      e.hover(e.barRects(0, 2)[1].$2.center);
      expect(e.state['selection'], {
        'index': 2,
        'key': 'Mar',
        'label': 'Mar',
        'pane': 0,
        'mark': 1,
        'name': 'Store',
        'field': 'store',
        'value': 40,
        'pinned': false,
        'row': e.rows[2],
      });
      expect(e.selectionRows().single.$2, 'Store');
      expect(e.selectionRows().single.$3, 40);
    });

    test('what is not selected is dimmed', () {
      final e = engine(barsSpec(), sales());
      expect(e.emphasis(0, 0, 1), 1);
      e.hover(const Offset(160, 50));
      expect(e.emphasis(0, 0, 1), 1);
      expect(e.emphasis(0, 1, 1), 1);
      expect(e.emphasis(0, 0, 2), 0.35);
    });

    test('a page sets the pinned selection from state', () {
      final e = engine(barsSpec(), sales());
      e.select({'index': 3});
      expect(e.selection, const GraphHit(pane: 0, index: 3));
      e.select(null);
      expect(e.selection, isNull);
      e.select({'index': 9});
      expect(e.selection, isNull);
    });

    test('a selection past the rows that are left is let go', () {
      final e = engine(barsSpec(), sales());
      e.select({'index': 3});
      e.setData(sales().sublist(0, 2));
      expect(e.selection, isNull);
    });
  });

  group('slices', () {
    test('each row is its share of the turn, clockwise from the top', () {
      final e = engine(donutSpec(), budget(), const Size(200, 200));
      final mark = e.spec.panes[0].marks[0];
      final slices = e.slices(mark);
      expect([for (final s in slices) s.index], [0, 1, 2]);
      expect(slices[0].start, 0);
      expect(slices[0].sweep, closeTo(0.6 * 2 * math.pi, 1e-9));
      expect(slices[1].start, closeTo(0.6 * 2 * math.pi, 1e-9));
      expect(slices[2].sweep, closeTo(0.15 * 2 * math.pi, 1e-9));
      expect(slices[0].color, const Color(0xFF2563EB));
      final (center, outer, inner) = e.arcGeometry(0, mark);
      expect(center, const Offset(100, 100));
      // Room for a selected slice, drawn larger.
      expect(outer, 94);
      expect(inner, closeTo(94 * 0.6, 1e-9));
    });

    test('a row with nothing has no slice, and nothing at all is no slices', () {
      final e = engine(donutSpec(), [
        {'label': 'A', 'value': 10},
        {'label': 'B', 'value': 0},
        {'label': 'C', 'value': -4},
        {'label': 'D'},
      ], const Size(200, 200));
      expect([for (final s in e.slices(e.spec.panes[0].marks[0])) s.index], [0]);
      final none = engine(donutSpec(), [
        {'label': 'A', 'value': 0},
      ], const Size(200, 200));
      expect(none.slices(none.spec.panes[0].marks[0]), isEmpty);
      expect(none.hitAt(const Offset(100, 20)), isNull);
    });

    test('a point on the ring selects its slice; the hole and outside select nothing', () {
      final e = engine(donutSpec(), budget(), const Size(200, 200));
      // Right of the center: the first slice (0 to 216 degrees).
      expect(e.hitAt(const Offset(180, 100)), const GraphHit(pane: 0, index: 0, mark: 0));
      // 216 to 306 degrees: left, a little above the middle.
      expect(e.hitAt(const Offset(22, 90)), const GraphHit(pane: 0, index: 1, mark: 0));
      // 306 to 360: up and to the left.
      expect(e.hitAt(const Offset(72, 26)), const GraphHit(pane: 0, index: 2, mark: 0));
      expect(e.hitAt(const Offset(100, 100)), isNull, reason: 'the hole');
      expect(e.hitAt(const Offset(4, 4)), isNull, reason: 'the corner');
      // A pie has no hole.
      final pie = engine(donutSpec(inner: 0), budget(), const Size(200, 200));
      expect(pie.hitAt(const Offset(110, 100)), const GraphHit(pane: 0, index: 0, mark: 0));
    });

    test('a selected slice is published with its value, and the others dim', () {
      final e = engine(donutSpec(), budget(), const Size(200, 200));
      e.hover(const Offset(22, 90));
      final s = e.selectionState!;
      expect(s['index'], 1);
      expect(s['key'], 'Food');
      expect(s['label'], 'Food');
      expect(s['value'], 25);
      expect(e.emphasis(0, 0, 1), 1);
      expect(e.emphasis(0, 0, 0), 0.35);
    });
  });

  group('on screen', () {
    testWidgets('a mouse over a bar selects its row, draws it apart, and leaving clears it', (tester) async {
      final states = <Json>[];
      final graph = await show(tester, barsSpec(), sales(), onState: states.add);
      await tester.pump();
      final e = graph.engine;
      final web = e.barRects(0, 0)[0].$2, far = e.barRects(0, 2)[0].$2;
      expect(await pixel(tester, graph, far.center), const Color(0xFF2563EB));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(430, 220));
      await mouse.moveTo(web.center);
      await tester.pump();
      expect(e.selection?.index, 0);
      expect(states.last['selection'], containsPair('index', 0));
      // The row under the pointer as it was, the others dimmed.
      expect(await pixel(tester, graph, web.center - const Offset(20, 0)), const Color(0xFF2563EB));
      final other = await pixel(tester, graph, far.center);
      expect(other, isNot(const Color(0xFF2563EB)));
      expect(other.b, greaterThan(other.r), reason: 'still blue, lighter');

      await mouse.moveTo(const Offset(600, 500));
      await tester.pump();
      expect(e.selection, isNull);
      expect(states.last['selection'], isNull);
      expect(await pixel(tester, graph, far.center), const Color(0xFF2563EB));
    });

    testWidgets('a finger pressing and moving over the bars selects each in turn, and lifting lets go', (tester) async {
      for (final on in ['both', 'hover']) {
        final states = <Json>[];
        final graph = await show(tester, barsSpec(on: on), sales(), onState: states.add);
        await tester.pump();
        final e = graph.engine;
        final finger = await tester.startGesture(Offset(e.xOf(0), 100), kind: PointerDeviceKind.touch);
        await tester.pump();
        expect(e.selection?.index, 0, reason: '$on: selected as it goes down');
        for (var step = 1; step <= 10; step++) {
          await finger.moveTo(Offset(e.xOf(0) + (e.xOf(2) - e.xOf(0)) * step / 10, 100));
          await tester.pump();
        }
        expect(e.selection?.index, 2, reason: '$on: follows the finger');
        expect(states.last['selection'], containsPair('index', 2));
        await finger.up();
        await tester.pump();
        expect(e.selection, isNull, reason: '$on: a drag pins nothing');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a finger on a slice selects it; a tap pins it', (tester) async {
      final graph = await show(tester, donutSpec(), budget(), size: const Size(200, 200));
      await tester.pump();
      final finger = await tester.startGesture(const Offset(180, 100), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(graph.engine.selection, const GraphHit(pane: 0, index: 0, mark: 0));
      await finger.moveTo(const Offset(160, 150));
      await finger.moveTo(const Offset(60, 170));
      await finger.moveTo(const Offset(22, 90));
      await tester.pump();
      expect(graph.engine.selection?.index, 1);
      await finger.up();
      await tester.pump();
      expect(graph.engine.selection, isNull);
      await tester.tapAt(const Offset(22, 90));
      await tester.pump();
      expect(graph.engine.selection?.index, 1);
      expect(graph.engine.selectionState, containsPair('pinned', true));
    });

    testWidgets('a tap pins a row and a tap on it again lets go', (tester) async {
      final graph = await show(tester, barsSpec(), sales());
      await tester.pump();
      await tester.tapAt(const Offset(250, 100));
      await tester.pump();
      expect(graph.engine.selection?.index, 2);
      expect(graph.engine.selectionState, containsPair('pinned', true));
      await tester.tapAt(const Offset(250, 100));
      await tester.pump();
      expect(graph.engine.selection, isNull);
    });

    testWidgets('a mouse over a slice selects it and draws it larger', (tester) async {
      final graph = await show(tester, donutSpec(), budget(), size: const Size(200, 200));
      await tester.pump();
      // Past the ring's edge at rest: nothing but the background.
      const beyond = Offset(197, 100);
      expect(await pixel(tester, graph, beyond), const Color(0xFFFFFFFF));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(400, 400));
      await mouse.moveTo(const Offset(180, 100));
      await tester.pump();
      expect(graph.engine.selection, const GraphHit(pane: 0, index: 0, mark: 0));
      expect(await pixel(tester, graph, beyond), const Color(0xFF2563EB));
      // Another slice, dimmed.
      final dimmed = await pixel(tester, graph, const Offset(22, 90));
      expect(dimmed, isNot(const Color(0xFF719AF2)));
    });

    testWidgets('a graph of bars and a line draws both, and a selected row dots the line', (tester) async {
      final graph = await show(tester, barsSpec(line: true), sales());
      await tester.pump();
      final e = graph.engine;
      final at = Offset(e.xOf(1), e.yOf(0, 60));
      e.select({'index': 1});
      await tester.pump();
      expect(await pixel(tester, graph, at), const Color(0xFFEF4444));
      expect(e.selectionRows().map((r) => r.$2), ['Web', 'Store', 'Goal']);
    });

    testWidgets('a graph that neither pans nor pins leaves a drag to the page', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          controller: controller,
          child: Column(children: [
            SizedBox(width: 440, height: 300, child: CodelesslyGraph(spec: barsSpec(on: 'hover'), data: sales())),
            const SizedBox(height: 2000),
          ]),
        ),
      ));
      await tester.drag(find.byType(CodelesslyGraph), const Offset(0, -120));
      await tester.pump();
      expect(controller.offset, greaterThan(60));
    });
  });
}
