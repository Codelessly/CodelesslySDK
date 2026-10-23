import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../codelessly_sdk.dart';

/// Builds [LineChartNode]s as a [PassiveLineChartWidget].
class PassiveLineChartTransformer extends NodeWidgetTransformer<LineChartNode> {
  PassiveLineChartTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    LineChartNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveLineChartWidget(node: node, settings: settings);

  /// Builds a preview of a chart with [properties] and no data.
  Widget buildPreview({
    LineChartProperties? properties,
    LineChartNode? node,
    double? width,
    double? height,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
    ),
  }) {
    final LineChartNode previewNode = LineChartNode(
      id: '',
      name: 'Line Chart',
      basicBoxLocal: NodeBox(
        0,
        0,
        width ?? kLineChartDefaultWidth,
        height ?? kLineChartDefaultHeight,
      ),
      retainedOuterBoxLocal: NodeBox(
        0,
        0,
        width ?? kLineChartDefaultWidth,
        height ?? kLineChartDefaultHeight,
      ),
      properties: properties ?? node?.properties,
      variables: {...?node?.variables},
    );
    return PassiveLineChartWidget(node: previewNode, settings: settings);
  }
}

/// A full-height band of a line chart, e.g. night shading.
typedef ChartBand = ({double from, double to, Color color});

/// A horizontal grid line with an optional label.
typedef ChartYTick = ({double y, String? label, Color? color});

/// The part of the area under the curve inside [from, to] and below
/// [below], with an optional bar on the x axis.
typedef ChartAreaBand = ({
  double from,
  double to,
  double below,
  Color color,
  Color? barColor,
});

/// A dashed horizontal line.
typedef ChartReferenceLine = ({
  double y,
  Color color,
  double width,
  (double, double) dash,
});

/// A tick and label on the x axis.
typedef ChartXTick = ({double x, String label});

/// A circle on a point with an optional label above or below it.
typedef ChartMarker = ({
  double x,
  double y,
  String? label,
  bool filled,
  bool above,
});

/// A dashed vertical line with an optional tag and dot on the curve.
typedef ChartVerticalLine = ({
  double x,
  Color? color,
  (double, double) dash,
  String? label,
  bool dotOnCurve,
  Color? dotColor,
});

/// Everything a [LineChartPainter] draws, resolved from a [LineChartNode]
/// and its bindings.
class LineChartSpec {
  final List<Offset> points;
  final bool isDate;
  final ChartDomain domain;
  final EdgeInsets insets;
  final bool smooth;
  final List<ChartBand> bands;
  final List<ChartYTick> yTicks;
  final String yAxisTitle;
  final List<ChartAreaBand> areaBands;
  final List<ChartReferenceLine> referenceLines;
  final List<ChartXTick> xTicks;
  final List<ChartMarker> markers;
  final List<ChartVerticalLine> verticalLines;
  final Color lineColor;
  final double lineWidth;
  final Color areaTopColor;
  final Color areaBottomColor;
  final Color gridColor;
  final Color zeroLineColor;
  final Color axisColor;
  final Color markerHollowColor;
  final Color tagBackground;
  final Color cursorColor;
  final Color cursorRingFill;
  final Color tooltipBackground;
  final Color tooltipShadowColor;
  final TextStyle axisLabelStyle;
  final TextStyle axisTitleStyle;
  final TextStyle markerLabelStyle;
  final TextStyle tagTextStyle;
  final TextStyle tooltipLabelStyle;
  final TextStyle tooltipValueStyle;
  final String tooltipXFormat;
  final double tooltipYScale;
  final int tooltipYDecimals;
  final String tooltipYSuffix;
  final bool tooltipTrend;

