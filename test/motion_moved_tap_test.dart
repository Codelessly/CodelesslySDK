import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The Orrery's planets: items of a stacked list that rest on the Sun and
/// are drawn on their orbits by a motion path. A tap where a planet is drawn
/// runs its click reaction.
void main() {
  testWidgets('a stacked item moved by its motion path is tapped where it is drawn', (tester) async {
    final List<String> taps = [];
    final RectangleNode item = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'planet',
        name: 'Planet',
        basicBoxLocal: NodeBox(0, 0, 20, 20),
        fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#C1553A'))],
        reactions: [
          Reaction(action: CallFunctionAction(name: 'open'), trigger: TriggerModel(type: TriggerType.click)),
        ],
      ).toJson(),
      'variables': {'x': r'${= 190}', 'y': r'${= 90}'},
      'motion': {'path': 'M0 0 L150 0'},
      // A hover state, as the Orrery's planets have (it wraps the node in a
      // mouse region outside its motion).
      'interactionStates': {'hovered': {'planet': {'drawScale': 1.15}}},
      // At the end of the path: 150 px right of where it rests.
    })..motion = const MotionModel(path: 'M0 0 L150 0', pathProgress: 1);
    final ListViewNode list = ListViewNode(
      id: 'planets',
      name: 'Planets',
      basicBoxLocal: NodeBox(0, 0, 400, 200),
      properties: ListViewProperties(layout: ListLayout.stack),
      children: ['planet'],
      variables: {'data': r'${bodies}'},
    );
    item.parentID = list.id;
    list.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({list.id: list, item.id: item});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..functions = {'open': (context, reference, params) => taps.add('open')}
      ..variables['bodies'] = Observable(
        VariableData(id: 'bodies', name: 'bodies', type: VariableType.list, value: [{'id': 'jupiter'}]),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 200,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(list, context,
                    settings: const WidgetBuildSettings(debugLabel: 'test')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Drawn at (190 + 150, 90) .. +20.
    await tester.tapAt(const Offset(350, 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, ['open'], reason: 'tap where the planet is drawn');
  });
}
