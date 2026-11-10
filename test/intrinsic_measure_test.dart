import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'viewport_layout_test.dart' as vp;

/// A changelog entry, as in the Hookline site: a timeline rail (a column
/// holding a line that stretches) beside a content column with a title, tag
/// chips in wrapping lists, a scaled badge frame and a button that reacts
/// to entering the viewport and reveals on scroll. The entry row stretches
/// its cross axis, so it is wrapped in an IntrinsicHeight, and is the item
/// of a scrolling list.
List<BaseNode> changelogNodes() {
  final ListViewNode changelog = vp.list(
    id: 'changelog',
    item: 'entry',
    itemCount: 2,
    width: 380,
    height: 800,
  );
  final RowColumnNode entry = flex(
    'entry',
    'changelog',
    RowColumnType.row,
    ['rail', 'content'],
    horizontalFit: SizeFit.fixed,
    cross: CrossAxisAlignmentC.stretch,
    width: 364,
  );
  final RowColumnNode rail = flex(
    'rail',
    'entry',
    RowColumnType.column,
    ['line'],
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.expanded,
    width: 24,
    height: 100,
  );
  final RectangleNode line = vp.rect(
    'line',
    'rail',
    width: 2,
    height: 100,
    verticalFit: SizeFit.expanded,
  );
  final RowColumnNode content = flex(
    'content',
    'entry',
    RowColumnType.column,
    ['title', 'tags', 'chips', 'badge', 'cta'],
    horizontalFit: SizeFit.fixed,
    width: 340,
  );
  final RectangleNode title = vp.rect('title', 'content', height: 40);
  // A legacy wrapping list (wrap spacing): sized by a WrapNodeBox.
  final ListViewNode tags =
      vp.list(
          id: 'tags',
          parentID: 'content',
          item: 'tag',
          itemCount: 5,
          width: 300,
          height: 24,
          scrollDirection: AxisC.horizontal,
          verticalFit: SizeFit.shrinkWrap,
        )
        // Not scrolling, it was measured, and its LayoutBuilder threw.
        ..isScrollable = false
        ..properties.wrap = true
        ..properties.wrapSpacing = 8
        ..properties.wrapRunSpacing = 8;
  final RectangleNode tag = vp.rect('tag', 'tags', width: 80, height: 24);
  // A wrapping list that builds all its items in a Wrap.
  final ListViewNode chips =
      vp.list(
          id: 'chips',
          parentID: 'content',
          item: 'chip',
          itemCount: 4,
          width: 300,
          height: 24,
          scrollDirection: AxisC.horizontal,
          verticalFit: SizeFit.shrinkWrap,
        )
        // Scroll settings don't matter: a wrapping list never scrolls.
        ..properties.wrap = true
        ..properties.hasSeparator = true
        ..properties.separatorSpacing = 6;
  final RectangleNode chip = vp.rect('chip', 'chips', width: 90, height: 20);
  // A frame scaling its content (ScaledContent).
  final FrameNode badge = FrameNode(
    id: 'badge',
    name: 'badge',
    basicBoxLocal: NodeBox(0, 0, 120, 30),
    horizontalFit: SizeFit.expanded,
    children: ['badgeDot'],
    contentFit: Fit.contain,
  )..parentID = 'content';
  final RectangleNode badgeDot = vp.rect(
    'badgeDot',
    'badge',
    width: 10,
    height: 10,
  );
  final RectangleNode cta = vp.rect('cta', 'content', width: 120, height: 36)
    ..reactions = [
      Reaction(
        trigger: TriggerModel(type: TriggerType.enterViewport),
        action: CallFunctionAction(name: 'seen'),
      ),
    ]
    ..motion = const MotionModel(
      durationMs: 400,
      revealOnScroll: true,
      enterFrom: MotionModel(translateY: 24, opacity: 0),
    );
  return [
    changelog,
    entry,
    rail,
    line,
    content,
    title,
    tags,
    tag,
    chips,
    chip,
    badge,
    badgeDot,
    cta,
  ];
}

RowColumnNode flex(
  String id,
  String parentID,
  RowColumnType type,
  List<String> children, {
  SizeFit horizontalFit = SizeFit.shrinkWrap,
  SizeFit verticalFit = SizeFit.shrinkWrap,
  CrossAxisAlignmentC cross = CrossAxisAlignmentC.start,
  double width = 300,
  double height = 300,
}) => RowColumnNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  rowColumnType: type,
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  crossAxisAlignment: cross,
  children: children,
)..parentID = parentID;

void main() {
  test('wrapping lists and scaled frames do not block intrinsics', () {
    final Map<String, BaseNode> nodes = {
      for (final node in changelogNodes()) node.id: node,
    };
    BaseNode getNode(String id) => nodes[id]!;
    expect(subtreeBlocksIntrinsics(getNode('tags'), getNode), isFalse);
    expect(subtreeBlocksIntrinsics(getNode('chips'), getNode), isFalse);
    expect(subtreeBlocksIntrinsics(getNode('badge'), getNode), isFalse);
    expect(subtreeBlocksIntrinsics(getNode('entry'), getNode), isFalse);
  });

  vp.forEachLayout('a stretching changelog entry measures its content', (
    tester,
    screen,
    host,
  ) async {
    final List<BaseNode> nodes = changelogNodes();
    await vp.pump(tester, screen, host, nodes.first, nodes.skip(1).toList());
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Measured across: an IntrinsicHeight, or master's HugCross, which
    // stretches a hugging row's children to its tallest without a second
    // intrinsic pass.
    expect(
      find.byWidgetPredicate(
        (w) => w is IntrinsicHeight || '${w.runtimeType}' == 'HugCross',
      ),
      findsWidgets,
    );
    expect(find.byType(LayoutBuilder), findsNothing);
    final Finder line = vp.rectOf('line');
    final Finder content = vp.rectOf('content');
    expect(line, findsNWidgets(2));
    // The rail's line runs the whole height of the entry's content.
    expect(
      tester.getSize(line.first).height,
      moreOrLessEquals(tester.getSize(content.first).height),
    );
    expect(tester.getSize(content.first).height, greaterThan(40 + 24 + 20));
  });

  testWidgets('a measured parent can hold a MeasurableLayoutBuilder', (
    tester,
  ) async {
    int builds = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 4, child: ColoredBox(color: Colors.red)),
                MeasurableLayoutBuilder(
                  fallbackSize: const Size(50, 10),
                  builder: (context, constraints) {
                    builds++;
                    return const SizedBox(width: 50, height: 70);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // The first frame measures the design size, the next the content.
    await tester.pump();
    expect(tester.getSize(find.byType(Row)).height, 70);
    expect(tester.getSize(find.byType(ColoredBox)).height, 70);
    expect(builds, greaterThan(0));
  });
}
