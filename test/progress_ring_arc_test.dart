import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProgressBarNode arc({
  Map<String, String> variables = const {},
  ArcFit fit = ArcFit.circle,
}) => ProgressBarNode(
  id: 'seg',
  name: 'Segment',
  basicBoxLocal: NodeBox(0, 0, 200, 200),
  currentValue: 0.5,
  properties: ProgressBarProperties(
    shape: ProgressBarShape.arc,
    maxValue: 1,
    arcStartAngle: -90,
    arcSweepAngle: 90,
    arcStrokeWidth: 10,
    arcFit: fit,
    arcRoundCaps: true,
    progressEndColor: ColorRGBA.white,
    arcGlow: 8,
    arcHeadDot: true,
  ),
)..variables.addAll(variables);

void main() {
  test(
    'a circle-fitted arc shares the ring of its box, whatever its sweep',
    () {
      for (final double sweep in [30, 90, 250]) {
        final g = ArcProgressPainter.arcGeometry(
          const Size(200, 160),
          arc().properties.copyWith(arcSweepAngle: sweep),
        );
        expect(g.center, const Offset(100, 80));
        expect(g.radius, 75); // 160 / 2 - 10 / 2
      }
    },
  );

  test('an arc-fitted quarter arc is scaled up to fill the box instead', () {
    final g = ArcProgressPainter.arcGeometry(
      const Size(200, 200),
      arc(fit: ArcFit.arc).properties,
    );
    expect(g.radius, greaterThan(95));
    expect(g.center, isNot(const Offset(100, 100)));
  });

  test('angles, thickness, max and colors bind to formulas', () {
    final node = arc(
      variables: {
        'arcStartAngle': r'${= -90 + 4 / 16 * 360}',
        'arcSweepAngle': r'${= 7 / 16 * 360}',
        'arcStrokeWidth': r'${= 6}',
        'maxValue': r'${= 2}',
        'progressEndColor': r"${= '#FF0000'}",
      },
    );
    final p = boundArcProperties(node, ScopedValues.empty());
    expect(p.arcStartAngle, 0);
    expect(p.arcSweepAngle, closeTo(157.5, 1e-9));
    expect(p.arcStrokeWidth, 6);
    expect(p.maxValue, 2);
    expect(p.progressEndColor?.r, closeTo(1, 1e-6));
    expect(p.progressEndColor?.g, 0);
  });

  test('without bindings the node properties are used as they are', () {
    final node = arc();
    expect(
      identical(
        boundArcProperties(node, ScopedValues.empty()),
        node.properties,
      ),
      isTrue,
    );
  });

  test('ring properties round-trip through JSON and default off', () {
    final copy = ProgressBarNode.fromJson(arc().toJson());
    expect(copy.properties.arcFit, ArcFit.circle);
    expect(copy.properties.arcRoundCaps, isTrue);
    expect(copy.properties.arcGlow, 8);
    expect(copy.properties.arcHeadDot, isTrue);
    expect(copy.properties.progressEndColor, ColorRGBA.white);
    final plain = ProgressBarProperties();
    expect(plain.arcFit, ArcFit.arc);
    expect(plain.toJson().containsKey('arcFit'), isFalse);
  });

  testWidgets('a glowing, round-capped gradient arc with a head dot paints', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: PassiveProgressBarWidget(
              node: arc(),
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              scopedValues: ScopedValues.empty(),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
