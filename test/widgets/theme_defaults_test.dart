// What an indicator leaves unset, from a theme that names it: a series
// chart's series colors (`colors.chart1`...), a signature pad's corner
// (`radii.controlLarge`); a theme that names neither (SSUI) changes nothing.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/src/widgets/indicator_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  api.Node chart() => api.Node.fromJson({
        'type': 'chart',
        'props': {
          'series': [
            {'field': 'a'},
            {'field': 'b', 'color': '#FF123456'},
            {'field': 'c'},
          ],
        },
      })!;

  test('series without a color take chart1, chart2... in turn; one with its own keeps it', () {
    final theme = api.ThemeTokens.fromJson({
      'colors': {'chart1': '#FF2563EB', 'chart2': '#FF0891B2'},
    });
    final s = withChartPalette(chart(), theme).prop(api.ChartProps.series);
    expect([for (final x in s) x.color.value], [0xFF2563EB, 0xFF123456, 0xFF0891B2]);
  });

  test('a theme that names no series colors leaves the series as they are (SSUI: the series default)', () {
    final n = chart();
    expect(identical(withChartPalette(n, api.ThemeTokens.none), n), isTrue);
    expect(withChartPalette(n, api.ThemeTokens.fromJson({'colors': {'primary': '#FF2563EB'}})).prop(api.ChartProps.series).first.color.value, 0xFF2ED17A);
  });

  test('a signature pad without a corner takes radii.controlLarge; its own corner, or a theme without one, stays', () {
    api.Node pad([Map<String, Object?> props = const {}]) => api.Node.fromJson({'id': 'p', 'type': 'signature', 'props': props})!;
    final cards = api.ThemeTokens.fromJson({'radii': {'controlLarge': 12}});
    expect(withSignatureCorner(pad(), cards).prop(api.SignatureProps.borderRadius), const api.BorderRadius.circular(12));
    expect(withSignatureCorner(pad({'borderRadius': 2}), cards).prop(api.SignatureProps.borderRadius), const api.BorderRadius.circular(2));
    expect(withSignatureCorner(pad(), api.ThemeTokens.none).prop(api.SignatureProps.borderRadius), const api.BorderRadius.circular(4));
  });
}
