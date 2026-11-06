import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The Lamplight schedule form's day circles: seven 42 px rows (a letter in
// each, a bound fill, a transition) in a row with `wrap: true`. They took
// up their space but painted nothing; with `wrap: false` they painted.

RowColumnNode _day(int i, String parentID) => RowColumnNode.fromJson({
  ...RowColumnNode(
    id: 'day$i',
    name: 'Day',
    basicBoxLocal: NodeBox(0, 0, 42, 42),
    rowColumnType: RowColumnType.row,
    mainAxisAlignment: MainAxisAlignmentC.center,
    crossAxisAlignment: CrossAxisAlignmentC.center,
    children: ['letter$i'],
    fills: [PaintModel.solid(id: 'f$i', color: ColorRGB.white)],
    cornerRadius: const CornerRadius.all(RadiusModel.circular(21)),
  ).toJson(),
  'transitionMs': 160,
  'variables': {'fill': r"${= true ? '#FF0000' : '#00FF00'}"},
})..parentID = parentID;

TextNode _letter(int i) => TextNode(
  id: 'letter$i',
  name: 'Letter',
  basicBoxLocal: NodeBox(0, 0, 10, 16),
  data: 'M',
  horizontalFit: SizeFit.shrinkWrap,
  verticalFit: SizeFit.shrinkWrap,
)..parentID = 'day$i';

RowColumnNode _circles({required bool wrap, bool scrolls = false}) =>
    RowColumnNode(
      id: 'circles',
      name: 'Day circles',
      basicBoxLocal: NodeBox(0, 0, 342, 42),
      rowColumnType: RowColumnType.row,
      horizontalFit: SizeFit.fixed,
      verticalFit: SizeFit.shrinkWrap,
      spacing: 8,
      runSpacing: 8,
      wrap: wrap,
      isScrollable: scrolls,
      children: [for (int i = 0; i < 7; i++) 'day$i'],
    )..parentID = kRootNode;

Future<(ByteData, int)> _paint(
  WidgetTester tester, {
  required bool wrap,
  required bool canvas,
  bool scrolls = false,
}) async {
  final RowColumnNode root = _circles(wrap: wrap, scrolls: scrolls);
  final registry = NodeRegistry()
    ..setNodes({
      root.id: root,
      for (int i = 0; i < 7; i++) ...{
        'day$i': _day(i, root.id),
        'letter$i': _letter(i),
      },
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    TickerMode(
      enabled: !canvas,
      child: ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.black,
                child: SizedBox(
                  width: 400,
                  height: 120,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Builder(
                      builder: (context) => manager.buildWidgetFromNode(
                        root,
                        context,
                        // As the design canvas (RenderCanvasBoard) builds.
                        settings: canvas
                            ? const WidgetBuildSettings(
                                debugLabel: 'render canvas',
                                isPreview: true,
                                withReactions: false,
                              )
                            : const WidgetBuildSettings(debugLabel: 'test'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
  return (data, width);
}

bool _red((ByteData, int) image, int x, int y) {
  final (ByteData data, int width) = image;
  final int o = (y * width + x) * 4;
  return data.getUint8(o) > 200 && data.getUint8(o + 1) < 60;
}

void main() {
  for (final (bool canvas, bool wrap) in [
    for (final bool canvas in [false, true])
      for (final bool wrap in [false, true]) (canvas, wrap),
  ]) {
    final String where = canvas ? 'on the design canvas' : 'at runtime';
    testWidgets('day circles paint in a row with wrap: $wrap $where', (
      tester,
    ) async {
      final image = await _paint(tester, wrap: wrap, canvas: canvas);
      // Seven circles of 42 + 8 in 342: all on the first run (7*50-8).
      for (int i = 0; i < 7; i++) {
        // Left edge inside the circle, away from the letter.
        expect(_red(image, i * 50 + 8, 21), isTrue, reason: 'circle $i');
      }
    });
  }

  for (final bool canvas in [false, true]) {
    testWidgets('scrolling wrap paints (canvas: $canvas)', (tester) async {
      final image = await _paint(
        tester,
        wrap: true,
        canvas: canvas,
        scrolls: true,
      );
      for (int i = 0; i < 7; i++) {
        expect(_red(image, i * 50 + 8, 21), isTrue, reason: 'circle $i');
      }
    });
  }
}
