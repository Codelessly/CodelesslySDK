import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/chart_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicator_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Node _node(String type, Map<String, Object?> props) => Node.fromJson({
  'id': 'n',
  'type': type,
  'layout': {'width': 300, 'height': 180},
  'props': {'animationDuration': 1000, ...props},
})!;
Node _chart(
  List<Map<String, Object?>> data, {
  Map<String, Object?> props = const {},
}) => _node('chart', {
  'series': [
    {'field': 'votes'},
  ],
  'data': data,
  ...props,
});
Node _line(
  List<Map<String, Object?>> data, {
  Map<String, Object?> props = const {},
}) => _node('lineChart', {'data': data, ...props});
Node _plot(List<double> points, {Map<String, Object?> props = const {}}) =>
    _node('plotChart', {'points': points, 'xMin': 0, 'xMax': 2, ...props});

List<Map<String, Object?>> _data(Node n) =>
    n.type == 'chart' ? n.prop(ChartProps.data) : n.prop(LineChartProps.data);
Iterable<RenderObject> _descendants(RenderObject object) sync* {
  yield object;
  final children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final child in children) {
    yield* _descendants(child);
  }
}

Future<(DocumentSource, RenderIndicatorTransition)> _show(
  WidgetTester tester,
  Node n,
) async {
  LayoutDocument document(Node value) =>
      LayoutDocument(roots: ['n'], nodes: {'n': value});
  final source = DocumentSource(document(n));
  final tree = NodeTree(source);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(tree: tree, rootId: 'n', interactive: true),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
  return (
    source,
    _descendants(
      tree.boxOf('n')!,
    ).whereType<RenderIndicatorTransition>().single,
  );
}

void _set(DocumentSource source, Node n) =>
    source.document = source.document.copyWith(nodes: {'n': n});
Node _painted(RenderIndicatorTransition render) =>
    (render.painter! as NodePainter).n;

