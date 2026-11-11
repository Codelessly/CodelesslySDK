import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Caps the size a row or column that stretches its children gives [child]
/// across: [child] takes the whole cross axis up to [max], and is placed by
/// [alignment] in what is left.
///
/// Flutter's `CrossAxisAlignment.stretch` gives every child a tight cross
/// constraint, so neither a fixed size nor a ConstrainedBox can make a child
/// narrower. Codelessly honours a child's max constraint on the cross axis
/// (a paragraph's `maxWidth: 620` in a stretched column), as the editor's
/// layout does; a fixed size still stretches, as in Flutter. This box keeps
/// the stretched size itself, so the Flex lays out as before, and gives
/// [child] the cross constraint capped at [max].
class CrossAxisCap extends SingleChildRenderObjectWidget {
  /// The cross axis of the row or column: horizontal in a column.
  final Axis axis;

  /// The most [child] takes on [axis].
  final double max;

  /// Where [child] goes in the space left on [axis].
  final AlignmentGeometry alignment;

  /// Creates a [CrossAxisCap].
  const CrossAxisCap({
    super.key,
    required this.axis,
    required this.max,
    this.alignment = AlignmentDirectional.topStart,
    super.child,
  });

  @override
  RenderCrossAxisCap createRenderObject(BuildContext context) =>
      RenderCrossAxisCap(
        axis,
        max,
        alignment: alignment,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCrossAxisCap renderObject,
  ) {
    renderObject
      ..axis = axis
      ..max = max
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// The render object of [CrossAxisCap].
class RenderCrossAxisCap extends RenderAligningShiftedBox {
  /// Creates a [RenderCrossAxisCap] capping [axis] at [max].
  RenderCrossAxisCap(
    this._axis,
    this._max, {
    super.alignment,
    super.textDirection,
  });

  Axis _axis;

  /// See [CrossAxisCap.axis].
  Axis get axis => _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  double _max;

  /// See [CrossAxisCap.max].
  double get max => _max;
  set max(double value) {
    if (_max == value) return;
    _max = value;
    markNeedsLayout();
  }

  BoxConstraints _capped(BoxConstraints constraints) => switch (axis) {
    Axis.horizontal => constraints.copyWith(
      minWidth: math.min(constraints.minWidth, max),
      maxWidth: math.min(constraints.maxWidth, max),
    ),
    Axis.vertical => constraints.copyWith(
      minHeight: math.min(constraints.minHeight, max),
      maxHeight: math.min(constraints.maxHeight, max),
    ),
  };

  @override
  double computeMinIntrinsicWidth(double height) {
    final double width = super.computeMinIntrinsicWidth(height);
    return axis == Axis.horizontal ? math.min(width, max) : width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double width = super.computeMaxIntrinsicWidth(height);
    return axis == Axis.horizontal ? math.min(width, max) : width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double height = super.computeMinIntrinsicHeight(
      axis == Axis.horizontal ? math.min(width, max) : width,
    );
    return axis == Axis.vertical ? math.min(height, max) : height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double height = super.computeMaxIntrinsicHeight(
      axis == Axis.horizontal ? math.min(width, max) : width,
    );
    return axis == Axis.vertical ? math.min(height, max) : height;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(_capped(constraints)));
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_capped(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
    alignChild();
  }
}
