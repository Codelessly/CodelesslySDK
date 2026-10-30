import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../codelessly_sdk.dart' hide ChartReferenceLine;
import '../utils/node_state_provider.dart';

class PassiveChartSeriesTransformer extends NodeWidgetTransformer<ChartNode> {
  PassiveChartSeriesTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ChartNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveChartSeriesWidget(node: node, settings: settings);
}

/// Renders a [ChartNode]: resolves its data and selection, paints the chart
/// and turns taps into a selected category and `changed` reactions.
class PassiveChartSeriesWidget extends StatelessWidget {
  final ChartNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// The values bindings read instead of the build context's, such as the
  /// variable defaults a design canvas shows.
  final ScopedValues? scopedValues;

  const PassiveChartSeriesWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.scopedValues,
  });

  /// The chart's items: the bound `data` list, else the sample data.
  static List<Map<String, Object?>> resolveData(
    ChartNode node,
    ScopedValues scopedValues,
  ) {
    final String? path = node.variables['data'];
    final List? bound = path == null || path.isEmpty
        ? null
        : PropertyValueDelegate.getVariableValueFromPath<List>(
            path,
            scopedValues: scopedValues,
          );
    final List source =
        bound ??
        (path != null && path.isNotEmpty
            ? const []
            : node.properties.sampleData);
    return [
      for (final Object? item in source)
        if (item is Map)
          {for (final MapEntry e in item.entries) e.key.toString(): e.value}
        else
          {'value': item},
    ];
  }

  void onSelect(BuildContext context, int index) {
    // `${value}` in the reactions reads the node's state.
    NodeStateProvider.setState(context, index);
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'selectedIndex',
      value: index,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues =
        this.scopedValues ??
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final List<Map<String, Object?>> data = resolveData(node, scopedValues);
    final int selected =
        PropertyValueDelegate.getPropertyValue<int>(
          node,
          'selectedIndex',
          scopedValues: scopedValues,
        ) ??
        node.selectedIndex;
    final ChartSeriesPainter painter = ChartSeriesPainter(
      props: node.properties,
      data: data,
      selectedIndex: selected,
    );
    final Widget paint = CustomPaint(
      painter: painter,
      child: const SizedBox.expand(),
    );
    Widget chart = paint;
    if (node.properties.chartType != ChartType.timeline &&
        !settings.isPreview &&
        data.isNotEmpty) {
      chart = LayoutBuilder(
        builder: (context, constraints) => MouseRegion(
          cursor: node.reactions.isEmpty
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          onHover: !node.properties.selectOnHover
              ? null
              : (event) {
                  final int index =
                      painter.categoryAt(
                        event.localPosition,
                        constraints.biggest,
                      ) ??
                      -1;
                  if (index != selected) onSelect(context, index);
                },
          onExit: !node.properties.selectOnHover || selected < 0
              ? null
              : (_) => onSelect(context, -1),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final int? index = painter.categoryAt(
                details.localPosition,
                constraints.biggest,
              );
              if (index != null) onSelect(context, index);
            },
            child: paint,
          ),
        ),
      );
    }
    return AdaptiveNodeBox(node: node, child: chart);
  }
}

/// Reads a number from [item][field]; null when missing or not a number.
double? chartNumber(Map<String, Object?> item, String field) {
  final Object? v = item[field];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Parses a hex color like `#FF4A3D`; null when it isn't one.
Color? chartColor(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return ColorRGBA.fromJson(value).toFlutterColor();
  } catch (_) {
    return null;
  }
}

/// A rounded axis maximum and step for [max] split into [steps].
(double, double) niceAxis(double max, int steps) {
  if (max <= 0 || steps <= 0) return (math.max(1, steps).toDouble(), 1);
  final double raw = max / steps;
  final double mag = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final double n = raw / mag;
  final double step =
      (n <= 1
          ? 1
          : n <= 2
          ? 2
          : n <= 2.5
          ? 2.5
          : n <= 5
          ? 5
          : 10) *
      mag;
  return (step * steps, step);
}

