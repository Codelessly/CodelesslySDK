import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Marks that move to new values (and grow in), and a linear x scale: bars
// on it, and a view of it that pans and zooms.

Json bars({double animate = 400, bool animateIn = false}) => {
      'key': 'k',
      'animate': animate,
      'animateIn': animateIn,
      'x': {'label': 'k', 'format': '', 'fit': 'bars', 'axisHeight': 20},
      'crosshair': {'enabled': false},
      'panes': [
        {
          'y': {'width': 40, 'domain': 'fixed', 'min': 0, 'max': 100},
          'marks': [
            {'type': 'bar', 'y': 'v'},
          ],
        },
      ],
    };

List<Json> rows(List<num> values) => [
      for (var i = 0; i < values.length; i++) {'k': 'r$i', 'v': values[i]},
    ];

Json linear({bool bar = false, Json x = const {}, Json interactions = const {}}) => {
      'key': 'x',
      'x': {'scale': 'linear', 'field': 'x', 'label': 'x', 'format': '', 'axisHeight': 20, ...x},
      'crosshair': {'enabled': false},
      'interactions': interactions,
      'panes': [
        {
          'y': {'width': 40},
          'marks': [
            {'type': bar ? 'bar' : 'line', 'y': 'y'},
          ],
        },
      ],
    };

List<Json> points(List<num> xs) => [
      for (final x in xs) {'x': x, 'y': x * 2 + 1},
    ];

GraphEngine engine(Json spec, List<Json> data, [Size size = const Size(440, 220)]) =>
    GraphEngine(GraphSpec.fromJson(spec), data: data)..resize(size);

Future<RenderGraph> show(WidgetTester tester, Json spec, List<Json> data) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 440, height: 220, child: CodelesslyGraph(spec: spec, data: data)),
    ),
  ));
  return tester.renderObject<RenderGraph>(find.byType(CodelesslyGraph));
}

