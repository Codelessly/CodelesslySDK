import 'dart:convert';
import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Half-hourly tide heights on 2026-10-22, from midnight to midnight.
final List<Map<String, Object>> tides = [
  for (int i = 0; i <= 48; i++)
    {
      't':
          '2026-10-22 ${(i ~/ 2 % 24).toString().padLeft(2, '0')}:'
          '${i.isOdd ? '30' : '00'}',
      'ft': i <= 24 ? i / 4 : (48 - i) / 4,
    },
]..last['t'] = '2026-10-23 00:00';

double ms(String date) => LineChartGeometry.parseX(date)!;

LineChartNode chart({
  Map<String, String> variables = const {},
  LineChartProperties? properties,
}) => LineChartNode(
  id: 'chart',
  name: 'Chart',
  basicBoxLocal: NodeBox(0, 0, 400, 240),
  properties: properties,
  variables: {...variables},
);

VariableData listVariable(String name, List value) => VariableData(
  id: name,
  name: name,
  value: jsonEncode(value),
  type: VariableType.list,
);

Future<void> pumpChart(
  WidgetTester tester,
  LineChartNode node, {
  List<VariableData> variables = const [],
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: PassiveLineChartWidget(
              node: node,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              variablesOverrides: variables,
            ),
          ),
        ),
      ),
    ),
  );
}

LineChartPainter painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<LineChartPainter>()
    .single;

