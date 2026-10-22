import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import 'freeform_layout.dart';
import 'passive_stack_transformer.dart';

/// The layout properties that put a freeform child where it was moved to.
@immutable
class FreeformMove {
  /// The child's new pins, distances from the parent's middle box.
  final EdgePinsModel edgePins;

  /// The child's new alignment, for a child placed by alignment.
  final AlignmentModel alignment;

  /// The child's new outer box origin relative to the parent's middle box,
  /// as a design-size record. [FreeformLayout] reads it only for a child in
  /// align positioning mode that has no pins of its own on an axis.
  final Offset outerOrigin;

  const FreeformMove({
    required this.edgePins,
    required this.alignment,
    required this.outerOrigin,
  });

  /// The properties that make [FreeformLayout] place [node]'s outer box at
  /// [outerStart], measured from the start of [parent]'s inner (padded) box,
  /// when that inner box is [innerSize] and the node's outer box is
  /// [outerSize], as laid out.
  ///
  /// The node keeps its positioning rule on each axis: a pinned side stays
  /// pinned and gets the new distance, an aligned node gets a new alignment,
  /// and a node that keeps its share of the free space gets the share that
  /// lands it at [outerStart]. Its size is unchanged; an axis on which the
  /// node fills its parent can't move and is left as it is.
  ///
  /// This is the inverse of [PassiveStackTransformer.placementFor] followed
  /// by [FreeformAxisPlacement.offsetIn], so the node lands exactly at
  /// [outerStart] without clamping.
  static FreeformMove resolve({
    required BaseNode node,
    required BaseNode parent,
    required Offset outerStart,
    required Size innerSize,
    required Size outerSize,
    AxisC? scrollAxis,
  }) {
    final FreeformPlacement placement = PassiveStackTransformer.placementFor(
      node,
      parent,
      scrollAxis: scrollAxis,
    );
    final _AxisMove h = _move(
      placement.horizontal,
      start: outerStart.dx,
      extent: innerSize.width,
      childExtent: outerSize.width,
      startEdge: parent.innerBoxLocal.edgeLeft,
      endEdge: parent.innerBoxLocal.edgeRight,
      startPin: node.edgePins.left,
      endPin: node.edgePins.right,
      origin: node.outerBoxLocal.x,
    );
    final _AxisMove v = _move(
      placement.vertical,
      start: outerStart.dy,
      extent: innerSize.height,
      childExtent: outerSize.height,
      startEdge: parent.innerBoxLocal.edgeTop,
      endEdge: parent.innerBoxLocal.edgeBottom,
      startPin: node.edgePins.top,
      endPin: node.edgePins.bottom,
      origin: node.outerBoxLocal.y,
    );
    final AlignmentData? aligned = node.alignment.data;
    return FreeformMove(
      edgePins: EdgePinsModel(
        left: h.startPin,
        top: v.startPin,
        right: h.endPin,
        bottom: v.endPin,
      ),
      alignment: aligned == null
          ? node.alignment
          : AlignmentModel(
              AlignmentData(h.alignment ?? aligned.x, v.alignment ?? aligned.y),
            ),
      outerOrigin: Offset(h.origin, v.origin),
    );
  }

  static _AxisMove _move(
    FreeformAxisPlacement placement, {
    required double start,
    required double extent,
    required double childExtent,
    required double startEdge,
    required double endEdge,
    required double? startPin,
    required double? endPin,
    required double origin,
  }) {
    // Pins are measured from the parent's middle box, offsets from its
    // inner box.
    double? asStartPin(double offset) => offset + startEdge;
    double? asEndPin(double offset) => offset + endEdge;
    final double end = extent - start - childExtent;
    final double newOrigin = start + startEdge;

    switch (placement.mode) {
      case FreeformAxisMode.fill:
        return _AxisMove(startPin, endPin, origin);
      case FreeformAxisMode.align:
        final double free = extent - childExtent;
        return _AxisMove(
          startPin,
          endPin,
          newOrigin,
          alignment: free == 0 ? 0 : 2 * start / free - 1,
        );
      case FreeformAxisMode.stretch:
        return _AxisMove(asStartPin(start), asEndPin(end), newOrigin);
      case FreeformAxisMode.end:
        return _AxisMove(startPin, asEndPin(end), newOrigin);
      case FreeformAxisMode.start:
      // Data places the child at runtime; a drag moves its design box.
      case FreeformAxisMode.fraction:
        return _AxisMove(asStartPin(start), endPin, newOrigin);
      case FreeformAxisMode.relative:
        // offsetIn: designStart + (extent - designExtent) * share, with
        // share = designStart / (designExtent - childExtent). Solve for the
        // design start that lands at [start] in a parent of [extent].
        final double designFree = placement.parentExtent - placement.extent;
        final double runtimeFree = extent - placement.extent;
        final double designStart = designFree <= 0 || runtimeFree == 0
            ? start
            : start * designFree / runtimeFree;
        return _AxisMove(
          startPin == null ? null : asStartPin(designStart),
          endPin,
          designStart + startEdge,
        );
    }
  }
}

class _AxisMove {
  final double? startPin;
  final double? endPin;
  final double origin;
  final double? alignment;

  const _AxisMove(this.startPin, this.endPin, this.origin, {this.alignment});
}
