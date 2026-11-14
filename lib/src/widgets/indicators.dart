// Widget recipes: indicators. See lib/src/render/recipe.dart.
//
// Progress bars, gauges, charts and barcodes only lay out and paint: a fit
// box at the node's size and a painter (indicators_paint.dart,
// indicators_charts.dart), their value changes eased on the tree's ticker
// (indicator_transition.dart). Spinners are render objects that turn on their
// own ticker (render/controls/spinner.dart): SSUI's arc and a ticked wheel,
// no Material or Cupertino widget.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show
        ActivityIndicatorProps,
        CircularProgressIndicatorProps,
        Node,
        SizeFit,
        BarChartProps,
        BarcodeProps,
        ChartProps,
        GaugeMeterProps,
        LineChartProps,
        PlotChartProps,
        ProgressBarProps,
        RadialGaugeProps;
import 'package:flutter/rendering.dart';

import '../render/control_theme.dart' show backdropOf, themeDataOf;
import '../render/controls/spinner.dart';
import '../render/controls/tokens.dart';
import '../render/convert.dart';
import 'indicator_theme.dart';
import '../render/recipe.dart';
import 'indicator_transition.dart';
import 'indicators_charts.dart';
import 'indicators_paint.dart';

/// Recipes for the indicators group, by node type.
final Map<String, WidgetRecipe> indicatorsRecipes = {
  CircularProgressIndicatorProps.spec.type: _circularProgressIndicator,
  ActivityIndicatorProps.spec.type: _activityIndicator,
  ProgressBarProps.spec.type: (b, n, chain) => _transitioned(b, n, chain, ProgressBarPainter.new),
  RadialGaugeProps.spec.type: (b, n, chain) => _transitioned(b, n, chain, RadialGaugePainter.new),
  GaugeMeterProps.spec.type: (b, n, chain) => _transitioned(b, n, chain, GaugeMeterPainter.new),
  ChartProps.spec.type: (b, n, chain) => _transitioned(b, n, chain, ChartSeriesPainter.new),
  PlotChartProps.spec.type: (b, n, chain) => _transitioned(b, n, chain, PlotChartPainter.new),
  BarChartProps.spec.type: (b, n, chain) => _transitioned(b, n, chain, BarChartPainter.new),
  LineChartProps.spec.type: (b, n, chain) => _transitioned(b, n, chain, LineChartPainter.new),
  BarcodeProps.spec.type: (b, n, chain) => _painted(b, n, chain, BarcodePainter(_themed(b, n))),
};

/// The size a drawn indicator has along an axis it hugs: it has no content
/// to measure, so each type has a size of its own (a bar 6 high, a chart
/// 140).
Size _naturalSize(Node n) => switch (n.type) {
      'progressBar' => const Size(200, 6),
      'barcode' => const Size(200, 80),
      'radialGauge' || 'gaugeMeter' => const Size(120, 120),
      _ => const Size(280, 140),
    };

/// The fit box of a drawn indicator: an axis that hugs is its natural size.
RenderBox _indicatorFit(NodeBuilder b, Node n) {
  final l = n.layout, natural = _naturalSize(n);
  final hugW = l.width.isHug && l.width.value <= 0, hugH = l.height.isHug && l.height.value <= 0;
  return b.fitBox('indicatorFit', hugW ? SizeFit.fixed : l.width.fit, hugH ? SizeFit.fixed : l.height.fit,
      Size(hugW ? natural.width : l.width.value, hugH ? natural.height : l.height.value));
}

/// The node's box (AdaptiveNodeBox) painted by [painter].
/// [n] with the colors it leaves unset from the theme, for what it is drawn
/// on (its ancestors' fills over the project's surface).
/// The box is drawn again when the theme changes (its mode).
Node _themed(NodeBuilder b, Node n) {
  b.tree.dependOnTheme(b);
  return withThemeColors(
      n,
      themeDataOf(b.tree.components?.theme ?? api.ThemeTokens.none,
              surface: backdropOf(b.source.node, b.source.parentOf, b.id))
          .colorScheme);
}

void _painted(NodeBuilder b, Node n, List<RenderBox> chain, CustomPainter painter) {
  chain.add(_indicatorFit(b, n));
  chain.add(b.obtain<RenderCustomPaint>('indicatorPaint', RenderCustomPaint.new)
    ..painter = painter
    ..isComplex = true);
}

/// Data-change animation is isolated to the indicator's paint layer.
void _transitioned(NodeBuilder b, Node n, List<RenderBox> chain, IndicatorPainterFactory factory) {
  chain.add(_indicatorFit(b, n));
  chain.add(b.obtain<RenderIndicatorTransition>('indicatorPaint', RenderIndicatorTransition.new)
    ..update(_themed(b, n), factory, interactive: b.tree.animates));
}

