import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a canvas without a fill is see-through in any dialog route', (
    tester,
  ) async {
    final FrameNode body = FrameNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, 300, 200),
      children: const [],
    );
    final CanvasNode canvas = CanvasNode(
      id: 'dialog',
      name: 'Confirm',
      basicBoxLocal: NodeBox(0, 0, 300, 200),
      fills: const [],
      children: const ['body'],
      properties: CanvasProperties(bodyId: 'body'),
    )..parentID = kRootNode;
    body.parentID = canvas.id;
    final Map<String, BaseNode> nodes = {canvas.id: canvas, body.id: body};
    final manager = PassiveNodeTransformerManager(
      (id) => nodes[id]!,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    late BuildContext root;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(builder: (c) {
            root = c;
            return const SizedBox();
          }),
        ),
      ),
    );
    showDialog<void>(
      context: root,
      builder: (c) => Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: manager.buildWidgetFromNode(
            canvas,
            c,
            settings: const WidgetBuildSettings(debugLabel: 'test'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Iterable<Material> surfaces = tester
        .widgetList<Material>(find.descendant(of: find.byType(Dialog).hitTestable().evaluate().isEmpty ? find.byType(Center).last : find.byType(Dialog), matching: find.byType(Material)))
        .where((m) => m.type != MaterialType.transparency);
    expect(surfaces, isEmpty);
  });
}
