import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'viewport_layout_test.dart' as vp;

/// A list that doesn't scroll and hugs its three items.
ListViewNode staticList({String parentID = kRootNode}) =>
    vp.list(parentID: parentID, verticalFit: SizeFit.shrinkWrap)
      ..isScrollable = false;

RowColumnNode flex(
  String id,
  String parentID,
  RowColumnType type,
  List<String> children, {
  SizeFit horizontalFit = SizeFit.shrinkWrap,
  SizeFit verticalFit = SizeFit.shrinkWrap,
  CrossAxisAlignmentC cross = CrossAxisAlignmentC.start,
}) => RowColumnNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 300, 300),
  rowColumnType: type,
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  crossAxisAlignment: cross,
  children: children,
)..parentID = parentID;

void main() {
  test('a list that neither scrolls nor has a fixed extent lets intrinsics '
      'through', () {
    final list = staticList();
    final item = vp.rect('item', 'list');
    BaseNode getNode(String id) => {'list': list, 'item': item}[id]!;

    expect(listBuildsAllItems(list), isTrue);
    expect(subtreeBlocksIntrinsics(list, getNode), isFalse);

    list.isScrollable = true;
    expect(listBuildsAllItems(list), isFalse);
    expect(subtreeBlocksIntrinsics(list, getNode), isTrue);

    list
      ..isScrollable = false
      ..verticalFit = SizeFit.fixed;
    expect(subtreeBlocksIntrinsics(list, getNode), isTrue);

    list
      ..verticalFit = SizeFit.shrinkWrap
      ..properties = ListViewProperties();
    expect(listBuildsAllItems(list), isFalse, reason: 'endless list');
  });

  vp.forEachLayout('a static list lays its items out without a viewport', (
    tester,
    screen,
    host,
  ) async {
    await vp.pump(tester, screen, host, staticList(), [
      vp.rect('item', 'list'),
    ]);
    expect(find.byType(ViewportNodeBox), findsNothing);
    expect(vp.rectOf('item'), findsNWidgets(3));
    final Rect first = tester.getRect(vp.rectOf('item').at(0));
    final Rect last = tester.getRect(vp.rectOf('item').at(2));
    expect(last.bottom - first.top, 150);
    expect(first.size, const Size(100, 50));
  });

  vp.forEachLayout('a stretched row keeps cards equal with a list in one', (
    tester,
    screen,
    host,
  ) async {
    // row(stretch) > [left column > list of 3 x 50, right column > 300 rect]
    final row = flex('row', kRootNode, RowColumnType.row, [
      'left',
      'right',
    ], cross: CrossAxisAlignmentC.stretch);
    await vp.pump(tester, screen, host, row, [
      flex('left', 'row', RowColumnType.column, [
        'list',
      ], verticalFit: SizeFit.expanded),
      staticList(parentID: 'left'),
      vp.rect('item', 'list'),
      flex('right', 'row', RowColumnType.column, ['tall']),
      vp.rect('tall', 'right', height: 300),
    ]);
    final Finder left = vp.rectOf('left');
    final Finder right = vp.rectOf('right');
    // Without intrinsics the stretch fell back to start and the left card
    // kept its own (list) height. A tight host stretches both to the screen.
    if (host != vp.Host.tight) expect(tester.getSize(right).height, 300);
    expect(tester.getSize(left).height, tester.getSize(right).height);
    expect(vp.rectOf('item'), findsNWidgets(3));
  });
}