void main() {
  group('LineChartGeometry', () {
    test('reads numbers, numeric strings and wall-clock dates', () {
      expect(LineChartGeometry.parseX(3), 3);
      expect(LineChartGeometry.parseX('2.5'), 2.5);
      final double space = ms('2026-10-22 00:30');
      expect(space, DateTime.utc(2026, 10, 22, 0, 30).millisecondsSinceEpoch);
      expect(ms('2026-10-22T00:30:00'), space);
      expect(LineChartGeometry.dateOf(space).hour, 0);
      expect(LineChartGeometry.dateOf(space).minute, 30);
      expect(LineChartGeometry.parseX('soon'), isNull);
      expect(LineChartGeometry.isDate('2026-10-22 00:30'), isTrue);
      expect(LineChartGeometry.isDate('12'), isFalse);
    });

    test('reads and sorts points, skipping invalid items', () {
      final points = LineChartGeometry.points(
        [
          {'x': 2, 'y': '4'},
          {'x': 1, 'y': 1},
          {'x': 'nope', 'y': 1},
          {'x': 3},
          'junk',
        ],
        'x',
        'y',
      );
      expect(points, [const Offset(1, 1), const Offset(2, 4)]);
    });

    test('domain defaults to the data extent and takes overrides', () {
      final points = [const Offset(0, -2), const Offset(10, 6)];
      expect(LineChartGeometry.domain(points), const ChartDomain(0, 10, -2, 6));
      expect(
        LineChartGeometry.domain(points, yMin: -3, xMax: 12),
        const ChartDomain(0, 12, -3, 6),
      );
      expect(
        LineChartGeometry.domain([const Offset(1, 1)]),
        const ChartDomain(0.5, 1.5, 0.5, 1.5),
      );
    });

    test('interpolates linearly and holds the ends', () {
      final points = [
        const Offset(0, 0),
        const Offset(10, 10),
        const Offset(20, 0),
      ];
      expect(LineChartGeometry.interpolate(points, 5), 5);
      expect(LineChartGeometry.interpolate(points, 15), 5);
      expect(LineChartGeometry.interpolate(points, -1), 0);
      expect(LineChartGeometry.interpolate(points, 25), 0);
      expect(LineChartGeometry.interpolate(const [], 1), isNull);
    });

    test('Catmull-Rom control points clamp at the ends', () {
      final points = [
        const Offset(0, 0),
        const Offset(6, 6),
        const Offset(12, 0),
      ];
      final segments = LineChartGeometry.catmullRom(points);
      expect(segments, hasLength(2));
      // p0 is clamped to p1 for the first segment: c1 = p1 + (p2 - p1) / 6.
      expect(segments[0].c1, const Offset(1, 1));
      // c2 = p2 - (p3 - p1) / 6 = (6, 6) - (12, 0) / 6.
      expect(segments[0].c2, const Offset(4, 6));
      expect(segments[0].end, const Offset(6, 6));
      // The last segment's p3 is clamped to p2.
      expect(segments[1].c2, const Offset(11, 1));
      expect(segments[1].end, const Offset(12, 0));
    });

    test('maps data to pixels inside the plot', () {
      final plot = LineChartGeometry.plotRect(
        const Size(400, 240),
        left: 44,
        top: 30,
        right: 14,
        bottom: 30,
      );
      expect(plot, const Rect.fromLTRB(44, 30, 386, 210));
      final scale = ChartScale(const ChartDomain(0, 10, 0, 6), plot);
      expect(scale.toPixel(const Offset(0, 0)), const Offset(44, 210));
      expect(scale.toPixel(const Offset(10, 6)), const Offset(386, 30));
      expect(scale.xAt(44 + 342 / 2), 5);
      expect(scale.xAt(-100), 0);
    });

    test('formats the readout for a date axis', () {
      final points = LineChartGeometry.points(tides, 't', 'ft');
      final domain = LineChartGeometry.domain(points);
      final (String x, String y) = LineChartGeometry.readout(
        points,
        ms('2026-10-22 04:30'),
        domain: domain,
        isDate: true,
        xFormat: 'h:mm a',
        ySuffix: ' ft',
        trend: true,
      );
      expect(x, '4:30 AM');
      expect(y, '2.3 ft ↑');

      final (String x2, String y2) = LineChartGeometry.readout(
        points,
        ms('2026-10-22 16:15'),
        domain: domain,
        isDate: true,
        xFormat: 'EEE h:mm a',
        yScale: 0.3048,
        yDecimals: 2,
        ySuffix: ' m',
        trend: true,
      );
      expect(x2, 'Thu 4:15 PM');
      // 16:15 is 32.5 half hours, (48 - 32.5) / 4 = 3.875 ft = 1.18 m.
      expect(y2, '1.18 m ↓');
    });

    test('formats number axes and places the readout card', () {
      expect(LineChartGeometry.formatX(3, isDate: false), '3');
      expect(LineChartGeometry.formatX(2.5, isDate: false), '2.5');
      const plot = Rect.fromLTRB(44, 30, 386, 210);
      expect(
        LineChartGeometry.readoutRect(
          const Offset(100, 150),
          const Size(80, 40),
          plot,
        ),
        const Rect.fromLTWH(112, 98, 80, 40),
      );
      // Flipped near the right edge and clamped to the plot's top.
      expect(
        LineChartGeometry.readoutRect(
          const Offset(350, 40),
          const Size(80, 40),
          plot,
        ),
        const Rect.fromLTWH(258, 30, 80, 40),
      );
    });

    test('reads colors with opacity and dash patterns', () {
      final color = LineChartGeometry.parseColor('#2A3A44', 0.08)!;
      expect(color.a, closeTo(0.08, 0.001));
      expect((color.r * 255).round(), 0x2A);
      expect(LineChartGeometry.parseColor('#80FF0000')!.a, closeTo(0.5, 0.01));
      expect(LineChartGeometry.parseColor('nope'), isNull);
      expect(LineChartGeometry.parseDash([4, 2], (5, 5)), (4.0, 2.0));
      expect(LineChartGeometry.parseDash(null, (5, 5)), (5.0, 5.0));
    });
  });

  group('PassiveLineChartWidget', () {
    testWidgets('renders bound points, lists and domain overrides', (
      tester,
    ) async {
      await pumpChart(
        tester,
        chart(
          properties: LineChartProperties(
            xField: 't',
            yField: 'ft',
            smooth: true,
          ),
          variables: {
            'data': r'${tides}',
            'yMin': r'${= -1}',
            'yMax': r'${= 7}',
            'xMax': r'${= "2026-10-23 00:00"}',
            'markers': r'${markers}',
            'verticalLines': r'${now}',
          },
        ),
        variables: [
          listVariable('tides', tides),
          listVariable('markers', [
            {'x': '2026-10-22 12:00', 'y': 6, 'label': 'H 6.0', 'above': true},
          ]),
          listVariable('now', [
            {'x': '2026-10-22 09:00', 'label': 'NOW', 'dotOnCurve': true},
          ]),
        ],
      );
      expect(tester.takeException(), isNull);
      final spec = painterOf(tester).spec;
      expect(spec.points, hasLength(49));
      expect(spec.isDate, isTrue);
      expect(
        spec.domain,
        ChartDomain(ms('2026-10-22 00:00'), ms('2026-10-23 00:00'), -1, 7),
      );
      expect(spec.markers.single.label, 'H 6.0');
      expect(spec.verticalLines.single.dotOnCurve, isTrue);
      expect(spec.valueAt(ms('2026-10-22 09:00')), 4.5);
    });

    testWidgets('binds the data list from a formula', (tester) async {
      await pumpChart(
        tester,
        chart(
          variables: {
            'data': r'${= filter(points, p => p.y > 1)}',
            'lineColor': r'${= "#FF0000"}',
          },
        ),
        variables: [
          listVariable('points', [
            {'x': 1, 'y': 0},
            {'x': 2, 'y': 3},
            {'x': 3, 'y': 5},
            {'x': 4, 'y': 2},
          ]),
        ],
      );
      expect(tester.takeException(), isNull);
      final spec = painterOf(tester).spec;
      expect(spec.points, [
        const Offset(2, 3),
        const Offset(3, 5),
        const Offset(4, 2),
      ]);
      expect(spec.isDate, isFalse);
      expect(spec.domain, const ChartDomain(2, 4, 2, 5));
      expect(spec.lineColor.toARGB32(), 0xFFFF0000);
    });

    testWidgets('scrubs with hover and arrow keys and reads out the value', (
      tester,
    ) async {
      final node = chart(
        properties: LineChartProperties(
          xField: 't',
          yField: 'ft',
          scrubEnabled: true,
          scrubStep: 30,
          tooltipYSuffix: ' ft',
          tooltipTrend: true,
          semanticLabel: 'Tide chart',
        ),
        variables: {'data': r'${tides}'},
      );
      await pumpChart(tester, node, variables: [listVariable('tides', tides)]);
      expect(painterOf(tester).cursorX, isNull);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      // Halfway across the plot (44 to 386) is noon.
      await gesture.moveTo(const Offset(44 + 342 / 2, 120));
      await tester.pump();
      expect(painterOf(tester).cursorX, ms('2026-10-22 12:00'));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tide chart')),
        isSemantics(
          label: 'Tide chart',
          value: 'Cursor 12:00 PM, 6.0 ft',
        ),
      );

      // Tap to focus, then step 30 minutes with the arrow keys.
      await gesture.removePointer();
      await tester.tapAt(const Offset(44 + 342 / 4, 120));
      await tester.pump();
      expect(painterOf(tester).cursorX, ms('2026-10-22 06:00'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final double cursor = painterOf(tester).cursorX!;
      expect(cursor, ms('2026-10-22 06:30'));
      expect(painterOf(tester).spec.readout(cursor), ('6:30 AM', '3.3 ft ↑'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(painterOf(tester).cursorX, isNull);
    });

    testWidgets('builds through the passive transformer manager', (
      tester,
    ) async {
      final node = LineChartNode.empty();
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PassiveLineChartWidget), findsOneWidget);
    });
  });

  testWidgets('the axis title and readout units can be bound', (
    tester,
  ) async {
    await pumpChart(
      tester,
      chart(
        variables: {
          'yAxisTitle': r"${= 1 > 0 ? 'M' : 'FT'}",
          'tooltipYScale': r'${= 0.3048}',
          'tooltipYDecimals': r'${= 2}',
          'tooltipYSuffix': r"${= ' m'}",
        },
      ),
    );
    final spec = painterOf(tester).spec;
    expect(spec.yAxisTitle, 'M');
    expect(spec.tooltipYScale, 0.3048);
    expect(spec.tooltipYDecimals, 2);
    expect(spec.tooltipYSuffix, ' m');
  });
}
