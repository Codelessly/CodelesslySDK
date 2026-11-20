// The colors a gauge, chart, barcode or signature pad leaves unset: the
// theme's, for what it is drawn on (`ControlTheme`'s roles), so an unstyled
// one reads in light and dark and nothing is a palette of its own.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show
        BarChartProps,
        BarcodeProps,
        ChartProps,
        ChartSeries,
        GaugeMeterProps,
        LineChartProps,
        Node,
        PlotChartProps,
        RadialGaugeProps,
        SignatureProps;
import 'dart:ui' show Color;

import '../graph/graph_spec.dart' show graphPalette;
import '../render/surface_roles.dart';

typedef _Role = Color Function(SurfaceRoles s);

Color _primary(SurfaceRoles s) => s.primary;
Color _fill(SurfaceRoles s) => s.fill;
Color _onSurface(SurfaceRoles s) => s.onSurface;
Color _surface(SurfaceRoles s) => s.surface;
Color _muted(SurfaceRoles s) => s.muted;
Color _outline(SurfaceRoles s) => s.outline;
Color _hairline(SurfaceRoles s) => s.hairline;
Color _error(SurfaceRoles s) => s.error;
_Role _alpha(_Role role, double a) => (s) => role(s).withValues(alpha: a);

/// By node type: each color prop whose unset value is a theme role.
final Map<String, List<(api.PropDef<api.Color?>, _Role)>> themedIndicatorColors = {
  RadialGaugeProps.spec.type: [
    (RadialGaugeProps.trackColor, _hairline),
    (RadialGaugeProps.valueColor, _primary),
    (RadialGaugeProps.tickColor, _outline),
    (RadialGaugeProps.labelColor, _muted),
    (RadialGaugeProps.targetColor, _onSurface),
    (RadialGaugeProps.needleColor, _onSurface),
  ],
  GaugeMeterProps.spec.type: [
    (GaugeMeterProps.color, _primary),
    (GaugeMeterProps.trackColor, _hairline),
    (GaugeMeterProps.tickColor, _outline),
  ],
  ChartProps.spec.type: [
    (ChartProps.gridColor, _hairline),
    (ChartProps.axisLabelColor, _muted),
    (ChartProps.selectionColor, _alpha(_primary, .10)),
    (ChartProps.trackColor, _hairline),
    (ChartProps.tooltipColor, _onSurface),
    (ChartProps.tooltipTextColor, _surface),
  ],
  PlotChartProps.spec.type: [
    (PlotChartProps.lineColor, _primary),
    (PlotChartProps.gridColor, _hairline),
    (PlotChartProps.referenceColor, _error),
    (PlotChartProps.selectionColor, _alpha(_onSurface, .10)),
    (PlotChartProps.selectionLineColor, _onSurface),
    (PlotChartProps.selectionDotColor, _surface),
    (PlotChartProps.selectionDotStrokeColor, _onSurface),
    (PlotChartProps.minorGridColor, _alpha(_hairline, .5)),
    (PlotChartProps.selectionTagColor, _onSurface),
    (PlotChartProps.selectionHaloColor, _alpha(_onSurface, .18)),
  ],
  BarChartProps.spec.type: [
    (BarChartProps.color, _fill),
    (BarChartProps.emptyColor, _hairline),
    (BarChartProps.gridColor, _hairline),
    (BarChartProps.baselineColor, _outline),
    (BarChartProps.labelColor, _muted),
    (BarChartProps.highlightLabelColor, _onSurface),
  ],
  LineChartProps.spec.type: [
    (LineChartProps.lineColor, _primary),
    (LineChartProps.areaTopColor, _alpha(_primary, .10)),
    (LineChartProps.gridColor, _hairline),
    (LineChartProps.zeroLineColor, _outline),
    (LineChartProps.axisColor, _outline),
    (LineChartProps.markerHollowColor, _surface),
    (LineChartProps.tagBackground, _onSurface),
    (LineChartProps.cursorColor, _onSurface),
    (LineChartProps.cursorRingFill, _surface),
    (LineChartProps.tooltipBackground, _onSurface),
  ],
  BarcodeProps.spec.type: [(BarcodeProps.color, _onSurface)],
  SignatureProps.spec.type: [
    (SignatureProps.inkColor, _onSurface),
    (SignatureProps.backgroundColor, _surface),
    (SignatureProps.borderColor, _outline),
    (SignatureProps.errorBorderColor, _error),
    (SignatureProps.placeholderColor, _muted),
  ],
};

