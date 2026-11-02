import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> pump(WidgetTester tester, BaseNode node, {required bool preview}) {
  final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
  final PassiveNodeTransformerManager manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  return tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: WidgetBuildSettings(debugLabel: 'test', isPreview: preview),
            ),
          ),
        ),
      ),
    ),
  );
}

RectangleNode entering() => RectangleNode(
  id: 'r',
  name: 'Bar',
  basicBoxLocal: NodeBox(0, 0, 40, 100),
)
  ..parentID = kRootNode
  ..motion = const MotionModel(
    durationMs: 600,
    enterFrom: MotionModel(opacity: 0, scale: 0),
  );

void main() {
  testWidgets('the design canvas shows an entering node at rest', (tester) async {
    await pump(tester, entering(), preview: true);
    expect(find.byType(Opacity), findsNothing, reason: 'not stuck at opacity 0');
  });

  testWidgets('at runtime the node still enters from opacity 0', (tester) async {
    await pump(tester, entering(), preview: false);
    final Opacity start = tester.widget(
      find.descendant(of: find.byType(NodeMotion), matching: find.byType(Opacity)).first,
    );
    expect(start.opacity, lessThan(0.05));
    await tester.pumpAndSettle();
  });
}