/// A `CircularProgressIndicator`: SSUI's spinner (a 2 px arc in the
/// primary color, 16 px when it hugs) or a ring filled to its value, in a
/// square of the box's shortest side; an arc painter when it has its own
/// start or sweep.
void _circularProgressIndicator(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  final hugs = l.width.isHug && l.height.isHug;
  if (hugs) {
    // No size: SSUI's 16 px spinner.
    chain.add(b.fitBox('indicatorFit', SizeFit.hug, SizeFit.hug, Size.zero));
    if (l.padding != api.EdgeInsets.zero) {
      chain.add(b.obtain<RenderPadding>('spinnerPadding', () => RenderPadding(padding: EdgeInsets.zero))..padding = l.padding.flutter);
    }
  } else {
    // As it always laid out: a square of its design size (less padding),
    // centered in what its parent gives it.
    final inner = Size(
      (l.width.value - l.padding.horizontal).clamp(0, double.infinity),
      (l.height.value - l.padding.vertical).clamp(0, double.infinity),
    );
    final square = BoxConstraints.tight(Size.square(inner.shortestSide));
    chain.add(b.obtain<RenderPositionedBox>(
        'spinnerCenter', () => RenderPositionedBox(alignment: Alignment.center, textDirection: TextDirection.ltr)));
    chain.add(b.obtain<RenderConstrainedBox>('spinnerSquare', () => RenderConstrainedBox(additionalConstraints: square))
      ..additionalConstraints = square);
  }
  final start = n.prop(CircularProgressIndicatorProps.startAngle);
  final sweep = n.prop(CircularProgressIndicatorProps.sweepAngle);
  if (start != -90 || sweep != 360) {
    chain.add(b.obtain<RenderCustomPaint>('arc', RenderCustomPaint.new)..painter = ArcIndicatorPainter(n));
    return;
  }
  final tokens = ControlTokens.of(b);
  final cap = n.prop(CircularProgressIndicatorProps.strokeCap);
  chain.add(b.obtain<RenderSpinner>('spinner', RenderSpinner.new)
    ..style = SpinnerStyle.arc
    ..value = n.prop(CircularProgressIndicatorProps.value)
    ..color = n.prop(CircularProgressIndicatorProps.color)?.flutter ?? tokens.primary
    ..track = n.prop(CircularProgressIndicatorProps.backgroundColor)?.flutter
    // Unset: SSUI's (2 px, inside the square, round ends).
    ..strokeWidth = n.props.has(CircularProgressIndicatorProps.strokeWidth) ? n.prop(CircularProgressIndicatorProps.strokeWidth) : null
    ..strokeAlign = n.props.has(CircularProgressIndicatorProps.strokeAlign) ? n.prop(CircularProgressIndicatorProps.strokeAlign) : -1
    ..strokeCap = cap == null ? StrokeCap.round : strokeCap(cap)
    ..trackGap = n.prop(CircularProgressIndicatorProps.trackGap) ?? 0
    ..diameter = 16
    ..period = const Duration(milliseconds: 900)
    // It spins on a design canvas too, as the island did.
    ..animating = true);
}

/// An activity indicator (Flutter's `CupertinoActivityIndicator`): eight
/// ticks stepping round, a square of twice its radius, in the secondary
/// text color unless it says.
void _activityIndicator(NodeBuilder b, Node n, List<RenderBox> chain) {
  final radius = n.prop(ActivityIndicatorProps.radius);
  if (radius <= 0) {
    chain.add(b.fitBox('activityEmpty', SizeFit.hug, SizeFit.hug, Size.zero));
    return;
  }
  // As the island laid out: a square of twice its radius, whatever its box.
  final square = BoxConstraints.tight(Size.square(radius * 2));
  chain.add(b.obtain<RenderConstrainedBox>('activitySquare', () => RenderConstrainedBox(additionalConstraints: square))
    ..additionalConstraints = square);
  chain.add(b.obtain<RenderSpinner>('activity', RenderSpinner.new)
    ..style = SpinnerStyle.ticks
    ..color = n.prop(ActivityIndicatorProps.color)?.flutter ?? ControlTokens.of(b).secondaryText
    ..diameter = radius * 2
    ..period = const Duration(seconds: 1)
    ..animating = n.prop(ActivityIndicatorProps.animating));
}

/// [c] as Flutter's `StrokeCap`.
StrokeCap strokeCap(api.StrokeCap c) => StrokeCap.values.byName(c.name);
