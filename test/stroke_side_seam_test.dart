import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A shrink-wrapped row with a one-side stroke ends at a fractional x. The
/// stroke was painted as a drawDRRect whose outer and inner rects shared
/// that right edge; GPU backends antialias each rect on its own and left a
/// faint vertical line there. Only the band itself is painted now.
void main() {
  final GlobalKey boundary = GlobalKey();

  Future<void> pumpRow(WidgetTester tester, StrokeSide side) async {
    final TextNode text = TextNode(
      id: 't',
      name: 't',
      basicBoxLocal: NodeBox(0, 0, 60, 16),
      data: 'Hive',
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      // 13.3px glyphs make the shrink-wrapped row fractionally wide.
      textMixedProps: [StartEndProp(start: 0, end: 4, fontSize: 13.3)],
    )..parentID = 'row';
    final RowColumnNode row = RowColumnNode(
      id: 'row',
      name: 'Row',
      basicBoxLocal: NodeBox(0, 0, 80, 30),
      children: const ['t'],
      rowColumnType: RowColumnType.row,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.fixed,
      padding: EdgeInsetsModel.symmetric(horizontal: 3.3),
      strokes: [PaintModel.solid(id: 's', color: ColorRGB.fromHex('#000000'))],
      strokeWeight: 1.2,
      strokeAlign: StrokeAlignC.inside,
      strokeSide: side,
    )..parentID = kRootNode;
    final NodeRegistry registry = NodeRegistry()
      ..setNodes({for (final BaseNode n in <BaseNode>[row, text]) n.id: n});
    final PassiveNodeTransformerManager manager = PassiveNodeTransformerManager(
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
              key: boundary,
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 120,
                  height: 40,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Builder(
                      builder: (context) => manager.buildWidgetFromNode(
                        row,
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
    );
  }

  Finder strokePaint() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is StrokePainter,
  );

  for (final StrokeSide side in const [StrokeSide.top, StrokeSide.bottom]) {
    testWidgets('a shrink-wrapped row with a ${side.name} stroke paints no '
        'line at its right edge', (tester) async {
      await pumpRow(tester, side);
      final Size size = tester.getSize(strokePaint());
      expect(
        size.width,
        isNot(size.width.roundToDouble()),
        reason: 'the row should end at a fractional x for this check',
      );

      // Only the 1.2px band is painted: no shape with an edge at the right
      // edge below it.
      final double top = side == StrokeSide.top ? 0 : size.height - 1.2;
      expect(
        strokePaint(),
        paints..rect(rect: Rect.fromLTWH(0, top, size.width, 1.2)),
      );
      expect(strokePaint(), isNot(paints..drrect()));

      // The pixels at the right edge, away from the band, are background.
      final RenderRepaintBoundary render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = (await tester.runAsync(() => render.toImage()))!;
      final ByteData pixels = (await tester.runAsync<ByteData?>(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final int edge = size.width.floor();
      for (final int y in const [8, 15, 22]) {
        expect(
          pixels.getUint32((y * 120 + edge) * 4),
          0xFFFFFFFF,
          reason: 'pixel ($edge, $y)',
        );
      }
    });
  }
}
