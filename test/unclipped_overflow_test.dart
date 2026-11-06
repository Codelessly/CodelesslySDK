import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A gridline row 100 x 1 that doesn't clip its content, holding its kg
/// label (12px text, as tall as its line) moved up 7.5 to sit on the line.
Future<void> _pump(WidgetTester tester, {bool clipsContent = false}) async {
  final TextNode label = TextNode(
    id: 'kg',
    name: 'kg',
    basicBoxLocal: NodeBox(0, 0, 20, 15),
    data: '12',
    horizontalFit: SizeFit.shrinkWrap,
    verticalFit: SizeFit.shrinkWrap,
    textMixedProps: [StartEndProp(start: 0, end: 2, fontSize: 12)],
  )
    ..parentID = 'line'
    ..motion = const MotionModel(translateY: -7.5);
  final RowColumnNode line = RowColumnNode(
    id: 'line',
    name: 'line',
    basicBoxLocal: NodeBox(0, 0, 100, 1),
    children: const ['kg'],
    rowColumnType: RowColumnType.row,
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.fixed,
    mainAxisAlignment: MainAxisAlignmentC.end,
    crossAxisAlignment: CrossAxisAlignmentC.start,
    clipsContent: clipsContent,
  )..parentID = kRootNode;
  final registry = NodeRegistry()..setNodes({line.id: line, label.id: label});
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
                line,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The render objects between the label's text and the screen that clip it.
List<RenderObject> _clipsAbove(WidgetTester tester) {
  final List<RenderObject> clips = [];
  RenderObject? node = tester.renderObject(find.text('12'));
  final RenderParagraph paragraph = node as RenderParagraph;
  // A paragraph laid out shorter than its text clips it.
  if (paragraph.size.height < paragraph.getMaxIntrinsicHeight(100) - 0.5 &&
      paragraph.overflow == TextOverflow.clip) {
    clips.add(paragraph);
  }
  while (node != null) {
    final Clip? clip = switch (node) {
      RenderClipRect r => r.clipBehavior,
      RenderClipRRect r => r.clipBehavior,
      RenderClipPath r => r.clipBehavior,
      RenderFlex r when r.clipBehavior != Clip.none => r.clipBehavior,
      _ => null,
    };
    if (clip != null && clip != Clip.none) clips.add(node);
    node = node.parent;
  }
  return clips;
}

void main() {
  testWidgets('a row that does not clip lets its moved text show', (
    tester,
  ) async {
    await _pump(tester);
    final List<RenderObject> clips = _clipsAbove(tester);
    expect(clips, isEmpty, reason: '$clips');
    // The label keeps its height on the row's top, moved up 7.5 by its
    // motion: from 7.5 above the line to 8.5 below it.
    final Rect line = tester.getRect(
      find.byKey(const ValueKey('Rectangle Transformer of line [line]')),
    );
    final Rect label = tester.getRect(find.text('12'));
    expect(line.height, 1);
    expect(label.height, 16);
    expect(label.top, closeTo(line.top - 7.5, 0.01));
  });

  testWidgets('a row that clips its content still clips it', (tester) async {
    await _pump(tester, clipsContent: true);
    expect(_clipsAbove(tester), isNotEmpty);
  });
}
