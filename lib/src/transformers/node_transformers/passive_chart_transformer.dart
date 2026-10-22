import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

class PassiveChartTransformer extends NodeWidgetTransformer<ChartNode> {
  PassiveChartTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ChartNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveChartWidget(node: node, settings: settings);
  }
}

/// Paints a [ChartNode] and lets the user select an x value on it.
///
/// The points, markers and selection come from the variables bound to
/// `points`, `markers` and `selectedX` when there are any, and from the
/// node otherwise. Selecting writes `selectedX` and fires
/// [TriggerType.changed] with the selected value, which actions read as
/// `${value}`.
class PassiveChartWidget extends StatefulWidget {
  final ChartNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// Whether tapping or dragging selects. False paints the chart only, as
  /// on the editor's canvas.
  final bool interactive;

  const PassiveChartWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.interactive = true,
  });

  @override
  State<PassiveChartWidget> createState() => _PassiveChartWidgetState();
}

class _PassiveChartWidgetState extends State<PassiveChartWidget> {
  /// The selection made on this chart while no variable or node value holds
  /// it.
  double? localSelection;

  /// The selection painted last, so a drag fires only when it changes.
  double? shownSelection;

  /// Bumped when a font finishes loading, so labels paint with it.
  int fontsGeneration = 0;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(onFontsChanged);
  }

  @override
  void didUpdateWidget(covariant PassiveChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.selectedX != widget.node.selectedX) {
      localSelection = null;
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(onFontsChanged);
    super.dispose();
  }

  void onFontsChanged() {
    if (mounted) setState(() => fontsGeneration++);
  }

  ChartNode get node => widget.node;

  ChartProperties get props => widget.node.properties;

  void select(BuildContext context, Offset position) {
    final Size? size = context.size;
    if (size == null || size.width <= 0 || props.xMax == props.xMin) return;
    final double x =
        props.xMin + position.dx / size.width * (props.xMax - props.xMin);
    final double selected = props.snapSelection(x);
    if (selected == shownSelection) return;
    shownSelection = selected;
    setState(() => localSelection = selected);

    // Whole values read as `7`, not `7.0`, in variables and actions.
    final num value = selected == selected.roundToDouble()
        ? selected.toInt()
        : selected;
    NodeStateProvider.setState(context, value);
    if (!FunctionsRepository.setPropertyVariable(
      context,
      node: node,
      property: 'selectedX',
      value: value.toString(),
    )) {
      FunctionsRepository.setNodeValue(
        context,
        node: node,
        property: 'selectedX',
        value: selected,
      );
    }
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: widget.variablesOverrides,
    );
    final List<double> points = chartPoints(node, scopedValues);
    final List<ChartMarker> markers = chartMarkers(node, scopedValues);
    final double? selectedX =
        PropertyValueDelegate.getPropertyValue<double>(
          node,
          'selectedX',
          scopedValues: scopedValues,
        ) ??
        localSelection ??
        node.selectedX;
    shownSelection = selectedX;

    final Widget paint = CustomPaint(
      size: node.basicBoxLocal.size.flutterSize,
      painter: ChartPainter(
        properties: props,
        points: points,
        markers: markers,
        selectedX: selectedX,
        textScaler:
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        fontsGeneration: fontsGeneration,
      ),
    );

    if (!widget.interactive || !props.selectable) {
      return AdaptiveNodeBox(node: node, child: paint);
    }

    return AdaptiveNodeBox(
      node: node,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Builder(
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => select(context, details.localPosition),
            onHorizontalDragStart: (details) =>
                select(context, details.localPosition),
            onHorizontalDragUpdate: (details) =>
                select(context, details.localPosition),
            child: paint,
          ),
        ),
      ),
    );
  }
}

/// The points of [node]'s chart: the list bound to `points`, or the node's.
List<double> chartPoints(ChartNode node, ScopedValues scopedValues) {
  final List? bound = node.variables['points'] == null
      ? null
      : PropertyValueDelegate.getPropertyValue<List>(
          node,
          'points',
          scopedValues: scopedValues,
        );
  if (bound == null) return node.properties.points;
  return [
    for (final Object? value in bound)
      if (value.typedValue<double>() case final double number) number,
  ];
}

