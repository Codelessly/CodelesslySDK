import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final manager = PassiveNodeTransformerManager(
    (id) => throw StateError(id),
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );

  /// The angle (radians) [node] is rotated by, or null when it isn't.
  Future<double?> angleOf(WidgetTester tester, RectangleNode node) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => manager.applyWidgetRotation(
              context,
              node,
              const SizedBox(key: Key('hand'), width: 2, height: 40),
            ),
          ),
        ),
      ),
    );
    final transforms = tester.widgetList<Transform>(
      find.ancestor(
        of: find.byKey(const Key('hand')),
        matching: find.byType(Transform),
      ),
    );
    if (transforms.isEmpty) return null;
    final Matrix4 m = transforms.first.transform;
    return atan2(m.entry(1, 0), m.entry(0, 0));
  }

  RectangleNode hand({int rotation = 0, Map<String, String> variables = const {}}) =>
      RectangleNode(
        id: 'hand',
        name: 'Hand',
        basicBoxLocal: NodeBox(0, 0, 2, 40),
        rotationDegrees: rotation,
      )..variables = variables;

  testWidgets('a bound rotation turns the node by the formula', (tester) async {
    final double? angle = await angleOf(
      tester,
      hand(variables: {'rotationDegrees': r'${= 1230 / 4}'}),
    );
    expect(angle, closeTo(307.5 * pi / 180 - 2 * pi, 1e-9));
  });

  testWidgets('without a binding the node keeps its own rotation', (
    tester,
  ) async {
    expect(await angleOf(tester, hand(rotation: 90)), closeTo(pi / 2, 1e-9));
    expect(await angleOf(tester, hand()), isNull);
  });
}
