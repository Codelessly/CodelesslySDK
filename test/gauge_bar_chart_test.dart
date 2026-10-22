import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  ChangeNotifierProvider<CodelesslyContext>.value(
    value: CodelesslyContext.empty(),
    child: MaterialApp(home: Center(child: child)),
  ),
);

GaugeNode gauge(GaugeProperties props, {Map<String, String> variables = const {}}) =>
    GaugeNode(
      id: 'gauge',
      name: 'Gauge',
      basicBoxLocal: NodeBox(0, 0, 168, 144),
      value: 20,
      limit: 30,
      properties: props,
    )..variables.addAll(variables);

GaugePainter painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<GaugePainter>()
    .single;

void main() {
  group('Gauge', () {
    testWidgets('fills to its static value and limit', (tester) async {
      await pump(
        tester,
        PassiveGaugeWidget(
          node: gauge(GaugeProperties(animate: false)),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      final GaugePainter painter = painterOf(tester);
      expect(painter.fraction, closeTo(0.2, 1e-9));
      expect(painter.limit, closeTo(0.3, 1e-9));
    });

    testWidgets('reads value, limit and colors from formulas', (tester) async {
      await pump(
        tester,
        PassiveGaugeWidget(
          node: gauge(
            GaugeProperties(animate: false, min: 0, max: 1),
            variables: {
              'value': r'${= 0.8 + 0.07}',
              'limit': r'${= 0.75}',
              'color': r'${= 0.87 > 0.85 ? "#FF4D4F" : "#3DD68C"}',
              'limitColor': '#F2C230',
            },
          ),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      final GaugePainter painter = painterOf(tester);
      expect(painter.fraction, closeTo(0.87, 1e-9));
      expect(painter.limit, closeTo(0.75, 1e-9));
      expect(painter.color.toARGB32(), 0xFFFF4D4F);
    });

    testWidgets('a limit bound to nothing hides the marker', (tester) async {
      await pump(
        tester,
        PassiveGaugeWidget(
          node: gauge(
            GaugeProperties(animate: false),
            variables: {'limit': r'${= rules.missing}'},
          ),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      expect(painterOf(tester).limit, isNull);
    });

    for (final shape in GaugeShape.values) {
      for (final segments in [0, 24]) {
        testWidgets('paints a ${shape.name} with $segments segments', (
          tester,
        ) async {
          await pump(
            tester,
            RepaintBoundary(
              child: PassiveGaugeWidget(
                node: gauge(
                  GaugeProperties(
                    shape: shape,
                    segments: segments,
                    ticks: 10,
                    majorTickEvery: 5,
                    limitStyle: GaugeLimitStyle.dashed,
                    limitPointer: true,
                    edgeWidth: 2,
                    fillStartOpacity: 0.5,
                    inset: 3,
                    borderColor: ColorRGBA.white,
                    backgroundColor: ColorRGBA.black,
                    animate: false,
                  ),
                ),
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Bar chart', () {
    BarChartNode chart({Map<String, String> variables = const {}}) =>
        BarChartNode(
          id: 'chart',
          name: 'Chart',
          basicBoxLocal: NodeBox(0, 0, 300, 140),
          values: [10, 20, null],
          labels: ['a', '', 'c'],
          highlight: 1,
          properties: BarChartProperties(
            max: 40,
            animate: false,
            gridLabels: ['1', '2', '3'],
          ),
        )..variables.addAll(variables);

    double barHeight(WidgetTester tester, int index) {
      final bars = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .toList();
      return tester.getSize(find.byWidget(bars[index])).height;
    }

    testWidgets('scales bars to max and dims all but the highlight', (
      tester,
    ) async {
      await pump(
        tester,
        PassiveBarChartWidget(
          node: chart(),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      expect(find.text('a'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(barHeight(tester, 1), closeTo(barHeight(tester, 0) * 2, 0.01));
      final bars = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(bars[0].color!.a, lessThan(bars[1].color!.a));
    });

    testWidgets('reads values, labels and highlight from formulas', (
      tester,
    ) async {
      await pump(
        tester,
        PassiveBarChartWidget(
          node: chart(
            variables: {
              'values': r'${= [40, 10]}',
              'labels': r'${= ["x", "y"]}',
              'highlight': r'${= 0}',
            },
          ),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      expect(find.text('x'), findsOneWidget);
      expect(find.text('y'), findsOneWidget);
      expect(find.text('a'), findsNothing);
      expect(barHeight(tester, 0), closeTo(barHeight(tester, 1) * 4, 0.01));
    });
  });
}
