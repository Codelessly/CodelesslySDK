import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'feedback_actions_test.dart' show brandRegular, text;

void main() {
  testWidgets('probe', (tester) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RectangleNode pin = RectangleNode(
      id: 'pin',
      name: 'Pin',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
    )
      ..parentID = kRootNode
      ..draggable = const DraggableModel(
        group: 'g',
        start: DragStart.press,
        feedbackNodeId: 'fb',
      );
    final FrameNode holder = FrameNode(
      id: 'holder',
      name: 'Holder',
      basicBoxLocal: NodeBox(0, 0, 1, 1),
      children: ['fb'],
    )..parentID = kRootNode..visible = false;
    final TextNode fb = text('fb', 'holder', 'Feedback!', brandRegular)
      ..visible = false;
    final registry = NodeRegistry()
      ..setNodes({'pin': pin, 'holder': holder, 'fb': fb});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final c = CodelesslyContext.empty();
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: c,
        child: MaterialApp(
          home: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    pin,
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
    final g = await tester.startGesture(const Offset(20, 20));
    await tester.pump();
    for (int i = 1; i <= 5; i++) {
      await g.moveTo(Offset(20.0 + i * 20, 20.0 + i * 20));
      await tester.pump();
    }

    expect(find.text('Feedback!', findRichText: true), findsWidgets);
    await g.up();
    await tester.pumpAndSettle();
  });
}
