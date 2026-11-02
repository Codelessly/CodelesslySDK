import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A list with `clipsContent: false`, or a scrolling row/column with
// `clipsScrollContent: false`, lets its children's shadows paint past its
// edges (cards in a list keep their whole drop shadow); one that clips, or
// doesn't say, still clips them.

const double _inset = 40;

/// A 100x50 white card whose hard red shadow sits 20 px above it.
RectangleNode _card(String id, String parentID) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 100, 50),
  fills: [PaintModel.solid(id: 'f', color: ColorRGB.white)],
  effects: [
    Effect(
      id: 's',
      type: EffectType.dropShadow,
      radius: 0,
      offset: const Vec(0, -20),
      color: const ColorRGBA(r: 1, g: 0, b: 0, a: 1),
    ),
  ],
)..parentID = parentID;

ListViewNode _list({
  bool? clipsContent,
  AxisC scrollDirection = AxisC.vertical,
  bool wrap = false,
}) {
  final ListViewNode list = ListViewNode(
    id: 'list',
    name: 'list',
    // Six 100x50 cards overflow it, so a viewport that clips does.
    basicBoxLocal: NodeBox(
      0,
      0,
      300,
      scrollDirection == AxisC.vertical ? 200 : 50,
    ),
    scrollDirection: scrollDirection,
    properties: ListViewProperties(itemCount: 6),
    children: ['card'],
    clipsContent: clipsContent ?? true,
  )..parentID = kRootNode;
  if (wrap) {
    list
      ..verticalFit = SizeFit.shrinkWrap
      ..properties.wrap = true;
  }
  return list;
}

/// A scrolling column of five cards (250 px of them in 200).
RowColumnNode _column({
  bool clipsContent = false,
  bool clipsScrollContent = true,
}) =>
    RowColumnNode(
        id: 'column',
        name: 'column',
        basicBoxLocal: NodeBox(0, 0, 300, 200),
        rowColumnType: RowColumnType.column,
        mainAxisAlignment: MainAxisAlignmentC.start,
        crossAxisAlignment: CrossAxisAlignmentC.start,
        isScrollable: true,
        clipsContent: clipsContent,
        children: ['c0', 'c1', 'c2', 'c3', 'c4'],
      )
      ..parentID = kRootNode
      ..clipsScrollContent = clipsScrollContent;

/// Whether the shadow's red shows in the row of pixels just above the
/// scrollable, outside it.
Future<bool> _shadowOutside(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes,
) async {
  final GlobalKey key = GlobalKey();
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [root, ...nodes]) node.id: node,
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
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(_inset),
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
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  late ByteData data;
  late int width;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    width = image.width;
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  // 10 px above the scrollable's top edge, across its width.
  final int y = _inset.toInt() - 10;
  for (int x = _inset.toInt(); x < _inset + 300; x++) {
    final int offset = (y * width + x) * 4;
    if (data.getUint8(offset) > 200 && data.getUint8(offset + 1) < 60) {
      return true;
    }
  }
  return false;
}

void main() {
  for (final (String name, ListViewNode Function({bool? clipsContent}) list)
      in [
        (
          'vertical list',
          ({bool? clipsContent}) => _list(clipsContent: clipsContent),
        ),
        (
          'horizontal list',
          ({bool? clipsContent}) => _list(
            clipsContent: clipsContent,
            scrollDirection: AxisC.horizontal,
          ),
        ),
        (
          'horizontal wrapping list',
          ({bool? clipsContent}) => _list(
            clipsContent: clipsContent,
            scrollDirection: AxisC.horizontal,
            wrap: true,
          ),
        ),
      ]) {
    testWidgets('a $name with clipsContent false paints shadows past it', (
      tester,
    ) async {
      expect(
        await _shadowOutside(tester, list(clipsContent: false), [
          _card('card', 'list'),
        ]),
        isTrue,
      );
    });

    testWidgets('a $name that clips (the default) cuts them', (tester) async {
      expect(
        await _shadowOutside(tester, list(), [_card('card', 'list')]),
        isFalse,
      );
    });
  }

  final List<BaseNode> cards = [
    for (int i = 0; i < 5; i++) _card('c$i', 'column'),
  ];

  testWidgets('a scrolling column with clipsScrollContent false paints '
      'its children\'s shadows past it', (tester) async {
    expect(
      await _shadowOutside(tester, _column(clipsScrollContent: false), cards),
      isTrue,
    );
  });

  testWidgets('a scrolling column clips them by default', (tester) async {
    expect(await _shadowOutside(tester, _column(), cards), isFalse);
  });

  testWidgets('clipsContent true still clips them', (tester) async {
    expect(
      await _shadowOutside(
        tester,
        _column(clipsContent: true, clipsScrollContent: false),
        cards,
      ),
      isFalse,
    );
  });
}
