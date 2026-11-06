import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an angular gradient stroke builds a gradient painter, not a crash', () {
    final node = RectangleNode(
      id: 'spinner',
      name: 'Spinner',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
      strokeWeight: 2,
      strokes: [
        PaintModel(
          id: 'ring',
          type: PaintType.gradientAngular,
          gradientStops: [
            ColorStop(position: 0, color: ColorRGBA(r: 0, g: 1, b: 0.5, a: 1)),
            ColorStop(position: 1, color: ColorRGBA(r: 0, g: 1, b: 0.5, a: 0)),
          ],
          gradientTransform: [1, 0, 0, 0, 1, 0],
        ),
      ],
    );
    final widgets = buildStrokes(node, ScopedValues.empty());
    expect(widgets, hasLength(1));
    final painter =
        (((widgets.single as Positioned).child as IgnorePointer).child
                    as CustomPaint)
                .painter
            as StrokePainter;
    expect(painter.gradient, isA<SweepGradient>());
  });
}
