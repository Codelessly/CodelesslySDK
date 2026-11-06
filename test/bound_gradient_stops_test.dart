import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Gradient stops bound to a variable or formula
/// (`fill-<paintId>-stop-<index>`, `fill-<paintId>-stop-position-<index>`):
/// a hive icon whose gradient follows the hive's status color, on any node
/// with fills.

PaintModel gradient(String id) => PaintModel.fromJson({
  'id': id,
  'type': 'gradientLinear',
  'gradientTransform': [1, 0, 0, 1, 0, 0],
  'gradientStops': [
    {
      'position': 0,
      'color': {'r': 0, 'g': 0, 'b': 0, 'a': 1},
    },
    {
      'position': 0.5,
      'color': {'r': 0, 'g': 0, 'b': 0, 'a': 1},
    },
    {
      'position': 1,
      'color': {'r': 0, 'g': 0, 'b': 0, 'a': 0.4},
    },
  ],
});

final PaintModel solid = PaintModel.solid(
  id: 'solid',
  color: const ColorRGB(r: 1, g: 1, b: 1),
);

/// The bindings of a hive icon: a lightened status color, the status color,
/// and the status color again at the stop's own 40%.
const Map<String, String> hiveBindings = {
  'fill-hive-stop-0': r"${= mix(hive.statusColor, '#FFFFFF', 0.5)}",
  'fill-hive-stop-1': r'${hive.statusColor}',
  'fill-hive-stop-2': r'${hive.statusColor}',
  'fill-hive-stop-position-1': r'${= hive.split}',
};

CodelesslyContext hiveContext() => CodelesslyContext.empty()
  ..variables['hive'] = Observable(
    VariableData(
      id: 'hive',
      name: 'hive',
      value: {'statusColor': '#E0A030', 'split': 0.55},
      type: VariableType.map,
    ),
  );

PassiveNodeTransformerManager managerFor(BaseNode node) {
  node.parentID = kRootNode;
  final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
  return PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
}

Future<BuildContext> pumpWith(
  WidgetTester tester,
  CodelesslyContext codelesslyContext, [
  Widget? child,
]) async {
  late BuildContext context;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (c) {
                context = c;
                return child ?? const SizedBox();
              },
            ),
          ),
        ),
      ),
    ),
  );
  return context;
}

void expectHiveGradient(PaintModel paint, {String? reason}) {
  final List<ColorStop> stops = paint.gradientStops!;
  int rgb(ColorStop stop) =>
      stop.color.toFlutterColor().toARGB32() & 0xFFFFFF;
  expect(rgb(stops[0]), 0xF0D098, reason: reason);
  expect(rgb(stops[1]), 0xE0A030, reason: reason);
  expect(stops[1].position, 0.55, reason: reason);
  expect(rgb(stops[2]), 0xE0A030, reason: reason);
  expect(stops[2].color.a, closeTo(0.4, 1e-3), reason: '#RRGGBB keeps alpha');
}

void main() {
  group('StyleBindings', () {
    Map<String, dynamic> patchOf(BaseNode node, CodelesslyContext data) {
      final Map<String, dynamic> patch = {};
      StyleBindings.addTo(
        patch,
        node,
        // As the design canvas evaluates bindings: variables at their
        // preview values.
        scopedValues: ScopedValues.preview(
          variables: {
            for (final entry in data.variables.entries)
              entry.key: entry.value.value,
          },
        ),
      );
      return patch;
    }

    test('binds the stops of a fill named by its paint id', () {
      // The gradient is the second fill: index keys can't reach it.
      final RectangleNode node = RectangleNode(
        id: 'icon',
        name: 'Icon',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        fills: [solid, gradient('hive')],
      )..variables.addAll(hiveBindings);
      final List fills = patchOf(node, hiveContext())['fills'] as List;
      expect(PaintModel.fromJson(fills[0]), solid);
      expectHiveGradient(PaintModel.fromJson(fills[1]));
    });

    test('a binding that gives no color keeps the stop', () {
      final RectangleNode node = RectangleNode(
        id: 'icon',
        name: 'Icon',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        fills: [gradient('hive')],
      )..variables['fill-hive-stop-0'] = r'${missing.color}';
      expect(patchOf(node, hiveContext()), isEmpty);
    });

    test('the first fill still takes index keys', () {
      final RectangleNode node = RectangleNode(
        id: 'icon',
        name: 'Icon',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        fills: [gradient('hive')],
      )..variables.addAll({
          StyleBindings.fillStop(1): r"${= '#112233'}",
          StyleBindings.fillStopPosition(1): r'${= 0.3}',
        });
      final PaintModel paint = PaintModel.fromJson(
        (patchOf(node, hiveContext())['fills'] as List).first,
      );
      expect(
        paint.gradientStops![1].color.toFlutterColor().toARGB32(),
        0xFF112233,
      );
      expect(paint.gradientStops![1].position, 0.3);
    });
  });

  group('at runtime', () {
    final Map<String, BaseNode Function()> nodes = {
      'rectangle': () => RectangleNode(
        id: 'n',
        name: 'Rect',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        fills: [gradient('hive')],
      ),
      'frame': () => FrameNode(
        id: 'n',
        name: 'Frame',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        children: const [],
        fills: [gradient('hive')],
      ),
      'row': () => RowNode(
        id: 'n',
        name: 'Row',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        children: const [],
        fills: [gradient('hive')],
      ),
      'column': () => ColumnNode(
        id: 'n',
        name: 'Column',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        children: const [],
        fills: [gradient('hive')],
      ),
    };

    for (final MapEntry(key: String type, value: BaseNode Function() make)
        in nodes.entries) {
      testWidgets('a $type paints its bound stops', (tester) async {
        final BaseNode node = make()..variables.addAll(hiveBindings);
        final BuildContext context = await pumpWith(tester, hiveContext());
        final BaseNode styled = managerFor(
          node,
        ).applyStyleOverrides(context, node);
        expectHiveGradient((styled as GeometryMixin).fills.single, reason: type);
      });
    }

    testWidgets('a rectangle draws the resolved gradient', (tester) async {
      final RectangleNode node = RectangleNode(
        id: 'n',
        name: 'Rect',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        fills: [gradient('hive')],
      )..variables.addAll(hiveBindings);
      final PassiveNodeTransformerManager manager = managerFor(node);
      await pumpWith(
        tester,
        hiveContext(),
        Builder(
          builder: (context) => manager.buildWidgetFromNode(
            node,
            context,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
          ),
        ),
      );
      final List<Gradient> gradients = [
        for (final Element e in find.byType(DecoratedBox).evaluate())
          if ((e.widget as DecoratedBox).decoration case BoxDecoration(
            :final Gradient gradient,
          ))
            gradient,
        for (final Element e in find.byType(Container).evaluate())
          if ((e.widget as Container).decoration case BoxDecoration(
            :final Gradient gradient,
          ))
            gradient,
      ];
      expect(gradients, isNotEmpty);
      expect(
        gradients.first.colors.map((c) => c.toARGB32() & 0xFFFFFF),
        [0xF0D098, 0xE0A030, 0xE0A030],
      );
      expect(gradients.first.stops, [0, 0.55, 1]);
    });
  });
}
