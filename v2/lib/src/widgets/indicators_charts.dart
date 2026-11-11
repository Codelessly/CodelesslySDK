// Chart painters of the indicators group: the series chart (bars, lines,
// areas, timeline, donut), the plot chart and the line chart, each painting
// one node from its props as SDK 8.x's painters did.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_api_v2/codelessly_api.dart'
    show ChartProps, ChartSeries, ChartSeriesKind, ChartType, LineChartProps, PlotChartMarkerPosition, PlotChartProps;
import 'package:flutter/painting.dart';

import '../render/convert.dart';
import 'indicators_paint.dart';

/// Reads a number from [item][field]; null when missing or not a number.
double? chartNumber(Map<String, Object?> item, String field) {
  final v = item[field];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// A hex color (`#FF4A3D`, `#AARRGGBB`); null when it isn't one.
Color? chartColor(Object? value) => value is String ? api.Color.fromJson(value.trim())?.flutter : null;

/// A rounded axis maximum and step for [max] split into [steps].
(double, double) niceAxis(double max, int steps) {
  if (max <= 0 || steps <= 0) return (math.max(1, steps).toDouble(), 1);
  final raw = max / steps;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  final step = (n <= 1
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

/// A y-axis label: [prefix] and [suffix] around the compact number, the
/// minus sign in front (`−$5k`).
String yAxisLabel(num v, String prefix, String suffix) => '${v < 0 ? '−' : ''}$prefix${compactNumber(v.abs())}$suffix';

/// A y domain (low, high, step) from just under [min] to just over [max],
/// on round steps.
(double, double, double) fittedYDomain(double min, double max, int lines) {
  final pad = (max - min) * 0.05;
  final (_, step) = niceAxis(max - min + pad * 2, lines);
  final lo = ((min - pad) / step).floorToDouble() * step;
  var hi = lo + step * lines;
  while (hi < max) {
    hi += step;
  }
  return (lo, hi, step);
}

/// The path through [pts]: straight, or with [curved] a smooth curve that
/// passes through every point without overshooting it.
Path seriesPath(List<Offset> pts, {bool curved = false}) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    if (curved) {
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    } else {
      path.lineTo(b.dx, b.dy);
    }
  }
  return path;
}

void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 4, double gap = 4}) {
  final len = (b - a).distance;
  if (len == 0) return;
  final dir = (b - a) / len;
  for (double d = 0; d < len; d += dash + gap) {
    canvas.drawLine(a + dir * d, a + dir * math.min(len, d + dash), paint);
  }
}

// --- series chart ---------------------------------------------------------------

/// Paints a series chart: bars (stacked or side by side), lines, areas and
/// ticks over categories, a timeline of segments, or a donut.
class ChartSeriesPainter extends NodePainter {
  ChartSeriesPainter(super.n) : super(repaint: PaintingBinding.instance.systemFonts);

  static const double _xAxisHeight = 22;

  List<Map<String, Object?>> get data => p(ChartProps.data);
  List<ChartSeries> get series => p(ChartProps.series);
  int get selectedIndex => p(ChartProps.selectedIndex);
  ChartType get chartType => p(ChartProps.chartType);

  TextStyle _labelStyle(String? family) => TextStyle(
        fontFamily: family,
        fontSize: p(ChartProps.axisFontSize),
        color: p(ChartProps.axisLabelColor).flutter,
        fontWeight: FontWeight.w500,
      );

  TextStyle get _axisStyle => _labelStyle(p(ChartProps.axisFontFamily));

  /// The plot area inside [size], leaving room for the axes.
  Rect plotRect(Size size) {
    final isLine = chartType == ChartType.line;
    final inset = p(ChartProps.plotInset) ?? 6;
    return Rect.fromLTRB(
      p(ChartProps.showYAxis) ? p(ChartProps.yAxisWidth) + 8 : 0,
      isLine ? inset : 0,
      size.width - (isLine ? inset : 0),
      size.height - (p(ChartProps.showXAxis) ? _xAxisHeight : 0),
    );
  }

  int get _slots {
    final slots = p(ChartProps.xSlots);
    return slots > 0 ? slots : math.max(1, data.length - 1);
  }

  /// Bar groups in series order: series sharing a stack id form one group.
  List<List<ChartSeries>> get _groups {
    final groups = <List<ChartSeries>>[];
    final byStack = <String, List<ChartSeries>>{};
    for (final s in series.where((s) => s.kind == ChartSeriesKind.bar)) {
      final stack = s.stack;
      if (stack == null) {
        groups.add([s]);
      } else if (byStack[stack] case final existing?) {
        existing.add(s);
      } else {
        groups.add(byStack[stack] = [s]);
      }
    }
    return groups;
  }