/// The markers of [node]'s chart: the list bound to `markers`, or the
/// node's. Bound markers are maps shaped like [ChartMarker]'s JSON.
List<ChartMarker> chartMarkers(ChartNode node, ScopedValues scopedValues) {
  final List? bound = node.variables['markers'] == null
      ? null
      : PropertyValueDelegate.getPropertyValue<List>(
          node,
          'markers',
          scopedValues: scopedValues,
        );
  if (bound == null) return node.properties.markers;
  final List<ChartMarker> markers = [];
  for (final Object? value in bound) {
    if (value is! Map) continue;
    try {
      markers.add(ChartMarker.fromJson(value));
    } catch (_) {
      // Skip markers that aren't shaped like one.
    }
  }
  return markers;
}

/// Paints a line/area chart as described by [properties].
class ChartPainter extends CustomPainter {
  final ChartProperties properties;
  final List<double> points;
  final List<ChartMarker> markers;
  final double? selectedX;
  final TextScaler textScaler;
  final int fontsGeneration;

  ChartPainter({
    required this.properties,
    required this.points,
    required this.markers,
    required this.selectedX,
    this.textScaler = TextScaler.noScaling,
    this.fontsGeneration = 0,
  });

  ChartProperties get p => properties;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final double labelHeight = math.max(0, p.labelHeight);
    final double chartHeight = math.max(0, size.height - labelHeight);
    final double span = p.xMax - p.xMin;
    double x(double value) =>
        span == 0 ? 0 : (value - p.xMin) / span * size.width;

    double low = p.yMin ?? (points.isEmpty ? 0 : points.reduce(math.min));
    double high = p.yMax ?? (points.isEmpty ? 1 : points.reduce(math.max));
    if (high == low) {
      low -= 1;
      high += 1;
    }
    final double inset = p.plotInset;
    double y(double value) =>
        inset + (1 - (value - low) / (high - low)) * (chartHeight - inset * 2);

    // Grid and its labels.
    final double? gridStep = p.gridStepX;
    if (gridStep != null && gridStep > 0 && span > 0) {
      final Paint grid = Paint()
        ..color = p.gridColor.toFlutterColor()
        ..strokeWidth = 1;
      final int lines = (span / gridStep + 1e-9).floor();
      for (int i = 0; i <= lines; i++) {
        final double value = p.xMin + i * gridStep;
        final double dx = x(value);
        canvas.drawLine(Offset(dx, 0), Offset(dx, chartHeight), grid);
        if (p.xLabels.isEmpty && i > 0 && value < p.xMax - 1e-9) {
          final String label = i - 1 < p.gridLabels.length
              ? p.gridLabels[i - 1]
              : formatChartNumber(value);
          paintLabel(canvas, label, dx, chartHeight, labelHeight);
        }
      }
    }
    for (final ChartLabel label in p.xLabels) {
      paintLabel(canvas, label.label, x(label.x), chartHeight, labelHeight);
    }
    if (p.axisColor case final ColorRGBA axisColor) {
      canvas.drawLine(
        Offset(0, chartHeight),
        Offset(size.width, chartHeight),
        Paint()
          ..color = axisColor.toFlutterColor()
          ..strokeWidth = 1,
      );
    }

    for (final ChartRange range in p.ranges) {
      canvas.drawRect(
        Rect.fromLTRB(x(range.from), 0, x(range.to), chartHeight),
        Paint()..color = range.color.toFlutterColor(),
      );
    }

