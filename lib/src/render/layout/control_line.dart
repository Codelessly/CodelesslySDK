// The control line: a row lines its children up on their control boxes.
//
// A field draws its label above its box and its helper or error line below
// it, inside its own layout box. Centered on the whole of that box, a button
// beside it sits half a label too high; a web page gets this right for free,
// because a flex item there aligns on its first baseline. Here a box can say
// where its control box is inside it ([ControlInsets]: the extent above it
// and below it), and a row (`RenderCodelesslyFlex`, `RenderCodelesslyWrap`)
// aligns its children on those control boxes instead of on their whole
// boxes, as it aligns text on baselines: the label hangs above the line, the
// helper below it, and what has no insets (a button, a text, an icon) is all
// control box.
//
// Who answers:
//
// | Box | Its insets |
// |---|---|
// | a field ([ControlLineField]: text field, dropdown) | its label above, its helper/error/counter below (zero without them) |
// | a row | its children's control band, when one of them has insets (none: zero) |
// | a column of a label, one field-like control and captions under it | the label above, the captions below |
// | a box that draws (a fill, a stroke, a shadow) around a reporter | zero: what is drawn is the control box |
// | a wrapper (proxy, padding, align, margin, fit box, a shell's stack) | its child's, moved by where it puts it |
// | anything else | none ([ControlLine.of] is null) |
//
// Whether a box has insets at all (null or not) is decided by the tree's
// structure only, so a layout and a dry layout agree on it; the values
// themselves come from the layout ([ControlLine.of]) or are computed for
// constraints without one ([ControlLine.dryOf]).
//
// Insets that are all zero change nothing: a row whose children have none
// (or only zero ones) lays out exactly as a Flutter row.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../islands.dart' show SkippedChildLayout;
import '../paint/icon_glyph.dart' show RenderIconGlyph;
import 'fit_box.dart';

/// Where a box's control box is within it: the extent above it (a label and
/// its gap) and below it (a helper, an error, a counter, and their gap).
@immutable
class ControlInsets {
  const ControlInsets(this.above, this.below);

  static const zero = ControlInsets(0, 0);

  final double above, below;

  bool get isZero => above <= 0 && below <= 0;

  @override
  bool operator ==(Object other) => other is ControlInsets && other.above == above && other.below == below;

  @override
  int get hashCode => Object.hash(above, below);

  @override
  String toString() => 'ControlInsets(above: $above, below: $below)';
}

/// A render box that says where its control box is: after its layout
/// ([controlInsets]) and for constraints without one ([dryControlInsets]).
/// Null: it has none (it is not a control, nor holds one a row lines up).
/// Whether it is null must not depend on the constraints.
abstract interface class ControlLineReporter {
  ControlInsets? get controlInsets;
  ControlInsets? dryControlInsets(BoxConstraints constraints);
}

/// A field: a control box with a label that may hang above it and lines
/// that may hang below it. Always has insets (zero without a label or a
/// line below).
abstract interface class ControlLineField implements ControlLineReporter {
  @override
  ControlInsets get controlInsets;
  @override
  ControlInsets dryControlInsets(BoxConstraints constraints);
}

/// A box that draws a node's own decoration: around a control, it is the
/// control box ([drawsBox] true: a fill, a stroke or a shadow).
abstract interface class ControlLineDecoration {
  bool get drawsBox;
}

/// Where a line's children go across it ([ControlLine.place]).
enum ControlLineAlign { start, center, end }

/// Children placed on a control line: each one's top, the extent they take
/// together, and their control band (the union of their control boxes).
class ControlLinePlacement {
  const ControlLinePlacement(this.tops, this.extent, this.bandTop, this.band, this.stretchExtent);

  final List<double> tops;
  final double extent;
  final double bandTop, band;

  /// The extent stretching needs: the tallest label, the tallest control
  /// box and the tallest line below, stacked.
  final double stretchExtent;
}

/// The control line's queries.
abstract final class ControlLine {
  static int _fields = 0;

  /// A field was attached somewhere (its count keeps the rows of a tree
  /// that has none from asking at all).
  static void fieldAttached() => _fields++;
  static void fieldDetached() => _fields = math.max(0, _fields - 1);