  (double, double, double) _yDomain() {
    double maxV = 0, minV = 0, dataMin = double.infinity;
    final groups = _groups;
    for (final item in data) {
      for (final group in groups) {
        double sum = 0;
        for (final s in group) {
          sum += chartNumber(item, s.field) ?? 0;
        }
        maxV = math.max(maxV, sum);
        minV = math.min(minV, sum);
      }
      for (final s in series.where((s) => s.kind != ChartSeriesKind.bar)) {
        final v = chartNumber(item, s.field);
        if (v != null) {
          maxV = math.max(maxV, v);
          minV = math.min(minV, v);
          dataMin = math.min(dataMin, v);
        }
      }
    }
    for (final line in p(ChartProps.referenceLines)) {
      maxV = math.max(maxV, line.value);
    }
    final minY = p(ChartProps.minY), maxY = p(ChartProps.maxY);
    final gridLines = p(ChartProps.gridLines);
    if (minY == null &&
        maxY == null &&
        p(ChartProps.fitMinY) &&
        chartType == ChartType.line &&
        dataMin.isFinite &&
        maxV > dataMin) {
      return fittedYDomain(dataMin, maxV, math.max(1, gridLines));
    }
    final lo = minY ?? minV;
    if (maxY != null) {
      final step = gridLines > 0 ? (maxY - lo) / gridLines : maxY - lo;
      return (lo, maxY, step);
    }
    final (top, step) = niceAxis((maxV - lo) * 1.05, math.max(1, gridLines));
    return (lo, lo + top, step);
  }

