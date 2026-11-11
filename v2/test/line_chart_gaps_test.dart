import 'package:codelessly_sdk_v2/src/widgets/indicators_charts.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null and non-finite samples split a curve instead of joining over a pole', () {
    expect(
      LineChartPainter.sampleSegments(
        [
          {'x': -2, 'y': -.5},
          {'x': -1, 'y': -1},
          {'x': 0, 'y': null},
          {'x': 1, 'y': 1},
          {'x': 2, 'y': .5},
          {'x': 3, 'y': double.infinity},
          {'x': 4, 'y': .25},
          {'x': 5, 'y': '.2'},
        ],
        'x',
        'y',
      ),
      [
        [const Offset(-2, -.5), const Offset(-1, -1)],
        [const Offset(1, 1), const Offset(2, .5)],
        [const Offset(4, .25), const Offset(5, .2)],
      ],
    );
  });
  test('explicit discontinuities split and rows sort by x', () {
    expect(
      LineChartPainter.sampleSegments(
        [
          {'x': 2, 'y': 9, 'breakBefore': true},
          {'x': 0, 'y': 0},
          {'x': 3, 'y': 10},
          {'x': 1, 'y': 1},
        ],
        'x',
        'y',
      ),
      [
        [const Offset(0, 0), const Offset(1, 1)],
        [const Offset(2, 9), const Offset(3, 10)],
      ],
    );
  });
  test('date domains and empty/all-invalid data remain supported', () {
    expect(LineChartPainter.sampleSegments([], 'x', 'y'), isEmpty);
    expect(
      LineChartPainter.sampleSegments(
        [
          {'x': 0, 'y': 'NaN'},
        ],
        'x',
        'y',
      ),
      isEmpty,
    );
    expect(
      LineChartPainter.sampleSegments(
        [
          {'x': '2026-01-01', 'y': 2},
        ],
        'x',
        'y',
      ).single.single.dy,
      2,
    );
  });
}