  /// Whether any field is attached: when none is, no box has insets.
  static bool get anyField => enabled && _fields > 0;

  /// Off, no box has insets and every row aligns its children on their
  /// whole boxes, as before the control line: tests compare the two.
  @visibleForTesting
  static bool enabled = true;

  /// The control insets of [box] after its layout (null: none).
  static ControlInsets? of(RenderBox box) {
    if (!box.hasSize) return null;
    if (box is SkippedChildLayout && (box as SkippedChildLayout).skipsChildLayout) return null;
    if (box is ControlLineReporter) return (box as ControlLineReporter).controlInsets;
    final child = _through(box);
    if (child == null || !child.hasSize) return null;
    return through(box, child);
  }

  /// [child]'s insets (laid out) as [box]'s, the box it is placed in.
  static ControlInsets? through(RenderBox box, RenderBox child) {
    final inner = of(child);
    if (inner == null) return null;
    if (box is ControlLineDecoration && (box as ControlLineDecoration).drawsBox) return ControlInsets.zero;
    final data = child.parentData;
    final dy = data is BoxParentData ? data.offset.dy : 0.0;
    return ControlInsets(
      math.max(0, dy + inner.above),
      math.max(0, box.size.height - dy - child.size.height + inner.below),
    );
  }

  /// The control insets [box] would have laid out under [constraints]
  /// (null: none). Approximate where a wrapper's placement can't be known
  /// without a layout; null exactly when [of] is.
  static ControlInsets? dryOf(RenderBox box, BoxConstraints constraints) {
    final wasChecking = RenderObject.debugCheckingIntrinsics;
    RenderObject.debugCheckingIntrinsics = true;
    try {
      return _dry(box, constraints);
    } finally {
      RenderObject.debugCheckingIntrinsics = wasChecking;
    }
  }

  static ControlInsets? _dry(RenderBox box, BoxConstraints c) {
    if (box is SkippedChildLayout && (box as SkippedChildLayout).skipsChildLayout) return null;
    if (box is ControlLineReporter) return (box as ControlLineReporter).dryControlInsets(c);
    final child = _through(box);
    if (child == null) return null;
    double top = 0, bottom = 0;
    BoxConstraints inner = c;
    if (box is RenderPadding) {
      final p = box.padding.resolve(box.textDirection);
      inner = c.deflate(p);
      top = p.top;
      bottom = p.bottom;
    } else if (box is RenderPositionedBox) {
      inner = c.loosen();
      final own = box.getDryLayout(c), at = child.getDryLayout(inner);
      final dy = box.alignment.resolve(box.textDirection).alongOffset(Offset(own.width - at.width, own.height - at.height)).dy;
      top = dy;
      bottom = own.height - dy - at.height;
    } else if (box is RenderStack) {
      inner = switch (box.fit) {
        StackFit.passthrough => c,
        StackFit.expand => BoxConstraints.tight(c.biggest),
        StackFit.loose => c.loosen(),
      };
    } else if (box is RenderConstrainedBox) {
      inner = box.additionalConstraints.enforce(c);
    }
    final insets = _dry(child, inner);
    if (insets == null) return null;
    if (box is ControlLineDecoration && (box as ControlLineDecoration).drawsBox) return ControlInsets.zero;
    return ControlInsets(math.max(0, top + insets.above), math.max(0, bottom + insets.below));
  }

  /// The child a wrapper [box] places, whose insets become its own; null
  /// when [box] is not a wrapper the line looks through. A box that scales
  /// its child ([RenderFittedBox]) is not: its child's insets aren't its.
  static RenderBox? _through(RenderBox box) {
    if (box is RenderFittedBox) return null;
    if (box is RenderStack) return _soleInFlow(box);
    if (box is RenderProxyBox) return box.child;
    if (box is RenderPadding) return box.child;
    if (box is RenderPositionedBox) return box.child;
    return null;
  }

