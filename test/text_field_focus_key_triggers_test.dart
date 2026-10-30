import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction on(TriggerType type, String name, {String? key}) => Reaction(
  name: name,
  trigger: TriggerModel(type: type, key: key),
  action: CallFunctionAction(name: 'log', params: {'what': name, 'key': r'${result.key}'}),
);

void main() {
  testWidgets('a text field fires focus gained/lost and key down for its keys', (tester) async {
    final List<String> log = [];
    final node = TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(),
      reactions: [
        on(TriggerType.focusGained, 'gained'),
        on(TriggerType.focusLost, 'lost'),
        on(TriggerType.keyDown, 'down', key: 'Arrow Down'),
        on(TriggerType.keyDown, 'escape', key: 'Escape'),
      ],
    );
    final codelesslyContext = CodelesslyContext.empty()
      ..functions = {
        'log': (context, reference, params) => log.add(
          params['what'] == 'down' || params['what'] == 'escape'
              ? '${params['what']}:${params['key']}'
              : params['what'],
        ),
      };
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Scaffold(
            body: Column(children: [
              Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
              const TextField(key: ValueKey('other')),
            ]),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // no reaction
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('other')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(log, ['gained', 'down:ArrowDown', 'escape:Escape', 'lost']);
  });

  test('the new triggers are text field triggers with labels', () {
    final node = TextFieldNode(
      id: 'f',
      name: 'F',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
      properties: TextFieldProperties(),
    );
    expect(node.triggerTypes, containsAll([TriggerType.focusGained, TriggerType.focusLost, TriggerType.keyDown]));
    expect(TriggerType.focusGained.prettify, 'Focus Gained');
  });

  test('key labels match however the trigger spells them', () {
    expect(normalizeKeyLabel('Arrow Down'), normalizeKeyLabel(keyTriggerLabel(LogicalKeyboardKey.arrowDown)));
  });
}
