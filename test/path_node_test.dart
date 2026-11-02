import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The path primitive: a shape drawn from SVG path data, scaled from its
/// view box, trimmed to part of its length (a line drawing itself on).
void main() {
  double lengthOf(ui.Path path) =>
      path.computeMetrics().fold(0.0, (sum, m) => sum + m.length);

  test('parses SVG data and rejects bad data', () {
    expect(PathNodePainter.parse('M0 0 L100 0'), isNotNull);
    expect(PathNodePainter.parse(''), isNull);
    expect(PathNodePainter.parse('nonsense 12'), isNull);
  });

  test('trims by length across segments', () {
    final ui.Path path = PathNodePainter.parse('M0 0 L100 0 L100 100')!;
    expect(lengthOf(PathNodePainter.trim(path, 0, 1)), closeTo(200, 0.01));
    expect(lengthOf(PathNodePainter.trim(path, 0, 0.75)), closeTo(150, 0.01));
    expect(lengthOf(PathNodePainter.trim(path, 0.25, 0.5)), closeTo(50, 0.01));
    expect(lengthOf(PathNodePainter.trim(path, 0.6, 0.4)), 0);
  });

  test('dashes stay in place while trimming', () {
    final ui.Path path = PathNodePainter.parse('M0 0 L100 0')!;
    // 10 on, 10 off: half of the line is ink.
    expect(
      lengthOf(PathNodePainter.trim(path, 0, 1, [10, 10])),
      closeTo(50, 0.01),
    );
    // The first 35px hold the dashes at 0-10 and 20-30; 30-35 is a gap.
    expect(
      lengthOf(PathNodePainter.trim(path, 0, 0.35, [10, 10])),
      closeTo(20, 0.01),
    );
  });

  test('round-trips through JSON as a path node', () {
    final PathNode node = PathNode(
      id: 'trail',
      name: 'Trail',
      basicBoxLocal: NodeBox(0, 0, 320, 120),
      pathData: 'M0 60 C 80 0 160 120 320 60',
      viewBoxWidth: 320,
      viewBoxHeight: 120,
      trimEnd: 0.4,
    );
    final BaseNode copy = NodeJsonConverter.instance.fromJson(node.toJson())!;
    expect(copy, isA<PathNode>());
    expect((copy as PathNode).pathData, node.pathData);
    expect(copy.trimEnd, 0.4);
    expect(copy.strokeCap, StrokeCapEnum.round);
  });

  testWidgets('a bound trim draws part of the line and eases to new values', (
    tester,
  ) async {
    final PathNode node =
        PathNode(
            id: 'trail',
            name: 'Trail',
            basicBoxLocal: NodeBox(0, 0, 200, 100),
            pathData: 'M0 0 L100 0',
            viewBoxWidth: 100,
            viewBoxHeight: 50,
            strokes: [PaintModel.solid(id: 's', color: ColorRGB.black)],
          )
          ..parentID = kRootNode
          ..transitionMs = 400
          ..variables['trimEnd'] = r'${goal}';
    final Observable<VariableData> goal = Observable(
      VariableData(
        id: 'goal',
        name: 'goal',
        type: VariableType.decimal,
        value: 0.25,
      ),
    );
    final CodelesslyContext codelessly = CodelesslyContext.empty()
      ..variables['goal'] = goal;
    final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelessly,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    PathNodePainter painter() => tester
        .widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PathNodePainter,
          ),
        )
        .painter! as PathNodePainter;
    expect(painter().trimEnd, 0.25);
    expect(painter().viewBox, const Size(100, 50));

    goal.set(goal.value.copyWith(value: 0.75));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(painter().trimEnd, greaterThan(0.25));
    expect(painter().trimEnd, lessThan(0.75));
    await tester.pumpAndSettle();
    expect(painter().trimEnd, 0.75);
  });
}
