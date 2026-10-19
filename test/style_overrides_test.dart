import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('fill, opacity and size follow bound formulas', (tester) async {
    final RectangleNode node = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'cup',
        name: 'Cup layer',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        fills: [
          PaintModel.solid(id: 'fill', color: ColorRGB.fromHex('#EDE3D6')),
        ],
      ).toJson(),
      'variables': {
        'fill': r"${= qty > 1 ? '#C8643B' : '#EDE3D6'}",
        'height': r'${= qty * 20}',
        'opacity': r'${= qty > 2 ? 0.5 : 1}',
      },
    });
    node.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Observable<VariableData> qty = Observable(
      VariableData(
        id: 'qty',
        name: 'qty',
        type: VariableType.integer,
        value: 1,
      ),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['qty'] = qty;

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

    Color? color() => tester.allWidgets
        .map(
          (w) => switch (w) {
            final Ink ink => ink.decoration,
            final DecoratedBox box => box.decoration,
            _ => null,
          },
        )
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .nonNulls
        .firstOrNull;
    final Finder box = find.byWidgetPredicate(
      (w) => w is Container && w.decoration is BoxDecoration,
    );

    expect(tester.getSize(box).height, 20);
    expect(color(), const Color(0xFFEDE3D6));
    expect(find.byType(Opacity), findsNothing);

    qty.set(qty.value.copyWith(value: 3));
    await tester.pump();

    expect(tester.getSize(box).height, 60);
    expect(color(), const Color(0xFFC8643B));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
    // The node itself is unchanged.
    expect(node.basicBoxLocal.height, 40);
  });
}
