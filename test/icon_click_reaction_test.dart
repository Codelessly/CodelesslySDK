import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// An icon with a click reaction is a button, e.g. a settings gear: tapping
/// it runs its reactions like tapping a rectangle does.
void main() {
  testWidgets('tapping an icon runs its click reactions', (tester) async {
    final Observable<VariableData> toast = Observable(
      VariableData(id: 'toast', name: 'toast'),
    );
    final IconNode node = IconNode(
      id: 'gear',
      name: 'Settings',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.click),
          action: SetVariableAction(
            variable: VariableData(id: 'toast', name: 'toast'),
            newValue: 'Settings',
          ),
        ),
      ],
    )..parentID = kRootNode;
    // Not drawn, so the test loads no SVG over the network: an icon's box
    // takes the tap all the same.
    node.properties.icon = node.properties.icon.copyWith(show: false);
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['toast'] = toast;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Material(
            child: ActionChainHost(
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
    );
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(toast.value.value, 'Settings');
    // And it reads as a button to assistive technology.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.button == true,
      ),
      findsOneWidget,
    );
  });
}
