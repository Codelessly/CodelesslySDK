import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'viewport_layout_test.dart' as vp;

/// A horizontal list of [itemCount] 100x50 items that wraps, 14 apart with
/// 6 between runs, and hugs its height.
ListViewNode wrappingList({
  double width = 250,
  int? itemCount = 4,
  SizeFit horizontalFit = SizeFit.fixed,
  bool hasSeparator = true,
}) {
  final ListViewNode list = vp.list(
    width: width,
    height: 50,
    itemCount: itemCount,
    horizontalFit: horizontalFit,
    verticalFit: SizeFit.shrinkWrap,
    scrollDirection: AxisC.horizontal,
  );
  list.properties
    ..wrap = true
    ..hasSeparator = hasSeparator
    ..separatorSpacing = 14
    ..runSpacing = 6;
  return list;
}

List<Rect> itemRects(WidgetTester tester) => [
  for (final Element element in vp.rectOf('item').evaluate())
    tester.getRect(find.byWidget(element.widget).first),
];

void main() {
  test('a wrapping list with a known count builds all its items', () {
    final ListViewNode list = wrappingList();
    expect(list.isScrollable, isTrue);
    expect(listWraps(list), isTrue);
    expect(listBuildsAllItems(list), isTrue);
    expect(listWrapSpacing(list), 14);

    list.properties.itemCount = null;
    expect(listWraps(list), isFalse, reason: 'endless list');
    expect(listBuildsAllItems(list), isFalse);

    list
      ..properties.itemCount = 3
      ..useCloudDatabase = true;
    expect(listWraps(list), isFalse, reason: 'cloud query');
  });

  testWidgets('a wrapping list keeps its items on one run when they fit', (
    tester,
  ) async {
    await vp.pump(tester, const Size(800, 800), vp.Host.loose, wrappingList(
      width: 500,
    ), [vp.rect('item', 'list')]);
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(ViewportNodeBox), findsNothing);
    final List<Rect> items = itemRects(tester);
    expect(items, hasLength(4));
    for (int i = 1; i < 4; i++) {
      expect(items[i].top, items[0].top);
      expect(items[i].left - items[i - 1].right, 14);
    }
    expect(tester.getSize(find.byType(Wrap)).height, 50);
  });

  testWidgets('a wrapping list moves items that do not fit to a new run', (
    tester,
  ) async {
    await vp.pump(tester, const Size(800, 800), vp.Host.loose, wrappingList(), [
      vp.rect('item', 'list'),
    ]);
    final List<Rect> items = itemRects(tester);
    // 100 + 14 + 100 = 214 fits in 250, a third item does not.
    expect(items[1].top, items[0].top);
    expect(items[2].left, items[0].left);
    expect(items[2].top - items[0].bottom, 6);
    expect(items[3].top, items[2].top);
    expect(tester.getSize(find.byType(Wrap)), const Size(250, 106));
  });

  testWidgets('an expanded wrapping list wraps at the width it gets', (
    tester,
  ) async {
    await vp.pump(
      tester,
      const Size(250, 800),
      vp.Host.tight,
      wrappingList(width: 800, horizontalFit: SizeFit.expanded),
      [vp.rect('item', 'list')],
    );
    final List<Rect> items = itemRects(tester);
    expect(items[2].top - items[0].bottom, 6);
  });

  testWidgets('without a separator the items touch', (tester) async {
    await vp.pump(
      tester,
      const Size(800, 800),
      vp.Host.loose,
      wrappingList(width: 500, hasSeparator: false),
      [vp.rect('item', 'list')],
    );
    final List<Rect> items = itemRects(tester);
    expect(items[1].left, items[0].right);
  });

  testWidgets('a wrapping list with no count scrolls as before', (
    tester,
  ) async {
    await vp.pump(
      tester,
      const Size(800, 800),
      vp.Host.loose,
      wrappingList(itemCount: null)..verticalFit = SizeFit.fixed,
      [vp.rect('item', 'list')],
    );
    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(ViewportNodeBox), findsOneWidget);
  });
}
