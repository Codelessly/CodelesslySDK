import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A node hidden in the design keeps its space at runtime, like on the
/// canvas, but it must not take taps: a hidden full-screen scrim over a page
/// would otherwise swallow every tap meant for the buttons under it.
void main() {
  Future<List<String>> tapThrough(
    WidgetTester tester, {
    required bool visible,
  }) async {
    final List<String> taps = [];
    final manager = PassiveNodeTransformerManager(
      (id) => throw StateError(id),
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final RectangleNode scrim = RectangleNode(
      id: 'scrim',
      name: 'Scrim',
      basicBoxLocal: NodeBox(0, 0, 200, 200),
      visible: visible,
      reactions: [
        Reaction(
          name: 'close',
          trigger: TriggerModel(type: TriggerType.click),
          action: CallFunctionAction(name: 'close'),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()
          ..functions = {
            'close': (context, reference, params) => taps.add('scrim'),
          },
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps.add('button'),
                      ),
                    ),
                    Positioned.fill(
                      child: Builder(
                        builder: (context) => manager.applyWidgetVisibility(
                          context,
                          scrim,
                          manager.wrapWithReaction(
                            context,
                            scrim,
                            const SizedBox(width: 200, height: 200),
                          ),
                          maintainState: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    return taps;
  }

  testWidgets('a hidden node lets taps through to what is under it', (
    tester,
  ) async {
    expect(await tapThrough(tester, visible: false), ['button']);
  });

  testWidgets('a shown node still takes its taps', (tester) async {
    expect(await tapThrough(tester, visible: true), ['scrim']);
  });

  testWidgets('a hidden node keeps its space', (tester) async {
    final manager = PassiveNodeTransformerManager(
      (id) => throw StateError(id),
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final RectangleNode node = RectangleNode(
      id: 'hidden',
      name: 'Hidden',
      basicBoxLocal: NodeBox(0, 0, 80, 30),
      visible: false,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.applyWidgetVisibility(
                context,
                node,
                const SizedBox(key: ValueKey('box'), width: 80, height: 30),
                maintainState: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Visibility)), const Size(80, 30));
  });
}