  void _label(Canvas canvas, String text, Offset anchor, {TextAlign align = TextAlign.center, TextStyle? style}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style ?? _axisStyle), textDirection: TextDirection.ltr)
      ..layout();
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => -tp.width,
      TextAlign.left || TextAlign.start => 0.0,
      _ => -tp.width / 2,
    };
    tp.paint(canvas, anchor + Offset(dx, -tp.height / 2));
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (chartType) {
      case ChartType.timeline:
        _paintTimeline(canvas, size);
      case ChartType.donut:
        _paintDonut(canvas, size);
      case ChartType.bar || ChartType.line:
        _paintXY(canvas, size);
    }
  }

  /// Donut slices: the first series' field of each row (negative and missing
  /// values count as 0).
  List<double> get _sliceValues {
    final field = series.isEmpty ? 'value' : series.first.field;
    return [for (final item in data) math.max(0, chartNumber(item, field) ?? 0)];
  }

  void _paintDonut(Canvas canvas, Size size) {
    final values = _sliceValues;
    final total = values.fold(0.0, (a, b) => a + b);
    final diameter = math.min(size.width, size.height);
    final stroke = diameter * p(ChartProps.donutThickness).clamp(0.02, 0.5);
    // Room for the selected slice, drawn thicker.
    final r = diameter / 2 - stroke / 2 - 4;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final paint = Paint()..style = PaintingStyle.stroke;
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint
        ..color = p(ChartProps.trackColor).flutter
        ..strokeWidth = stroke);
      return;
    }
    final first = series.firstOrNull;
    final gap = p(ChartProps.sliceGap) * math.pi / 180;
    var start = -math.pi / 2 + p(ChartProps.startAngle) * math.pi / 180;
    final selected = selectedIndex;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      final colorField = first?.colorField;
      final base = (colorField == null ? null : chartColor(data[i][colorField])) ??
          first?.color.flutter ??
          const Color(0xFF888888);
      final on = selected < 0 || selected == i;
      paint
        ..color = on ? base : base.withValues(alpha: 0.28)
        ..strokeWidth = selected == i ? stroke + 8 : stroke;
      if (sweep > gap) canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      start += sweep;
    }
  }

  void _paintXY(Canvas canvas, Size size) {
    final plot = plotRect(size);
    final (lo, hi, _) = _yDomain();
    double y(double v) => plot.bottom - plot.height * ((v - lo) / (hi - lo == 0 ? 1 : hi - lo));
    final isLine = chartType == ChartType.line;
    final data = this.data;
    final n = data.length;
    final catW = n == 0 ? plot.width : plot.width / n;
    final slots = _slots;
    double cx(int i) => isLine ? plot.left + plot.width * i / slots : plot.left + catW * (i + 0.5);
    final gridColor = p(ChartProps.gridColor).flutter;

    // Grid and y labels.
    final gridLines = p(ChartProps.gridLines);
    if (gridLines > 0) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      final yFamily = p(ChartProps.yAxisFontFamily);
      for (var k = 0; k <= gridLines; k++) {
        final v = lo + (hi - lo) * k / gridLines;
        final gy = y(v).roundToDouble() - (k == 0 ? 0.5 : 0);
        canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
        if (p(ChartProps.showYAxis)) {
          _label(
            canvas,
            yAxisLabel(v, p(ChartProps.yLabelPrefix), p(ChartProps.yLabelSuffix)),
            Offset(plot.left - 8, gy),
            align: TextAlign.right,
            style: yFamily == null ? null : _labelStyle(yFamily),
          );
        }
      }
    }
    if (n == 0) return;

    // Selection.
    final selected = selectedIndex;
    final selection = p(ChartProps.selectionColor).flutter;
    if (!isLine && selected >= 0 && selected < n) {
      canvas.drawRect(
        Rect.fromLTWH(plot.left + catW * selected + 2, plot.top, catW - 4, plot.height),
        Paint()..color = selection,
      );
    }

    // Bars.
    final groups = _groups;
    final barGap = p(ChartProps.barGap);
    final total = math.min(p(ChartProps.maxBarWidth) * math.max(1, groups.length), catW * p(ChartProps.barWidthFraction));
    final groupW = groups.isEmpty ? 0.0 : (total - barGap * (groups.length - 1)) / groups.length;
    final firstTick = series.where((s) => s.kind == ChartSeriesKind.tick).firstOrNull;
    final barRadius = p(ChartProps.barRadius);
    if (!isLine) {
      for (var i = 0; i < n; i++) {
        final item = data[i];
        final empty = groups.isNotEmpty && groups.every((g) => g.every((s) => chartNumber(item, s.field) == null));
        final left0 = cx(i) - total / 2;
        if (empty) {
          if (p(ChartProps.dashEmpty) && firstTick != null) {
            final t = chartNumber(item, firstTick.field);
            if (t != null) {
              final r = Rect.fromLTRB(left0, y(t), left0 + total, plot.bottom);
              // A shade lighter than the grid, so it reads over grid lines.
              final dash = Paint()
                ..color = Color.lerp(gridColor, const Color(0xFFFFFFFF), 0.15)!
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1;
              _dashedLine(canvas, r.topLeft, r.topRight, dash, dash: 3, gap: 3);
              _dashedLine(canvas, r.topLeft, r.bottomLeft, dash, dash: 3, gap: 3);
              _dashedLine(canvas, r.topRight, r.bottomRight, dash, dash: 3, gap: 3);
            }
          }
          continue;
        }
        for (var g = 0; g < groups.length; g++) {
          double base = 0;
          final left = left0 + g * (groupW + barGap);
          for (final s in groups[g]) {
            final v = chartNumber(item, s.field);
            if (v == null || v == 0) continue;
            final colorField = s.colorField;
            final color = chartColor(colorField == null ? null : item[colorField]) ?? s.color.flutter;
            final r = Rect.fromLTRB(left, y(base + v), left + groupW, y(base));
            final top = s == groups[g].last;
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                r,
                topLeft: Radius.circular(top ? barRadius : 0),
                topRight: Radius.circular(top ? barRadius : 0),
              ),
              Paint()..color = color,
            );
            base += v;
          }
        }
      }
    }

    // Reference lines.
    for (final line in p(ChartProps.referenceLines)) {
      final ly = y(line.value);
      final paint = Paint()
        ..color = line.color.flutter
        ..strokeWidth = line.strokeWidth;
      if (line.dashed) {
        _dashedLine(canvas, Offset(plot.left, ly), Offset(plot.right, ly), paint);
      } else {
        canvas.drawLine(Offset(plot.left, ly), Offset(plot.right, ly), paint);
      }
    }

    List<Offset> points(ChartSeries s) => [
          for (var i = 0; i < n; i++)
            if (chartNumber(data[i], s.field) case final double v) Offset(cx(i), y(v)),
        ];

    // Areas (fills first, so lines sit on top).
    for (final s in series.where((s) => s.kind == ChartSeriesKind.area)) {
      final pts = points(s);
      if (pts.length < 2) continue;
      final area = seriesPath(pts, curved: s.curved);
      final color = s.color.flutter;
      final fillTo = s.fillTo;
      if (fillTo != null) {
        final other = [
          for (var i = 0; i < n; i++)
            if (chartNumber(data[i], s.field) != null) Offset(cx(i), y(chartNumber(data[i], fillTo) ?? 0)),
        ];
        for (final pt in other.reversed) {
          area.lineTo(pt.dx, pt.dy);
        }
        area.close();
        canvas.drawPath(area, Paint()..color = color.withValues(alpha: s.fillOpacity));
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
              colors: [color.withValues(alpha: s.fillOpacity), color.withValues(alpha: 0)],
            ).createShader(plot),
        );
      }
    }

    // Lines and area outlines.
    for (final s in series.where((s) => s.kind == ChartSeriesKind.line || s.kind == ChartSeriesKind.area)) {
      if (s.strokeWidth <= 0) continue;
      final pts = points(s);
      if (pts.isEmpty) continue;
      final paint = Paint()
        ..color = s.color.flutter
        ..strokeWidth = s.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      if (s.dashed) {
        for (var i = 0; i < pts.length - 1; i++) {
          _dashedLine(canvas, pts[i], pts[i + 1], paint, dash: 4, gap: 4);
        }
      } else if (pts.length > 1) {
        canvas.drawPath(seriesPath(pts, curved: s.curved), paint);
      }
      if (s.endDot) {
        canvas.drawCircle(pts.last, s.strokeWidth + 2.5,
            Paint()..color = s.endDotHaloColor?.flutter ?? const Color(0xFF000000).withValues(alpha: 0.85));
        canvas.drawCircle(pts.last, s.strokeWidth + 1, Paint()..color = s.color.flutter);
      }
    }

    // Ticks (plan marks).
    for (final s in series.where((s) => s.kind == ChartSeriesKind.tick)) {
      final paint = Paint()
        ..color = s.color.flutter
        ..strokeWidth = s.strokeWidth;
      for (var i = 0; i < n; i++) {
        final v = chartNumber(data[i], s.field);
        if (v == null) continue;
        final ty = y(v);
        final half = (isLine ? 6 : total / 2) + 5;
        final a = Offset(cx(i) - half, ty), b = Offset(cx(i) + half, ty);
        if (s.dashed) {
          _dashedLine(canvas, a, b, paint, dash: 3, gap: 2);
        } else {
          canvas.drawLine(a, b, paint);
        }
      }
    }

    // X labels.
    if (p(ChartProps.showXAxis)) {
      final style = _axisStyle;
      final selectedStyle = style.copyWith(color: selection.withValues(alpha: 1));
      final every = math.max(1, p(ChartProps.xLabelEvery));
      final labelField = p(ChartProps.labelField);
      for (var i = 0; i < n; i += every) {
        final label = data[i][labelField];
        if (label == null) continue;
        _label(canvas, '$label', Offset(cx(i), plot.bottom + _xAxisHeight / 2 + 2),
            style: i == selected && !isLine ? selectedStyle : style);
      }
    }
  }

  void _paintTimeline(Canvas canvas, Size size) {
    final bandH = p(ChartProps.showXAxis) ? size.height - _xAxisHeight : size.height;
    final band = Rect.fromLTWH(0, 0, size.width, bandH);
    final domainMin = p(ChartProps.domainMin), domainMax = p(ChartProps.domainMax);
    final span = domainMax - domainMin;
    double x(double v) => span == 0 ? 0 : band.width * ((v - domainMin) / span).clamp(0.0, 1.0);
    final gridColor = p(ChartProps.gridColor).flutter;
    canvas.drawRect(band, Paint()..color = p(ChartProps.trackColor).flutter);
    for (final item in data) {
      final from = chartNumber(item, p(ChartProps.startField));
      final to = chartNumber(item, p(ChartProps.endField));
      if (from == null || to == null) continue;
      final color = chartColor(item[p(ChartProps.segmentColorField)]) ??
          series.firstOrNull?.color.flutter ??
          const Color(0xFF4CAF50);
      canvas.drawRect(Rect.fromLTRB(x(from), 0, math.max(x(from) + 1.5, x(to)), bandH), Paint()..color = color);
    }
    final nowValue = p(ChartProps.nowValue);
    // Hatch after now.
    if (nowValue != null) {
      final nx = x(nowValue);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(nx, 0, band.right, bandH));
      final hatch = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (var i = nx - bandH; i < band.right; i += 6) {
        canvas.drawLine(Offset(i, bandH), Offset(i + bandH, 0), hatch);
      }
      canvas.restore();
    }
    // Division ticks.
    final divisions = p(ChartProps.divisions);
    if (divisions > 1) {
      final tick = Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 1;
      for (var k = 1; k < divisions; k++) {
        final tx = band.width * k / divisions;
        canvas.drawLine(Offset(tx, 0), Offset(tx, bandH), tick);
      }
    }
    if (nowValue != null) {
      final nx = x(nowValue);
      final nowColor = p(ChartProps.nowColor)?.flutter ?? p(ChartProps.axisLabelColor).flutter;
      canvas.drawRect(Rect.fromLTWH(nx - 1, 0, 2, bandH), Paint()..color = nowColor.withValues(alpha: 1));
    }
    canvas.drawRect(
      band.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = gridColor,
    );
    // Division labels.
    if (p(ChartProps.showXAxis) && divisions > 0) {
      final every = math.max(1, p(ChartProps.xLabelEvery));
      for (var k = 0; k <= divisions; k += every) {
        final v = domainMin + span * k / divisions;
        final lx = band.width * k / divisions;
        _label(canvas, compactNumber(v), Offset(lx, bandH + _xAxisHeight / 2 + 2),
            align: k == 0 ? TextAlign.left : (k == divisions ? TextAlign.right : TextAlign.center));
      }
    }
  }
}