void main() {
  group('marks move to new values', () {
    test('a tween runs each mark from what it showed to what it is, rows told apart by key', () {
      final e = engine(bars(), rows([20, 80]));
      e.setData([
        {'k': 'r1', 'v': 40},
        {'k': 'r0', 'v': 60},
        {'k': 'new', 'v': 50},
      ], tween: true);
      expect(e.tweening, isTrue);
      // At the start, where they were (r1 was 80, r0 was 20); a row not there before, at zero.
      expect([for (final r in e.rows) r['v']], [80, 20, 0]);
      e.tweenTo(0.5);
      expect([for (final r in e.rows) r['v']], [60, 40, 25]);
      e.tweenTo(1);
      expect(e.tweening, isFalse);
      expect([for (final r in e.rows) r['v']], [40, 60, 50]);
    });

    test('the scale is where the marks are going, from the first frame', () {
      final spec = bars()..['panes'] = [
          {
            'y': {'width': 40, 'domain': 'data', 'margins': [0, 0]},
            'marks': [
              {'type': 'bar', 'y': 'v'},
            ],
          },
        ];
      final e = engine(spec, rows([10, 20]));
      expect(e.yDomain(0), (0.0, 20.0));
      e.setData(rows([10, 200]), tween: true);
      expect(e.yDomain(0), (0.0, 200.0));
      e.tweenTo(0.3);
      expect(e.yDomain(0), (0.0, 200.0));
    });

    test('a spec that does not animate, and rows set with no tween, change at once', () {
      final still = engine(bars(animate: 0), rows([20, 80]));
      still.setData(rows([40, 60]), tween: true);
      expect(still.tweening, isFalse);
      expect([for (final r in still.rows) r['v']], [40, 60]);
      final e = engine(bars(), rows([20, 80]));
      e.setData(rows([40, 60]));
      expect(e.tweening, isFalse);
    });

    testWidgets('on screen, new rows glide over the spec\'s time and then rest', (tester) async {
      final graph = await show(tester, bars(), rows([20, 80]));
      await tester.pump();
      final e = graph.engine;
      final before = e.barRects(0, 0).single.$2.top;
      await show(tester, bars(), rows([60, 80]));
      await tester.pump();
      expect(e.tweening, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      final mid = e.barRects(0, 0).single.$2.top;
      expect(mid, lessThan(before));
      expect(mid, greaterThan(e.yOf(0, 60)));
      await tester.pump(const Duration(milliseconds: 250));
      expect(e.tweening, isFalse);
      expect(e.barRects(0, 0).single.$2.top, closeTo(e.yOf(0, 60), 0.001));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('with animateIn the marks grow from zero when the graph first shows', (tester) async {
      final graph = await show(tester, bars(animateIn: true), rows([50, 100]));
      final e = graph.engine;
      await tester.pump(const Duration(milliseconds: 1));
      expect(e.tweening, isTrue);
      expect((e.rows[1]['v']! as num).toDouble(), lessThan(100));
      await tester.pumpAndSettle();
      expect([for (final r in e.rows) r['v']], [50, 100]);
      // Once: the same rows again start nothing.
      await show(tester, bars(animateIn: true), rows([50, 100]));
      await tester.pump();
      expect(e.tweening, isFalse);
    });

    testWidgets('a graph with no animateIn shows its rows at rest', (tester) async {
      final graph = await show(tester, bars(), rows([50, 100]));
      await tester.pump();
      expect(graph.engine.tweening, isFalse);
      expect(graph.engine.rows[1]['v'], 100);
    });
  });

  group('bars on a linear scale', () {
    test('each bar stands at its number, as wide as the closest two rows allow, whole at both ends', () {
      final e = engine(linear(bar: true), points([0, 10, 20, 50]));
      // Half a row's room (5) past the first and the last: -5 to 55 over 400 px.
      expect((e.from, e.to), (-5.0, 55.0));
      final px = 400 / 60;
      expect(e.slotWidth, closeTo(10 * px, 0.001));
      expect(e.barWidth, (10 * px * 0.72).floorToDouble());
      final first = e.barRects(0, 0).single.$2, last = e.barRects(0, 3).single.$2;
      expect(first.center.dx, closeTo(e.xOf(0), 0.001));
      expect(first.left, greaterThanOrEqualTo(e.plotLeft));
      expect(last.center.dx, closeTo(e.xOf(50), 0.001));
      expect(last.right, lessThanOrEqualTo(e.plotRight));
      // Uneven: the third bar is a third of the way from the second to the fourth.
      expect(e.xOfRow(2) - e.xOfRow(1), closeTo((e.xOfRow(3) - e.xOfRow(1)) / 4, 0.001));
    });

    test('a point selects the bar nearest it', () {
      final spec = linear(bar: true)..['selection'] = {'on': 'hover'};
      final e = engine(spec, points([0, 10, 20, 50]));
      e.hover(Offset(e.xOf(38), 100));
      expect(e.selection?.index, 3);
      e.hover(Offset(e.xOf(12), 100));
      expect(e.selection?.index, 1);
    });
  });

  group('a linear scale\'s view', () {
    test('at rest it is the whole stretch; zooming keeps the position under the pointer', () {
      final e = engine(linear(), points([0, 25, 50, 75, 100]));
      expect((e.from, e.to), (0.0, 100.0));
      expect(e.visible, (0, 4));
      final at = e.xOf(25);
      e.zoomAt(at, 2);
      expect(e.to - e.from, closeTo(50, 1e-9));
      expect(e.xOf(25), closeTo(at, 1e-9));
      expect((e.from, e.to), (12.5, 62.5));
      expect(e.visible, (1, 2));
    });

    test('panning moves it and stops at the ends of the scale; zooming out stops at the whole', () {
      final e = engine(linear(), points([0, 25, 50, 75, 100]));
      e.zoomAt(e.xOf(50), 4);
      expect((e.from, e.to), (37.5, 62.5));
      // 400 px show 25: 160 px is 10.
      e.panBy(160);
      expect((e.from, e.to), (27.5, 52.5));
      e.panBy(100000);
      expect((e.from, e.to), (0.0, 25.0));
      e.panBy(-100000);
      expect((e.from, e.to), (75.0, 100.0));
      e.zoomAt(e.xOf(90), 0.001);
      expect((e.from, e.to), (0.0, 100.0));
      expect(e.visible, (0, 4));
    });

    test('the y scale fits the rows in view, and resetting shows the whole again', () {
      final e = engine(linear(), points([0, 25, 50, 75, 100]));
      final whole = e.yDomain(0);
      e.zoomAt(e.xOf(25), 4);
      expect(e.visible, (1, 1));
      expect(e.yDomain(0).$2, lessThan(whole.$2));
      e.resetX();
      expect((e.from, e.to), (0.0, 100.0));
      expect(e.yDomain(0), whole);
    });

    test('a page sets it from state, and reads it back', () {
      final e = engine(linear(), points([0, 25, 50, 75, 100]));
      e.applyView({'from': 20, 'to': 60});
      expect((e.from, e.to), (20.0, 60.0));
      expect(e.viewState['from'], 20);
      expect(e.viewState['to'], 60);
      expect((e.viewState['first'], e.viewState['last']), (1, 2));
    });

    test('a spec may let the view past the scale', () {
      final e = engine(linear(x: {'overscroll': true}), points([0, 100]));
      e.panBy(200);
      expect((e.from, e.to), (-50.0, 50.0));
    });

    testWidgets('on screen, a drag pans it and the wheel zooms it about the pointer', (tester) async {
      final graph = await show(tester, linear(), points([0, 25, 50, 75, 100]));
      await tester.pump();
      final e = graph.engine;
      await tester.sendEventToBinding(PointerScrollEvent(
          position: Offset(e.xOf(50), 100), scrollDelta: const Offset(0, -400), kind: PointerDeviceKind.mouse));
      await tester.pump();
      expect(e.to - e.from, lessThan(100));
      expect((e.from + e.to) / 2, closeTo(50, 1e-6));
      final from = e.from;
      final drag = await tester.startGesture(const Offset(200, 100), kind: PointerDeviceKind.mouse);
      for (var i = 1; i <= 8; i++) {
        await drag.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await drag.up();
      // Past the double tap's wait and the fling.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(e.from, lessThan(from));
    });
  });
}
