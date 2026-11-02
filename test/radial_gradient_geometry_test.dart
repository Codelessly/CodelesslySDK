import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<ColorStop> glow = [
  ColorStop(position: 0, color: ColorRGBA(r: 1, g: 0.8, b: 0.3, a: 1)),
  ColorStop(position: 1, color: ColorRGBA(r: 0, g: 0, b: 0, a: 0)),
];

void main() {
  test('a radial gradient takes its radius and centre from the paint', () {
    final RadialGradient gradient =
        retrieveGradient(
              PaintModel.radialGradient(
                id: 'g',
                gradientStops: glow,
                gradientRadius: 1.2,
                gradientCenterX: 0.5,
                gradientCenterY: -1,
              ),
            )!
            as RadialGradient;
    expect(gradient.radius, 1.2);
    expect(gradient.center, const Alignment(0.5, -1));
    // An off-centre circle isn't turned about the box centre.
    expect(gradient.transform, isNull);
  });

  test('without them it stays centred with the default radius', () {
    final RadialGradient gradient =
        retrieveGradient(
              PaintModel.radialGradient(id: 'g', gradientStops: glow),
            )!
            as RadialGradient;
    expect(gradient.radius, 0.5);
    expect(gradient.center, Alignment.center);
    expect(gradient.transform, isA<GradientRotation>());
  });

  test('a zero or negative radius falls back to the default', () {
    final RadialGradient gradient =
        retrieveGradient(
              PaintModel.radialGradient(
                id: 'g',
                gradientStops: glow,
                gradientRadius: 0,
              ),
            )!
            as RadialGradient;
    expect(gradient.radius, 0.5);
  });

  test('an angular gradient takes the centre too', () {
    final SweepGradient gradient =
        retrieveGradient(
              PaintModel(
                id: 'g',
                type: PaintType.gradientAngular,
                gradientStops: glow,
                gradientCenterX: -1,
                gradientCenterY: 1,
              ),
            )!
            as SweepGradient;
    expect(gradient.center, const Alignment(-1, 1));
  });

  test('radius and centre survive JSON, copyWith and sanitize', () {
    final PaintModel paint = PaintModel.fromJson({
      'id': 'g',
      'type': 'gradientRadial',
      'gradientStops': [for (final s in glow) s.toJson()],
      'gradientRadius': 0.9,
      'gradientCenterX': 0,
      'gradientCenterY': -0.6,
    });
    expect(paint.gradientRadius, 0.9);
    expect(paint.gradientCenterY, -0.6);
    expect(PaintModel.fromJson(paint.toJson()), paint);
    expect(paint.toJson()['gradientRadius'], 0.9);
    expect(paint.sanitize().gradientRadius, 0.9);
    expect(paint.copyWith(gradientRadius: 2).gradientRadius, 2);
    final PaintModel cleared = paint.copyWith(clearGradientGeometry: true);
    expect(cleared.gradientRadius, isNull);
    expect(cleared.gradientCenterY, isNull);
    expect(cleared.toJson().containsKey('gradientRadius'), isFalse);
    expect(paint.isEquivalentTo(cleared), isFalse);
  });

  testWidgets('a rectangle draws its radial fill at the given radius', (
    tester,
  ) async {
    final RectangleNode node = RectangleNode(
      id: 'r',
      name: 'Glow',
      basicBoxLocal: NodeBox(0, 0, 200, 100),
      fills: [
        PaintModel.radialGradient(
          id: 'g',
          gradientStops: glow,
          gradientRadius: 1.5,
          gradientCenterY: -1,
        ),
      ],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: buildFill(
              node,
              index: 0,
              useInk: false,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              scopedValues: ScopedValues.empty(),
            ),
          ),
        ),
      ),
    );
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    final RadialGradient gradient =
        (box.decoration as BoxDecoration).gradient! as RadialGradient;
    expect(gradient.radius, 1.5);
    expect(gradient.center, const Alignment(0, -1));
  });
}
