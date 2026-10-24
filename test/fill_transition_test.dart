import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  RectangleNode row(String hex, {int transitionMs = 0}) =>
      RectangleNode(
          id: 'row',
          name: 'Row',
          basicBoxLocal: NodeBox(0, 0, 200, 40),
          fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex(hex))],
        )
        ..parentID = kRootNode
        ..transitionMs = transitionMs;

  Future<void> show(WidgetTester tester, RectangleNode node) {
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    return tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Center(
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
  }

  /// The solid fill's color, painted as an [Ink] or a [DecoratedBox].
  Color fillColor(WidgetTester tester) => [
    for (final Ink ink in tester.widgetList<Ink>(find.byType(Ink)))
      ink.decoration,
    for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    ))
      box.decoration,
  ].whereType<BoxDecoration>().firstWhere((d) => d.color != null).color!;

  testWidgets('with a transition a fill eases to its new color', (
    tester,
  ) async {
    await show(tester, row('#FFFFFF', transitionMs: 200));
    expect(fillColor(tester), const Color(0xFFFFFFFF));
    await show(tester, row('#000000', transitionMs: 200));
    await tester.pump(const Duration(milliseconds: 60));
    final Color mid = fillColor(tester);
    expect(mid, isNot(const Color(0xFFFFFFFF)));
    expect(mid, isNot(const Color(0xFF000000)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fillColor(tester), const Color(0xFF000000));
  });

  testWidgets('without one the fill changes at once', (tester) async {
    await show(tester, row('#FFFFFF'));
    await show(tester, row('#000000'));
    expect(fillColor(tester), const Color(0xFF000000));
  });
}
