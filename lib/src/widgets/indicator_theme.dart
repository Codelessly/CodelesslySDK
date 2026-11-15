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

import '../render/surface_roles.dart';

typedef _Role = Color Function(SurfaceRoles s);

Color _primary(SurfaceRoles s) => s.primary;
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
    (BarChartProps.color, _primary),
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

/// A series chart's series that set no color of their own, in the theme's
/// series colors when it names them (`colors.chart1`, `chart2`...: one per
/// series, in turn), else as they are (the series' own default).
Node withChartPalette(Node n, api.ThemeTokens theme) {
  if (n.type != ChartProps.spec.type || theme.colors['chart1'] == null) return n;
  final palette = [for (var i = 1; theme.colors['chart$i'] != null; i++) theme.colors['chart$i']!];
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
