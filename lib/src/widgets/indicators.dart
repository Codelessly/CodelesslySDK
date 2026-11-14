// Widget recipes: indicators. See lib/src/render/recipe.dart.
//
// Progress bars, gauges, charts and barcodes only lay out and paint: a fit
// box at the node's size and a painter (indicators_paint.dart,
// indicators_charts.dart). Spinners animate, so they're islands: an island that
// rebuilds itself becomes its own layer, keeping each frame local.
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
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' show CircularProgressIndicator, Theme;
import 'package:flutter/rendering.dart';

import '../render/control_theme.dart' show backdropOf, themeDataOf;
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

Size _designSize(Node n) => Size(n.layout.width.value, n.layout.height.value);

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
  chain.add(b.fitBox('indicatorFit', n.layout.width.fit, n.layout.height.fit, _designSize(n)));
  chain.add(b.obtain<RenderCustomPaint>('indicatorPaint', RenderCustomPaint.new)
    ..painter = painter
    ..isComplex = true);
}

/// Data-change animation is isolated to the indicator's paint layer.
void _transitioned(NodeBuilder b, Node n, List<RenderBox> chain, IndicatorPainterFactory factory) {
  chain.add(b.fitBox('indicatorFit', n.layout.width.fit, n.layout.height.fit, _designSize(n)));
  chain.add(b.obtain<RenderIndicatorTransition>('indicatorPaint', RenderIndicatorTransition.new)
    ..update(_themed(b, n), factory, interactive: b.tree.animates));
}

/// A `CircularProgressIndicator` centred in a square of the box's shortest
/// side, or an arc painter.
void _circularProgressIndicator(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  final inner = Size(
    (l.width.value - l.padding.horizontal).clamp(0, double.infinity),
    (l.height.value - l.padding.vertical).clamp(0, double.infinity),
  );
  final square = BoxConstraints.tight(Size.square(inner.shortestSide));
  chain.add(b.obtain<RenderPositionedBox>(
      'spinnerCenter', () => RenderPositionedBox(alignment: Alignment.center, textDirection: TextDirection.ltr)));
  chain.add(b.obtain<RenderConstrainedBox>('spinnerSquare', () => RenderConstrainedBox(additionalConstraints: square))
    ..additionalConstraints = square);
  final start = n.prop(CircularProgressIndicatorProps.startAngle);
  final sweep = n.prop(CircularProgressIndicatorProps.sweepAngle);
  if (start != -90 || sweep != 360) {
    chain.add(b.obtain<RenderCustomPaint>('arc', RenderCustomPaint.new)..painter = ArcIndicatorPainter(n));
    return;
  }
  final value = n.prop(CircularProgressIndicatorProps.value);
  final color = n.prop(CircularProgressIndicatorProps.color)?.flutter;
  final background = n.prop(CircularProgressIndicatorProps.backgroundColor)?.flutter;
  final strokeWidth = n.prop(CircularProgressIndicatorProps.strokeWidth);
  final strokeAlign = n.prop(CircularProgressIndicatorProps.strokeAlign);
  final cap = n.prop(CircularProgressIndicatorProps.strokeCap);
  final trackGap = n.prop(CircularProgressIndicatorProps.trackGap);
  chain.add(b.island(
    'spinner',
    (_) => CircularProgressIndicator(
      value: value,
      color: color,
      backgroundColor: background,
      strokeWidth: strokeWidth,
      strokeAlign: strokeAlign,
      strokeCap: cap == null ? null : strokeCap(cap),
      trackGap: trackGap,
    ),
  ));
}

/// A `CupertinoActivityIndicator`, a square of twice its radius.
void _activityIndicator(NodeBuilder b, Node n, List<RenderBox> chain) {
  final radius = n.prop(ActivityIndicatorProps.radius);
  if (radius <= 0) {
    chain.add(b.fitBox('activityEmpty', SizeFit.hug, SizeFit.hug, Size.zero));
    return;
  }
  final color = n.prop(ActivityIndicatorProps.color)?.flutter;
  final animating = n.prop(ActivityIndicatorProps.animating);
  chain.add(b.island(
    'activity',
    // Unset: the theme's muted ink, not Cupertino's tinted grey.
    (context) => CupertinoActivityIndicator(
        radius: radius, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant, animating: animating),
  ));
}

/// [c] as Flutter's `StrokeCap`.
StrokeCap strokeCap(api.StrokeCap c) => StrokeCap.values.byName(c.name);
