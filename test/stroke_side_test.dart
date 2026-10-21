import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode rectangle({
  required StrokeSide side,
  StrokeAlignC align = StrokeAlignC.inside,
  double radius = 0,
  List<double> dashPattern = const [],
}) => RectangleNode(
  id: 'card',
  name: 'Card',
  basicBoxLocal: NodeBox(0, 0, 100, 40),
  cornerRadius: CornerRadius.all(RadiusModel.circular(radius)),
  strokes: [PaintModel.solid(id: 'stroke', color: ColorRGB.fromHex('#C8643B'))],
  strokeWeight: 2,
  strokeAlign: align,
  strokeSide: side,
  dashPattern: dashPattern,
)..parentID = kRootNode;

Future<void> pumpNode(WidgetTester tester, BaseNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
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
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
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

Finder borderBox() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).border != null,
);

void main() {
  group('strokeBandInsets', () {
    test('splits the width by alignment on the named side only', () {
      final inside = strokeBandInsets(
        side: StrokeSide.top,
        width: 2,
        align: StrokeAlignC.inside,
      );
      expect(inside.inset, const EdgeInsets.only(top: 2));
      expect(inside.outset, EdgeInsets.zero);

      final center = strokeBandInsets(
        side: StrokeSide.left,
        width: 2,
        align: StrokeAlignC.center,
      );
      expect(center.inset, const EdgeInsets.only(left: 1));
      expect(center.outset, const EdgeInsets.only(left: 1));

      final outside = strokeBandInsets(
        side: StrokeSide.all,
        width: 2,
        align: StrokeAlignC.outside,
      );
      expect(outside.inset, EdgeInsets.zero);
      expect(outside.outset, const EdgeInsets.all(2));
    });
  });

  testWidgets('A top inside stroke covers only the top band and tapers into '
      'rounded corners', (tester) async {
    await pumpNode(tester, rectangle(side: StrokeSide.top, radius: 8));
    expect(tester.takeException(), isNull);
    expect(borderBox(), findsNothing);
    expect(
      strokePaint(),
      paints..drrect(
        outer: RRect.fromLTRBR(0, 0, 100, 40, const Radius.circular(8)),
        inner: RRect.fromLTRBAndCorners(
          0,
          2,
          100,
          40,
          topLeft: const Radius.elliptical(8, 6),
          topRight: const Radius.elliptical(8, 6),
          bottomRight: const Radius.circular(8),
          bottomLeft: const Radius.circular(8),
        ),
      ),
    );
  });

  testWidgets('A bottom outside stroke on a sharp box stays sharp', (
    tester,
  ) async {
    await pumpNode(
      tester,
      rectangle(side: StrokeSide.bottom, align: StrokeAlignC.outside),
    );
    expect(tester.takeException(), isNull);
    expect(
      strokePaint(),
      paints..drrect(
        outer: RRect.fromLTRBR(0, 0, 100, 42, Radius.zero),
        inner: RRect.fromLTRBR(0, 0, 100, 40, Radius.zero),
      ),
    );
  });

  testWidgets('A right center stroke straddles the right edge', (tester) async {
    await pumpNode(
      tester,
      rectangle(side: StrokeSide.right, align: StrokeAlignC.center),
    );
    expect(
      strokePaint(),
      paints..drrect(
        outer: RRect.fromLTRBR(0, 0, 101, 40, Radius.zero),
        inner: RRect.fromLTRBR(0, 0, 99, 40, Radius.zero),
      ),
    );
  });

  testWidgets('A dashed left stroke dashes along the left edge only', (
    tester,
  ) async {
    await pumpNode(
      tester,
      rectangle(side: StrokeSide.left, dashPattern: const [10, 10]),
    );
    expect(
      strokePaint(),
      paints
        ..line(p1: const Offset(1, 0), p2: const Offset(1, 10))
        ..line(p1: const Offset(1, 20), p2: const Offset(1, 30)),
    );
  });

  testWidgets('A solid stroke on all sides stays a Flutter border', (
    tester,
  ) async {
    await pumpNode(tester, rectangle(side: StrokeSide.all, radius: 8));
    final DecoratedBox box = tester.widget<DecoratedBox>(borderBox());
    final Border border = (box.decoration as BoxDecoration).border! as Border;
    expect(border.isUniform, isTrue);
    expect(border.top.width, 2);
    expect(strokePaint(), findsNothing);
  });

  for (final Size size in const [
    Size(390, 844),
    Size(834, 1194),
    Size(1440, 900),
  ]) {
    testWidgets('Every side and alignment paints without errors at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final StrokeSide side in StrokeSide.values) {
        for (final StrokeAlignC align in StrokeAlignC.values) {
          for (final double radius in const [0.0, 8.0, 40.0]) {
            for (final dashes in const [
              <double>[],
              <double>[4, 2],
            ]) {
              await pumpNode(
                tester,
                rectangle(
                  side: side,
                  align: align,
                  radius: radius,
                  dashPattern: dashes,
                ),
              );
              expect(tester.takeException(), isNull);
              final Size box = tester.getSize(
                find
                    .byWidgetPredicate(
                      (w) => w is Container && w.constraints != null,
                    )
                    .first,
              );
              expect(box, const Size(100, 40));
            }
          }
        }
      }
    });
  }
}