  /// A stack's only child that isn't positioned (a shell's content, its
  /// paint layers around it), else null.
  static RenderBox? _soleInFlow(RenderStack stack) {
    RenderBox? found;
    for (var c = stack.firstChild; c != null; c = stack.childAfter(c)) {
      final data = c.parentData! as StackParentData;
      if (data.isPositioned) continue;
      if (found != null) return null;
      found = c;
    }
    return found;
  }

  /// The box under [box] past its wrappers (decorations, scaling and
  /// single-child stacks included): what it is.
  static RenderBox _core(RenderBox box) {
    RenderBox at = box;
    while (true) {
      final next = at is RenderFittedBox ? at.child : _through(at);
      if (next == null) return at;
      at = next;
    }
  }

  static bool _collapsed(RenderBox box) {
    final data = box.parentData;
    if (data is CodelesslyFlexParentData && data.collapsed) return true;
    return box is SkippedChildLayout && (box as SkippedChildLayout).skipsChildLayout;
  }

  /// The children of [flex] that show.
  static List<RenderBox> shownChildren(ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>> flex) => [
        for (var c = flex.firstChild; c != null; c = flex.childAfter(c))
          if (!_collapsed(c)) c,
      ];

  /// Whether [box] is a caption: a text, an icon, or a row of them (a
  /// label with its required mark, an error's icon and message). Something
  /// that draws a box of its own (a button made of a filled row and its
  /// text, a badge) is not.
  ///
  /// A label, a field and its lines are a few boxes deep and a few wide:
  /// past [_deepest] rows and columns, or [_widest] children, nothing is
  /// one, so asking costs little however large the subtree under [box].
  static bool isCaption(RenderBox box, [int depth = 0]) {
    if (depth > _deepest) return false;
    final core = _core(box);
    for (RenderBox? at = box; at != null && !identical(at, core); at = at is RenderFittedBox ? at.child : _through(at)) {
      if (at is ControlLineDecoration && (at as ControlLineDecoration).drawsBox) return false;
    }
    if (core is RenderParagraph || core is RenderIconGlyph) return true;
    if (core is RenderCodelesslyFlex && core.direction == Axis.horizontal) {
      final shown = shownChildren(core);
      return shown.isNotEmpty && shown.length <= _widest && shown.every((c) => isCaption(c, depth + 1));
    }
    return false;
  }

  static const int _deepest = 3, _widest = 6;

  /// Whether [box] is a field, or a field with what goes with it: a row of
  /// it and captions or icons (a search field's icon), a column of a label,
  /// it and captions under it ([labelledFieldIndex]).
  static bool isFieldLike(RenderBox box, [int depth = 0]) {
    if (depth > _deepest) return false;
    final core = _core(box);
    if (core is ControlLineField) return true;
    if (core is! RenderCodelesslyFlex) return false;
    final shown = shownChildren(core);
    if (shown.length > _widest) return false;
    if (core.direction == Axis.vertical) return labelledFieldIndex(shown, depth) != null;
    var fields = 0;
    for (final c in shown) {
      if (isFieldLike(c, depth + 1)) {
        if (++fields > 1) return false;
      } else if (!isCaption(c, depth + 1)) {
        return false;
      }
    }
    return fields == 1;
  }

  /// The index in [shown] (a column's shown children) of its field when the
  /// column is a labelled field: at most one caption (its label) before
  /// one field-like child, and only captions (help, error) after it. Null
  /// otherwise: a column of anything else is not lined up as a field.
  static int? labelledFieldIndex(List<RenderBox> shown, [int depth = 0]) {
    if (shown.length > _widest || depth > _deepest) return null;
    int? field;
    for (var i = 0; i < shown.length; i++) {
      final c = shown[i];
      // Past its label, a column's child is its field or nothing is.
      if (field == null && i <= 1 && isFieldLike(c, depth + 1)) {
        field = i;
      } else if (!isCaption(c, depth + 1)) {
        return null;
      }
    }
    return field;
  }

