import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A property can be bound to data and set by conditions at once: the
/// conditions win when one matches, otherwise the binding gives the value.
void main() {
  testWidgets('a condition wins when it matches, else the binding', (
    tester,
  ) async {
    final RectangleNode node = RectangleNode(
      id: 'dot',
      name: 'Dot',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
      fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#000000'))],
    )..parentID = kRootNode;
    node.variables = {'opacity': r'${= level / 10}'};

    final Observable<VariableData> level = Observable(
      VariableData(
        id: 'level',
        name: 'level',
        type: VariableType.integer,
        value: 5,
      ),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['level'] = level
      ..conditions['c'] = ConditionGroup(
        id: 'c',
        ifCondition: Condition(
          id: 'if',
          mode: ConditionMode.ifMode,
          expression: Expression(
            leftPart: VariablePart(valueString: r'${level}'),
            operator: ConditionOperation.greaterThan,
            rightPart: RawValuePart('8'),
          ),
          actions: [
            SetValueAction(
              nodeID: 'dot',
              values: [DoubleValue(name: 'opacity', value: 1)],
            ),
          ],
        ),
      );

    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
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

    double opacity() =>
        tester.widgetList<Opacity>(find.byType(Opacity)).firstOrNull?.opacity ??
        1;

    // No branch matches: the binding gives 0.5.
    expect(opacity(), 0.5);

    level.set(level.value.copyWith(value: 9));
    await tester.pump();
    // The condition matches and wins over the binding's 0.9.
    expect(opacity(), 1);

    level.set(level.value.copyWith(value: 2));
    await tester.pump();
    expect(opacity(), closeTo(0.2, 1e-9));
  });
}