  const LineChartSpec({
    required this.points,
    required this.isDate,
    required this.domain,
    required this.insets,
    required this.smooth,
    required this.bands,
    required this.yTicks,
    required this.yAxisTitle,
    required this.areaBands,
    required this.referenceLines,
    required this.xTicks,
    required this.markers,
    required this.verticalLines,
    required this.lineColor,
    required this.lineWidth,
    required this.areaTopColor,
    required this.areaBottomColor,
    required this.gridColor,
    required this.zeroLineColor,
    required this.axisColor,
    required this.markerHollowColor,
    required this.tagBackground,
    required this.cursorColor,
    required this.cursorRingFill,
    required this.tooltipBackground,
    required this.tooltipShadowColor,
    required this.axisLabelStyle,
    required this.axisTitleStyle,
    required this.markerLabelStyle,
    required this.tagTextStyle,
    required this.tooltipLabelStyle,
    required this.tooltipValueStyle,
    required this.tooltipXFormat,
    required this.tooltipYScale,
    required this.tooltipYDecimals,
    required this.tooltipYSuffix,
    required this.tooltipTrend,
  });

  /// Resolves [node]'s properties and bindings with [scopedValues].
  factory LineChartSpec.resolve(LineChartNode node, ScopedValues scopedValues) {
    final LineChartProperties props = node.properties;

    Object? bound(String name) {
      final String? path = node.variables[name];
      if (path == null || path.isEmpty) return null;
      return PropertyValueDelegate.getVariableValueFromPath<Object>(
        path,
        scopedValues: scopedValues,
      );
    }

    List<Map> maps(String name) => [
      if (bound(name) case final List list)
        for (final Object? item in list)
          if (item is Map) item,
    ];

    Color color(String name, ColorRGBA fallback) =>
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          name,
          scopedValues: scopedValues,
        )?.toFlutterColor() ??
        fallback.toFlutterColor();

    String? text(Object? value) =>
        value == null ? null : FormulaEvaluator.stringify(value);

    final Object? data = bound('data');
    final List? list = data is List ? data : null;
    final List<Offset> points = LineChartGeometry.points(
      list,
      props.xField,
      props.yField,
    );
    final Object? xMinBinding = bound('xMin');
    final bool isDate = list != null && points.isNotEmpty
        ? LineChartGeometry.hasDateX(list, props.xField)
        : LineChartGeometry.isDate(xMinBinding);
    final ChartDomain domain = LineChartGeometry.domain(
      points,
      xMin: LineChartGeometry.parseX(xMinBinding) ?? props.xMin,
      xMax: LineChartGeometry.parseX(bound('xMax')) ?? props.xMax,
      yMin: LineChartGeometry.parseNum(bound('yMin')) ?? props.yMin,
      yMax: LineChartGeometry.parseNum(bound('yMax')) ?? props.yMax,
    );
    final Color lineColor = color('lineColor', props.lineColor);
    double? x(Object? value) => LineChartGeometry.parseX(value);
    double? n(Object? value) => LineChartGeometry.parseNum(value);
    Color? c(Map item, [String key = 'color']) =>
        LineChartGeometry.parseColor(item[key], item['opacity']);

