import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpGauge(WidgetTester tester, GaugeNode node) =>
      tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Center(
              child: PassiveRadialGaugeWidget(
                node: node,
                settings: const WidgetBuildSettings(debugLabel: 'radial test'),
              ),
            ),
          ),
        ),
      );

  GaugeNode radial(
    GaugeProperties props, {
    Map<String, String> variables = const {},
  }) => GaugeNode(
    id: 'radial',
    name: 'Radial',
    basicBoxLocal: NodeBox(0, 0, 220, 185),
    value: 72,
    properties: props,
  )..variables.addAll(variables);

  RadialGaugePainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<RadialGaugePainter>()
      .single;

  testWidgets('normalizes static value and resolves its zone color', (
    tester,
  ) async {
    final props = GaugeProperties(animate: false);
    await pumpGauge(tester, radial(props));
    expect(painter(tester).fraction, closeTo(0.72, 1e-9));
    expect(props.colorFor(72), kDefaultGaugeZones[1].color);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reads bound value and clamps it to the dial range', (
    tester,
  ) async {
    await pumpGauge(
      tester,
      radial(
        GaugeProperties(animate: false),
        variables: {'value': r'${= 80 + 7}'},
      ),
    );
    expect(painter(tester).fraction, closeTo(0.87, 1e-9));
    await pumpGauge(
      tester,
      radial(
        GaugeProperties(animate: false),
        variables: {'value': r'${= 150}'},
      ),
    );
    expect(painter(tester).fraction, 1);
  });

  for (final segments in [0, 40]) {
    testWidgets(
      'paints $segments segments with zones, ticks, labels, target and needle',
      (tester) async {
        await pumpGauge(
          tester,
          radial(
            GaugeProperties(
              animate: false,
              segments: segments,
              majorTicks: 10,
              minorTicks: 1,
              showNeedle: true,
              showTarget: true,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('paints without optional decorations', (tester) async {
    await pumpGauge(
      tester,
      radial(
        GaugeProperties(
          animate: false,
          segments: 0,
          zoneThickness: 0,
          majorTicks: 0,
          labels: [],
          showNeedle: false,
          showTarget: false,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