// --- plot chart -----------------------------------------------------------------

/// Paints a plot chart: grid and labels, shaded ranges, the curve and the
/// area under it, markers, a reference line and the selection.
class PlotChartPainter extends NodePainter {
  PlotChartPainter(super.n) : super(repaint: PaintingBinding.instance.systemFonts);

  double get xMin => p(PlotChartProps.xMin);
  double get xMax => p(PlotChartProps.xMax);
  List<double> get points => p(PlotChartProps.points);

  /// The y of the curve at [x], interpolated between points.
  double? valueAt(double x) {
    final values = points;
    if (values.isEmpty) return null;
    if (values.length == 1 || xMax == xMin) return values.first;
    final position = ((x - xMin) / (xMax - xMin)).clamp(0.0, 1.0) * (values.length - 1);
    final index = position.floor().clamp(0, values.length - 2);
    final t = position - index;
    return values[index] + (values[index + 1] - values[index]) * t;
  }

  /// [style] over the chart's defaults ([fontSize] 10, 54% black, 400).
  static TextStyle _style(api.TextStyle style, {Color? color, int weight = 400}) {
    final w = style.fontWeight ?? weight;
    return TextStyle(
      fontSize: style.fontSize ?? 10,
      fontWeight: FontWeight.values[((w / 100).round() - 1).clamp(0, 8)],
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      color: color ?? style.color?.flutter ?? const Color(0x8A000000),
      height: style.height,
    );
  }

