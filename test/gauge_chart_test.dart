import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:codelessly_sdk/src/transformers/utils/node_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Observable<VariableData> variable(
  String name,
  Object? value,
  VariableType type,
) => Observable(VariableData(id: name, name: name, value: value, type: type));

Future<void> pump(
  WidgetTester tester,
  CodelesslyContext context,
  Widget child,
) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: context,
      child: MaterialApp(
        home: ActionChainHost(
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}

ChartNode hourly({
  Map<String, String> variables = const {},
  List<Reaction> reactions = const [],
}) => ChartNode(
  id: 'chart',
  name: 'Hourly',
  basicBoxLocal: NodeBox(0, 0, 400, 220),
  properties: ChartProperties(),
  reactions: reactions,
)..variables.addAll(variables);

void main() {
  test(
    'series and plot charts, radial and meter gauges keep separate schemas',
    () {
      expect(hourly().type, 'chart');
      expect(hourly().toJson()['chartKind'], 'series');
      expect(PlotChartNode.empty().type, 'chart');
      expect(PlotChartNode.empty().toJson()['chartKind'], 'plot');
      expect(GaugeNode.empty().type, 'gauge');
      expect(GaugeNode.empty().toJson()['gaugeKind'], 'radial');
      expect(GaugeMeterNode.empty().type, 'gauge');
      expect(GaugeMeterNode.empty().toJson()['gaugeKind'], 'meter');
    },
  );

  group('niceAxis', () {
    test('rounds up to 1, 2, 2.5 or 5 times a power of ten', () {
      expect(niceAxis(830, 4), (1000.0, 250.0));
      expect(niceAxis(3100, 4), (4000.0, 1000.0));
      expect(niceAxis(95, 5), (100.0, 20.0));
      expect(niceAxis(0, 4), (4.0, 1.0));
    });

    test('compact labels', () {
      expect(compactNumber(750), '750');
      expect(compactNumber(1000), '1.0k');
      expect(compactNumber(12000), '12k');
    });
  });

  group('RadialGaugePainter', () {
    test('uses a fraction of the radial gauge range', () {
      final props = GaugeProperties(min: 20, max: 120);
      final painter = RadialGaugePainter(
        props: props,
        fraction: props.fraction(70),
      );
      expect(painter.fraction, 0.5);
      expect(
        painter.shouldRepaint(RadialGaugePainter(props: props, fraction: 0)),
        isTrue,
      );
    });
  });

  testWidgets('a gauge reads its bound value and paints', (tester) async {
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['oee'] = variable('oee', 72.6, VariableType.decimal);
    final GaugeNode node = GaugeNode(
      id: 'gauge',
      name: 'Gauge',
      basicBoxLocal: NodeBox(0, 0, 220, 185),
      properties: GaugeProperties(animate: false),
    )..variables['value'] = r'${oee}';
    await pump(
      tester,
      context,
      PassiveRadialGaugeWidget(
        node: node,
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    final CustomPaint paint = tester.widget(
      find
          .descendant(
            of: find.byType(PassiveRadialGaugeWidget),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      (paint.painter! as RadialGaugePainter).fraction,
      closeTo(0.726, 1e-6),
    );
    expect(tester.takeException(), isNull);
  });

  group('ChartSeriesPainter', () {
    final ChartSeriesPainter painter = ChartSeriesPainter(
      props: ChartProperties(),
      data: kDefaultChartSampleData,
    );

    test('categories split the plot evenly', () {
      const Size size = Size(400, 220);
      final Rect plot = painter.plotRect(size);
      expect(plot.left, 44);
      expect(plot.bottom, 198);
      final double catW = plot.width / 6;
      expect(painter.categoryAt(Offset(plot.left + 1, 100), size), 0);
      expect(painter.categoryAt(Offset(plot.left + catW * 2.5, 100), size), 2);
      expect(painter.categoryAt(Offset(plot.right - 1, 100), size), 5);
      expect(painter.categoryAt(const Offset(10, 100), size), isNull);
    });

    test('lines put points on slot boundaries', () {
      final ChartSeriesPainter line = ChartSeriesPainter(
        props: ChartProperties(chartType: ChartType.line, xSlots: 8),
        data: List.generate(7, (i) => {'actual': i * 100}),
      );
      const Size size = Size(400, 220);
      final Rect plot = line.plotRect(size);
      expect(
        line.categoryAt(Offset(plot.left + plot.width / 8 * 3, 50), size),
        3,
      );
    });
  });

  testWidgets('a chart reads its bound data and selection', (tester) async {
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['hours'] = variable('hours', [
        {'label': '14', 'good': 500, 'scrap': 4, 'plan': 600},
        {'label': '15', 'good': null, 'scrap': 0, 'plan': 600},
      ], VariableType.list)
      ..variables['selected'] = variable('selected', 1, VariableType.integer);
    await pump(
      tester,
      context,
      PassiveChartSeriesWidget(
        node: hourly(
          variables: {'data': r'${hours}', 'selectedIndex': r'${selected}'},
        ),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    final ChartSeriesPainter painter =
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(PassiveChartSeriesWidget),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as ChartSeriesPainter;
    expect(painter.data.length, 2);
    expect(painter.data[0]['good'], 500);
    expect(painter.selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a bar stores its index and runs changed reactions', (
    tester,
  ) async {
    final Observable<VariableData> selected = variable(
      'selected',
      0,
      VariableType.integer,
    );
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['selected'] = selected;
    await pump(
      tester,
      context,
      SizedBox(
        width: 400,
        height: 220,
        // The transformer manager provides the node's state, which
        // `${value}` reads.
        child: Builder(
          builder: (context) {
            final ChartNode node = hourly(
              reactions: [
                Reaction(
                  trigger: TriggerModel(type: TriggerType.changed),
                  action: SetVariableAction(
                    variable: VariableData(
                      id: 'selected',
                      name: 'selected',
                      type: VariableType.integer,
                    ),
                    newValue: r'${value}',
                  ),
                ),
              ],
            );
            return NodeStateProvider(
              node: node,
              child: PassiveChartSeriesWidget(
                node: node,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            );
          },
        ),
      ),
    );
    final Rect box = tester.getRect(find.byType(PassiveChartSeriesWidget));
    // Plot starts 44 px in; six categories over the rest. Tap the fourth.
    final double catW = (box.width - 44) / 6;
    await tester.tapAt(Offset(box.left + 44 + catW * 3.5, box.center.dy));
    await tester.pumpAndSettle();
    expect(selected.value.getValue(), 3);
  });

  testWidgets('an unbound chart shows its sample data', (tester) async {
    await pump(
      tester,
      CodelesslyContext.empty(),
      PassiveChartSeriesWidget(
        node: hourly(),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    final ChartSeriesPainter painter =
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(PassiveChartSeriesWidget),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as ChartSeriesPainter;
    expect(painter.data.length, kDefaultChartSampleData.length);
  });

  test('a repeating linear gradient spans 1 / scale of the box', () {
    final PaintModel stripes = PaintModel.linearGradient(
      id: 'stripes',
      gradientTileMode: GradientTileMode.repeated,
      // Scale 10: the gradient repeats ten times across the box.
      gradientTransform: const [10, 0, 0, 10, 0, 0],
      gradientStops: const [
        ColorStop(position: 0, color: ColorRGBA.black),
        ColorStop(position: 0.5, color: ColorRGBA.black),
        ColorStop(position: 0.5, color: ColorRGBA.white),
        ColorStop(position: 1, color: ColorRGBA.white),
      ],
    );
    final LinearGradient gradient =
        retrieveGradient(stripes)! as LinearGradient;
    expect(gradient.tileMode, TileMode.repeated);
    expect(gradient.begin, Alignment.centerLeft);
    expect((gradient.end as Alignment).x, closeTo(-0.8, 1e-9));

    final LinearGradient clamped =
        retrieveGradient(
              PaintModel.linearGradient(
                id: 'c',
                gradientStops: stripes.gradientStops,
              ),
            )!
            as LinearGradient;
    expect(clamped.tileMode, TileMode.clamp);
    expect(clamped.end, Alignment.centerRight);
  });
}
