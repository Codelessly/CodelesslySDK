import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// An image fill on a row/column that hugs its content covers the size the
// row/column lays out at, like a DecoratedBox image, and doesn't size it:
// it used to paint in the stored basicBoxLocal height and make the node
// at least that tall.

/// A 1x1 transparent PNG.
const String _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
    'DUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Future<(Size node, Size image)> _pump(
  WidgetTester tester, {
  required double storedHeight,
  required double contentHeight,
}) async {
  final RectangleNode content = RectangleNode(
    id: 'content',
    name: 'content',
    basicBoxLocal: NodeBox(0, 0, 200, contentHeight),
  )..parentID = 'card';
  final RowColumnNode card = RowColumnNode(
    id: 'card',
    name: 'card',
    basicBoxLocal: NodeBox(0, 0, 200, storedHeight),
    children: [content.id],
    rowColumnType: RowColumnType.column,
    verticalFit: SizeFit.shrinkWrap,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.start,
    fills: [
      PaintModel(
        id: 'texture',
        type: PaintType.image,
        downloadUrl: _pixel,
        fit: Fit.cover,
      ),
    ],
  )..parentID = kRootNode;
  final registry = NodeRegistry()
    ..setNodes({card.id: card, content.id: content});
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
  return (
    tester.getSize(
      find.byKey(const ValueKey('Rectangle Transformer of card [card]')),
    ),
    tester.getSize(find.byType(RawImage)),
  );
}

void main() {
  testWidgets('covers content taller than the stored box', (tester) async {
    final (node, image) = await _pump(
      tester,
      storedHeight: 50,
      contentHeight: 300,
    );
    expect(node, const Size(200, 300));
    expect(image, const Size(200, 300));
  });

  testWidgets("a taller stored box doesn't grow the node", (tester) async {
    final (node, image) = await _pump(
      tester,
      storedHeight: 600,
      contentHeight: 300,
    );
    expect(node, const Size(200, 300));
    expect(image, const Size(200, 300));
  });
}
