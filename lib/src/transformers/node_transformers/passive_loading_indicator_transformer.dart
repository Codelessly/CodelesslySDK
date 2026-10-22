import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveLoadingIndicatorTransformer
    extends NodeWidgetTransformer<LoadingIndicatorNode> {
  PassiveLoadingIndicatorTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    LoadingIndicatorNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(node, settings: settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required LoadingIndicatorProperties props,
    required double height,
    required double width,
    bool animate = true,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildFromProps',
    ),
  }) {
    final node = LoadingIndicatorNode(
      id: '',
      name: 'LoadingIndicator',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildFromNode(node, animate: animate, settings: settings);
  }

  Widget buildPreview({
    LoadingIndicatorProperties? properties,
    LoadingIndicatorNode? node,
    double? height,
    double? width,
    ValueChanged<bool>? onChanged,
    bool animate = false,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildPreview',
    ),
  }) {
    final previewNode = LoadingIndicatorNode(
      properties: node?.properties ?? properties!,
      id: '',
      name: 'LoadingIndicator',
      basicBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
      retainedOuterBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
    );
    return PassiveLoadingIndicatorWidget(
      node: previewNode,
      onChanged: onChanged,
      animate: animate,
      settings: settings,
    );
  }

  Widget buildFromNode(
    LoadingIndicatorNode node, {
    bool animate = true,
    WidgetBuildSettings settings = const WidgetBuildSettings(
      debugLabel: 'buildFromNode',
    ),
  }) {
    return PassiveLoadingIndicatorWidget(
      node: node,
      settings: settings,
      animate: animate,
      onChanged: (value) => onChanged(node.reactions),
    );
  }

  void onChanged(List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .forEach(onAction);

  void onAction(Reaction reaction) {
    switch (reaction.action.type) {
      case ActionType.link:
        FunctionsRepository.openLink((reaction.action as LinkAction).url);
      default:
        break;
    }
  }
}

class PassiveLoadingIndicatorWidget extends StatelessWidget {
  final LoadingIndicatorNode node;
  final List<VariableData> variables;
  final ValueChanged<bool>? onChanged;
  final bool animate;
  final WidgetBuildSettings settings;

  const PassiveLoadingIndicatorWidget({
    super.key,
    required this.node,
    required this.onChanged,
    this.animate = true,
    this.variables = const [],
    required this.settings,
  });

  /// [props] with what bindings give `value`, `startAngle`, `sweepAngle`,
  /// `color` and `backgroundColor`, so a gauge or dial follows its data.
  MaterialLoadingIndicatorProperties _bound(
    BuildContext context,
    MaterialLoadingIndicatorProperties props,
  ) {
    if (node.variables.isEmpty) return props;
    final ScopedValues scopedValues = ScopedValues.of(context);
    T? bound<T extends Object>(String property) =>
        node.variables.containsKey(property)
        ? PropertyValueDelegate.getPropertyValue<T>(
            node,
            property,
            scopedValues: scopedValues,
          )
        : null;
    return props.copyWith(
      value: bound<double>('value')?.clamp(0, 1).toDouble(),
      startAngle: bound<double>('startAngle'),
      sweepAngle: bound<double>('sweepAngle'),
      color: bound<ColorRGBA>('color'),
      backgroundColor: bound<ColorRGBA>('backgroundColor'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (node.properties.isMaterial) {
      final MaterialLoadingIndicatorProperties props = _bound(
        context,
        node.properties.asMaterial(),
      );

      if (props.isArc) {
        return Center(
          child: SizedBox.square(
            dimension: node.innerBoxLocal.size.shortestSide,
            child: CustomPaint(
              painter: ArcIndicatorPainter(
                startAngle: props.startAngle,
                sweepAngle: props.sweepAngle,
                value: !animate ? props.value ?? 0.7 : props.value,
                strokeWidth: props.strokeWidth,
                strokeAlign: props.strokeAlign ?? 0,
                strokeCap: props.strokeCap.flutterStrokeCap,
                color: props.color.toFlutterColor(),
                trackColor: props.backgroundColor.toFlutterColor(),
              ),
            ),
          ),
        );
      }

      return Center(
        child: SizedBox.square(
          dimension: node.innerBoxLocal.size.shortestSide,
          child: CircularProgressIndicator(
            strokeWidth: props.strokeWidth,
            value: !animate ? props.value ?? 0.7 : props.value,
            color: props.color.toFlutterColor(),
            backgroundColor: props.backgroundColor.toFlutterColor(),
            strokeCap: props.strokeCap.flutterStrokeCap,
            strokeAlign: props.strokeAlign,
            trackGap: props.trackGap,
          ),
        ),
      );
    } else if (node.properties.isCupertino) {
      final CupertinoLoadingIndicatorProperties props = node.properties
          .asCupertino();
      return CupertinoActivityIndicator(
        radius: (node.basicBoxLocal.width ~/ 2).toDouble(),
        color: props.color.toFlutterColor(),
        animating: animate,
      );
    }

    throw Exception('LoadingIndicatorProperties type not supported');
  }
}

/// Paints a circular indicator as an arc: a track across [sweepAngle]
/// degrees from [startAngle] (clockwise from 3 o'clock) and, over it, the
/// [value] fraction of that arc. Without a value the whole arc is [color].
/// The stroke sits on the bounds like `CircularProgressIndicator`'s:
/// [strokeAlign] -1 inside, 0 centered on the edge, 1 outside.
class ArcIndicatorPainter extends CustomPainter {
  /// Creates an [ArcIndicatorPainter].
  const ArcIndicatorPainter({
    required this.startAngle,
    required this.sweepAngle,
    required this.value,
    required this.strokeWidth,
    required this.strokeAlign,
    required this.strokeCap,
    required this.color,
    required this.trackColor,
  });

  /// Start of the arc, in degrees clockwise from 3 o'clock.
  final double startAngle;

  /// Span of the arc, in degrees.
  final double sweepAngle;

  /// Filled fraction of the arc, or null for all of it.
  final double? value;

  /// Thickness of the stroke.
  final double strokeWidth;

  /// Where the stroke sits relative to the bounds, from -1 to 1.
  final double strokeAlign;

  /// Ends of the stroke.
  final StrokeCap strokeCap;

  /// Color of the filled part.
  final Color color;

  /// Color of the track.
  final Color trackColor;

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double offset = strokeWidth / 2 * -strokeAlign;
    final Rect rect =
        Offset(offset, offset) &
        Size(size.width - offset * 2, size.height - offset * 2);
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap;
    if (trackColor.a > 0) {
      canvas.drawArc(
        rect,
        _radians(startAngle),
        _radians(sweepAngle),
        false,
        stroke(trackColor),
      );
    }
    final double filled = sweepAngle * (value ?? 1);
    if (filled != 0) {
      canvas.drawArc(
        rect,
        _radians(startAngle),
        _radians(filled),
        false,
        stroke(color),
      );
    }
  }

  @override
  bool shouldRepaint(ArcIndicatorPainter oldDelegate) =>
      oldDelegate.startAngle != startAngle ||
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.value != value ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.strokeAlign != strokeAlign ||
      oldDelegate.strokeCap != strokeCap ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
