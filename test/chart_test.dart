import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A 240 x 100 tide chart: 10 pixels per hour, selection clamped to 5..20.
PlotChartNode tideChart({
  Map<String, String> variables = const {},
  List<Reaction> reactions = const [],
  double? selectedX,
  bool selectable = true,
}) => PlotChartNode(
  id: 'tide',
  name: 'Tide',
  basicBoxLocal: NodeBox(0, 0, 240, 100),
  selectedX: selectedX,
  reactions: reactions,
  properties: PlotChartProperties(
    points: [for (int i = 0; i <= 24; i++) 1],
    xMax: 24,
    fillColor: ColorRGBA.grey10,
    gridStepX: 3,
    gridLabels: const ['3a', '6a', '9a', '12p', '3p', '6p', '9p'],
    ranges: const [
      PlotChartRange(from: 0, to: 5),
      PlotChartRange(from: 21, to: 24),
    ],
    markers: const [PlotChartMarker(x: 4.2, label: '4:12am')],
    referenceX: 7.67,
    selectionStep: 1,
    selectionMin: 5,
    selectionMax: 20,
    selectable: selectable,
  ),
)..variables.addAll(variables);

Observable<VariableData> variable(
  String name,
  Object? value, [
  VariableType type = VariableType.text,
]) => Observable(VariableData(id: name, name: name, value: value, type: type));

Reaction onChanged(String variableName) => Reaction(
  trigger: TriggerModel(type: TriggerType.changed),
  action: SetVariableAction(
    variable: VariableData(id: variableName, name: variableName),
    newValue: r'${value}',
  ),
);

Future<void> pumpChart(
  WidgetTester tester,
  PlotChartNode node,
  CodelesslyContext codelesslyContext,
) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: ActionChainHost(
          child: Scaffold(
            body: Align(
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
      ),
    ),
  );
}

final Finder chartPaint = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is ChartPainter,
);

ChartPainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(chartPaint).painter! as ChartPainter;

/// Taps the chart [hours] from its left edge.
Future<void> tapAt(WidgetTester tester, double hours) async {
  await tester.tapAt(tester.getTopLeft(chartPaint) + Offset(hours * 10, 50));
  await tester.pumpAndSettle();
}

void main() {
  test('plot chart JSON keeps its own schema and painted details', () {
    final original = tideChart(selectedX: 7);
    final json = original.toJson();
    expect(json['type'], 'chart');
    expect(json['chartKind'], 'plot');
    final restored = PlotChartNode.fromJson(json);
    expect(restored.type, 'chart');
    expect(restored.selectedX, 7);
    expect(restored.properties.points, hasLength(25));
    expect(restored.properties.ranges, hasLength(2));
    expect(restored.properties.markers.single.label, '4:12am');
    expect(restored.properties.gridLabels, contains('12p'));
  });

  testWidgets('paints the bound points and selection', (tester) async {
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['curve'] = variable('curve', [
        0,
        1.5,
        '3',
        2,
      ], VariableType.list)
      ..variables['hour'] = variable('hour', 7, VariableType.integer);
    await pumpChart(
      tester,
      tideChart(variables: {'points': r'${curve}', 'selectedX': r'${hour}'}),
      codelesslyContext,
    );

    expect(chartPaint, findsOneWidget);
    expect(tester.getSize(chartPaint), const Size(240, 100));
    expect(painter(tester).points, [0, 1.5, 3, 2]);
    expect(painter(tester).selectedX, 7);
    expect(painter(tester).markers.single.label, '4:12am');
    expect(tester.takeException(), isNull);
  });

  testWidgets('points and markers can come from a formula', (tester) async {
    await pumpChart(
      tester,
      tideChart(
        variables: {'points': r'${= [1, 2, 3]}', 'markers': r'${markers}'},
      ),
      CodelesslyContext.empty()
        ..variables['markers'] = variable('markers', [
          {'x': 1, 'label': 'high', 'position': 'below'},
          'not a marker',
        ], VariableType.list),
    );

    expect(painter(tester).points, [1, 2, 3]);
    final PlotChartMarker marker = painter(tester).markers.single;
    expect(marker.label, 'high');
    expect(marker.position, PlotChartMarkerPosition.below);
  });

  testWidgets('tapping selects the snapped hour, writes the bound variable '
      'and fires changed', (tester) async {
    final hour = variable('hour', 7, VariableType.integer);
    final picked = variable('picked', '');
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['hour'] = hour
      ..variables['picked'] = picked;
    await pumpChart(
      tester,
      tideChart(
        variables: {'selectedX': r'${hour}'},
        reactions: [onChanged('picked')],
      ),
      codelesslyContext,
    );

    await tapAt(tester, 12.4);
    expect(hour.value.value.typedValue<int>(), 12);
    expect(picked.value.value, '12');
    expect(painter(tester).selectedX, 12);

    // Clamped to selectionMin and selectionMax.
    await tapAt(tester, 1.5);
    expect(hour.value.value.typedValue<int>(), 5);
    expect(picked.value.value, '5');
    await tapAt(tester, 23.5);
    expect(hour.value.value.typedValue<int>(), 20);
    expect(painter(tester).selectedX, 20);
  });

  testWidgets('dragging scrubs the selection', (tester) async {
    final List<String> fired = [];
    final picked = variable('picked', '');
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['picked'] = picked;
    picked.addListener(() => fired.add(picked.value.value.toString()));
    await pumpChart(
      tester,
      tideChart(selectedX: 7, reactions: [onChanged('picked')]),
      codelesslyContext,
    );
    expect(painter(tester).selectedX, 7);

    final TestGesture gesture = await tester.startGesture(
      tester.getTopLeft(chartPaint) + const Offset(75, 50),
    );
    for (double dx = 75; dx <= 115; dx += 5) {
      await gesture.moveTo(tester.getTopLeft(chartPaint) + Offset(dx, 50));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // Without a bound variable the chart keeps the selection itself, and
    // fires once per hour it moves to (the drag starts past the touch slop).
    expect(painter(tester).selectedX, 11);
    expect(fired, ['9', '10', '11']);
  });

  testWidgets('a chart that is not selectable ignores taps', (tester) async {
    final picked = variable('picked', '');
    await pumpChart(
      tester,
      tideChart(
        selectedX: 7,
        selectable: false,
        reactions: [onChanged('picked')],
      ),
      CodelesslyContext.empty()..variables['picked'] = picked,
    );
    await tapAt(tester, 12.4);
    expect(painter(tester).selectedX, 7);
    expect(picked.value.value, '');
  });

  testWidgets('paints without points, grid or labels', (tester) async {
    await pumpChart(
      tester,
      PlotChartNode(
        id: 'empty',
        name: 'Empty',
        basicBoxLocal: NodeBox(0, 0, 100, 40),
        selectedX: 0,
        properties: PlotChartProperties(smooth: true, labelHeight: 0),
      ),
      CodelesslyContext.empty(),
    );
    expect(chartPaint, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