    return LineChartSpec(
      points: points,
      isDate: isDate,
      domain: domain,
      insets: EdgeInsets.fromLTRB(
        props.padLeft,
        props.padTop,
        props.padRight,
        props.padBottom,
      ),
      smooth: props.smooth,
      bands: [
        for (final Map b in maps('bands'))
          if ((x(b['from']), x(b['to']), c(b)) case (
            final double from,
            final double to,
            final Color color,
          ))
            (from: from, to: to, color: color),
      ],
      yTicks: [
        for (final Map t in maps('yTicks'))
          if (n(t['y']) case final double y)
            (
              y: y,
              label: text(t['label']),
              color: LineChartGeometry.parseColor(t['color']),
            ),
      ],
      yAxisTitle: text(bound('yAxisTitle')) ?? props.yAxisTitle,
      areaBands: [
        for (final Map b in maps('areaBands'))
          if ((x(b['from']), x(b['to']), n(b['below']), c(b)) case (
            final double from,
            final double to,
            final double below,
            final Color color,
          ))
            (
              from: from,
              to: to,
              below: below,
              color: color,
              barColor: LineChartGeometry.parseColor(b['barColor']),
            ),
      ],
      referenceLines: [
        for (final Map r in maps('referenceLines'))
          if (n(r['y']) case final double y)
            (
              y: y,
              color: c(r) ?? props.axisColor.toFlutterColor(),
              width: n(r['width']) ?? 1.5,
              dash: LineChartGeometry.parseDash(r['dash'], (5, 5)),
            ),
      ],
      xTicks: [
        for (final Map t in maps('xTicks'))
          if (x(t['x']) case final double tx)
            (x: tx, label: text(t['label']) ?? ''),
      ],
      markers: [
        for (final Map m in maps('markers'))
          if ((x(m['x']), n(m['y'])) case (final double mx, final double my))
            (
              x: mx,
              y: my,
              label: text(m['label']),
              filled: m['filled'] == true,
              above: m['above'] == true,
            ),
      ],
      verticalLines: [
        for (final Map v in maps('verticalLines'))
          if (x(v['x']) case final double vx)
            (
              x: vx,
              color: c(v),
              dash: LineChartGeometry.parseDash(v['dash'], (3, 3)),
              label: text(v['label']),
              dotOnCurve: v['dotOnCurve'] == true,
              dotColor: LineChartGeometry.parseColor(v['dotColor']),
            ),
      ],
      lineColor: lineColor,
      lineWidth: props.lineWidth,
      areaTopColor: color('areaTopColor', props.areaTopColor),
      areaBottomColor: color('areaBottomColor', props.areaBottomColor),
      gridColor: color('gridColor', props.gridColor),
      zeroLineColor: color('zeroLineColor', props.zeroLineColor),
      axisColor: color('axisColor', props.axisColor),
      markerHollowColor: color('markerHollowColor', props.markerHollowColor),
      tagBackground: color('tagBackground', props.tagBackground),
      cursorColor: color('cursorColor', props.cursorColor),
      cursorRingFill: color('cursorRingFill', props.cursorRingFill),
      tooltipBackground: color('tooltipBackground', props.tooltipBackground),
      tooltipShadowColor: color('tooltipShadowColor', props.tooltipShadowColor),
      axisLabelStyle: TextUtils.retrieveTextStyleFromProp(props.axisLabelStyle),
      axisTitleStyle: TextUtils.retrieveTextStyleFromProp(props.axisTitleStyle),
      markerLabelStyle: TextUtils.retrieveTextStyleFromProp(
        props.markerLabelStyle,
      ),
      tagTextStyle: TextUtils.retrieveTextStyleFromProp(props.tagTextStyle),
      tooltipLabelStyle: TextUtils.retrieveTextStyleFromProp(
        props.tooltipLabelStyle,
      ),
      tooltipValueStyle: TextUtils.retrieveTextStyleFromProp(
        props.tooltipValueStyle,
      ),
      tooltipXFormat: props.tooltipXFormat,
      // The readout's units can follow a setting (feet or metres).
      tooltipYScale: n(bound('tooltipYScale')) ?? props.tooltipYScale,
      tooltipYDecimals:
          n(bound('tooltipYDecimals'))?.round() ?? props.tooltipYDecimals,
      tooltipYSuffix: text(bound('tooltipYSuffix')) ?? props.tooltipYSuffix,
      tooltipTrend: props.tooltipTrend,
    );
  }

  /// The plot rectangle of a chart of [size].
  Rect plotRect(Size size) => LineChartGeometry.plotRect(
    size,
    left: insets.left,
    top: insets.top,
    right: insets.right,
    bottom: insets.bottom,
  );

  /// The interpolated y of the curve at [x].
  double? valueAt(double x) => LineChartGeometry.interpolate(points, x);

  /// The scrub readout's two lines at [x].
  (String, String) readout(double x) => LineChartGeometry.readout(
    points,
    x,
    domain: domain,
    isDate: isDate,
    xFormat: tooltipXFormat,
    yScale: tooltipYScale,
    yDecimals: tooltipYDecimals,
    ySuffix: tooltipYSuffix,
    trend: tooltipTrend,
  );

  /// The semantics value while the cursor is at [x], e.g.
  /// `Cursor 4:30 PM, 1.9 ft`.
  String cursorSemantics(double x) {
    final String xText = LineChartGeometry.formatX(
      x,
      isDate: isDate,
      pattern: tooltipXFormat,
    );
    final String yText = LineChartGeometry.formatY(
      valueAt(x) ?? 0,
      scale: tooltipYScale,
      decimals: tooltipYDecimals,
      suffix: tooltipYSuffix,
    );
    return 'Cursor $xText, $yText';
  }
}