void main() {
  test('series values match category identity when the rows reorder', () {
    final old = _chart([
      {'label': 'A', 'votes': 10},
      {'label': 'B', 'votes': 30},
    ]);
    final target = _chart([
      {'label': 'B', 'votes': 50},
      {'label': 'A', 'votes': 90},
    ]);
    expect(_data(chartDataFrame(old, target, .5)), [
      {'label': 'B', 'votes': 40.0},
      {'label': 'A', 'votes': 50.0},
    ]);
  });
  test(
    'new categories grow from zero; removed rows do not become other categories',
    () {
      final old = _chart([
        {'label': 'A', 'votes': 10},
        {'label': 'B', 'votes': 30},
      ]);
      final target = _chart([
        {'label': 'B', 'votes': 50},
        {'label': 'C', 'votes': 60},
      ]);
      expect(_data(chartDataFrame(old, target, .5)), [
        {'label': 'B', 'votes': 40.0},
        {'label': 'C', 'votes': 30.0},
      ]);
      expect(
        chartDataChanges(
          old,
          _chart([
            {'label': 'B', 'votes': 30},
          ]),
        ),
        isFalse,
      );
    },
  );
  test(
    'null and missing values remain gaps instead of morphing into unrelated values',
    () {
      final old = _chart([
        {'label': 'A', 'votes': 10},
        {'label': 'B', 'votes': 30},
      ]);
      final target = _chart([
        {'label': 'A', 'votes': null},
        {'label': 'B'},
      ]);
      expect(_data(chartDataFrame(old, target, .5)), [
        {'label': 'A', 'votes': null},
        {'label': 'B'},
      ]);
      expect(chartDataChanges(old, target), isFalse);
    },
  );
  test('duplicate category labels match occurrence order', () {
    final old = _chart([
      {'label': 'A', 'votes': 10},
      {'label': 'A', 'votes': 30},
    ]);
    final target = _chart([
      {'label': 'A', 'votes': 50},
      {'label': 'A', 'votes': 70},
    ]);
    expect(_data(chartDataFrame(old, target, .5)).map((r) => r['votes']), [
      30,
      50,
    ]);
  });
  test(
    'only declared series and fillTo fields interpolate; metadata uses target values',
    () {
      final props = {
        'series': [
          {'field': 'votes', 'kind': 'area', 'fillTo': 'base'},
        ],
      };
      final old = _chart([
        {'label': 'A', 'votes': 10, 'base': 2, 'color': 'old', 'metadata': 90},
      ], props: props);
      final target = _chart([
        {'label': 'A', 'votes': 50, 'base': 6, 'color': 'new', 'metadata': 100},
      ], props: props);
      expect(_data(chartDataFrame(old, target, .5)).single, {
        'label': 'A',
        'votes': 30.0,
        'base': 4.0,
        'color': 'new',
        'metadata': 100,
      });
    },
  );
  test(
    'timeline interval endpoints and unconfigured donut values interpolate',
    () {
      final a = _chart(
        [
          {'label': 'A', 'from': 2, 'to': 8},
        ],
        props: {'chartType': 'timeline'},
      );
      final b = _chart(
        [
          {'label': 'A', 'from': 4, 'to': 12},
        ],
        props: {'chartType': 'timeline'},
      );
      expect(_data(chartDataFrame(a, b, .5)).single, {
        'label': 'A',
        'from': 3.0,
        'to': 10.0,
      });
      final d0 = _node('chart', {
        'chartType': 'donut',
        'data': [
          {'label': 'A', 'value': 10},
        ],
      });
      final d1 = _node('chart', {
        'chartType': 'donut',
        'data': [
          {'label': 'A', 'value': 30},
        ],
      });
      expect(_data(chartDataFrame(d0, d1, .5)).single['value'], 20);
    },
  );
  test(
    'line rows preserve numeric x identity across reorder and numeric string representations',
    () {
      final old = _line([
        {'x': '1', 'y': 10},
        {'x': 2, 'y': 30},
      ]);
      final target = _line([
        {'x': 2, 'y': 50},
        {'x': 1.0, 'y': 90},
        {'x': 3, 'y': 40},
      ]);
      expect(_data(chartDataFrame(old, target, .5)), [
        {'x': 2, 'y': 40.0},
        {'x': 1.0, 'y': 50.0},
        {'x': 3, 'y': 20.0},
      ]);
    },
  );
  test(
    'line rows match equivalent ISO timestamps and keep null target values',
    () {
      final old = _line([
        {'x': '2026-11-11T00:00:00Z', 'y': 10},
        {'x': 1, 'y': 30},
      ]);
      final target = _line([
        {'x': '2026-11-11T01:00:00+01:00', 'y': 50},
        {'x': 1, 'y': null},
      ]);
      expect(_data(chartDataFrame(old, target, .5)), [
        {'x': '2026-11-11T01:00:00+01:00', 'y': 30.0},
        {'x': 1, 'y': null},
      ]);
    },
  );
  test('plot resampling matches x on the old curve rather than row index', () {
    final old = _plot([10, 30]);
    final target = _plot([20, 40, 60]);
    expect(chartDataFrame(old, target, .5).prop(PlotChartProps.points), [
      15,
      30,
      45,
    ]);
  });
  test(
    'plot added domain samples enter from zero and shrinking samples preserve their x values',
    () {
      final old = _plot([10, 20], props: {'xMax': 1});
      final target = _plot([20, 40, 60]);
      expect(chartDataFrame(old, target, .5).prop(PlotChartProps.points), [
        15,
        30,
        30,
      ]);
      expect(
        chartDataFrame(
          _plot([10, 20, 30]),
          _plot([40, 60]),
          .5,
        ).prop(PlotChartProps.points),
        [25, 45],
      );
    },
  );
  test(
    'cleared datasets snap empty; datasets entering from empty grow from baseline',
    () {
      expect(chartDataChanges(_plot([10, 20]), _plot([])), isFalse);
      expect(
        chartDataChanges(
          _line([
            {'x': 0, 'y': 10},
          ]),
          _line([]),
        ),
        isFalse,
      );
      expect(
        chartDataChanges(
          _chart([
            {'label': 'A', 'votes': 10},
          ]),
          _chart([]),
        ),
        isFalse,
      );
      expect(
        chartDataFrame(
          _plot([]),
          _plot([10, 20]),
          .5,
        ).prop(PlotChartProps.points),
        [5, 10],
      );
    },
  );
  test(
    'style, domain, selection and non-series metadata do not start data transitions',
    () {
      final old = _chart([
        {'label': 'A', 'votes': 10, 'color': 'red'},
      ]);
      final target = _chart(
        [
          {'label': 'A', 'votes': 10, 'color': 'blue'},
        ],
        props: {'maxY': 100, 'selectedIndex': 0},
      );
      expect(chartDataChanges(old, target), isFalse);
      expect(
        chartDataChanges(
          _line([
            {'x': 0, 'y': 10},
          ]),
          _line(
            [
              {'x': 0, 'y': 10},
            ],
            props: {'lineColor': '#FFFF0000', 'xMax': 20},
          ),
        ),
        isFalse,
      );
      expect(
        chartDataChanges(
          _plot([10, 20]),
          _plot([10, 20], props: {'xMax': 50, 'selectedX': 2}),
        ),
        isFalse,
      );
    },
  );
  test(
    'marker y values glide by x identity while cosmetics and null curve-following positions are retained',
    () {
      final old = _plot(
        [10, 20],
        props: {
          'markers': [
            {'x': 1, 'y': 10, 'label': 'old'},
            {'x': 2, 'label': 'curve'},
          ],
        },
      );
      final target = _plot(
        [10, 20],
        props: {
          'markers': [
            {'x': 1, 'y': 30, 'label': 'new'},
            {'x': 2, 'label': 'curve'},
          ],
        },
      );
      expect(chartDataChanges(old, target), isTrue);
      final markers = chartDataFrame(
        old,
        target,
        .5,
      ).prop(PlotChartProps.markers);
      expect(markers.first.y, 20);
      expect(markers.first.label, 'new');
      expect(markers.last.y, isNull);
      final a = _line(
        [
          {'x': 0, 'y': 10},
        ],
        props: {
          'markers': [
            {'x': 1, 'y': 20},
          ],
        },
      );
      final b = _line(
        [
          {'x': 0, 'y': 10},
        ],
        props: {
          'markers': [
            {'x': 1, 'y': 40},
          ],
        },
      );
      expect(
        chartDataFrame(a, b, .5).prop(LineChartProps.markers).single['y'],
        30,
      );
    },
  );

  for (final type in ['chart', 'lineChart', 'plotChart']) {
    Node n(double value, {Map<String, Object?> extra = const {}}) =>
        switch (type) {
          'chart' => _chart([
            {'label': 'A', 'votes': value},
          ], props: extra),
          'lineChart' => _line([
            {'x': 0, 'y': value},
          ], props: extra),
          _ => _plot([value, value + 10], props: extra),
        };
    double value(Node node) => switch (type) {
      'chart' => (node.prop(ChartProps.data).single['votes'] as num).toDouble(),
      'lineChart' =>
        (node.prop(LineChartProps.data).single['y'] as num).toDouble(),
      _ => node.prop(PlotChartProps.points).first,
    };
    testWidgets(
      '$type renders data-change intermediate frames and retargets from displayed values',
      (tester) async {
        final (source, render) = await _show(tester, n(20));
        expect(value(_painted(render)), 20);
        expect(tester.binding.transientCallbackCount, 0);
        _set(source, n(80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(value(_painted(render)), 50);
        _set(source, n(0));
        await tester.pump();
        expect(value(_painted(render)), 50);
        await tester.pump(const Duration(milliseconds: 500));
        expect(value(_painted(render)), 25);
        await tester.pump(const Duration(milliseconds: 500));
        expect(value(_painted(render)), 0);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
    testWidgets(
      '$type style/domain-only updates do not start or restart a data timeline',
      (tester) async {
        final (source, render) = await _show(tester, n(20));
        _set(
          source,
          n(20, extra: {'maxY': 200, 'xMax': 50, 'lineColor': '#FFFF0000'}),
        );
        await tester.pump();
        expect(value(_painted(render)), 20);
        expect(tester.binding.transientCallbackCount, 0);
        _set(source, n(80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        _set(
          source,
          n(80, extra: {'maxY': 200, 'xMax': 50, 'lineColor': '#FFFF0000'}),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(value(_painted(render)), 50);
        await tester.pump(const Duration(milliseconds: 500));
        expect(value(_painted(render)), 80);
      },
    );
    for (final setting in [
      {'animate': false},
      {'animationDuration': 0},
    ]) {
      testWidgets('$type $setting disables data motion', (tester) async {
        final (source, render) = await _show(tester, n(20, extra: setting));
        _set(source, n(80, extra: setting));
        await tester.pump();
        expect(value(_painted(render)), 80);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  }
  testWidgets(
    'category reorder during a running count retargets the matching painted categories',
    (tester) async {
      final (source, render) = await _show(
        tester,
        _chart([
          {'label': 'A', 'votes': 0},
          {'label': 'B', 'votes': 20},
        ]),
      );
      _set(
        source,
        _chart([
          {'label': 'A', 'votes': 100},
          {'label': 'B', 'votes': 60},
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      _set(
        source,
        _chart([
          {'label': 'B', 'votes': 0},
          {'label': 'A', 'votes': 70},
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_data(_painted(render)), [
        {'label': 'B', 'votes': 20.0},
        {'label': 'A', 'votes': 60.0},
      ]);
    },
  );
  testWidgets(
    'clearing an actively changing dataset stops its ticker immediately',
    (tester) async {
      final (source, render) = await _show(
        tester,
        _line([
          {'x': 0, 'y': 10},
        ]),
      );
      _set(
        source,
        _line([
          {'x': 0, 'y': 90},
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.binding.transientCallbackCount, 1);
      _set(source, _line([]));
      await tester.pump();
      expect(_data(_painted(render)), isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
  testWidgets(
    'changing chart model snaps its new data without keeping an obsolete timeline',
    (tester) async {
      final (source, render) = await _show(
        tester,
        _chart([
          {'label': 'A', 'votes': 10},
        ]),
      );
      _set(
        source,
        _chart([
          {'label': 'A', 'votes': 90},
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      _set(
        source,
        _chart(
          [
            {'label': 'A', 'votes': 90},
          ],
          props: {'chartType': 'line'},
        ),
      );
      await tester.pump();
      expect(_data(_painted(render)).single['votes'], 90);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
