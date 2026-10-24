import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // A dialog is a bottom sheet on phones, squared at the bottom, and a card
  // rounded on every corner above.
  testWidgets('corner radius follows a bound formula', (tester) async {
    final RectangleNode node = RectangleNode.fromJson({
      ...RectangleNode(
        id: 'dialog',
        name: 'Dialog',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
      ).toJson(),
      'variables': {'cornerRadius': r'${= sheet ? [6, 6, 0, 0] : 6}'},
    });
    node.parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final Observable<VariableData> sheet = Observable(
      VariableData(
        id: 'sheet',
        name: 'sheet',
        type: VariableType.boolean,
        value: true,
      ),
    );
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['sheet'] = sheet;

    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    CornerRadius radius() => (manager.applyStyleOverrides(
      context,
      node,
    ) as CornerMixin).cornerRadius;

    expect(radius().tl, const RadiusModel.circular(6));
    expect(radius().tr, const RadiusModel.circular(6));
    expect(radius().br, RadiusModel.zero);
    expect(radius().bl, RadiusModel.zero);

    sheet.set(sheet.value.copyWith(value: false));
    expect(radius(), const CornerRadius.all(RadiusModel.circular(6)));
  });
}