/// "1.0k", "750", "12k".
String compactNumber(num v) => v.abs() >= 10000
    ? '${(v / 1000).toStringAsFixed(0)}k'
    : v.abs() >= 1000
    ? '${(v / 1000).toStringAsFixed(1)}k'
    : (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1));

/// Resolves series-chart axis label fonts, including Google Fonts.
TextStyle _chartSeriesLabelStyle({
  required String? family,
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w500,
}) {
  if (family != null && GoogleFonts.asMap().containsKey(family)) {
    return GoogleFonts.getFont(
      family,
      fontSize: size,
      color: color,
      fontWeight: weight,
    );
  }
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    color: color,
    fontWeight: weight,
  );
}

/// Paints a [ChartProperties] chart for [data].
class ChartSeriesPainter extends CustomPainter {
  ChartSeriesPainter({
    required this.props,
    required this.data,
    this.selectedIndex = -1,
  }) : super(repaint: PaintingBinding.instance.systemFonts);

  final ChartProperties props;
  final List<Map<String, Object?>> data;
  final int selectedIndex;

  static const double _xAxisHeight = 22;

  TextStyle get _axisStyle => _chartSeriesLabelStyle(
    family: props.axisFontFamily,
    size: props.axisFontSize,
    color: props.axisLabelColor.toFlutterColor(),
  );

  /// The plot area inside [size], leaving room for the axes.
  Rect plotRect(Size size) {
    final double left = props.showYAxis ? props.yAxisWidth + 8 : 0;
    final double bottom = props.showXAxis ? _xAxisHeight : 0;
    return Rect.fromLTRB(
      left,
      props.chartType == ChartType.line ? 6 : 0,
      size.width - (props.chartType == ChartType.line ? 6 : 0),
      size.height - bottom,
    );
  }

  /// The category under [position], or null.
  int? categoryAt(Offset position, Size size) {
    if (data.isEmpty) return null;
    if (props.chartType == ChartType.donut) return sliceAt(position, size);
    final Rect plot = plotRect(size);
    if (position.dx < plot.left || position.dx > plot.right) return null;
    if (props.chartType == ChartType.line) {
      final int slots = _slots;
      final int i = ((position.dx - plot.left) / plot.width * slots).round();
      return i.clamp(0, data.length - 1);
    }
    final double catW = plot.width / data.length;
    return ((position.dx - plot.left) / catW).floor().clamp(0, data.length - 1);
  }

  int get _slots =>
      props.xSlots > 0 ? props.xSlots : math.max(1, data.length - 1);

  Iterable<ChartSeries> get _bars =>
      props.series.where((s) => s.kind == ChartSeriesKind.bar);

  /// Bar groups in series order: series sharing a stack id form one group.
  List<List<ChartSeries>> get _groups {
    final List<List<ChartSeries>> groups = [];
    final Map<String, List<ChartSeries>> byStack = {};
    for (final ChartSeries s in _bars) {
      if (s.stack == null) {
        groups.add([s]);
      } else {
        final List<ChartSeries>? existing = byStack[s.stack!];
        if (existing != null) {
          existing.add(s);
        } else {
          groups.add(byStack[s.stack!] = [s]);
        }
      }
    }
    return groups;
  }

