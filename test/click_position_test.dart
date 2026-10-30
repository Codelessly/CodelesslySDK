import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A click's result says where it landed, so one tappable track can tell
/// which time slot of a timeline was tapped.
void main() {
  testWidgets('a click result carries the tap position', (tester) async {
    final Observable<VariableData> last = Observable(
      VariableData(id: 'last', name: 'last'),
    );
    final RectangleNode node = RectangleNode(
      id: 'track',
      name: 'track',
      basicBoxLocal: NodeBox(0, 0, 280, 40),
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.click),
          action: SetVariableAction(
            variable: VariableData(id: 'last', name: 'last'),
            newValue: r'${result.x} ${result.y} ${result.globalX} ${= floor(result.x / 70)}',
          ),
        ),
      ],
    )..parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['last'] = last;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Material(
            child: ActionChainHost(
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
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
        ),
      ),
    );
    await tester.tapAt(const Offset(170, 10));
    await tester.pumpAndSettle();
    expect(last.value.value, '150.0 10.0 170.0 2');
  });
}
