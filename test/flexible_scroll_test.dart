import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A form card: `Column(header, Flexible(scroll view), footer)`. The body is
/// as tall as its content, up to the space left, and scrolls past that.
void main() {
  RectangleNode box(String id, String parent, double height) =>
      RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(0, 0, 300, height))
        ..parentID = parent;

  Future<void> pump(WidgetTester tester, List<double> fields) async {
    final RowColumnNode card = RowColumnNode(
      id: 'card',
      name: 'card',
      basicBoxLocal: NodeBox(0, 0, 300, 600),
      rowColumnType: RowColumnType.column,
      mainAxisAlignment: MainAxisAlignmentC.start,
      crossAxisAlignment: CrossAxisAlignmentC.start,
      children: ['header', 'body', 'footer'],
    )..parentID = kRootNode;
    final RowColumnNode body = RowColumnNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, 300, 40),
      rowColumnType: RowColumnType.column,
      mainAxisAlignment: MainAxisAlignmentC.start,
      crossAxisAlignment: CrossAxisAlignmentC.start,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.flexible,
      isScrollable: true,
      children: [for (var i = 0; i < fields.length; i++) 'f$i'],
    )..parentID = 'card';
    final nodes = <BaseNode>[
      card,
      box('header', 'card', 60),
      body,
      box('footer', 'card', 50),
      for (final (i, h) in fields.indexed) box('f$i', 'body', h),
    ];
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                card,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  Rect rect(WidgetTester tester, String id) => tester.getRect(
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]')),
  );

  testWidgets('a short body hugs its content', (tester) async {
    await pump(tester, [100, 100]);
    expect(rect(tester, 'footer').top, 260);
    expect(tester.getSize(find.byType(SingleChildScrollView)).height, 200);
  });

  testWidgets('a long body takes the space left and scrolls', (tester) async {
    await pump(tester, [400, 400]);
    expect(rect(tester, 'footer').top, 550);
    expect(tester.getSize(find.byType(SingleChildScrollView)).height, 490);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(rect(tester, 'f0').top, 60 - 200);
  });
}