    // Curve and the area under it.
    if (points.isNotEmpty) {
      final List<Offset> offsets = [
        for (int i = 0; i < points.length; i++)
          Offset(
            points.length == 1 ? 0 : x(p.xMin + span * i / (points.length - 1)),
            y(points[i]),
          ),
      ];
      final Path line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        if (p.smooth) {
          final Offset previous = offsets[i - 1];
          final Offset current = offsets[i];
          final double midX = (previous.dx + current.dx) / 2;
          line.cubicTo(
            midX,
            previous.dy,
            midX,
            current.dy,
            current.dx,
            current.dy,
          );
        } else {
          line.lineTo(offsets[i].dx, offsets[i].dy);
        }
      }
      if (p.fillColor case final ColorRGBA fillColor) {
        final Path area = Path.from(line)
          ..lineTo(offsets.last.dx, chartHeight)
          ..lineTo(offsets.first.dx, chartHeight)
          ..close();
        canvas.drawPath(area, Paint()..color = fillColor.toFlutterColor());
      }
      if (p.lineWidth > 0) {
        canvas.drawPath(
          line,
          Paint()
            ..color = p.lineColor.toFlutterColor()
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.lineWidth
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    for (final ChartMarker marker in markers) {
      final double? value = marker.y ?? p.valueAt(marker.x, points);
      if (value == null) continue;
      final Offset dot = Offset(x(marker.x), y(value));
      final Color color = marker.color.toFlutterColor();
      canvas.drawCircle(dot, p.markerRadius, Paint()..color = color);
      if (marker.label.isEmpty) continue;
      final TextPainter text = layoutText(
        marker.label,
        p.markerLabelStyle,
        color: color,
      );
      final double dx = (dot.dx - text.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - text.width),
      );
      final double dy = switch (marker.position) {
        ChartMarkerPosition.above =>
          dot.dy - p.markerRadius - p.markerLabelStyle.fontSize * 1.3,
        ChartMarkerPosition.below => dot.dy + p.markerRadius + 1.5,
      };
      text.paint(canvas, Offset(dx, dy));
      text.dispose();
    }

    if (p.referenceX case final double referenceX) {
      final double dx = x(referenceX);
      final Paint paint = Paint()
        ..color = p.referenceColor.toFlutterColor()
        ..strokeWidth = p.referenceWidth;
      if (p.referenceDashed) {
        for (double dy = 0; dy < chartHeight; dy += 6) {
          canvas.drawLine(
            Offset(dx, dy),
            Offset(dx, math.min(chartHeight, dy + 3)),
            paint,
          );
        }
      } else {
        canvas.drawLine(Offset(dx, 0), Offset(dx, chartHeight), paint);
      }
    }

    if (selectedX case final double selected) {
      final double step = math.max(0, p.selectionStep);
      if (step > 0) {
        canvas.drawRect(
          Rect.fromLTRB(x(selected), 0, x(selected + step), chartHeight),
          Paint()..color = p.selectionColor.toFlutterColor(),
        );
      }
      final double center = selected + step / 2;
      final double dx = x(center);
      if (p.selectionLineWidth > 0) {
        canvas.drawLine(
          Offset(dx, 0),
          Offset(dx, chartHeight),
          Paint()
            ..color = p.selectionLineColor.toFlutterColor()
            ..strokeWidth = p.selectionLineWidth,
        );
      }
      final double? value = p.valueAt(center, points);
      if (value != null && p.selectionDotRadius > 0) {
        final Offset dot = Offset(dx, y(value));
        canvas.drawCircle(
          dot,
          p.selectionDotRadius,
          Paint()..color = p.selectionDotColor.toFlutterColor(),
        );
        if (p.selectionDotStrokeWidth > 0) {
          canvas.drawCircle(
            dot,
            p.selectionDotRadius,
            Paint()
              ..color = p.selectionDotStrokeColor.toFlutterColor()
              ..style = PaintingStyle.stroke
              ..strokeWidth = p.selectionDotStrokeWidth,
          );
        }
      }
    }

    canvas.restore();
  }

  void paintLabel(
    Canvas canvas,
    String label,
    double dx,
    double chartHeight,
    double labelHeight,
  ) {
    if (labelHeight <= 0 || label.isEmpty) return;
    final TextPainter text = layoutText(label, p.labelStyle);
    text.paint(canvas, Offset(dx - text.width / 2, chartHeight + 3));
    text.dispose();
  }

  TextPainter layoutText(String text, ChartTextStyle style, {Color? color}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: chartTextStyle(style, color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate.properties != properties ||
      !_listEquals(oldDelegate.points, points) ||
      !_listEquals(oldDelegate.markers, markers) ||
      oldDelegate.selectedX != selectedX ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.fontsGeneration != fontsGeneration;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The Flutter text style of a chart's [style].
TextStyle chartTextStyle(ChartTextStyle style, {Color? color}) {
  final FontWeight weight =
      FontWeight.values[((style.fontWeight / 100).round() - 1).clamp(0, 8)];
  final String? family = style.fontFamily;
  if (family != null && GoogleFonts.asMap().containsKey(family)) {
    return GoogleFonts.getFont(
      family,
      fontSize: style.fontSize,
      fontWeight: weight,
      color: color ?? style.color.toFlutterColor(),
      height: style.height,
    );
  }
  return TextStyle(
    fontSize: style.fontSize,
    fontWeight: weight,
    fontFamily: family,
    color: color ?? style.color.toFlutterColor(),
    height: style.height,
  );
}

/// Formats an axis value without a trailing `.0`.
String formatChartNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : double.parse(value.toStringAsFixed(2)).toString();
