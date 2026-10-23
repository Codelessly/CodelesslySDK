import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf, pumpLayouts;

PaintModel sweep() => PaintModel(
  id: 'bezel',
  type: PaintType.gradientAngular,
  visible: true,
  opacity: 1,
  gradientTransform: const [1, 0, 0, 1, 0, 0],
  gradientStops: const [
    ColorStop(position: 0, color: ColorRGBA(r: 0.6, g: 0.5, b: 0.2, a: 1)),
    ColorStop(position: 1, color: ColorRGBA(r: 0.9, g: 0.8, b: 0.5, a: 1)),
  ],
);

void main() {
  testWidgets('a gradient stroke paints with the gradient instead of failing', (
    tester,
  ) async {
    final RectangleNode ring = RectangleNode(
      id: 'ring',
      name: 'Bezel',
      basicBoxLocal: NodeBox(0, 0, 120, 120),
      strokes: [sweep()],
      strokeWeight: 6,
    )..parentID = 'mainBody';
    await pumpLayouts(tester, [
      layoutOf('layout', [
        canvas('main', 'mainBody'),
        body('mainBody', 'main', ['ring']),
        ring,
      ]),
    ]);
    await tester.pump();
    expect(tester.takeException(), isNull);

    final Iterable<StrokePainter> painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<StrokePainter>();
    expect(painters.single.gradient, isA<SweepGradient>());
  });
}
