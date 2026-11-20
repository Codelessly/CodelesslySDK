import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/graph.dart' show GraphEngine, GraphHit, GraphSpec, RenderGraph;
import 'package:codelessly_sdk/src/widgets/chart_words.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

// The chart types are words over the graph: each node is written out as a
// graph spec and rows, and drawn (and made interactive) by the graph.

Node node(String type, Map<String, Object?> props) => Node.fromJson({'type': type, 'props': props}, id: 'c')!;

GraphEngine engineOf(Node n, [Size size = const Size(400, 200)]) {
  final chart = chartGraphOf(n)!;
  return GraphEngine(GraphSpec.fromJson(chart.spec), data: chart.data)
    ..resize(size)
    ..select(chart.selected);
}

Iterable<RenderObject> _all(RenderObject o) sync* {
  yield o;
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield* _all(k);
  }
}

RenderGraph graphOf(harness.Screen s, String id) => _all(s.tree.boxOf(id)!).whereType<RenderGraph>().single;

void main() {
  group('barChart', () {
    test('a bar per value with its label, from zero to the largest (or max)', () {
      final e = engineOf(node('barChart', {
        'values': [3, 5, 4],
        'labels': ['Mon', 'Tue', 'Wed'],
        'color': '#FF2563EB',
        'barRadius': 4,
      }));
      expect(e.count, 3);
      expect([for (var i = 0; i < 3; i++) e.xLabel(i)], ['Mon', 'Tue', 'Wed']);
      expect(e.yDomain(0), (0.0, 5.0));
      final mark = e.spec.panes.single.marks.single;
      expect(mark.type, 'bar');
      expect(mark.color, const Color(0xFF2563EB));
      expect(mark.radius, 4);
      // The tallest bar fills the plot.
      expect(e.barRects(0, 1).single.$2.top, closeTo(e.plotRect(0).top, 0.001));
      expect(engineOf(node('barChart', {'values': [3, 5], 'max': 10})).yDomain(0), (0.0, 10.0));
    });

    test('grid lines are evenly from zero to the top, with the labels given them', () {
      final e = engineOf(node('barChart', {
        'values': [3, 5, 4],
        'max': 6,
        'gridLines': 3,
        'gridLabels': ['0', '2', '4', ''],
        'gridLabelsLeft': true,
      }));
      expect(e.yTicks(0), [0, 2, 4, 6]);
      expect([for (final t in e.yTicks(0)) e.yLabel(0, t)], ['0', '2', '4', '']);
      expect(e.axisLeft, isTrue);
      expect(e.plotLeft, 40);
    });

    test('a highlighted bar is drawn apart, and each bar may have a color of its own', () {
      final e = engineOf(node('barChart', {
        'values': [1, 2, 3],
        'highlight': 1,
        'dimmedOpacity': 0.4,
        'colors': ['#FFFF0000', '#FF00FF00'],
      }));
      expect(e.selection, const GraphHit(pane: 0, index: 1));
      expect(e.emphasis(0, 0, 1), 1);
      expect(e.emphasis(0, 0, 0), 0.4);
      final mark = e.spec.panes.single.marks.single;
      expect(e.markColor(mark, 0), const Color(0xFFFF0000));
      expect(e.markColor(mark, 1), const Color(0xFF00FF00));
      expect(e.markColor(mark, 2), const Color(0xFFFF0000));
      // The bar under the pointer says its value.
      expect(e.spec.selection.on, 'hover');
      expect(e.spec.selection.tooltip, isTrue);
    });

    test('a missing value is no bar', () {
      final e = engineOf(node('barChart', {
        'values': [2, null, 4],
      }));
      expect(e.barRects(0, 1), isEmpty);
      expect(e.barRects(0, 2), hasLength(1));
    });
  });

  group('chart', () {
    Map<String, Object?> stacked([Map<String, Object?> extra = const {}]) => {
          'chartType': 'bar',
          'data': [
            {'label': '7A', 'a': 3, 'b': 1},
            {'label': '8A', 'a': 10, 'b': 4},
            {'label': '9A', 'a': 6, 'b': 2},
          ],
          'series': [
            {'field': 'a', 'name': 'General', 'color': '#FFFFD400', 'stack': 's'},
            {'field': 'b', 'name': 'VIP', 'color': '#FFFF2E93', 'stack': 's'},
          ],
          ...extra,
        };

    test('bar series with one stack stand on one another over the rows, the axis on the left', () {
      final e = engineOf(node('chart', stacked({'yLabelPrefix': r'$', 'yLabelSuffix': 'k'})));
      expect(e.barGroups(0), [
        [0, 1],
      ]);
      expect(e.yDomain(0).$1, 0);
      expect(e.yDomain(0).$2, greaterThanOrEqualTo(14));
      expect([for (var i = 0; i < 3; i++) e.xLabel(i)], ['7A', '8A', '9A']);
      expect(e.axisLeft, isTrue);
      expect(e.plotLeft, 44);
      expect(e.yLabel(0, 10), r'$10k');
    });

    test('selectOnHover offers the selection, with the chart\'s tooltip and dimming', () {
      // Unless the chart says otherwise the pointer selects, with a tooltip.
      final plain = engineOf(node('chart', stacked()));
      expect((plain.spec.selection.on, plain.spec.selection.tooltip), ('both', true));
      final off = engineOf(node('chart', stacked({'selectOnHover': false, 'tooltip': false})));
      expect((off.spec.selection.on, off.spec.selection.tooltip), ('none', false));
      final e = engineOf(node('chart', stacked({'selectOnHover': true, 'dimUnselected': true, 'tooltip': true})));
      expect(e.spec.selection.on, 'both');
      expect(e.spec.selection.tooltip, isTrue);
      e.hover(Offset(e.xOfRow(1), 80));
      expect(e.selection?.index, 1);
      expect(e.selectionRows().map((r) => (r.$2, r.$3)), [('General', 10.0), ('VIP', 4.0)]);
      expect(e.emphasis(0, 0, 0), 0.35);
    });

    test('selectedIndex is the pinned row', () {
      expect(engineOf(node('chart', stacked({'selectedIndex': 2}))).selection?.index, 2);
      expect(engineOf(node('chart', stacked())).selection, isNull);
    });

    test('a line chart draws every series as a line, its ends just inside the plot, from zero unless it fits its least', () {
      Map<String, Object?> lines([Map<String, Object?> extra = const {}]) => {
            'chartType': 'line',
            'data': [
              {'label': 'Mon', 'v': 40},
              {'label': 'Tue', 'v': 60},
              {'label': 'Wed', 'v': 50},
            ],
            'series': [
              {'field': 'v', 'name': 'Visits', 'kind': 'bar', 'curved': true, 'strokeWidth': 3},
            ],
            ...extra,
          };
      final e = engineOf(node('chart', lines()));
      final mark = e.spec.panes.single.marks.single;
      expect((mark.type, mark.curved, mark.width), ('line', true, 3.0));
      expect(e.xOfRow(0), closeTo(e.plotLeft + 6, 0.001));
      expect(e.xOfRow(2), closeTo(e.plotRight - 6, 0.001));
      expect(e.yDomain(0).$1, 0);
      expect(engineOf(node('chart', lines({'fitMinY': true}))).yDomain(0).$1, 40);
      expect(engineOf(node('chart', lines({'minY': 30, 'maxY': 90}))).yDomain(0), (30.0, 90.0));
    });

    test('a donut is slices round a center, colored by the rows', () {
      final e = engineOf(
          node('chart', {
            'chartType': 'donut',
            'donutThickness': 0.2,
            'series': [
              {'field': 'value', 'colorField': 'color'},
            ],
            'data': [
              {'label': 'Rent', 'value': 60, 'color': '#FF2563EB'},
              {'label': 'Food', 'value': 40, 'color': '#FF719AF2'},
            ],
          }),
          const Size(200, 200));
      final pane = e.spec.panes.single;
      expect(pane.polar, isTrue);
      final mark = pane.marks.single;
      expect(mark.type, 'arc');
      // The ring is 0.2 of the diameter thick.
      expect(mark.inner, closeTo(0.6, 1e-9));
      final slices = e.slices(mark);
      expect(slices.map((s) => s.color), [const Color(0xFF2563EB), const Color(0xFF719AF2)]);
      expect(e.xLabel(0), 'Rent');
    });

    test('reference lines are lines across the plot, always in view', () {
      final e = engineOf(node('chart', stacked({
        'referenceLines': [
          {'value': 30, 'color': '#FFFF4B3E', 'label': 'CAPACITY'},
        ],
      })));
      final guide = e.spec.panes.single.guides.single;
      expect((guide.y, guide.label), (30.0, 'CAPACITY'));
      expect(e.yDomain(0).$2, greaterThanOrEqualTo(30));
    });
  });

  group('lineChart', () {
    Map<String, Object?> props([Map<String, Object?> extra = const {}]) => {
          'data': [
            {'x': 0, 'y': 10},
            {'x': 10, 'y': 30},
            {'x': 40, 'y': 20},
          ],
          'xMin': 0,
          'xMax': 40,
          'yMin': 0,
          'yMax': 40,
          'plotPadding': [40, 10, 0, 20],
          ...extra,
        };

    test('rows whose x is a name are drawn in the order written, each labelled by it', () {
      final named = node('lineChart', {
        'data': [
          {'day': 'Mon', 'n': 3},
          {'day': 'Tue', 'n': 5},
          {'day': 'Wed', 'n': 4},
        ],
        'xField': 'day',
        'yField': 'n',
      });
      final e = engineOf(named);
      expect(e.count, 3);
      expect(e.xOfRow(0), lessThan(e.xOfRow(1)));
      expect(e.xOfRow(1), lessThan(e.xOfRow(2)));
      final x = chartGraphOf(named)!.spec['x'] as Map;
      expect(x['labels'], isTrue);
      expect(x['tickValues'], [
        {'value': 0, 'label': 'Mon'},
        {'value': 1, 'label': 'Tue'},
        {'value': 2, 'label': 'Wed'},
      ]);
      // Rows with numbers are as they were: only those, by their x.
      expect(engineOf(node('lineChart', props())).count, 3);
    });

    test('points stand where their numbers are, not one place each', () {
      final e = engineOf(node('lineChart', props()));
      expect(e.linear, isTrue);
      expect((e.plotLeft, e.plotWidth), (40.0, 360.0));
      expect(e.xOfRow(0), 40);
      expect(e.xOfRow(1), closeTo(40 + 90, 0.001));
      expect(e.xOfRow(2), 400);
      final plot = e.plotRect(0);
      expect((plot.top, plot.bottom), (10.0, 180.0));
      expect(e.yOf(0, 20), closeTo(95, 0.001));
    });

    test('the ticks are the ones the chart is told, with their labels', () {
      final e = engineOf(node('lineChart', props({
        'xTicks': [
          {'x': 0, 'label': '9 AM'},
          {'x': 20, 'label': 'Noon'},
          {'x': 40, 'label': '4 PM'},
        ],
        'yTicks': [
          {'y': 0, 'label': '0'},
          {'y': 20, 'label': '20%'},
        ],
      })));
      expect(e.xTicks, [0, 20, 40]);
      expect([for (final t in e.xTicks) e.xTickText(t)], ['9 AM', 'Noon', '4 PM']);
      expect(e.yTicks(0), [0, 20]);
      expect(e.yLabel(0, 20), '20%');
    });

    test('the area under the line runs from its top color to its bottom one', () {
      final e = engineOf(node('lineChart', props({'lineColor': '#FF2563EB', 'areaTopColor': '#402563EB'})));
      final marks = e.spec.panes.single.marks;
      expect(marks.map((m) => m.type), ['area', 'line']);
      expect(marks[0].color, const Color(0x402563EB));
      expect(marks[0].fillTo, const Color(0x00000000));
      expect(marks[1].color, const Color(0xFF2563EB));
      expect(engineOf(node('lineChart', props())).spec.panes.single.marks.map((m) => m.type), ['line']);
    });

    test('markers, vertical lines and reference lines are guides at their numbers', () {
      final e = engineOf(node('lineChart', props({
        'markers': [
          {'x': 10, 'y': 30, 'label': 'Peak', 'color': '#FFEF4444'},
        ],
        'verticalLines': [
          {'x': 20, 'label': 'Now'},
        ],
        'referenceLines': [
          {'y': 25, 'label': 'Goal'},
        ],
      })));
      final guides = e.spec.panes.single.guides;
      expect(guides.map((g) => (g.x, g.y, g.label)), [(null, 25.0, 'Goal'), (20, null, 'Now'), (10, 30.0, 'Peak')]);
      expect(e.xOf(e.place(20)!), closeTo(40 + 180, 0.001));
    });

    test('scrubEnabled selects the nearest point under the pointer; selectedX pins one', () {
      final e = engineOf(node('lineChart', props({'scrubEnabled': true})));
      e.hover(Offset(e.xOf(12), 50));
      expect(e.selection?.index, 1);
      e.hover(Offset(e.xOf(30), 50));
      expect(e.selection?.index, 2);
      expect(engineOf(node('lineChart', props({'selectedX': 10}))).selection?.index, 1);
      // On unless the chart says not.
      final plain = engineOf(node('lineChart', props()));
      plain.hover(Offset(plain.xOf(12), 50));
      expect(plain.selection?.index, 1);
      final off = engineOf(node('lineChart', props({'scrubEnabled': false})));
      off.hover(const Offset(100, 50));
      expect(off.selection, isNull);
    });
  });

  group('plotChart', () {
    test('points are spread evenly over the x stretch', () {
      final e = engineOf(node('plotChart', {
        'points': [1, 3, 2, 5, 4],
        'xMin': 0,
        'xMax': 8,
        'yMin': 0,
        'yMax': 5,
        'lineColor': '#FF2563EB',
      }));
      expect(e.linear, isTrue);
      expect([for (var i = 0; i < 5; i++) e.pos(i)], [0, 2, 4, 6, 8]);
      expect(e.yDomain(0), (0.0, 5.0));
      expect(e.xOfRow(4), closeTo(e.plotRight, 0.001));
      expect(e.spec.panes.single.marks.single.color, const Color(0xFF2563EB));
    });

    test('several series are several lines over the same stretch', () {
      final e = engineOf(node('plotChart', {
        'xMin': 0,
        'xMax': 2,
        'series': [
          {'points': [1, 2, 3], 'color': '#FFFF0000', 'id': 'a'},
          {'points': [3, null, 1], 'color': '#FF0000FF', 'id': 'b'},
        ],
      }));
      final marks = e.spec.panes.single.marks;
      expect(marks.map((m) => (m.y, m.color)), [('s0', const Color(0xFFFF0000)), ('s1', const Color(0xFF0000FF))]);
      expect(e.rows[1]['s1'], isNull);
      expect(e.rows[2]['s1'], 1);
    });

    test('labels, ranges, markers and a reference line are the graph\'s ticks and guides', () {
      final e = engineOf(node('plotChart', {
        'points': [1, 2, 3],
        'xMin': 0,
        'xMax': 10,
        'xLabels': [
          {'x': 0, 'label': 'Start'},
          {'x': 10, 'label': 'End'},
        ],
        'ranges': [
          {'from': 2, 'to': 4, 'color': '#22FF0000', 'label': 'Fed'},
        ],
        'markers': [
          {'x': 5, 'y': 2, 'label': 'Now'},
        ],
        'referenceX': 7,
      }));
      expect([for (final t in e.xTicks) e.xTickText(t)], ['Start', 'End']);
      final guides = e.spec.panes.single.guides;
      expect(guides.map((g) => (g.from, g.to, g.x, g.y)), [(2.0, 4.0, null, null), (null, null, 7.0, null), (null, null, 5.0, 2.0)]);
    });

    test('a selectable plot selects the nearest point; selectedX pins it', () {
      final n = node('plotChart', {
        'points': [1, 2, 3, 4, 5],
        'xMin': 0,
        'xMax': 4,
        'selectedX': 2.9,
      });
      final e = engineOf(n);
      expect(e.selection?.index, 3);
      expect(e.spec.selection.on, 'both');
      expect(engineOf(node('plotChart', {'points': [1, 2], 'selectable': false})).spec.selection.on, 'none');
    });
  });

  group('on a page', () {
    Map<String, Json> page(Json chart) => {
          'col': {
            'type': 'column',
            'children': ['chart'],
            'layout': {'width': 400, 'height': {'hug': 220}},
          },
          'chart': chart,
        };

    testWidgets('each chart type is drawn by the graph', (tester) async {
      for (final (type, props) in <(String, Map<String, Object?>)>[
        ('barChart', {'values': [3, 5, 4], 'labels': ['a', 'b', 'c']}),
        ('lineChart', {'data': [{'x': 0, 'y': 1}, {'x': 1, 'y': 3}]}),
        ('plotChart', {'points': [1, 3, 2]}),
        ('chart', {'chartType': 'donut', 'data': [{'label': 'a', 'value': 2}, {'label': 'b', 'value': 1}], 'series': [{'field': 'value'}]}),
        ('chart', {'chartType': 'bar', 'data': [{'label': 'a', 'v': 2}], 'series': [{'field': 'v'}]}),
      ]) {
        final s = await harness.show(tester, page({'type': type, 'layout': {'width': 400, 'height': 200}, 'props': props}));
        await tester.pump();
        final graph = graphOf(s, 'chart');
        expect(graph.size, const Size(400, 200), reason: type);
        expect(graph.engine.count, greaterThan(0), reason: type);
        expect(tester.takeException(), isNull, reason: type);
        // It paints with no error.
        expect(graph.debugNeedsPaint, isFalse, reason: type);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a chart with selectOnHover selects the bar under a mouse and under a finger', (tester) async {
      final s = await harness.show(
          tester,
          page({
            'type': 'chart',
            'layout': {'width': 400, 'height': 200},
            'props': {
              'chartType': 'bar',
              'selectOnHover': true,
              'tooltip': true,
              'data': [
                {'label': '7A', 'a': 3},
                {'label': '8A', 'a': 10},
                {'label': '9A', 'a': 6},
              ],
              'series': [
                {'field': 'a', 'name': 'General'},
              ],
            },
          }));
      await tester.pump();
      final graph = graphOf(s, 'chart');
      final e = graph.engine;
      final origin = graph.localToGlobal(Offset.zero);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(700, 550));
      await mouse.moveTo(origin + Offset(e.xOfRow(1), 100));
      await tester.pump();
      expect(e.selection?.index, 1);
      await mouse.moveTo(const Offset(700, 550));
      await tester.pump();
      expect(e.selection, isNull);

      final finger = await tester.startGesture(origin + Offset(e.xOfRow(2), 100), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(e.selection?.index, 2);
      await finger.up();
      await tester.pump();
      // A press and lift in one place is a tap: it stays, for a screen with no pointer to hover.
      expect(e.selection?.index, 2);
      expect(e.selectionState, containsPair('pinned', true));
    });
  });
}
