import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Lamplight's loading skeleton: a row of skeleton chips 414 px wide in a
// 350 px slot. With `clipsContent: true` the row cuts the chips off at its
// edge, as the reference does (4 chips of 96 px, 10 px apart), with no yellow "RIGHT OVERFLOWED" stripes
// (debug builds, and so the editor's captures) and no overflow error.

RowColumnNode _chips({
  required bool clips,
  required String parentID,
  MainAxisAlignmentC main = MainAxisAlignmentC.center,
}) => RowColumnNode(
      id: 'chips',
      name: 'Chips',
      basicBoxLocal: NodeBox(0, 0, 350, 30),
      rowColumnType: RowColumnType.row,
      mainAxisAlignment: main,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.fixed,
      spacing: 10,
      clipsContent: clips,
      children: [for (int i = 0; i < 4; i++) 'chip$i'],
    )..parentID = parentID;

/// A 96 px skeleton chip: a fixed column with a pulse layer filling it.
RowColumnNode _chip(int i) => RowColumnNode(
  id: 'chip$i',
  name: 'chip$i',
  basicBoxLocal: NodeBox(0, 0, 96, 30),
  rowColumnType: RowColumnType.column,
  crossAxisAlignment: CrossAxisAlignmentC.stretch,
  children: ['pulse$i'],
)..parentID = 'chips';

RectangleNode _pulse(int i) => RectangleNode(
  id: 'pulse$i',
  name: 'pulse$i',
  basicBoxLocal: NodeBox(0, 0, 96, 30),
  horizontalFit: SizeFit.expanded,
  verticalFit: SizeFit.expanded,
  fills: [PaintModel.solid(id: 'f$i', color: ColorRGB.fromHex('#FF0000'))],
)..parentID = 'chip$i';

/// A 350 px column slot holding the row.
RowColumnNode _slot() => RowColumnNode(
  id: 'slot',
  name: 'Slot',
  basicBoxLocal: NodeBox(0, 0, 350, 30),
  rowColumnType: RowColumnType.column,
  crossAxisAlignment: CrossAxisAlignmentC.stretch,
  children: ['chips'],
)..parentID = kRootNode;

Future<(ByteData, int)> _paint(
  WidgetTester tester, {
  required bool clips,
  MainAxisAlignmentC main = MainAxisAlignmentC.center,
}) async {
  final RowColumnNode slot = _slot();
  final registry = NodeRegistry()
    ..setNodes({
      slot.id: slot,
      'chips': _chips(clips: clips, parentID: slot.id, main: main),
      for (int i = 0; i < 4; i++) ...{'chip$i': _chip(i), 'pulse$i': _pulse(i)},
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final GlobalKey key = GlobalKey();
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
              child: SizedBox(
                width: 400,
                height: 30,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 350,
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
          ),
        ),
      ),
    ),
  );
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

void main() {
  testWidgets('a clipping row cuts its overflow off with no stripes', (
    tester,
  ) async {
    final (ByteData data, int width) = await _paint(tester, clips: true);
    expect(tester.takeException(), isNull);
    // The last chip runs past the 350 px row: it overflows.
    expect(
      tester
          .getRect(
            find.byKey(
              const ValueKey('Rectangle Transformer of chip3 [chip3]'),
            ),
          )
          .right,
      414,
    );
    int yellow = 0;
    for (int y = 0; y < 30; y++) {
      for (int x = 0; x < 400; x++) {
        final int o = (y * width + x) * 4;
        // The stripes' yellow (#FFFFBF00-ish): red and green, no blue.
        if (data.getUint8(o) > 200 &&
            data.getUint8(o + 1) > 150 &&
            data.getUint8(o + 2) < 80) {
          yellow++;
        }
      }
    }
    expect(yellow, 0);
    // The chips paint up to the row's edge and nothing past it.
    int at(int x) => data.getUint8((15 * width + x) * 4 + 1);
    expect(at(345), lessThan(60), reason: 'red chip at 345');
    expect(at(355), greaterThan(200), reason: 'white past the row');
  });

  late WidgetTester current;
  Rect chip(int i) => current.getRect(
    find.byKey(ValueKey('Rectangle Transformer of chip$i [chip$i]')),
  );

  // As in Flutter's RenderFlex, the main axis' free space is clamped at 0:
  // whatever the alignment, an overflow starts at the leading edge, and a
  // row that doesn't clip reports it.
  for (final MainAxisAlignmentC main in [
    MainAxisAlignmentC.start,
    MainAxisAlignmentC.center,
    MainAxisAlignmentC.end,
  ]) {
    testWidgets('a ${main.name} row that does not clip overflows from its '
        'start and reports it', (tester) async {
      current = tester;
      await _paint(tester, clips: false, main: main);
      final Object? error = tester.takeException();
      expect(error, isNotNull);
      expect('$error', contains('overflowed'));
      expect(chip(0).left, 0);
      expect(chip(3).right, 414);
    });
  }

  testWidgets('a centred row that clips keeps its children at its start', (
    tester,
  ) async {
    current = tester;
    await _paint(tester, clips: true);
    expect(tester.takeException(), isNull);
    expect(chip(0).left, 0);
  });
}
