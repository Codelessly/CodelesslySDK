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

LayoutDocument _doc(
  String type,
  Object value, {
  bool animate = true,
  int duration = 1000,
  String color = '#FF000000',
}) => LayoutDocument.fromJson({
  'roots': ['indicator'],
  'nodes': {
    'indicator': {
      'type': type,
      'layout': {'width': 240, 'height': 160},
      'props': {
        if (type == 'barChart') 'values': value else 'value': value,
        'animate': animate,
        'animationDuration': duration,
        if (type == 'barChart') 'max': 100,
        'color': color,
      },
    },
  },
});

Future<(DocumentSource, NodeTree, RenderIndicatorTransition)> _showGauge(
  WidgetTester tester,
  String type,
  Object value, {
  bool interactive = true,
  bool animate = true,
  int duration = 1000,
}) async {
  final source = DocumentSource(
    _doc(type, value, animate: animate, duration: duration),
  );
  final tree = NodeTree(
    source,
    environment: IslandEnvironment(interactive: interactive),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(
          tree: tree,
          rootId: 'indicator',
          interactive: interactive,
        ),
      ),
    ),
  );
  final render = _descendants(
    tree.boxOf('indicator')!,
  ).whereType<RenderIndicatorTransition>().single;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
  return (source, tree, render);
}

double _value(String type, RenderIndicatorTransition render) => switch (type) {
  'progressBar' => _painted(render).prop(ProgressBarProps.value),
  'radialGauge' => _painted(render).prop(RadialGaugeProps.value),
  'gaugeMeter' => _painted(render).prop(GaugeMeterProps.value),
  _ => throw StateError(type),
};

void main() {
  group('when a chart\'s data changes', () {
    test('each value follows its own category when the rows reorder', () {
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
      'a new category grows from zero and a removed one does not turn into another',
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
      'a missing value stays a gap instead of gliding from another value',
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
    test(
      'cleared data empties at once, and data arriving into an empty chart grows from the baseline',
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
        'a $type shows frames between the old and new data, and a further change continues from what is shown',
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
        'a $type does not animate when only its style or range changes',
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
        testWidgets('a $type with $setting does not animate', (tester) async {
          final (source, render) = await _show(tester, n(20, extra: setting));
          _set(source, n(80, extra: setting));
          await tester.pump();
          expect(value(_painted(render)), 80);
          expect(tester.binding.transientCallbackCount, 0);
        });
      }
    }
  });

  group('when a gauge\'s value changes', () {
    for (final type in ['progressBar', 'radialGauge', 'gaugeMeter']) {
      testWidgets('a $type glides to its new value over its duration', (
        tester,
      ) async {
        final (source, _, render) = await _showGauge(tester, type, 20);
        expect(_value(type, render), 20, reason: 'Initial values draw at rest.');
        expect(tester.binding.transientCallbackCount, 0);
        source.document = _doc(type, 80);
        await tester.pump();
        expect(_value(type, render), 20);
        await tester.pump(const Duration(milliseconds: 500));
        expect(_value(type, render), closeTo(50, .001));
        await tester.pump(const Duration(milliseconds: 500));
        expect(_value(type, render), 80);
        expect(tester.binding.transientCallbackCount, 0);
        expect(render.size, const Size(240, 160));
      });
    }

    testWidgets('a bound value that changes starts the glide', (tester) async {
      final vars = VariableScope([
        const Variable(
          id: 'count',
          name: 'count',
          type: VariableType.decimal,
          value: 10.0,
        ),
      ]);
      final doc = _doc('gaugeMeter', 0);
      final node = doc.nodes['indicator']!;
      final source = DocumentSource(
        doc.copyWith(
          nodes: {
            'indicator': node.copyWith(bind: {'props.value': r'${count}'}),
          },
        ),
      );
      final tree = NodeTree(source, binder: NodeBinder(scope: vars));
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'indicator', interactive: true),
        ),
      );
      final render = _descendants(
        tree.boxOf('indicator')!,
      ).whereType<RenderIndicatorTransition>().single;
      expect(_value('gaugeMeter', render), 10);
      vars.set('count', 90);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_value('gaugeMeter', render), 50);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    });

    for (final mode in ['design', 'disabled', 'zeroDuration']) {
      testWidgets('with $mode the value changes at once', (
        tester,
      ) async {
        final (source, _, render) = await _showGauge(
          tester,
          'radialGauge',
          10,
          interactive: mode != 'design',
          animate: mode != 'disabled',
          duration: mode == 'zeroDuration' ? 0 : 1000,
        );
        source.document = _doc(
          'radialGauge',
          90,
          animate: mode != 'disabled',
          duration: mode == 'zeroDuration' ? 0 : 1000,
        );
        await tester.pump();
        expect(_value('radialGauge', render), 90);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  });
}
