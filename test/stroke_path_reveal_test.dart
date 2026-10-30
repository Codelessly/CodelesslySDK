import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('path points read lists and maps, fractions scale with the box', () {
    expect(readPathPoints([
      [0.5, 70],
      {'x': 1, 'y': '248'},
      'junk',
    ]), [
      [0.5, 70.0],
      [1.0, 248.0],
    ]);
    final painter = StrokePathPainter(
      const StrokePath(curve: PathCurve.vertical),
      const [
        [0.5, 0],
        [1, 100],
      ],
    );
    final Rect bounds = painter.pathFor(const Size(200, 100)).getBounds();
    expect(bounds.left, closeTo(100, 0.01));
    expect(bounds.right, closeTo(200, 0.01));
    expect(bounds.bottom, closeTo(100, 0.01));
  });

  testWidgets('a bound stroke path paints behind the node', (tester) async {
    final node = RectangleNode(id: 'trail', name: 'Trail', basicBoxLocal: NodeBox(0, 0, 200, 300))
      ..parentID = kRootNode
      ..strokePath = const StrokePath(dash: [12, 18], width: 10, curve: PathCurve.vertical)
      ..variables['strokePath.points'] = r'${= map(range(3), i => object("x", i % 2 == 0 ? 0.3 : 0.7, "y", 20 + i * 100))}';
    await _pump(tester, node);
    final CustomPaint paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere((p) => p.painter is StrokePathPainter);
    expect((paint.painter! as StrokePathPainter).points, [
      [0.3, 20.0],
      [0.7, 120.0],
      [0.3, 220.0],
    ]);
  });

  testWidgets('reveal scrolls the node into view when it appears', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(controller: controller, child: Column(children: [
        const SizedBox(height: 2000),
        RevealBox(
          reveal: const RevealModel(alignment: 0.5, durationMs: 0),
          when: true,
          child: const SizedBox(height: 100, width: 100),
        ),
        const SizedBox(height: 2000),
      ])),
    ));
    await tester.pumpAndSettle();
    // Centered in a 600 high view: the box (2000..2100) sits at 250..350.
    expect(controller.offset, closeTo(2000 - 250, 1));
  });

  testWidgets('a text field capitalizes words', (tester) async {
    final node = TextFieldNode(
      id: 'name',
      name: 'Name',
      basicBoxLocal: NodeBox(0, 0, 200, 48),
      properties: TextFieldProperties(textCapitalization: TextCapitalizationC.words),
    )..parentID = kRootNode;
    await _pump(tester, node);
    expect(tester.widget<TextField>(find.byType(TextField)).textCapitalization, TextCapitalization.words);
  });

  test('motion.delayMs is bindable', () {
    final node = RectangleNode(id: 'chip', name: 'Chip', basicBoxLocal: NodeBox(0, 0, 10, 10))
      ..motion = const MotionModel(enter: true, durationMs: 700)
      ..variables['motion.delayMs'] = r'${= 1500 + 2 * 120}';
    final MotionModel? motion = WidgetNodeTransformerManager.resolveMotion(
      node,
      scopedValues: ScopedValues.empty(),
    );
    expect(motion!.delayMs, 1740);
  });
}

Future<void> _pump(WidgetTester tester, BaseNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(registry.getNodeByID, (c, b, p, l, cv) => const SizedBox());
  await tester.pumpWidget(ChangeNotifierProvider<CodelesslyContext>.value(
    value: CodelesslyContext.empty(),
    child: MaterialApp(
      home: Material(child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 300,
          child: Builder(builder: (context) => manager.buildWidgetFromNode(node, context, settings: const WidgetBuildSettings(debugLabel: 't'))),
        ),
      )),
    ),
  ));
}