  TextPainter _text(String text, TextStyle style) =>
      TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final labelHeight = math.max(0.0, p(PlotChartProps.labelHeight));
    final chartHeight = math.max(0.0, size.height - labelHeight);
    final span = xMax - xMin;
    double x(double value) => span == 0 ? 0 : (value - xMin) / span * size.width;
    final points = this.points;
    var low = p(PlotChartProps.yMin) ?? (points.isEmpty ? 0 : points.reduce(math.min));
    var high = p(PlotChartProps.yMax) ?? (points.isEmpty ? 1 : points.reduce(math.max));
    if (high == low) {
      low -= 1;
      high += 1;
    }
    final inset = p(PlotChartProps.plotInset);
    double y(double value) => inset + (1 - (value - low) / (high - low)) * (chartHeight - inset * 2);
    final labelStyle = _style(p(PlotChartProps.labelStyle));

    void paintLabel(String label, double dx) {
      if (labelHeight <= 0 || label.isEmpty) return;
      final text = _text(label, labelStyle);
      text.paint(canvas, Offset(dx - text.width / 2, chartHeight + 3));
      text.dispose();
    }

    // Grid and its labels.
    final gridStep = p(PlotChartProps.gridStepX);
    final xLabels = p(PlotChartProps.xLabels);
    final gridLabels = p(PlotChartProps.gridLabels);
    if (gridStep != null && gridStep > 0 && span > 0) {
      final grid = Paint()
        ..color = p(PlotChartProps.gridColor).flutter
        ..strokeWidth = 1;
      final lines = (span / gridStep + 1e-9).floor();
      for (var i = 0; i <= lines; i++) {
        final value = xMin + i * gridStep;
        final dx = x(value);
        canvas.drawLine(Offset(dx, 0), Offset(dx, chartHeight), grid);
        if (xLabels.isEmpty && i > 0 && value < xMax - 1e-9) {
          paintLabel(i - 1 < gridLabels.length ? gridLabels[i - 1] : _formatNumber(value), dx);
        }
      }
    }
    for (final label in xLabels) {
      paintLabel(label.label, x(label.x));
    }
    if (p(PlotChartProps.axisColor) case final api.Color axisColor) {
      canvas.drawLine(
        Offset(0, chartHeight),
        Offset(size.width, chartHeight),
        Paint()
          ..color = axisColor.flutter
          ..strokeWidth = 1,
      );
    }

    for (final range in p(PlotChartProps.ranges)) {
      canvas.drawRect(Rect.fromLTRB(x(range.from), 0, x(range.to), chartHeight), Paint()..color = range.color.flutter);
    }