/// The theme's series colors: the ones it names (`colors.chart1`,
/// `chart2`...), else its primary as a filled shape on the surface followed
/// by colors of other hues as light and as strong as it
/// (`chartPaletteOf`), so series are told apart and belong to the theme.
///
/// A theme with no primary has no accent to start from: the graph's own
/// colors (`graphPalette`), a blue first.
List<api.Color> chartColors(api.ThemeTokens theme, SurfaceRoles roles) => theme.colors['chart1'] != null
    ? [for (var i = 1; theme.colors['chart$i'] != null; i++) theme.colors['chart$i']!]
    : theme.resolvedRoles().primary == null
        ? [for (final c in graphPalette) api.Color(c.toARGB32())]
        : [for (final c in api.chartPaletteOf(roles.fill.toARGB32())) api.Color(c)];

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// What a graph's style leaves out, from the theme, for what the graph is
/// drawn on: the grid and the labels in its quiet colors, a tag and a
/// tooltip as an inverted surface, a large figure in its ink, and the marks
/// in its series colors.
Map<String, Object?> graphThemeStyle(api.ThemeTokens theme, SurfaceRoles roles) => {
      'grid': _hex(roles.hairline),
      'text': _hex(roles.muted),
      'crosshair': _hex(roles.outline),
      'tag': _hex(roles.onSurface),
      'tagText': _hex(roles.surface),
      'separator': _hex(roles.hairline),
      'ink': _hex(roles.onSurface),
      'palette': [for (final c in chartColors(theme, roles)) _hex(Color(c.value))],
    };

/// A series chart's series that set no color of their own, in the theme's
/// series colors ([chartColors]): one per series, in turn. A donut's one
/// series is left as it is: its slices take those colors, row by row.
Node withChartPalette(Node n, api.ThemeTokens theme, SurfaceRoles roles) {
  if (n.type != ChartProps.spec.type || n.prop(ChartProps.chartType) == api.ChartType.donut) return n;
  final palette = chartColors(theme, roles);
  final series = n.prop(ChartProps.series);
  var changed = false, i = 0;
  final out = [
    for (final s in series)
      if (s.toJson() case final Map<String, Object?> j when !j.containsKey('color'))
        () {
          changed = true;
          return ChartSeries.fromJson({...j, 'color': palette[i++ % palette.length].toJson()}) ?? s;
        }()
      else
        s,
  ];
  return changed ? n.withProp(ChartProps.series, out) : n;
}

/// A signature pad with no corner of its own: the theme's large control
/// corner when it names one (`radii.controlLarge`), else the pad's own 4.
Node withSignatureCorner(Node n, api.ThemeTokens theme) {
  final corner = theme.radii['controlLarge'];
  if (corner == null || n.type != SignatureProps.spec.type || n.props.has(SignatureProps.borderRadius)) return n;
  return n.withProp(SignatureProps.borderRadius, api.BorderRadius.circular(corner));
}

/// [n] with every themed color it leaves unset set from [roles].
Node withThemeColors(Node n, SurfaceRoles scheme) {
  final themed = themedIndicatorColors[n.type];
  if (themed == null) return n;
  var out = n;
  for (final (def, role) in themed) {
    if (out.prop(def) == null) out = out.withProp<api.Color?>(def, api.Color(role(scheme).toARGB32()));
  }
  return out;
}

/// The color [def] of [n] as drawn: its own, else (a node not themed with
/// [withThemeColors]) a mid grey that reads on light and dark.
Color themedColor(Node n, api.PropDef<api.Color?> def) {
  final c = n.prop(def);
  return c == null ? const Color(0xFF808080) : Color(c.value);
}
