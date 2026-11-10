import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A fixed-width card in a column with less room than its width is
/// clamped to the column, as Flutter's SizedBox is (a 360 px card in a
/// 390 px phone's column with 20 px padding is 350 px wide).
Future<Size> _cardSize(
  WidgetTester tester, {
  MotionModel? motion,
  bool scrolls = false,
}) async {
  final FrameNode card = FrameNode(
    id: 'card',
    name: 'card',
    basicBoxLocal: NodeBox(20, 20, 360, 200),
    children: const [],
  )..motion = motion;
  final RowColumnNode column = RowColumnNode(
    id: 'column',
    name: 'column',
    basicBoxLocal: NodeBox(0, 0, 390, 400),
    rowColumnType: RowColumnType.column,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.center,
    padding: const EdgeInsetsModel.all(20),
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.expanded,
    isScrollable: scrolls,
    children: ['card'],
  )..parentID = kRootNode;
  card.parentID = column.id;
  final NodeRegistry registry = NodeRegistry()
    ..setNodes({column.id: column, card.id: card});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: 390,
            height: 400,
            child: Builder(
              builder: (c) => manager.buildWidgetFromNode(
                column,
                c,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getSize(
    find.byKey(const ValueKey('Rectangle Transformer of card [card]')).first,
  );
}

void main() {
  testWidgets('a fixed card is clamped to a narrower column', (tester) async {
    expect((await _cardSize(tester)).width, 350);
  });

  testWidgets('a fixed card with a motion is clamped too', (tester) async {
    final Size size = await _cardSize(
      tester,
      motion: const MotionModel(
        rotate: 0.8,
        durationMs: 420,
        keyframes: [MotionKeyframe(t: 0.25, translateX: -7.5)],
      ),
    );
    expect(size.width, 350);
  });

  testWidgets('a fixed card is clamped in a scrolling column', (tester) async {
    expect((await _cardSize(tester, scrolls: true)).width, 350);
  });
}
