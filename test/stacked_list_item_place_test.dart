import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Lamplight's lamp dots in a room are a stacked list: each item placed by
/// bound fields of its item. An axis left unbound keeps the template's own
/// place, a literal number binding (`"y": "17.0"`) places it like a formula,
/// and a rotated item turns about its own centre where it was placed.
void main() {
  late CodelesslyContext codelesslyContext;

  Future<void> pump(WidgetTester tester, ListViewNode list, BaseNode item) async {
    final registry = NodeRegistry()..setNodes({list.id: list, item.id: item});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    codelesslyContext = CodelesslyContext.empty()
      ..variables['spots'] = Observable(
        VariableData(
          id: 'spots',
          name: 'spots',
          type: VariableType.list,
          value: [
            {'x': 10},
            {'x': 80},
          ],
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 120,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  list,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  ListViewNode room() => ListViewNode(
    id: 'room',
    name: 'Room lamps',
    basicBoxLocal: NodeBox(0, 0, 300, 120),
    padding: const EdgeInsetsModel.all(4),
    properties: ListViewProperties(layout: ListLayout.stack),
    children: ['dot'],
    variables: {'data': r'${spots}'},
  )..parentID = kRootNode;

  RectangleNode dot({
    required Map<String, String> variables,
    double y = 17,
    double rotation = 0,
  }) =>
      RectangleNode(
          id: 'dot',
          name: 'Lamp dot',
          basicBoxLocal: NodeBox(0, y, 20, 20),
          rotationDegrees: rotation.round(),
          fills: [PaintModel.solid(id: 'f', color: ColorRGBA.black)],
        )
        ..variables = variables
        ..parentID = 'room';

  Rect dotRect(WidgetTester tester, int index) {
    final RenderBox box = tester.renderObject<RenderBox>(
      find.byWidgetPredicate(
        (w) => w is Positioned && '${w.key}'.contains('stacked item'),
      ).at(index),
    );
    return box.localToGlobal(Offset.zero) & box.size;
  }

  testWidgets('binding only x keeps the template y', (tester) async {
    final ListViewNode list = room();
    await pump(tester, list, dot(variables: {'x': r'${item.x}'}));
    // x from the item, inside the 4 px padding; y where the template sits
    // in the list (17, as the editor keeps it).
    expect(dotRect(tester, 0).topLeft, const Offset(14, 17));
    expect(dotRect(tester, 1).topLeft, const Offset(84, 17));
  });

  testWidgets('a literal number binding places the item', (tester) async {
    final ListViewNode list = room();
    await pump(
      tester,
      list,
      dot(variables: {'x': r'${item.x}', 'y': '30.0'}, y: 0),
    );
    expect(dotRect(tester, 0).topLeft, const Offset(14, 34));
    expect(dotRect(tester, 1).topLeft, const Offset(84, 34));
  });

  testWidgets('a rotated item turns about its centre where it is placed', (
    tester,
  ) async {
    final ListViewNode list = room();
    await pump(
      tester,
      list,
      dot(variables: {'x': r'${item.x}'}, rotation: 45),
    );
    // The 20 px dot's centre stays where the unturned dot's is.
    final RenderBox shape = tester.renderObject<RenderBox>(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is Positioned && '${w.key}'.contains('stacked item'),
            ).at(0),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final Offset centre = shape.localToGlobal(shape.size.center(Offset.zero));
    expect(centre, offsetMoreOrLessEquals(const Offset(24, 27), epsilon: 0.5));
    // Turned by 45°.
    final Offset a = shape.localToGlobal(Offset.zero);
    final Offset b = shape.localToGlobal(const Offset(1, 0));
    expect((b - a).direction * 180 / math.pi, closeTo(45, 0.5));
  });
}