/// Renders a [LineChartNode], with a scrub cursor when
/// [LineChartProperties.scrubEnabled] is set.
class PassiveLineChartWidget extends StatefulWidget {
  final LineChartNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  const PassiveLineChartWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
  });

  @override
  State<PassiveLineChartWidget> createState() => _PassiveLineChartWidgetState();
}

class _PassiveLineChartWidgetState extends State<PassiveLineChartWidget> {
  final FocusNode _focus = FocusNode(debugLabel: 'lineChart');

  /// The cursor's x in data units, or null when not scrubbing.
  double? _cursor;

  /// The domain [_cursor] was set in. A new domain clears the cursor.
  ChartDomain? _cursorDomain;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _setCursor(double? x, ChartDomain domain) {
    if (x == _cursor) return;
    setState(() {
      _cursor = x;
      _cursorDomain = domain;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: widget.variablesOverrides,
    );
    final LineChartNode node = widget.node;
    final LineChartSpec spec = LineChartSpec.resolve(node, scopedValues);
    if (_cursorDomain != spec.domain) _cursor = null;
    final double? cursor = node.properties.scrubEnabled ? _cursor : null;

    final String semanticLabel =
        PropertyValueDelegate.getPropertyValue<String>(
          node,
          'semanticLabel',
          scopedValues: scopedValues,
        ) ??
        node.properties.semanticLabel;

    return AdaptiveNodeBox(
      node: node,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size size = constraints.biggest.isFinite
              ? constraints.biggest
              : Size(node.basicBoxLocal.width, node.basicBoxLocal.height);
          Widget chart = SizedBox.fromSize(
            size: size,
            child: CustomPaint(
              painter: LineChartPainter(spec: spec, cursorX: cursor),
            ),
          );
          if (node.properties.scrubEnabled) {
            chart = _interactive(chart, spec, size);
          }
          return Semantics(
            container: true,
            label: semanticLabel.isEmpty ? null : semanticLabel,
            value: cursor == null ? null : spec.cursorSemantics(cursor),
            child: chart,
          );
        },
      ),
    );
  }

  Widget _interactive(Widget chart, LineChartSpec spec, Size size) {
    final ChartScale scale = ChartScale(spec.domain, spec.plotRect(size));
    void scrubTo(Offset local) => _setCursor(scale.xAt(local.dx), spec.domain);

    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final LogicalKeyboardKey key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowLeft) {
          final double step =
              widget.node.properties.scrubStep *
              (spec.isDate ? Duration.millisecondsPerMinute : 1);
          final double start =
              _cursor ??
              (spec.verticalLines.isNotEmpty
                  ? spec.verticalLines.first.x
                  : (spec.domain.xMin + spec.domain.xMax) / 2);
          final double next =
              start + (key == LogicalKeyboardKey.arrowRight ? step : -step);
          _setCursor(
            next.clamp(spec.domain.xMin, spec.domain.xMax).toDouble(),
            spec.domain,
          );
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape && _cursor != null) {
          _setCursor(null, spec.domain);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        onHover: (event) => scrubTo(event.localPosition),
        onExit: (_) => _setCursor(null, spec.domain),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _focus.requestFocus();
            scrubTo(details.localPosition);
          },
          onHorizontalDragStart: (details) => scrubTo(details.localPosition),
          onHorizontalDragUpdate: (details) => scrubTo(details.localPosition),
          child: chart,
        ),
      ),
    );
  }
}

