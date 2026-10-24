import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // A trip card tilts while it's dragged: rotation bound to a formula.
  testWidgets('rotation follows a bound formula', (tester) async {
    final RectangleNode node = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'card',
        name: 'Card',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
      ).toJson(),
      'variables': {'rotation': r'${= dragging ? -2 : 0}'},
    });
    node.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Observable<VariableData> dragging = Observable(
      VariableData(
        id: 'dragging',
        name: 'dragging',
        type: VariableType.boolean,
        value: false,
      ),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['dragging'] = dragging;

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

    double? angle() {
      for (final Transform t in tester.widgetList<Transform>(
        find.byType(Transform),
      )) {
        final double a = math.atan2(
          t.transform.entry(1, 0),
          t.transform.entry(0, 0),
        );
        if (a.abs() > 1e-9) return a;
      }
      return null;
    }

    expect(angle(), isNull);

    dragging.set(dragging.value.copyWith(value: true));
    await tester.pump();
    expect(angle(), closeTo(-2 * math.pi / 180, 1e-9));

    dragging.set(dragging.value.copyWith(value: false));
    await tester.pump();
    expect(angle(), isNull);
  });

  test('rotation resolves from a formula bound to the node', () {
    final RectangleNode node = RectangleNode(
      id: 'card',
      name: 'Card',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
    )..variables = {'rotation': r'${= tilt ? -2 : 0}'};
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'tilt': VariableData(
          id: 'tilt',
          name: 'tilt',
          type: VariableType.boolean,
          value: true,
        ),
      },
    );
    expect(
      PropertyValueDelegate.getPropertyValue<num>(
        node,
        'rotation',
        scopedValues: scope,
      ),
      -2,
    );
  });
}
