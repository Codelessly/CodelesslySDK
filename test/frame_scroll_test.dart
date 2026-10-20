import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode box(
  String id,
  double x,
  double y, {
  AlignmentModel alignment = AlignmentModel.none,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(x, y, 50, 50),
  alignment: alignment,
)..parentID = 'frame';

FrameNode frame(
  List<BaseNode> children, {
  bool isScrollable = true,
  AxisC scrollDirection = AxisC.vertical,
}) => FrameNode(
  id: 'frame',
  name: 'frame',
  basicBoxLocal: NodeBox(0, 0, 200, 300),
  children: [for (final child in children) child.id],
  isScrollable: isScrollable,
  scrollDirection: scrollDirection,
)..parentID = kRootNode;

Finder rectOf(BaseNode node) =>
    find.byKey(ValueKey('Rectangle Transformer of ${node.debugLabel}'));

/// Builds [root] with [children] and returns each node's rect relative to
/// [root]'s top left.
Future<Map<String, Rect>> layout(
  WidgetTester tester,
  FrameNode root,
  List<BaseNode> children,
) async {
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [root, ...children]) node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                root,
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
  final Offset origin = tester.getTopLeft(rectOf(root));
  return {
    for (final node in [root, ...children])
      node.id: tester.getRect(rectOf(node)).shift(-origin),
  };
}

void main() {
  testWidgets('vertical scroll frame keeps children at their positions', (
    tester,
  ) async {
    final a = box('a', 10, 0);
    final b = box('b', 40, 600);
    final rects = await layout(tester, frame([a, b]), [a, b]);

    expect(rects['frame'], const Rect.fromLTWH(0, 0, 200, 300));
    expect(rects['a'], const Rect.fromLTWH(10, 0, 50, 50));
    expect(rects['b'], const Rect.fromLTWH(40, 600, 50, 50));

    await tester.drag(rectOf(a), const Offset(0, -300));
    await tester.pumpAndSettle();
    final Offset origin = tester.getTopLeft(rectOf(frame([])));
    expect(
      tester.getRect(rectOf(b)).shift(-origin),
      const Rect.fromLTWH(40, 300, 50, 50),
    );
  });

  testWidgets('horizontal scroll frame keeps children at their positions', (
    tester,
  ) async {
    final a = box('a', 10, 20);
    final b = box('b', 400, 260);
    final c = box('c', 30, 500);
    final rects = await layout(
      tester,
      frame([a, b, c], scrollDirection: AxisC.horizontal),
      [a, b, c],
    );

    expect(rects['frame'], const Rect.fromLTWH(0, 0, 200, 300));
    expect(rects['a'], const Rect.fromLTWH(10, 20, 50, 50));
    expect(rects['b'], const Rect.fromLTWH(400, 260, 50, 50));
    expect(rects['c'], const Rect.fromLTWH(30, 500, 50, 50));
  });

  testWidgets('scroll frame aligns an aligned child within the viewport', (
    tester,
  ) async {
    final a = box('a', 75, 250, alignment: AlignmentModel.bottomCenter);
    final rects = await layout(tester, frame([a]), [a]);

    expect(rects['frame'], const Rect.fromLTWH(0, 0, 200, 300));
    expect(rects['a'], const Rect.fromLTWH(75, 250, 50, 50));
  });

  testWidgets('scroll frame aligns an aligned child next to a positioned one', (
    tester,
  ) async {
    final a = box('a', 75, 0, alignment: AlignmentModel.topCenter);
    final b = box('b', 40, 600);
    final rects = await layout(tester, frame([a, b]), [a, b]);

    expect(rects['frame'], const Rect.fromLTWH(0, 0, 200, 300));
    expect(rects['a'], const Rect.fromLTWH(75, 0, 50, 50));
    expect(rects['b'], const Rect.fromLTWH(40, 600, 50, 50));
  });

  testWidgets('non-scrolling frame positions children as designed', (
    tester,
  ) async {
    final a = box('a', 10, 0);
    final b = box('b', 40, 200);
    final c = box('c', 75, 125, alignment: AlignmentModel.center);
    final rects = await layout(tester, frame([a, b, c], isScrollable: false), [
      a,
      b,
      c,
    ]);

    expect(rects['frame'], const Rect.fromLTWH(0, 0, 200, 300));
    expect(rects['a'], const Rect.fromLTWH(10, 0, 50, 50));
    expect(rects['b'], const Rect.fromLTWH(40, 200, 50, 50));
    expect(rects['c'], const Rect.fromLTWH(75, 125, 50, 50));
  });
}