    // Curve and the area under it.
    if (points.isNotEmpty) {
      final offsets = [
        for (var i = 0; i < points.length; i++)
          Offset(points.length == 1 ? 0 : x(xMin + span * i / (points.length - 1)), y(points[i])),
      ];
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      final smooth = p(PlotChartProps.smooth);
      for (var i = 1; i < offsets.length; i++) {
        if (smooth) {
          final previous = offsets[i - 1], current = offsets[i];
          final midX = (previous.dx + current.dx) / 2;
          line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
        } else {
          line.lineTo(offsets[i].dx, offsets[i].dy);
        }
      }
      if (p(PlotChartProps.fillColor) case final api.Color fillColor) {
        final area = Path.from(line)
          ..lineTo(offsets.last.dx, chartHeight)
          ..lineTo(offsets.first.dx, chartHeight)
          ..close();
        canvas.drawPath(area, Paint()..color = fillColor.flutter);
      }
      final lineWidth = p(PlotChartProps.lineWidth);
      if (lineWidth > 0) {
        canvas.drawPath(
          line,
          Paint()
            ..color = p(PlotChartProps.lineColor).flutter
            ..style = PaintingStyle.stroke
            ..strokeWidth = lineWidth
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    final markerRadius = p(PlotChartProps.markerRadius);
    final markerStyle = p(PlotChartProps.markerLabelStyle);
    for (final marker in p(PlotChartProps.markers)) {
      final value = marker.y ?? valueAt(marker.x);
      if (value == null) continue;
      final dot = Offset(x(marker.x), y(value));
      final color = marker.color.flutter;
      canvas.drawCircle(dot, markerRadius, Paint()..color = color);
      if (marker.label.isEmpty) continue;
      final text = _text(marker.label, _style(markerStyle, color: color, weight: 700));
      final dx = (dot.dx - text.width / 2).clamp(0.0, math.max(0.0, size.width - text.width)).toDouble();
      final dy = switch (marker.position) {
        PlotChartMarkerPosition.above => dot.dy - markerRadius - (markerStyle.fontSize ?? 10) * 1.3,
        PlotChartMarkerPosition.below => dot.dy + markerRadius + 1.5,
      };
      text.paint(canvas, Offset(dx, dy));
      text.dispose();
    }

    if (p(PlotChartProps.referenceX) case final double referenceX) {
      final dx = x(referenceX);
      final paint = Paint()
        ..color = p(PlotChartProps.referenceColor).flutter
        ..strokeWidth = p(PlotChartProps.referenceWidth);
      if (p(PlotChartProps.referenceDashed)) {
        for (double dy = 0; dy < chartHeight; dy += 6) {
          canvas.drawLine(Offset(dx, dy), Offset(dx, math.min(chartHeight, dy + 3)), paint);
        }
      } else {
        canvas.drawLine(Offset(dx, 0), Offset(dx, chartHeight), paint);
      }
    }

    if (p(PlotChartProps.selectedX) case final double selected) {
      final step = math.max(0.0, p(PlotChartProps.selectionStep));
      if (step > 0) {
        canvas.drawRect(Rect.fromLTRB(x(selected), 0, x(selected + step), chartHeight),
            Paint()..color = p(PlotChartProps.selectionColor).flutter);
      }
      final center = selected + step / 2;
      final dx = x(center);
      final lineWidth = p(PlotChartProps.selectionLineWidth);
      if (lineWidth > 0) {
        canvas.drawLine(
          Offset(dx, 0),
          Offset(dx, chartHeight),
          Paint()
            ..color = p(PlotChartProps.selectionLineColor).flutter
            ..strokeWidth = lineWidth,
        );
      }
      final value = valueAt(center);
      final dotRadius = p(PlotChartProps.selectionDotRadius);
      if (value != null && dotRadius > 0) {
        final dot = Offset(dx, y(value));
        canvas.drawCircle(dot, dotRadius, Paint()..color = p(PlotChartProps.selectionDotColor).flutter);
        final strokeWidth = p(PlotChartProps.selectionDotStrokeWidth);
        if (strokeWidth > 0) {
          canvas.drawCircle(
            dot,
            dotRadius,
            Paint()
              ..color = p(PlotChartProps.selectionDotStrokeColor).flutter
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth,
          );
        }
      }
    }
    canvas.restore();
  }

  /// An axis value without a trailing `.0`.
  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : double.parse(value.toStringAsFixed(2)).toString();
}

// --- line chart -----------------------------------------------------------------

/// Paints a line chart: bands, grid lines with labels, the curve and the
/// area under it, area bands, reference lines, the x axis, markers and
/// vertical lines. Its data and overlays are rows (usually bound).
class LineChartPainter extends NodePainter {
  LineChartPainter(super.n) : super(repaint: PaintingBinding.instance.systemFonts);

  static double? _num(Object? value) => switch (value) {
        num() when value.isFinite => value.toDouble(),
        String() => double.tryParse(value.trim()),
        _ => null,
      };

  /// A number, or a date (ISO text) as epoch milliseconds of its wall-clock
  /// time.
  static double? _x(Object? value) {
    if (_num(value) case final double v) return v;
    if (value is! String) return null;
    final d = DateTime.tryParse(value.trim());
    if (d == null) return null;
    return DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second, d.millisecond)
        .millisecondsSinceEpoch
        .toDouble();
  }

  static Color? _color(Object? value, [Object? opacity]) {
    final color = chartColor(value);
    final alpha = _num(opacity);
    if (color == null || alpha == null) return color;
    return color.withValues(alpha: color.a * alpha.clamp(0, 1));
  }

  static (double, double) _dash(Object? value, (double, double) fallback) {
    if (value is List && value.length >= 2) {
      final on = _num(value[0]), off = _num(value[1]);
      if (on != null && off != null && on > 0 && off >= 0) return (on, off);
    }
    return fallback;
  }

  static String? _text(Object? value) => value?.toString();

  static TextPainter _layout(String text, TextStyle style) =>
      TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();

  static void _dashed(Canvas canvas, Offset from, Offset to, (double, double) dash, Paint paint) {
    final (on, off) = dash;
    final length = (to - from).distance;
    if (length == 0) return;
    final unit = (to - from) / length;
    for (double d = 0; d < length; d += on + off) {
      canvas.drawLine(from + unit * d, from + unit * math.min(d + on, length), paint);
    }
  }

  /// The y of [points] (sorted by x) at [x], linear between neighbours.
  static double? _interpolate(List<Offset> points, double x) {
    if (points.isEmpty) return null;
    if (x <= points.first.dx) return points.first.dy;
    if (x >= points.last.dx) return points.last.dy;
    var lo = 0, hi = points.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (points[mid].dx <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = points[lo], b = points[hi];
    if (b.dx == a.dx) return b.dy;
    return a.dy + (b.dy - a.dy) * (x - a.dx) / (b.dx - a.dx);
  }

  /// The curve through pixel [points]: a Catmull-Rom spline when [smooth].
  static Path _curve(List<Offset> points, {required bool smooth}) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (smooth) {
      Offset at(int i) => points[i.clamp(0, points.length - 1)];
      for (var i = 0; i < points.length - 1; i++) {
        final c1 = at(i) + (at(i + 1) - at(i - 1)) / 6;
        final c2 = at(i + 1) - (at(i + 2) - at(i)) / 6;
        final end = at(i + 1);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      }
    } else {
      for (final pt in points.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pad = p(LineChartProps.plotPadding);
    final plot = Rect.fromLTRB(
      pad.left,
      pad.top,
      math.max(pad.left, size.width - pad.right),
      math.max(pad.top, size.height - pad.bottom),
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final xField = p(LineChartProps.xField), yField = p(LineChartProps.yField);
    final points = [
      for (final item in p(LineChartProps.data))
        if ((_x(item[xField]), _num(item[yField])) case (final double x, final double y)) Offset(x, y),
    ]..sort((a, b) => a.dx.compareTo(b.dx));
    double extent(Iterable<double> values, double Function(double, double) f) =>
        values.isEmpty ? 0 : values.reduce(f);
    var x0 = p(LineChartProps.xMin) ?? extent(points.map((pt) => pt.dx), math.min);
    var x1 = p(LineChartProps.xMax) ?? extent(points.map((pt) => pt.dx), math.max);
    var y0 = p(LineChartProps.yMin) ?? extent(points.map((pt) => pt.dy), math.min);
    var y1 = p(LineChartProps.yMax) ?? extent(points.map((pt) => pt.dy), math.max);
    if (x1 <= x0) (x0, x1) = (x0 - 0.5, x0 + 0.5);
    if (y1 <= y0) (y0, y1) = (y0 - 0.5, y0 + 0.5);
    double px(double x) => plot.left + (x - x0) / (x1 - x0) * plot.width;
    double py(double y) => plot.bottom - (y - y0) / (y1 - y0) * plot.height;

    final lineColor = p(LineChartProps.lineColor).flutter;
    final axisColor = p(LineChartProps.axisColor).flutter;
    final axisLabelStyle = textStyle(p(LineChartProps.axisLabelStyle));

    // 1. Bands.
    for (final b in p(LineChartProps.bands)) {
      if ((_x(b['from']), _x(b['to']), _color(b['color'], b['opacity'])) case (
        final double from,
        final double to,
        final Color color,
      )) {
        canvas.drawRect(Rect.fromLTRB(px(from), plot.top, px(to), plot.bottom).intersect(plot), Paint()..color = color);
      }
    }

    // 2. Horizontal grid, y labels and the y axis title.
    final grid = Paint()..strokeWidth = 1;
    for (final t in p(LineChartProps.yTicks)) {
      final ty = _num(t['y']);
      if (ty == null) continue;
      final y = py(ty);
      grid.color = _color(t['color']) ??
          (ty == 0 ? p(LineChartProps.zeroLineColor).flutter : p(LineChartProps.gridColor).flutter);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      if (_text(t['label']) case final String label when label.isNotEmpty) {
        final tp = _layout(label, axisLabelStyle);
        final x = t['align'] == 'start' ? 0.0 : plot.left - tp.width - 10;
        tp.paint(canvas, Offset(x, y - tp.height / 2));
        tp.dispose();
      }
    }
    final title = p(LineChartProps.yAxisTitle);
    if (title.isNotEmpty) {
      final tp = _layout(title, textStyle(p(LineChartProps.axisTitleStyle)));
      tp.paint(canvas, Offset(plot.left - tp.width - 10, plot.top - 20));
      tp.dispose();
    }

    final pixels = [for (final pt in points) Offset(px(pt.dx), py(pt.dy))];
    if (pixels.length >= 2) {
      // 3. Area under the curve.
      final curve = _curve(pixels, smooth: p(LineChartProps.smooth));
      final area = Path.from(curve)
        ..lineTo(pixels.last.dx, plot.bottom)
        ..lineTo(pixels.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, plot.top), Offset(0, plot.bottom),
              [p(LineChartProps.areaTopColor).flutter, p(LineChartProps.areaBottomColor).flutter]),
      );

      // 4. Area bands.
      for (final b in p(LineChartProps.areaBands)) {
        if ((_x(b['from']), _x(b['to']), _num(b['below']), _color(b['color'], b['opacity'])) case (
          final double from,
          final double to,
          final double below,
          final Color color,
        )) {
          canvas.save();
          canvas.clipRect(Rect.fromLTRB(px(from), py(below), px(to), plot.bottom));
          canvas.drawPath(area, Paint()..color = color);
          canvas.restore();
          if (_color(b['barColor']) case final Color barColor) {
            canvas.drawRect(Rect.fromLTRB(px(from), plot.bottom - 4, px(to), plot.bottom), Paint()..color = barColor);
          }
        }
      }

      // 5. The curve.
      canvas.drawPath(
        curve,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = p(LineChartProps.lineWidth)
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 6. Reference lines.
    for (final r in p(LineChartProps.referenceLines)) {
      final ry = _num(r['y']);
      if (ry == null) continue;
      final y = py(ry);
      _dashed(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        _dash(r['dash'], (5, 5)),
        Paint()
          ..color = _color(r['color'], r['opacity']) ?? axisColor
          ..strokeWidth = _num(r['width']) ?? 1.5,
      );
    }

    // 7. X axis, ticks and labels.
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;
    final xTicks = [
      for (final t in p(LineChartProps.xTicks))
        if (_x(t['x']) case final double tx) (x: tx, label: _text(t['label']) ?? ''),
    ];
    for (var i = 0; i < xTicks.length; i++) {
      final x = px(xTicks[i].x);
      final tp = _layout(xTicks[i].label, axisLabelStyle);
      final dx = i == 0
          ? 0.0
          : i == xTicks.length - 1
              ? -tp.width
              : -tp.width / 2;
      tp.paint(canvas, Offset(x + dx, plot.bottom + 8));
      tp.dispose();
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, plot.bottom + 4), axis);
    }
    canvas.drawLine(Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), axis);

    // 8. Markers.
    final outline = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final markerStyle = textStyle(p(LineChartProps.markerLabelStyle));
    for (final m in p(LineChartProps.markers)) {
      final (mx, my) = (_x(m['x']), _num(m['y']));
      if (mx == null || my == null) continue;
      final pt = Offset(px(mx), py(my));
      final radius = _num(m['radius']) ?? 5;
      if (_color(m['haloColor']) case final Color halo) {
        canvas.drawCircle(pt, _num(m['haloRadius']) ?? radius + 1, Paint()..color = halo);
      }
      canvas.drawCircle(
        pt,
        radius,
        Paint()
          ..color = _color(m['color']) ??
              (m['filled'] == true ? lineColor : p(LineChartProps.markerHollowColor).flutter),
      );
      final outlineWidth = _num(m['outlineWidth']) ?? 2;
      if (outlineWidth > 0) {
        canvas.drawCircle(
          pt,
          radius,
          Paint()
            ..color = _color(m['outlineColor']) ?? lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = outlineWidth,
        );
      }
      if (_text(m['label']) case final String label when label.isNotEmpty) {
        final tp = _layout(label, markerStyle);
        final ly = m['above'] == true ? pt.dy - tp.height - 8 : pt.dy + 8;
        final lx = (pt.dx - tp.width / 2).clamp(plot.left, math.max(plot.left, plot.right - tp.width)).toDouble();
        tp.paint(canvas, Offset(lx, math.max(0, math.min(ly, plot.bottom - tp.height - 6))));
        tp.dispose();
      }
    }

    // 9. Vertical lines.
    final tagStyle = textStyle(p(LineChartProps.tagTextStyle));
    for (final v in p(LineChartProps.verticalLines)) {
      final vx = _x(v['x']);
      if (vx == null) continue;
      final x = px(vx);
      if (x < plot.left - 0.5 || x > plot.right + 0.5) continue;
      _dashed(
        canvas,
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        _dash(v['dash'], (3, 3)),
        Paint()
          ..color = _color(v['color'], v['opacity']) ?? axisColor
          ..strokeWidth = 1.5,
      );
      if (_text(v['label']) case final String label when label.isNotEmpty) {
        final tp = _layout(label, tagStyle);
        final box = Rect.fromCenter(center: Offset(x, plot.top - 12), width: tp.width + 10, height: tp.height + 6);
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2)),
            Paint()..color = p(LineChartProps.tagBackground).flutter);
        tp.paint(canvas, Offset(box.left + 5, box.top + 3));
        tp.dispose();
      }
      if (v['dotOnCurve'] == true) {
        if (_interpolate(points, vx) case final double y) {
          final dot = Offset(x, py(y));
          canvas.drawCircle(dot, 6, Paint()..color = _color(v['dotColor']) ?? lineColor);
          canvas.drawCircle(dot, 6, outline);
        }
      }
    }
  }
}