/// Paints a [LineChartSpec], with the scrub cursor at [cursorX] when set.
class LineChartPainter extends CustomPainter {
  final LineChartSpec spec;
  final double? cursorX;

  LineChartPainter({required this.spec, this.cursorX});

  static TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  static void _dashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    (double, double) dash,
    Paint paint,
  ) {
    final (double on, double off) = dash;
    final double length = (to - from).distance;
    if (length == 0) return;
    final Offset unit = (to - from) / length;
    for (double d = 0; d < length; d += on + off) {
      canvas.drawLine(
        from + unit * d,
        from + unit * math.min(d + on, length),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect plot = spec.plotRect(size);
    if (plot.width <= 0 || plot.height <= 0) return;
    final ChartScale scale = ChartScale(spec.domain, plot);
    final double Function(double) px = scale.px, py = scale.py;

    // 1. Bands.
    for (final ChartBand band in spec.bands) {
      canvas.drawRect(
        Rect.fromLTRB(
          px(band.from),
          plot.top,
          px(band.to),
          plot.bottom,
        ).intersect(plot),
        Paint()..color = band.color,
      );
    }

    // 2. Horizontal grid, y labels and the y axis title.
    final Paint grid = Paint()..strokeWidth = 1;
    for (final ChartYTick tick in spec.yTicks) {
      final double y = py(tick.y);
      grid.color =
          tick.color ?? (tick.y == 0 ? spec.zeroLineColor : spec.gridColor);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      if (tick.label case final String label when label.isNotEmpty) {
        final TextPainter tp = _text(label, spec.axisLabelStyle);
        tp.paint(canvas, Offset(plot.left - tp.width - 10, y - tp.height / 2));
      }
    }
    if (spec.yAxisTitle.isNotEmpty) {
      final TextPainter tp = _text(spec.yAxisTitle, spec.axisTitleStyle);
      tp.paint(canvas, Offset(plot.left - tp.width - 10, plot.top - 20));
    }

    final List<Offset> points = [
      for (final Offset p in spec.points) scale.toPixel(p),
    ];
    if (points.length >= 2) {
      // 3. Area under the curve.
      final Path curve = LineChartGeometry.curvePath(
        points,
        smooth: spec.smooth,
      );
      final Path area = LineChartGeometry.areaPath(curve, points, plot.bottom);
      canvas.drawPath(
        area,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, plot.top),
            Offset(0, plot.bottom),
            [spec.areaTopColor, spec.areaBottomColor],
          ),
      );

      // 4. Area bands.
      for (final ChartAreaBand band in spec.areaBands) {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(
            px(band.from),
            py(band.below),
            px(band.to),
            plot.bottom,
          ),
        );
        canvas.drawPath(area, Paint()..color = band.color);
        canvas.restore();
        if (band.barColor case final Color barColor) {
          canvas.drawRect(
            Rect.fromLTRB(
              px(band.from),
              plot.bottom - 4,
              px(band.to),
              plot.bottom,
            ),
            Paint()..color = barColor,
          );
        }
      }

      // 5. The curve.
      canvas.drawPath(
        curve,
        Paint()
          ..color = spec.lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = spec.lineWidth
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 6. Reference lines.
    for (final ChartReferenceLine line in spec.referenceLines) {
      final double y = py(line.y);
      _dashedLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        line.dash,
        Paint()
          ..color = line.color
          ..strokeWidth = line.width,
      );
    }

    // 7. X axis, ticks and labels.
    final Paint axis = Paint()
      ..color = spec.axisColor
      ..strokeWidth = 1.5;
    for (int i = 0; i < spec.xTicks.length; i++) {
      final ChartXTick tick = spec.xTicks[i];
      final double x = px(tick.x);
      final TextPainter tp = _text(tick.label, spec.axisLabelStyle);
      final double dx = i == 0
          ? 0
          : i == spec.xTicks.length - 1
          ? -tp.width
          : -tp.width / 2;
      tp.paint(canvas, Offset(x + dx, plot.bottom + 8));
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, plot.bottom + 4), axis);
    }
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axis,
    );

    // 8. Markers.
    final Paint outline = Paint()
      ..color = spec.lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final ChartMarker marker in spec.markers) {
      final Offset p = Offset(px(marker.x), py(marker.y));
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = marker.filled ? spec.lineColor : spec.markerHollowColor,
      );
      canvas.drawCircle(p, 5, outline);
      if (marker.label case final String label when label.isNotEmpty) {
        final TextPainter tp = _text(label, spec.markerLabelStyle);
        final double ly = marker.above ? p.dy - tp.height - 8 : p.dy + 8;
        final double lx = (p.dx - tp.width / 2)
            .clamp(plot.left, math.max(plot.left, plot.right - tp.width))
            .toDouble();
        tp.paint(
          canvas,
          Offset(lx, math.max(0, math.min(ly, plot.bottom - tp.height - 6))),
        );
      }
    }

    // 9. Vertical lines.
    for (final ChartVerticalLine line in spec.verticalLines) {
      final double x = px(line.x);
      if (x < plot.left - 0.5 || x > plot.right + 0.5) continue;
      _dashedLine(
        canvas,
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        line.dash,
        Paint()
          ..color = line.color ?? spec.axisColor
          ..strokeWidth = 1.5,
      );
      if (line.label case final String label when label.isNotEmpty) {
        final TextPainter tp = _text(label, spec.tagTextStyle);
        final Rect box = Rect.fromCenter(
          center: Offset(x, plot.top - 12),
          width: tp.width + 10,
          height: tp.height + 6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(2)),
          Paint()..color = spec.tagBackground,
        );
        tp.paint(canvas, Offset(box.left + 5, box.top + 3));
      }
      if (line.dotOnCurve) {
        if (spec.valueAt(line.x) case final double y) {
          final Offset dot = Offset(x, py(y));
          canvas.drawCircle(
            dot,
            6,
            Paint()..color = line.dotColor ?? spec.lineColor,
          );
          canvas.drawCircle(dot, 6, outline);
        }
      }
    }

    // 10. Scrub cursor and readout.
    if (cursorX case final double cx) {
      final double? value = spec.valueAt(cx);
      if (value == null) return;
      final Offset p = Offset(px(cx), py(value));
      canvas.drawLine(
        Offset(p.dx, plot.top),
        Offset(p.dx, plot.bottom),
        Paint()
          ..color = spec.cursorColor
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(p, 7, Paint()..color = spec.cursorRingFill);
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..color = spec.cursorColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final (String xText, String yText) = spec.readout(cx);
      final TextPainter a = _text(xText, spec.tooltipLabelStyle);
      final TextPainter b = _text(yText, spec.tooltipValueStyle);
      final Rect card = LineChartGeometry.readoutRect(
        p,
        Size(math.max(a.width, b.width) + 20, a.height + b.height + 14),
        plot,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          card.shift(const Offset(3, 3)),
          const Radius.circular(3),
        ),
        Paint()..color = spec.tooltipShadowColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(card, const Radius.circular(3)),
        Paint()..color = spec.tooltipBackground,
      );
      a.paint(canvas, Offset(card.left + 10, card.top + 7));
      b.paint(canvas, Offset(card.left + 10, card.top + 7 + a.height + 2));
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.cursorX != cursorX;
}
