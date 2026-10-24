import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('obscureText follows a bound variable', (tester) async {
    final TextFieldNode node =
        TextFieldNode(
            id: 'pin',
            name: 'PIN',
            basicBoxLocal: NodeBox(0, 0, 200, 48),
            properties: TextFieldProperties(obscureText: true, maxLines: 1),
          )
          ..parentID = kRootNode
          ..variables = {'obscureText': r'${= !pinVisible}'};
    final Observable<VariableData> pinVisible = Observable(
      VariableData(
        id: 'v',
        name: 'pinVisible',
        value: false,
        type: VariableType.boolean,
      ),
    );
    final CodelesslyContext ctx = CodelesslyContext.empty()
      ..variables['v'] = pinVisible;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: ctx,
        child: MaterialApp(
          home: Material(
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
    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;
    expect(obscured(), isTrue);
    pinVisible.set(
      VariableData(
        id: 'v',
        name: 'pinVisible',
        value: true,
        type: VariableType.boolean,
      ),
    );
    await tester.pump();
    expect(obscured(), isFalse);
  });
}
