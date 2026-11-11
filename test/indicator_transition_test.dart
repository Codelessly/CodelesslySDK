import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicator_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicators_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Iterable<RenderObject> _descendants(RenderObject object) sync* {
  yield object;
  final children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final child in children) {
    yield* _descendants(child);
  }
}

Future<(DocumentSource, NodeTree, RenderIndicatorTransition)> _show(
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

Node _painted(RenderIndicatorTransition render) =>
    (render.painter! as NodePainter).n;

double _value(String type, RenderIndicatorTransition render) => switch (type) {
  'progressBar' => _painted(render).prop(ProgressBarProps.value),
  'radialGauge' => _painted(render).prop(RadialGaugeProps.value),
  'gaugeMeter' => _painted(render).prop(GaugeMeterProps.value),
  _ => throw StateError(type),
};

void main() {
  for (final type in ['progressBar', 'radialGauge', 'gaugeMeter']) {
    testWidgets('$type glides on data changes, with its declared duration', (
      tester,
    ) async {
      final (source, _, render) = await _show(tester, type, 20);
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

  testWidgets('a new wave retargets from the currently painted value', (
    tester,
  ) async {
    final (source, _, render) = await _show(tester, 'gaugeMeter', 20);
    source.document = _doc('gaugeMeter', 80);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_value('gaugeMeter', render), 50);
    source.document = _doc('gaugeMeter', 0);
    await tester.pump();
    expect(_value('gaugeMeter', render), 50);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_value('gaugeMeter', render), 25);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_value('gaugeMeter', render), 0);
  });

  testWidgets(
    'bar chart animates values and new bars; null stubs remain null',
    (tester) async {
      final (source, _, render) = await _show(tester, 'barChart', [20, null]);
      source.document = _doc('barChart', [80, null, 40]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_painted(render).prop(BarChartProps.values), [50, null, 20]);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_painted(render).prop(BarChartProps.values), [80, null, 40]);
      source.document = _doc('barChart', [10]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_painted(render).prop(BarChartProps.values), [10]);
    },
  );

  testWidgets('style-only changes preserve an in-flight transition', (
    tester,
  ) async {
    final (source, _, render) = await _show(tester, 'progressBar', 0);
    source.document = _doc('progressBar', 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    source.document = _doc('progressBar', 100, color: '#FFFF0000');
    await tester.pump(const Duration(milliseconds: 250));
    expect(_value('progressBar', render), 50);
    expect(_painted(render).prop(ProgressBarProps.color).toJson(), '#FFFF0000');
  });

  testWidgets('bound feed values trigger data motion', (tester) async {
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

  testWidgets('rewiring an opacity layer does not finish an in-flight count', (
    tester,
  ) async {
    final (source, _, render) = await _show(tester, 'gaugeMeter', 0);
    source.document = _doc('gaugeMeter', 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final doc = _doc('gaugeMeter', 100);
    source.document = doc.copyWith(
      nodes: {'indicator': doc.nodes['indicator']!.copyWith(opacity: .5)},
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(_value('gaugeMeter', render), 50);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_value('gaugeMeter', render), 100);
  });

  for (final mode in ['design', 'disabled', 'zeroDuration']) {
    testWidgets('$mode snaps without scheduling indicator frames', (
      tester,
    ) async {
      final (source, _, render) = await _show(
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

  testWidgets('detaching an animating indicator cancels its ticker', (
    tester,
  ) async {
    final (source, _, render) = await _show(tester, 'gaugeMeter', 10);
    source.document = _doc('gaugeMeter', 90);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(render.attached, isFalse);
    expect(tester.takeException(), isNull);
  });
}
