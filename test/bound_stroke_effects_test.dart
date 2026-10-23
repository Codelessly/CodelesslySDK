import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A selectable chip: a thicker border and a shadow only while selected.
void main() {
  Future<void> pump(
    WidgetTester tester,
    BaseNode node,
    Observable<VariableData> selected,
  ) async {
    node.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()..variables['selected'] = selected,
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
    expect(tester.takeException(), isNull);
  }

  Observable<VariableData> selectedVar() => Observable(
    VariableData(
      id: 'selected',
      name: 'selected',
      type: VariableType.boolean,
      value: false,
    ),
  );

  List<BoxShadow> shadows(WidgetTester tester) => [
    for (final w in tester.allWidgets)
      ...?switch (w) {
        DecoratedBox(decoration: final BoxDecoration d) => d.boxShadow,
        _ => null,
      },
  ];

  RectangleNode chip(Map<String, String> variables) => RectangleNode.fromJson({
    ...RectangleNode(
      id: 'chip',
      name: 'Chip',
      basicBoxLocal: NodeBox(0, 0, 80, 32),
      fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#FFFFFF'))],
      strokes: [PaintModel.solid(id: 's', color: ColorRGB.fromHex('#FF6A13'))],
      strokeWeight: 1,
      effects: [
        Effect.dropShadow(
          id: 'shadow',
          radius: 2,
          color: const ColorRGBA(r: 0.06, g: 0.13, b: 0.21, a: 0.1),
          offset: Vec(0, 1),
          spread: 0,
        ),
      ],
    ).toJson(),
    'variables': variables,
  });

  testWidgets('strokeWeight and effectsVisible follow a variable', (
    tester,
  ) async {
    final selected = selectedVar();
    final RectangleNode node = chip({
      'strokeWeight': r'${= selected ? 1.5 : 1}',
      'effectsVisible': r'${selected}',
    });
    await pump(tester, node, selected);
    final manager = PassiveNodeTransformerManager(
      (id) => node,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    GeometryMixin styled() =>
        manager.applyStyleOverrides(
              tester.element(find.byType(Align).first),
              node,
            )
            as GeometryMixin;

    expect(shadows(tester), isEmpty);
    expect(styled().strokeWeight, 1);

    selected.set(selected.value.copyWith(value: true));
    await tester.pump();
    expect(styled().strokeWeight, 1.5);
    expect((styled() as BlendMixin).effects.single.visible, isTrue);
    expect(shadows(tester), hasLength(1));
    expect(shadows(tester).single.blurRadius, 2);

    selected.set(selected.value.copyWith(value: false));
    await tester.pump();
    expect(shadows(tester), isEmpty);
  });

  testWidgets('effects can be replaced by a bound list', (tester) async {
    final selected = selectedVar();
    final RectangleNode node = chip({
      'effects':
          r'''${= selected ? '[{"type": "dropShadow", "radius": 6, '''
          r'''"color": {"r": 0, "g": 0, "b": 0, "a": 0.2}, '''
          r'''"offset": {"x": 0, "y": 2}, "spread": 0}]' : '[]'}''',
    });
    await pump(tester, node, selected);
    expect(shadows(tester), isEmpty);

    selected.set(selected.value.copyWith(value: true));
    await tester.pump();
    expect(shadows(tester).single.blurRadius, 6);
  });
}
