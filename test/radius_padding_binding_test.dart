import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('corner radius and padding follow bound formulas', (
    tester,
  ) async {
    final RectangleNode node = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'sheet',
        name: 'Sheet',
        basicBoxLocal: NodeBox(0, 0, 200, 100),
        fills: [
          PaintModel.solid(id: 'fill', color: ColorRGB.fromHex('#FFFFFF')),
        ],
      ).toJson(),
      'variables': {
        'cornerRadius': r'${= isMobile ? [18, 18, 0, 0] : 12}',
        'padding': r'${= isMobile ? [16, 8] : 24}',
      },
    });
    node.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Observable<VariableData> isMobile = Observable(
      VariableData(
        id: 'isMobile',
        name: 'isMobile',
        type: VariableType.boolean,
        value: true,
      ),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['isMobile'] = isMobile;

    late BuildContext buildContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) {
                buildContext = context;
                return manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                );
              },
            ),
          ),
        ),
      ),
    );

    BorderRadiusGeometry? radius() => tester.allWidgets
        .map(
          (w) => switch (w) {
            final Ink ink => ink.decoration,
            final DecoratedBox box => box.decoration,
            final Container c => c.decoration,
            _ => null,
          },
        )
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.borderRadius)
        .nonNulls
        .firstOrNull;

    expect(
      radius(),
      const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
      ),
    );
    BaseNode styled = manager.applyStyleOverrides(buildContext, node);
    expect(
      styled.padding,
      EdgeInsetsModel.symmetric(horizontal: 16, vertical: 8),
    );
    expect(styled.innerBoxLocal.edgeLeft, 16);

    isMobile.set(isMobile.value.copyWith(value: false));
    await tester.pump();

    expect(radius(), BorderRadius.circular(12));
    styled = manager.applyStyleOverrides(buildContext, node);
    expect(styled.padding, EdgeInsetsModel.all(24));
    expect(
      (styled as CornerMixin).cornerRadius,
      CornerRadius.all(RadiusModel.circular(12)),
    );
    // The node itself is unchanged.
    expect(node.cornerRadius, CornerRadius.zero);
    expect(node.padding, EdgeInsetsModel.zero);
  });

  testWidgets('an unparseable binding keeps the node\'s own values', (
    tester,
  ) async {
    final RectangleNode node = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'box',
        name: 'Box',
        basicBoxLocal: NodeBox(0, 0, 50, 50),
        cornerRadius: CornerRadius.all(RadiusModel.circular(6)),
        padding: EdgeInsetsModel.all(4),
      ).toJson(),
      'variables': {'cornerRadius': r'${= "round"}', 'padding': r'${= "x"}'},
    });
    node.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    late BuildContext buildContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(manager.applyStyleOverrides(buildContext, node), same(node));
  });
}
