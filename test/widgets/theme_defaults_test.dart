// What an indicator leaves unset, from the theme: a series chart's series
// colors (`colors.chart1`... where it names them, else its primary and hues
// apart from it), a signature pad's corner (`radii.controlLarge`).
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/src/render/surface_roles.dart';
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
    final s = withChartPalette(chart(), theme, surfaceRoles(theme)).prop(api.ChartProps.series);
    expect([for (final x in s) x.color.value], [0xFF2563EB, 0xFF123456, 0xFF0891B2]);
  });

  test('a theme that names no series colors: its primary, then hues apart from it; no primary, from the blue of a page with no theme', () {
    List<int> colors(api.ThemeTokens theme) =>
        [for (final x in withChartPalette(chart(), theme, surfaceRoles(theme)).prop(api.ChartProps.series)) x.color.value];
    final palette = api.chartPaletteOf(0xFF7C3AED);
    expect(colors(api.ThemeTokens.fromJson({'primary': '#FF7C3AED'})), [palette[0], 0xFF123456, palette[1]]);
    final plain = api.chartPaletteOf(0xFF2563EB);
    expect(colors(api.ThemeTokens.none), [plain[0], 0xFF123456, plain[1]]);
    // Never the one color every series had when none was written.
    expect(colors(api.ThemeTokens.none).toSet(), hasLength(3));
  });

  test('a signature pad without a corner takes radii.controlLarge; its own corner, or a theme without one, stays', () {
    api.Node pad([Map<String, Object?> props = const {}]) => api.Node.fromJson({'id': 'p', 'type': 'signature', 'props': props})!;
    final cards = api.ThemeTokens.fromJson({'radii': {'controlLarge': 12}});
    expect(withSignatureCorner(pad(), cards).prop(api.SignatureProps.borderRadius), const api.BorderRadius.circular(12));
    expect(withSignatureCorner(pad({'borderRadius': 2}), cards).prop(api.SignatureProps.borderRadius), const api.BorderRadius.circular(2));
    expect(withSignatureCorner(pad(), api.ThemeTokens.none).prop(api.SignatureProps.borderRadius), const api.BorderRadius.circular(4));
  });
}
