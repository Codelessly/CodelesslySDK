import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ChartProperties props = ChartProperties(
    chartType: ChartType.donut,
    series: const [ChartSeries(field: 'spent', name: 'Spent', colorField: 'color')],
  );
  final List<Map<String, Object?>> data = [
    {'label': 'Housing', 'spent': 50, 'color': '#3E6A8A'},
    {'label': 'Groceries', 'spent': 25, 'color': '#4F8A6B'},
    {'label': 'Dining', 'spent': 25, 'color': '#C27A4A'},
  ];
  const Size size = Size(200, 200);

  test('slices are found by angle, clockwise from 12 o\'clock', () {
    final painter = ChartSeriesPainter(props: props, data: data);
    // Ring radius: 200 * (1 - 0.15) / 2 - 4 = 81, so points 81 from center.
    expect(painter.sliceAt(const Offset(181, 100), size), 0); // 3 o'clock
    expect(painter.sliceAt(const Offset(100, 181), size), 0); // 6 o'clock: end of half
    expect(painter.sliceAt(const Offset(30, 110), size), 1); // ~8 o'clock
    expect(painter.sliceAt(const Offset(40, 50), size), 2); // ~10:30
    expect(painter.categoryAt(const Offset(181, 100), size), 0);
  });

  test('the hole and the outside select nothing', () {
    final painter = ChartSeriesPainter(props: props, data: data);
    expect(painter.sliceAt(const Offset(100, 100), size), isNull);
    expect(painter.sliceAt(const Offset(199, 199), size), isNull);
    expect(ChartSeriesPainter(props: props, data: const []).sliceAt(const Offset(181, 100), size), isNull);
  });

  test('startAngle rotates the slices', () {
    final rotated = props.copyWith(startAngle: 180);
    expect(ChartSeriesPainter(props: rotated, data: data).sliceAt(const Offset(100, 181), size), 0);
    expect(ChartSeriesPainter(props: rotated, data: data).sliceAt(const Offset(157, 157), size), 2); // 4:30
  });

  test('donut properties survive JSON', () {
    final p = ChartProperties.fromJson(
      props.copyWith(donutThickness: 0.2, sliceGap: 2, selectOnHover: true).toJson(),
    );
    expect(p.chartType, ChartType.donut);
    expect(p.donutThickness, 0.2);
    expect(p.sliceGap, 2);
    expect(p.selectOnHover, isTrue);
  });

  testWidgets('a donut paints without errors, with and without a selection', (tester) async {
    for (final int selected in [-1, 1]) {
      await tester.pumpWidget(CustomPaint(
        size: size,
        painter: ChartSeriesPainter(props: props, data: data, selectedIndex: selected),
      ));
      expect(tester.takeException(), isNull);
    }
  });
}
