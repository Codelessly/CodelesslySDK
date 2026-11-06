import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A scrolling column's content is at least as long as its viewport when it
// centres or spreads its children or has an expanded child (Flutter's
// ConstrainedBox(minHeight: viewport) + IntrinsicHeight pattern), and in
// every case with `fillViewport: true`: an error card centred on the
// screen, expanded children sharing the room, and scrolling once the
// content is longer.

RowColumnNode _content({
  required bool fill,
  required SizeFit verticalFit,
  MainAxisAlignmentC main = MainAxisAlignmentC.center,
  List<String> children = const ['card'],
}) => RowColumnNode(
  id: 'content',
  name: 'Content',
  basicBoxLocal: NodeBox(0, 0, 300, 400),
  rowColumnType: RowColumnType.column,
  horizontalFit: SizeFit.expanded,
  verticalFit: verticalFit,
  mainAxisAlignment: main,
  crossAxisAlignment: CrossAxisAlignmentC.center,
  isScrollable: true,
  children: children,
)..fillViewport = fill;

RectangleNode _box(String id, double height, {SizeFit fit = SizeFit.fixed}) =>
    RectangleNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 200, height),
      verticalFit: fit,
      fills: [PaintModel.solid(id: 'f$id', color: ColorRGB.fromHex('#FF0000'))],
    )..parentID = 'content';

/// Lays [content] out in a 300x400 slot (a column giving it a Flexible
/// share) and returns the rects of [ids] relative to the slot.
Future<Map<String, Rect>> _layout(
  WidgetTester tester,
  RowColumnNode content,
  List<RectangleNode> boxes,
) async {
  final RowColumnNode slot = RowColumnNode(
    id: 'slot',
    name: 'Slot',
    basicBoxLocal: NodeBox(0, 0, 300, 400),
    rowColumnType: RowColumnType.column,
    crossAxisAlignment: CrossAxisAlignmentC.stretch,
    children: ['content'],
  )..parentID = kRootNode;
  content.parentID = slot.id;
  final registry = NodeRegistry()
    ..setNodes({
      slot.id: slot,
      content.id: content,
      for (final box in boxes) box.id: box,
    });
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
          child: SizedBox(
            width: 300,
            height: 400,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                slot,
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
  return {
    // The scroll view is the content's viewport.
    content.id: tester.getRect(find.byType(SingleChildScrollView)),
    for (final RectangleNode box in boxes)
      box.id: tester.getRect(
        find.byKey(ValueKey('Rectangle Transformer of ${box.id} [${box.id}]')),
      ),
  };
}

void main() {
  test('fillViewport survives JSON and is off by default', () {
    final RowColumnNode node = _content(
      fill: true,
      verticalFit: SizeFit.expanded,
    );
    final RowColumnNode back = RowColumnNode.fromJson(node.toJson());
    expect(back.fillViewport, isTrue);
    expect(
      _content(
        fill: false,
        verticalFit: SizeFit.expanded,
      ).toJson().containsKey('fillViewport'),
      isFalse,
    );
  });

  // A start-aligned column with no flex child lays its children out from
  // the top either way; with fillViewport its content still takes the whole
  // viewport, as ConstrainedBox(minHeight: viewport) does.
  for (final bool fill in [false, true]) {
    testWidgets(
      'the content of a start-aligned column ${fill ? 'fills' : 'hugs'} '
      'its viewport',
      (tester) async {
        final rects = await _layout(
          tester,
          _content(
            fill: fill,
            verticalFit: SizeFit.expanded,
            main: MainAxisAlignmentC.start,
          ),
          [_box('card', 100)],
        );
        expect(rects['content']!.height, 400);
        expect(rects['card']!.top, 0);
        expect(
          tester
            .getSize(
              find.descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byKey(const ValueKey('content')),
              ),
            )
            .height,
          fill ? 400 : 100,
        );
      },
    );
  }

  testWidgets('expanded children share the viewport, start aligned', (
    tester,
  ) async {
    final rects = await _layout(
      tester,
      _content(
        fill: true,
        verticalFit: SizeFit.expanded,
        main: MainAxisAlignmentC.start,
        children: ['top', 'card'],
      ),
      [_box('top', 50, fit: SizeFit.expanded), _box('card', 100)],
    );
    expect(rects['top']!.height, 300);
    expect(rects['card']!.top, 300);
  });

  testWidgets('a centred card sits in the middle of the viewport', (
    tester,
  ) async {
    final rects = await _layout(
      tester,
      _content(fill: true, verticalFit: SizeFit.expanded),
      [_box('card', 100)],
    );
    expect(rects['card']!.top, 150);
  });

  testWidgets('taller content still scrolls', (tester) async {
    final rects = await _layout(
      tester,
      _content(fill: true, verticalFit: SizeFit.expanded, children: ['a', 'b']),
      [_box('a', 300), _box('b', 300)],
    );
    expect(rects['b']!.top, 300);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -150),
    );
    await tester.pump();
    expect(
      tester
          .getRect(find.byKey(const ValueKey('Rectangle Transformer of b [b]')))
          .top,
      150,
    );
  });
}
