import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode glass(List<Effect> effects) => RectangleNode(
  id: 'glass',
  name: 'Glass',
  basicBoxLocal: NodeBox(0, 0, 200, 100),
  fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#FFFFFF'), opacity: 0.1)],
  cornerRadius: const CornerRadius.all(RadiusModel.circular(28)),
  effects: effects,
)..parentID = kRootNode;

Effect blur(EffectType type, double radius, {bool visible = true}) => Effect(
  id: '${type.name}$radius',
  type: type,
  radius: radius,
  visible: visible,
);

Future<void> pump(WidgetTester tester, RectangleNode node) async {
  final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
  final PassiveNodeTransformerManager manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Align(
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
    ),
  );
}

void main() {
  testWidgets('a background blur frosts what is behind, clipped to the corners', (tester) async {
    await pump(tester, glass([blur(EffectType.backgroundBlur, 24)]));
    final BackdropFilter filter = tester.widget(find.byType(BackdropFilter));
    expect(filter.filter.toString(), contains('24'));
    final ClipRRect clip = tester.widget(
      find.ancestor(of: find.byType(BackdropFilter), matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(28));
  });

  testWidgets('a layer blur blurs the node itself', (tester) async {
    await pump(tester, glass([blur(EffectType.layerBlur, 6)]));
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('hidden or zero blurs draw nothing', (tester) async {
    await pump(tester, glass([
      blur(EffectType.backgroundBlur, 24, visible: false),
      blur(EffectType.layerBlur, 0),
    ]));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
  });
}
