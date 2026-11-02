import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChartNode chart(Map<String, String> variables) => ChartNode(
        id: 'c',
        name: 'Balance',
        basicBoxLocal: NodeBox(0, 0, 300, 120),
        properties: ChartProperties(
          chartType: ChartType.line,
          series: const [ChartSeries(field: 'v', kind: ChartSeriesKind.area)],
        ),
      )..variables.addAll(variables);

  test('a chart reads its bound axis labels, scale and series color', () {
    final props = boundChartProperties(
      chart({
        'yLabelPrefix': r"${= base == 'EUR' ? '' : '$'}",
        'yLabelSuffix': r"${= base == 'EUR' ? ' €' : ''}",
        'minY': r'${= 0.5}',
        'maxY': r'${= 2}',
        'series0Color': r"${= '#B4553A'}",
      }),
      ScopedValues.preview(variables: {
        'base': VariableData(id: 'base', name: 'base', value: 'EUR'),
      }),
    );
    expect(props.yLabelPrefix, '');
    expect(props.yLabelSuffix, ' €');
    expect(props.minY, 0.5);
    expect(props.maxY, 2);
    expect(props.series.single.color, ColorRGBA.fromHex('#B4553A'));
    expect(props.series.single.kind, ChartSeriesKind.area);
  });

  test('without bindings the stored properties are used as they are', () {
    final node = chart(const {});
    expect(
      identical(
        boundChartProperties(node, ScopedValues.preview(variables: {})),
        node.properties,
      ),
      isTrue,
    );
  });
}
