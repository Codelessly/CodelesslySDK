// A line chart draws its series as lines: one written without a kind (the
// default, bar, which a line chart does not draw) is a line there.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter_test/flutter_test.dart';

ChartSeriesPainter _painter(String chartType) {
  final doc = LayoutDocument.fromJson({
    'schema': 3,
    'roots': ['c'],
    'nodes': {
      'c': {
        'type': 'chart',
        'layout': {'width': 400, 'height': 200},
        'props': {
          'chartType': chartType,
          'labelField': 'label',
          'series': [
            {'field': 'first', 'color': '#FF2266FF'},
            {'field': 'resolution', 'kind': 'area'},
          ],
          'data': [
            {'label': 'Thu', 'first': 0.5, 'resolution': 8.6},
            {'label': 'Fri', 'first': 0.4, 'resolution': 6.5},
          ],
        },
      },
    },
  });
  return ChartSeriesPainter(doc.nodes['c']!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('in a line chart a series of no kind written is a line', () {
    expect(_painter('line').series.map((s) => s.kind), [ChartSeriesKind.line, ChartSeriesKind.area]);
  });

  test('in a bar chart it is a bar, as before', () {
    expect(_painter('bar').series.map((s) => s.kind), [ChartSeriesKind.bar, ChartSeriesKind.area]);
  });
}