  /// Places children of [heights] with [insets] (null: none, all control
  /// box) on one control line: their control boxes start together, center
  /// on one line, or end together, as [align] says; what hangs above or
  /// below a box hangs out of the line. The tops are from the top of what
  /// they take together ([ControlLinePlacement.extent]).
  static ControlLinePlacement place(List<double> heights, List<ControlInsets?> insets, ControlLineAlign align) {
    final n = heights.length;
    final a = List<double>.filled(n, 0), b = List<double>.filled(n, 0), d = List<double>.filled(n, 0);
    double maxA = 0, maxB = 0, maxD = 0;
    for (var i = 0; i < n; i++) {
      final ins = insets[i];
      final h = heights[i];
      a[i] = math.min(h, ins?.above ?? 0);
      d[i] = math.min(h - a[i], ins?.below ?? 0);
      b[i] = math.max(0, h - a[i] - d[i]);
      maxA = math.max(maxA, a[i]);
      maxB = math.max(maxB, b[i]);
      maxD = math.max(maxD, d[i]);
    }
    final tops = List<double>.filled(n, 0);
    double bandTop;
    switch (align) {
      case ControlLineAlign.start:
        for (var i = 0; i < n; i++) {
          tops[i] = maxA - a[i];
        }
        bandTop = maxA;
      case ControlLineAlign.end:
        var e = 0.0;
        for (var i = 0; i < n; i++) {
          e = math.max(e, a[i] + b[i]);
        }
        for (var i = 0; i < n; i++) {
          tops[i] = e - b[i] - a[i];
        }
        bandTop = e - maxB;
      case ControlLineAlign.center:
        var m = 0.0;
        for (var i = 0; i < n; i++) {
          m = math.max(m, a[i] + b[i] / 2);
        }
        for (var i = 0; i < n; i++) {
          tops[i] = m - b[i] / 2 - a[i];
        }
        bandTop = m - maxB / 2;
    }
    var extent = 0.0;
    for (var i = 0; i < n; i++) {
      extent = math.max(extent, tops[i] + heights[i]);
    }
    return ControlLinePlacement(tops, extent, bandTop, maxB, maxA + maxB + maxD);
  }

  /// The line for a flex's [CrossAxisAlignment] (null: baseline, which
  /// lines up text, and stretch, which [stretch] does).
  static ControlLineAlign? alignOf(CrossAxisAlignment cross) => switch (cross) {
        CrossAxisAlignment.start => ControlLineAlign.start,
        CrossAxisAlignment.center => ControlLineAlign.center,
        CrossAxisAlignment.end => ControlLineAlign.end,
        CrossAxisAlignment.stretch || CrossAxisAlignment.baseline => null,
      };

  /// How far down a group [extent] thick goes in [room] when aligned by
  /// [align].
  static double shift(ControlLineAlign align, double room, double extent) => switch (align) {
        ControlLineAlign.start => 0,
        ControlLineAlign.center => (room - extent) / 2,
        ControlLineAlign.end => room - extent,
      };

  /// Lays [child] out stretched so its control box is [band] thick, its
  /// label above and its lines below as [natural] (its insets unstretched)
  /// says, and returns the extent above its box. A field held to a height
  /// keeps an error that has no helper's room out of it (the error hangs
  /// below), so the extents are read back and the height corrected once
  /// when its box came out thicker. (One that came out thinner keeps its
  /// own height inside the room: a child aligned in its slot.) [insetsOf]
  /// reads a laid-out child's insets.
  static double stretchTo(RenderBox child, double band, ControlInsets? natural, ControlInsets? Function(RenderBox) insetsOf) {
    final double width = child.size.width;
    double height = (natural?.above ?? 0) + band + (natural?.below ?? 0);
    child.layout(BoxConstraints.tightFor(width: width, height: height), parentUsesSize: true);
    if (natural == null) return 0;
    final ControlInsets now = insetsOf(child) ?? ControlInsets.zero;
    final double box = height - now.above - now.below;
    if (box - band > precisionErrorTolerance) {
      height = math.max(0, height + band - box);
      child.layout(BoxConstraints.tightFor(width: width, height: height), parentUsesSize: true);
    }
    return natural.above;
  }

  /// Whether any of [insets] is not zero: only then does a line differ from
  /// a Flutter row's alignment.
  static bool anyNonZero(Iterable<ControlInsets?> insets) => insets.any((i) => i != null && !i.isZero);
}
