import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A click tells its actions which modifier keys were held, so a list row
/// can toggle on ⌘-click and select a range on ⇧-click.
void main() {
  testWidgets('a click reads meta, shift and alt from result', (tester) async {
    final List<Object?> results = [];
    final manager = PassiveNodeTransformerManager(
      (id) => throw StateError(id),
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final RectangleNode node = RectangleNode(
      id: 'row',
      name: 'Row',
      basicBoxLocal: NodeBox(0, 0, 100, 40),
      reactions: [
        Reaction(
          name: 'select',
          trigger: TriggerModel(type: TriggerType.click),
          action: CallFunctionAction(name: 'select'),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()
          ..functions = {
            'select': (context, reference, params) =>
                results.add(ActionChain.current?.result),
          },
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.wrapWithReaction(
                  context,
                  node,
                  const SizedBox(width: 100, height: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(results, [
      {'meta': false, 'shift': false, 'alt': false},
      {'meta': true, 'shift': true, 'alt': false},
    ]);
  });
}
