// A plot chart's markers draw over the plot's edge. Before, they were
// painted inside the plot's clip: a "now" dot on the last point (Petri's
// population chart) sits on the right edge and showed as half a dot, and
// with one point (gen 0) as a sliver.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a marker on the plot\'s right edge is painted unclipped', () {
    final node = Node.fromJson({
      'id': 'p',
      'type': 'plotChart',
      'props': {
        'points': [10.0, 40.0, 30.0],
        'xMin': 0, 'xMax': 2, 'yMin': 0, 'yMax': 50, 'labelHeight': 0, 'markerRadius': 3.5,
        'markers': [
          {'x': 2, 'y': 30, 'color': '#FFE2BE6A'},
        ],
      },
    })!;
    final canvas = TestRecordingCanvas();
    PlotChartPainter(node).paint(canvas, const Size(200, 100));
    final calls = canvas.invocations.map((i) => i.invocation.memberName).toList();
    final dot = canvas.invocations.lastWhere((i) => i.invocation.memberName == #drawCircle);
    expect((dot.invocation.positionalArguments[0] as Offset).dx, 200, reason: 'centred on the right edge');
    expect(calls.indexOf(#drawCircle), greaterThan(calls.lastIndexOf(#restore)),
        reason: 'after the plot clip is gone, so the whole dot shows');
  });
}
