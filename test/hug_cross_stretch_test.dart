import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A row that hugs its height and stretches its children is as tall as its
/// tallest child, every child that tall, without an intrinsic pass: the
/// postcard art beside a phrase that wraps onto a second line grows with
/// it, and the phrase isn't cut to one line.
void main() {
  Future<void> pump(WidgetTester tester, List<BaseNode> nodes) async {
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (c, b, p, l, cv) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  nodes.first,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  TextNode text(String id, String parent, String chars) => TextNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, 100, 24),
    data: chars,
    horizontalFit: SizeFit.shrinkWrap,
    verticalFit: SizeFit.shrinkWrap,
    textMixedProps: [StartEndProp(start: 0, end: chars.length, fontSize: 20)],
  )..parentID = parent;

  RowColumnNode row(List<String> children) => RowColumnNode(
    id: 'row',
    name: 'row',
    basicBoxLocal: NodeBox(0, 0, 300, 40),
    children: children,
    rowColumnType: RowColumnType.row,
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.shrinkWrap,
    crossAxisAlignment: CrossAxisAlignmentC.stretch,
  )..parentID = kRootNode;

  RectangleNode art() => RectangleNode(
    id: 'art',
    name: 'art',
    basicBoxLocal: NodeBox(0, 0, 100, 10),
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.fixed,
  )..parentID = 'row';

  testWidgets('the short child stretches to the wrapped text', (tester) async {
    final RowColumnNode texts = RowColumnNode(
      id: 'texts',
      name: 'texts',
      basicBoxLocal: NodeBox(0, 0, 200, 40),
      children: const ['hello', 'under'],
      rowColumnType: RowColumnType.column,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.shrinkWrap,
    )..parentID = 'row';
    await pump(tester, [
      row(['art', 'texts']),
      art(),
      texts,
      text('hello', 'texts', 'ABCDE FGHIJ'),
      text('under', 'texts', 'X'),
    ]);
    final Rect hello = tester.getRect(find.text('ABCDE FGHIJ'));
    final Rect under = tester.getRect(find.text('X'));
    // 200 wide: the 220-wide phrase wraps onto a second line.
    expect(hello.height, closeTo(54, 1));
    expect(under.top, closeTo(hello.bottom, 0.5));
    final Rect artBox = tester.getRect(
      find.byKey(ValueKey('Rectangle Transformer of ${art().debugLabel}')),
    );
    expect(artBox.height, closeTo(under.bottom, 0.5));
  });
}