  /// The y domain: min and max.
  (double, double, double) _yDomain() {
    double maxV = 0, minV = 0;
    final groups = _groups;
    for (final item in data) {
      for (final group in groups) {
        double sum = 0;
        for (final s in group) {
          final double v = chartNumber(item, s.field) ?? 0;
          sum += v;
        }
        maxV = math.max(maxV, sum);
        minV = math.min(minV, sum);
      }
      for (final s in props.series.where(
        (s) => s.kind != ChartSeriesKind.bar,
      )) {
        final double? v = chartNumber(item, s.field);
        if (v != null) {
          maxV = math.max(maxV, v);
          minV = math.min(minV, v);
        }
      }
    }
    for (final line in props.referenceLines) {
      maxV = math.max(maxV, line.value);
    }
    final double lo = props.minY ?? minV;
    if (props.maxY != null) {
      final double step = props.gridLines > 0
          ? (props.maxY! - lo) / props.gridLines
          : props.maxY! - lo;
      return (lo, props.maxY!, step);
    }
    final (double top, double step) = niceAxis(
      (maxV - lo) * 1.05,
      math.max(1, props.gridLines),
    );
    return (lo, lo + top, step);
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double dash = 4,
    double gap = 4,
  }) {
    final double len = (b - a).distance;
    if (len == 0) return;
    final Offset dir = (b - a) / len;
    for (double d = 0; d < len; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * math.min(len, d + dash), paint);
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    TextAlign align = TextAlign.center,
    TextStyle? style,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style ?? _axisStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final double dx = switch (align) {
      TextAlign.right || TextAlign.end => -tp.width,
      TextAlign.left || TextAlign.start => 0,
      _ => -tp.width / 2,
    };
    tp.paint(canvas, anchor + Offset(dx, -tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (props.chartType) {
      case ChartType.timeline:
        _paintTimeline(canvas, size);
      case ChartType.donut:
        _paintDonut(canvas, size);
      case ChartType.bar:
      case ChartType.line:
        _paintXY(canvas, size);
    }
  }

  /// Donut slice values: the first series' field of each item (negative
  /// and missing values count as 0).
  List<double> get _sliceValues {
    final String field = props.series.isEmpty
        ? 'value'
        : props.series.first.field;
    return [
      for (final item in data) math.max(0, chartNumber(item, field) ?? 0),
    ];
  }

  /// The donut's ring: center and the radius of the middle of the stroke.
  (Offset, double, double) _ring(Size size) {
    final double diameter = math.min(size.width, size.height);
    final double stroke = diameter * props.donutThickness.clamp(0.02, 0.5);
    // Room for the selected slice, drawn thicker.
    final double radius = diameter / 2 - stroke / 2 - 4;
    return (size.center(Offset.zero), radius, stroke);
  }

  /// The slice under [position], or null (the hole and outside the ring).
  int? sliceAt(Offset position, Size size) {
    final List<double> values = _sliceValues;
    final double total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return null;
    final (Offset c, double r, double stroke) = _ring(size);
    final Offset v = position - c;
    if ((v.distance - r).abs() > stroke / 2 + 4) return null;
    double a =
        math.atan2(v.dy, v.dx) + math.pi / 2 - props.startAngle * math.pi / 180;
    a %= 2 * math.pi;
    if (a < 0) a += 2 * math.pi;
    double acc = 0;
    for (int i = 0; i < values.length; i++) {
      acc += values[i] / total * 2 * math.pi;
      if (a <= acc) return i;
    }
    return values.length - 1;
  }

  void _paintDonut(Canvas canvas, Size size) {
    final List<double> values = _sliceValues;
    final double total = values.fold(0.0, (a, b) => a + b);
    final (Offset c, double r, double stroke) = _ring(size);
    final Rect rect = Rect.fromCircle(center: c, radius: r);
    final Paint paint = Paint()..style = PaintingStyle.stroke;
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        paint
          ..color = props.trackColor.toFlutterColor()
          ..strokeWidth = stroke,
      );
      return;
    }
    final ChartSeries? series = props.series.firstOrNull;
    final double gap = props.sliceGap * math.pi / 180;
    double start = -math.pi / 2 + props.startAngle * math.pi / 180;
    for (int i = 0; i < values.length; i++) {
      final double sweep = values[i] / total * 2 * math.pi;
      final Color base =
          (series?.colorField == null
              ? null
              : chartColor(data[i][series!.colorField!])) ??
          series?.color.toFlutterColor() ??
          const Color(0xFF888888);
      final bool on = selectedIndex < 0 || selectedIndex == i;
      paint
        ..color = on ? base : base.withValues(alpha: 0.28)
        ..strokeWidth = selectedIndex == i ? stroke + 8 : stroke;
      if (sweep > gap) {
        canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      }
      start += sweep;
    }
  }

  void _paintXY(Canvas canvas, Size size) {
    final Rect plot = plotRect(size);
    final (double lo, double hi, double step) = _yDomain();
    double y(double v) =>
        plot.bottom - plot.height * ((v - lo) / (hi - lo == 0 ? 1 : hi - lo));
    final bool isLine = props.chartType == ChartType.line;
    final int n = data.length;
    final double catW = n == 0 ? plot.width : plot.width / n;
    double cx(int i) => isLine
        ? plot.left + plot.width * i / _slots
        : plot.left + catW * (i + 0.5);

    // Grid and y labels.
    if (props.gridLines > 0) {
      final Paint grid = Paint()
        ..color = props.gridColor.toFlutterColor()
        ..strokeWidth = 1;
      for (int k = 0; k <= props.gridLines; k++) {
        final double v = lo + (hi - lo) * k / props.gridLines;
        final double gy = y(v).roundToDouble() - (k == 0 ? 0.5 : 0);
        canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
        if (props.showYAxis) {
          _label(
            canvas,
            compactNumber(v),
            Offset(plot.left - 8, gy),
            align: TextAlign.right,
          );
        }
      }
    }
    if (n == 0) return;

    // Selection.
    final Color selection = props.selectionColor.toFlutterColor();
    if (!isLine && selectedIndex >= 0 && selectedIndex < n) {
      canvas.drawRect(
        Rect.fromLTWH(
          plot.left + catW * selectedIndex + 2,
          plot.top,
          catW - 4,
          plot.height,
        ),
        Paint()..color = selection,
      );
    }

    // Bars.
    final List<List<ChartSeries>> groups = _groups;
    final double total = math.min(
      props.maxBarWidth * math.max(1, groups.length),
      catW * props.barWidthFraction,
    );
    final double groupW = groups.isEmpty
        ? 0
        : (total - props.barGap * (groups.length - 1)) / groups.length;
    final ChartSeries? firstTick = props.series
        .where((s) => s.kind == ChartSeriesKind.tick)
        .firstOrNull;
    if (!isLine) {
      for (int i = 0; i < n; i++) {
        final Map<String, Object?> item = data[i];
        final bool empty =
            groups.isNotEmpty &&
            groups.every(
              (g) => g.every((s) => chartNumber(item, s.field) == null),
            );
        final double left0 = cx(i) - total / 2;
        if (empty) {
          if (props.dashEmpty && firstTick != null) {
            final double? t = chartNumber(item, firstTick.field);
            if (t != null) {
              final Rect r = Rect.fromLTRB(
                left0,
                y(t),
                left0 + total,
                plot.bottom,
              );
              // A shade lighter than the grid, so it reads over grid lines.
              final Paint dash = Paint()
                ..color = Color.lerp(
                  props.gridColor.toFlutterColor(),
                  Colors.white,
                  0.15,
                )!
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1;
              _dashedLine(canvas, r.topLeft, r.topRight, dash, dash: 3, gap: 3);
              _dashedLine(
                canvas,
                r.topLeft,
                r.bottomLeft,
                dash,
                dash: 3,
                gap: 3,
              );
              _dashedLine(
                canvas,
                r.topRight,
                r.bottomRight,
                dash,
                dash: 3,
                gap: 3,
              );
            }
          }
          continue;
        }
        for (int g = 0; g < groups.length; g++) {
          double base = 0;
          final double left = left0 + g * (groupW + props.barGap);
          for (final ChartSeries s in groups[g]) {
            final double? v = chartNumber(item, s.field);
            if (v == null || v == 0) continue;
            final Color color =
                chartColor(s.colorField == null ? null : item[s.colorField]) ??
                s.color.toFlutterColor();
            final Rect r = Rect.fromLTRB(
              left,
              y(base + v),
              left + groupW,
              y(base),
            );
            final bool top = s == groups[g].last;
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                r,
                topLeft: Radius.circular(top ? props.barRadius : 0),
                topRight: Radius.circular(top ? props.barRadius : 0),
              ),
              Paint()..color = color,
            );
            base += v;
          }
        }
      }
    }

    // Reference lines.
    for (final ChartReferenceLine line in props.referenceLines) {
      final double ly = y(line.value);
      final Paint p = Paint()
        ..color = line.color.toFlutterColor()
        ..strokeWidth = line.strokeWidth;
      if (line.dashed) {
        _dashedLine(canvas, Offset(plot.left, ly), Offset(plot.right, ly), p);
      } else {
        canvas.drawLine(Offset(plot.left, ly), Offset(plot.right, ly), p);
      }
    }

    // Areas (fills first, so lines sit on top).
    for (final ChartSeries s in props.series.where(
      (s) => s.kind == ChartSeriesKind.area,
    )) {
      final List<Offset> pts = [
        for (int i = 0; i < n; i++)
          if (chartNumber(data[i], s.field) case final double v)
            Offset(cx(i), y(v)),
      ];
      if (pts.length < 2) continue;
      final Path area = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final Offset p in pts.skip(1)) {
        area.lineTo(p.dx, p.dy);
      }
      final Color color = s.color.toFlutterColor();
      if (s.fillTo != null) {
        final List<Offset> other = [
          for (int i = 0; i < n; i++)
            if (chartNumber(data[i], s.field) != null)
              Offset(cx(i), y(chartNumber(data[i], s.fillTo!) ?? 0)),
        ];
        for (final Offset p in other.reversed) {
          area.lineTo(p.dx, p.dy);
        }
        area.close();
        canvas.drawPath(
          area,
          Paint()..color = color.withValues(alpha: s.fillOpacity),
        );
      } else {
        area
          ..lineTo(pts.last.dx, plot.bottom)
          ..lineTo(pts.first.dx, plot.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: s.fillOpacity),
                color.withValues(alpha: 0),
              ],
            ).createShader(plot),
        );
      }
    }

    // Lines and area outlines.
    for (final ChartSeries s in props.series.where(
      (s) => s.kind == ChartSeriesKind.line || s.kind == ChartSeriesKind.area,
    )) {
      if (s.strokeWidth <= 0) continue;
      final List<Offset> pts = [
        for (int i = 0; i < n; i++)
          if (chartNumber(data[i], s.field) case final double v)
            Offset(cx(i), y(v)),
      ];
      if (pts.isEmpty) continue;
      final Paint p = Paint()
        ..color = s.color.toFlutterColor()
        ..strokeWidth = s.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      if (s.dashed) {
        for (int i = 0; i < pts.length - 1; i++) {
          _dashedLine(canvas, pts[i], pts[i + 1], p, dash: 4, gap: 4);
        }
      } else if (pts.length > 1) {
        final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final Offset pt in pts.skip(1)) {
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, p);
      }
      if (s.endDot) {
        canvas.drawCircle(
          pts.last,
          s.strokeWidth + 2.5,
          Paint()..color = Colors.black.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          pts.last,
          s.strokeWidth + 1,
          Paint()..color = s.color.toFlutterColor(),
        );
      }
    }

    // Ticks (plan marks).
    for (final ChartSeries s in props.series.where(
      (s) => s.kind == ChartSeriesKind.tick,
    )) {
      final Paint p = Paint()
        ..color = s.color.toFlutterColor()
        ..strokeWidth = s.strokeWidth;
      for (int i = 0; i < n; i++) {
        final double? v = chartNumber(data[i], s.field);
        if (v == null) continue;
        final double ty = y(v);
        final double half = (isLine ? 6 : total / 2) + 5;
        final Offset a = Offset(cx(i) - half, ty), b = Offset(cx(i) + half, ty);
        if (s.dashed) {
          _dashedLine(canvas, a, b, p, dash: 3, gap: 2);
        } else {
          canvas.drawLine(a, b, p);
        }
      }
    }

    // X labels.
    if (props.showXAxis) {
      final TextStyle style = _axisStyle;
      final TextStyle selectedStyle = style.copyWith(
        color: selection.withValues(alpha: 1),
      );
      final int every = math.max(1, props.xLabelEvery);
      for (int i = 0; i < n; i += every) {
        final Object? label = data[i][props.labelField];
        if (label == null) continue;
        _label(
          canvas,
          '$label',
          Offset(cx(i), plot.bottom + _xAxisHeight / 2 + 2),
          style: i == selectedIndex && !isLine ? selectedStyle : style,
        );
      }
    }
  }

  void _paintTimeline(Canvas canvas, Size size) {
    final double bandH = props.showXAxis
        ? size.height - _xAxisHeight
        : size.height;
    final Rect band = Rect.fromLTWH(0, 0, size.width, bandH);
    final double span = props.domainMax - props.domainMin;
    double x(double v) => span == 0
        ? 0
        : band.width * ((v - props.domainMin) / span).clamp(0.0, 1.0);
    final Color track = props.trackColor.toFlutterColor();
    canvas.drawRect(band, Paint()..color = track);
    for (final Map<String, Object?> item in data) {
      final double? from = chartNumber(item, props.startField);
      final double? to = chartNumber(item, props.endField);
      if (from == null || to == null) continue;
      final Color color =
          chartColor(item[props.segmentColorField]) ??
          props.series.firstOrNull?.color.toFlutterColor() ??
          Colors.green;
      canvas.drawRect(
        Rect.fromLTRB(x(from), 0, math.max(x(from) + 1.5, x(to)), bandH),
        Paint()..color = color,
      );
    }
    // Hatch after now.
    if (props.nowValue != null) {
      final double nx = x(props.nowValue!);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(nx, 0, band.right, bandH));
      final Paint hatch = Paint()
        ..color = props.gridColor.toFlutterColor()
        ..strokeWidth = 1;
      for (double i = nx - bandH; i < band.right; i += 6) {
        canvas.drawLine(Offset(i, bandH), Offset(i + bandH, 0), hatch);
      }
      canvas.restore();
    }
    // Division ticks.
    if (props.divisions > 1) {
      final Paint tick = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..strokeWidth = 1;
      for (int k = 1; k < props.divisions; k++) {
        final double tx = band.width * k / props.divisions;
        canvas.drawLine(Offset(tx, 0), Offset(tx, bandH), tick);
      }
    }
    if (props.nowValue != null) {
      final double nx = x(props.nowValue!);
      canvas.drawRect(
        Rect.fromLTWH(nx - 1, 0, 2, bandH),
        Paint()
          ..color = (props.nowColor ?? props.axisLabelColor)
              .toFlutterColor()
              .withValues(alpha: 1),
      );
    }
    canvas.drawRect(
      band.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = props.gridColor.toFlutterColor(),
    );
    // Division labels.
    if (props.showXAxis && props.divisions > 0) {
      final int every = math.max(1, props.xLabelEvery);
      for (int k = 0; k <= props.divisions; k += every) {
        final double v = props.domainMin + span * k / props.divisions;
        final double lx = band.width * k / props.divisions;
        _label(
          canvas,
          compactNumber(v),
          Offset(lx, bandH + _xAxisHeight / 2 + 2),
          align: k == 0
              ? TextAlign.left
              : (k == props.divisions ? TextAlign.right : TextAlign.center),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ChartSeriesPainter oldDelegate) =>
      oldDelegate.props != props ||
      oldDelegate.selectedIndex != selectedIndex ||
      !_sameData(oldDelegate.data, data);

  static bool _sameData(
    List<Map<String, Object?>> a,
    List<Map<String, Object?>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (final MapEntry<String, Object?> e in a[i].entries) {
        if (b[i][e.key] != e.value) return false;
      }
    }
    return true;
  }
}
