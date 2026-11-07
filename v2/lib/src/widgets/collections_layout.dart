// Layout render objects of the collections group: what SDK 8.x's ListView,
// GridView, PageView, Wrap and Stack built for a list, grid or page view, at
// rest (scroll offset 0), laid out directly over the items' node boxes.
//
// Each lays out the boxes it holds, one per item (the item template repeated,
// see NodeBuilder.syncChildren's instances). An endless view (no item count)
// asks for more items during layout until they cover the viewport and its
// cache extent, as a sliver list builds them.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';

class CollectionParentData extends ContainerBoxParentData<RenderBox> {}

/// The base: a container of item boxes, clipped when they overflow.
abstract class RenderCollection extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CollectionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CollectionParentData> {
  Clip _clipBehavior = Clip.hardEdge;
  Clip get clipBehavior => _clipBehavior;
  set clipBehavior(Clip v) {
    if (v == _clipBehavior) return;
    _clipBehavior = v;
    markNeedsPaint();
  }

  /// Paints the last child first (the first on top).
  bool _paintReversed = false;
  bool get paintReversed => _paintReversed;
  set paintReversed(bool v) {
    if (v == _paintReversed) return;
    _paintReversed = v;
    markNeedsPaint();
  }

  /// Builds [count] items (an endless view that needs more), inside layout.
  void Function(int count)? onNeedItems;

  /// The items an endless view may build at most.
  static const int maxEndlessItems = 400;

  /// Asks for [count] items; true when more children came.
  bool requestItems(int count) {
    final cb = onNeedItems;
    if (cb == null || count <= childCount) return false;
    final before = childCount;
    invokeLayoutCallback<BoxConstraints>((_) => cb(math.min(count, maxEndlessItems)));
    return childCount > before;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CollectionParentData) child.parentData = CollectionParentData();
  }

  bool _overflows = false;

  /// Lays out the children and sets [size]; returns whether they overflow.
  bool layoutItems();

  @override
  void performLayout() {
    _overflows = layoutItems();
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle();

  void _paintChildren(PaintingContext context, Offset offset) {
    paintDecorations(context, offset);
    if (!_paintReversed) {
      defaultPaint(context, offset);
      return;
    }
    var child = lastChild;
    while (child != null) {
      final pd = child.parentData! as CollectionParentData;
      context.paintChild(child, pd.offset + offset);
      child = pd.previousSibling;
    }
  }

  /// Paints what goes under the items (dividers).
  void paintDecorations(PaintingContext context, Offset offset) {}

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_overflows && _clipBehavior != Clip.none) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintChildren,
        clipBehavior: _clipBehavior,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      _paintChildren(context, offset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _overflows && _clipBehavior != Clip.none ? Offset.zero & size : null;

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_paintReversed) return defaultHitTestChildren(result, position: position);
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as CollectionParentData;
      final hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (r, p) => child!.hitTest(r, position: p),
      );
      if (hit) return true;
      child = pd.nextSibling;
    }
    return false;
  }

  List<RenderBox> get children {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  static double main(Size s, Axis axis) => axis == Axis.vertical ? s.height : s.width;
  static double cross(Size s, Axis axis) => axis == Axis.vertical ? s.width : s.height;
  static Size sizeOf(double main, double cross, Axis axis) =>
      axis == Axis.vertical ? Size(cross, main) : Size(main, cross);
  static Offset offsetOf(double main, double cross, Axis axis) =>
      axis == Axis.vertical ? Offset(cross, main) : Offset(main, cross);
  static BoxConstraints constraintsOf({
    required double minMain,
    required double maxMain,
    required double minCross,
    required double maxCross,
    required Axis axis,
  }) => axis == Axis.vertical
      ? BoxConstraints(minWidth: minCross, maxWidth: maxCross, minHeight: minMain, maxHeight: maxMain)
      : BoxConstraints(minWidth: minMain, maxWidth: maxMain, minHeight: minCross, maxHeight: maxCross);

  bool get _anyChildOutside {
    for (final c in children) {
      final o = (c.parentData! as CollectionParentData).offset;
      final r = o & c.size;
      if (r.left < -0.01 || r.top < -0.01 || r.right > size.width + 0.01 || r.bottom > size.height + 0.01) {
        return true;
      }
    }
    return false;
  }
}

/// A divider between list items (Flutter's `Divider` / `VerticalDivider`).
class ListDivider {
  const ListDivider({required this.color, this.thickness = 1, this.indent = 0, this.endIndent = 0});
  final Color color;
  final double thickness, indent, endIndent;

  @override
  bool operator ==(Object other) =>
      other is ListDivider &&
      other.color == color &&
      other.thickness == thickness &&
      other.indent == indent &&
      other.endIndent == endIndent;

  @override
  int get hashCode => Object.hash(color, thickness, indent, endIndent);
}

/// A list's items one after another along [axis], as a `ListView` at rest
/// (viewport: [anchorEnd] when reversed) or as SDK 8.x's `Flex` of every
/// item (a list that builds all its items).
///
/// * Main axis: each item takes [itemMain] when set (a fixed item extent,
///   or the design extent of an item that fills), else its own extent;
///   [gap] goes between items (a separator); an item but the last takes
///   [overlap] less room, so the next is drawn over it.
/// * Cross axis: the item is laid out loose and centred in the list's
///   cross extent, or tight when [stretch]. With [hugCross], the list is as
///   thick as its thickest item (stretched items: that thick).
/// * Size: the incoming max on an axis, unless it hugs ([hugMain],
///   [hugCross]) or is unbounded.
class RenderListItems extends RenderCollection {
  Axis axis = Axis.vertical;
  bool reverse = false;

  /// Reversed, the first item sits at the end of the box (a viewport);
  /// otherwise the reversed items start at the box's start (a Flex).
  bool anchorEnd = true;
  EdgeInsets padding = EdgeInsets.zero;
  bool hugMain = false;
  bool hugCross = false;
  bool stretch = false;
  double? itemMain;
  double gap = 0;
  double overlap = 0;
  ListDivider? divider;

  /// Null: endless (builds items to cover the viewport and [cacheExtent]).
  int? itemCount;

  /// False for a scroll view (SDK 8.x's ListView): a viewport has no
  /// intrinsic size, so it reports none (a row squeezing it can take it to
  /// nothing). True when every item is laid out in a Flex.
  bool _measurable = true;
  bool get measurable => _measurable;
  set measurable(bool v) {
    if (v == _measurable) return;
    _measurable = v;
    markNeedsLayout();
  }
  double cacheExtent = 250;

  void update({
    required Axis axis,
    required bool reverse,
    required bool anchorEnd,
    required EdgeInsets padding,
    required bool hugMain,
    required bool hugCross,
    required bool stretch,
    required double? itemMain,
    required double gap,
    required double overlap,
    required ListDivider? divider,
    required int? itemCount,
    required double cacheExtent,
  }) {
    if (axis == this.axis &&
        reverse == this.reverse &&
        anchorEnd == this.anchorEnd &&
        padding == this.padding &&
        hugMain == this.hugMain &&
        hugCross == this.hugCross &&
        stretch == this.stretch &&
        itemMain == this.itemMain &&
        gap == this.gap &&
        overlap == this.overlap &&
        divider == this.divider &&
        itemCount == this.itemCount &&
        cacheExtent == this.cacheExtent) {
      return;
    }
    this.axis = axis;
    this.reverse = reverse;
    this.anchorEnd = anchorEnd;
    this.padding = padding;
    this.hugMain = hugMain;
    this.hugCross = hugCross;
    this.stretch = stretch;
    this.itemMain = itemMain;
    this.gap = gap;
    this.overlap = overlap;
    this.divider = divider;
    this.itemCount = itemCount;
    this.cacheExtent = cacheExtent;
    markNeedsLayout();
  }

  final List<Rect> _dividers = [];

  double get _padMain => axis == Axis.vertical ? padding.vertical : padding.horizontal;
  double get _padCross => axis == Axis.vertical ? padding.horizontal : padding.vertical;
  double get _padMainStart => axis == Axis.vertical ? padding.top : padding.left;
  double get _padMainEnd => axis == Axis.vertical ? padding.bottom : padding.right;
  double get _padCrossStart => axis == Axis.vertical ? padding.left : padding.top;

  BoxConstraints _childConstraints(double crossMax, {double? tightCross}) {
    final m = itemMain;
    return RenderCollection.constraintsOf(
      minMain: m ?? 0,
      maxMain: m ?? double.infinity,
      minCross: tightCross ?? 0,
      maxCross: tightCross ?? crossMax,
      axis: axis,
    );
  }

  @override
  bool layoutItems() {
    final c = constraints;
    final maxMain = RenderCollection.main(c.biggest, axis);
    final maxCross = RenderCollection.cross(c.biggest, axis);
    final minMain = RenderCollection.main(c.smallest, axis);
    final minCross = RenderCollection.cross(c.smallest, axis);
    final hugsCross = hugCross || !maxCross.isFinite;
    final crossAvail = math.max(0.0, (maxCross.isFinite ? maxCross : double.infinity) - _padCross);
    final viewportMain = hugMain || !maxMain.isFinite ? double.infinity : math.max(0.0, maxMain - _padMain);
    final stretchNow = stretch && !hugsCross;

    // Main-axis extents of the items' slots, in order.
    final advances = <double>[];
    var used = 0.0;
    var child = firstChild;
    RenderBox? last;
    var index = 0;
    while (true) {
      while (child != null) {
        child.layout(_childConstraints(crossAvail, tightCross: stretchNow ? crossAvail : null), parentUsesSize: true);
        final extent = RenderCollection.main(child.size, axis);
        final count = itemCount;
        final overlaps = overlap > 0 && count != null && index < count - 1;
        final advance = overlaps ? math.max(0.0, extent - overlap) : extent;
        if (advances.isNotEmpty) used += gap;
        advances.add(advance);
        used += advance;
        index++;
        last = child;
        child = childAfter(child);
      }
      if (itemCount != null || !viewportMain.isFinite || used >= viewportMain + cacheExtent) break;
      if (childCount >= RenderCollection.maxEndlessItems) break;
      final per = advances.isEmpty ? 0.0 : (used / advances.length);
      if (per < 1) break;
      final more = ((viewportMain + cacheExtent - used) / (per + gap)).ceil() + 1;
      if (!requestItems(childCount + more)) break;
      child = last == null ? firstChild : childAfter(last);
    }

    final items = children;
    var contentCross = 0.0;
    for (final it in items) {
      contentCross = math.max(contentCross, RenderCollection.cross(it.size, axis));
    }
    if (stretch && hugsCross) {
      // As thick as the thickest item (IntrinsicWidth / IntrinsicHeight
      // around the Flex), every item that thick.
      contentCross = 0;
      for (final it in items) {
        contentCross = math.max(
          contentCross,
          axis == Axis.vertical ? it.getMaxIntrinsicWidth(double.infinity) : it.getMaxIntrinsicHeight(double.infinity),
        );
      }
      for (final it in items) {
        it.layout(_childConstraints(contentCross, tightCross: contentCross), parentUsesSize: true);
      }
    }

    final contentMain = used;
    final mainSize = hugMain || !maxMain.isFinite
        ? (contentMain + _padMain).clamp(minMain, maxMain).toDouble()
        : maxMain;
    var crossSize = hugsCross ? (contentCross + _padCross).clamp(minCross, maxCross).toDouble() : maxCross;
    if (hugsCross && divider != null && maxCross.isFinite) crossSize = maxCross;
    size = RenderCollection.sizeOf(mainSize, crossSize, axis);

    // The cross extent items are centred in.
    final crossInner = hugsCross ? contentCross : math.max(0.0, crossSize - _padCross);
    final dividerCross = math.max(0.0, crossSize - _padCross);

    // Slots in visual order: reversed for a reversed Flex.
    final order = [for (var i = 0; i < items.length; i++) i];
    final flexReversed = reverse && !anchorEnd;
    if (flexReversed) order.setAll(0, order.reversed.toList());
    final logical = List<double>.filled(items.length, 0);
    var at = 0.0;
    _dividers.clear();
    for (var k = 0; k < order.length; k++) {
      final i = order[k];
      if (k > 0) {
        _addDivider(at, dividerCross, mainSize, gapBefore: true);
        at += gap;
      }
      logical[i] = at;
      at += advances[i];
    }
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final itemCross = RenderCollection.cross(it.size, axis);
      final double mainPos;
      if (reverse && anchorEnd) {
        mainPos = mainSize - _leading(_padMainEnd, mainSize) - logical[i] - advances[i];
      } else {
        mainPos = _leading(_padMainStart, mainSize) + logical[i];
      }
      final crossPos = _padCrossStart + (stretch ? 0 : (crossInner - itemCross) / 2);
      (it.parentData! as CollectionParentData).offset = RenderCollection.offsetOf(mainPos, crossPos, axis);
    }
    return _anyChildOutside || _dividers.any((r) => !(Offset.zero & size).contains(r.topLeft));
  }

  /// A viewport's leading padding is painted no further than its extent
  /// (SliverPadding's paint offset), so a list squeezed to nothing still
  /// shows its first item at its start.
  double _leading(double pad, double mainSize) => anchorEnd ? math.min(pad, mainSize) : pad;

  void _addDivider(double logicalStart, double crossExtent, double mainSize, {required bool gapBefore}) {
    final d = divider;
    if (d == null || gap <= 0 && d.thickness <= 0) return;
    final slotStart = reverse && anchorEnd
        ? mainSize - _leading(_padMainEnd, mainSize) - logicalStart - gap
        : _leading(_padMainStart, mainSize) + logicalStart;
    final lineStart = slotStart + (gap - d.thickness) / 2;
    final crossStart = _padCrossStart + d.indent;
    final crossEnd = _padCrossStart + crossExtent - d.endIndent;
    if (crossEnd <= crossStart || d.thickness <= 0) return;
    _dividers.add(
      axis == Axis.vertical
          ? Rect.fromLTRB(crossStart, lineStart, crossEnd, lineStart + d.thickness)
          : Rect.fromLTRB(lineStart, crossStart, lineStart + d.thickness, crossEnd),
    );
  }

  @override
  void paintDecorations(PaintingContext context, Offset offset) {
    final d = divider;
    if (d == null || _dividers.isEmpty) return;
    final paint = Paint()..color = d.color;
    for (final r in _dividers) {
      context.canvas.drawRect(r.shift(offset), paint);
    }
  }

  // Intrinsics, for a list that builds all its items (a row or column
  // around it may measure it).
  double _intrinsicMain(double cross, bool max) {
    var total = 0.0;
    var n = 0;
    for (final c in children) {
      final e =
          itemMain ??
          (axis == Axis.vertical
              ? (max ? c.getMaxIntrinsicHeight(cross) : c.getMinIntrinsicHeight(cross))
              : (max ? c.getMaxIntrinsicWidth(cross) : c.getMinIntrinsicWidth(cross)));
      total += e;
      n++;
    }
    if (n > 1) total += gap * (n - 1) - (itemCount != null ? overlap * (n - 1) : 0);
    return math.max(0, total) + _padMain;
  }

  double _intrinsicCross(double main, bool max) {
    var best = 0.0;
    for (final c in children) {
      final e = axis == Axis.vertical
          ? (max ? c.getMaxIntrinsicWidth(double.infinity) : c.getMinIntrinsicWidth(double.infinity))
          : (max ? c.getMaxIntrinsicHeight(double.infinity) : c.getMinIntrinsicHeight(double.infinity));
      best = math.max(best, e);
    }
    return best + _padCross;
  }

  @override
  double computeMinIntrinsicWidth(double height) => !_measurable
      ? 0
      : axis == Axis.horizontal ? _intrinsicMain(height, false) : _intrinsicCross(height, false);
  @override
  double computeMaxIntrinsicWidth(double height) => !_measurable
      ? 0
      : axis == Axis.horizontal ? _intrinsicMain(height, true) : _intrinsicCross(height, true);
  @override
  double computeMinIntrinsicHeight(double width) => !_measurable
      ? 0
      : axis == Axis.vertical ? _intrinsicMain(width, false) : _intrinsicCross(width, false);
  @override
  double computeMaxIntrinsicHeight(double width) => !_measurable
      ? 0
      : axis == Axis.vertical ? _intrinsicMain(width, true) : _intrinsicCross(width, true);
}

/// How a wrapping list places a run's items along it (`WrapAlignment`).
enum RunAlignment { start, end, center, spaceBetween, spaceAround, spaceEvenly }

/// A wrapping list's items, as Flutter's `Wrap` lays them out (runs along
/// [axis], [spacing] between items, [runSpacing] between runs) inside
/// [padding]. Each item takes [itemWidth] / [itemHeight] when set (its
/// design extent where it would fill), else its own size. The box takes the
/// incoming max on an axis unless it hugs it.
class RenderWrapItems extends RenderCollection {
  Axis axis = Axis.horizontal;
  EdgeInsets padding = EdgeInsets.zero;
  double spacing = 0, runSpacing = 0;
  RunAlignment alignment = RunAlignment.start;

  /// -1 start, 0 center, 1 end.
  double crossAlignment = -1;
  bool hugWidth = false, hugHeight = false;
  bool stretch = false;

  /// With [stretch], a run is as thick as its items' intrinsic thickness
  /// (SDK 8.x's RunStretchWrap); else as their laid-out thickness.
  bool measure = true;
  double? itemWidth, itemHeight;

  @override
  bool layoutItems() {
    final c = constraints;
    final vertical = axis == Axis.vertical;
    final padMain = vertical ? padding.vertical : padding.horizontal;
    final padCross = vertical ? padding.horizontal : padding.vertical;
    final hugMain = vertical ? hugHeight : hugWidth;
    final hugCross = vertical ? hugWidth : hugHeight;
    final maxMain = RenderCollection.main(c.biggest, axis);
    final maxCross = RenderCollection.cross(c.biggest, axis);
    final minMain = RenderCollection.main(c.smallest, axis);
    final minCross = RenderCollection.cross(c.smallest, axis);
    final mainLimit = maxMain.isFinite ? math.max(0.0, maxMain - padMain) : double.infinity;
    final childConstraints = BoxConstraints(
      minWidth: itemWidth ?? 0,
      maxWidth: itemWidth ?? (vertical ? double.infinity : mainLimit),
      minHeight: itemHeight ?? 0,
      maxHeight: itemHeight ?? (vertical ? mainLimit : double.infinity),
    );
    final items = children;
    final runs = <List<RenderBox>>[];
    var run = <RenderBox>[];
    var runMain = 0.0;
    for (final it in items) {
      it.layout(childConstraints, parentUsesSize: true);
      final e = RenderCollection.main(it.size, axis);
      if (run.isNotEmpty && runMain + spacing + e > mainLimit + precisionErrorTolerance) {
        runs.add(run);
        run = [];
        runMain = 0;
      }
      runMain += (run.isEmpty ? 0 : spacing) + e;
      run.add(it);
    }
    if (run.isNotEmpty) runs.add(run);

    double runMainOf(List<RenderBox> r) =>
        r.fold<double>(0, (s, it) => s + RenderCollection.main(it.size, axis)) + spacing * (r.length - 1);
    double runCrossOf(List<RenderBox> r) =>
        r.fold<double>(0, (s, it) => math.max(s, RenderCollection.cross(it.size, axis)));
    if (stretch) {
      double natural(RenderBox it) {
        final laid = RenderCollection.cross(it.size, axis);
        if (!measure) return laid;
        final main = RenderCollection.main(it.size, axis);
        final m = vertical ? it.getMaxIntrinsicWidth(main) : it.getMaxIntrinsicHeight(main);
        return m.isFinite && m > 0 ? m : laid;
      }

      for (final r in runs) {
        final thick = r.fold<double>(0, (s, it) => math.max(s, natural(it)));
        for (final it in r) {
          final w = vertical ? thick : it.size.width, h = vertical ? it.size.height : thick;
          it.layout(BoxConstraints.tight(Size(w, h)), parentUsesSize: true);
        }
      }
    }
    var contentMain = 0.0, contentCross = 0.0;
    for (final r in runs) {
      contentMain = math.max(contentMain, runMainOf(r));
      contentCross += runCrossOf(r);
    }
    if (runs.length > 1) contentCross += runSpacing * (runs.length - 1);

    // The Wrap is as long as its longest run, or the incoming extent when
    // that's tight; the box hugs or takes the incoming max.
    final mainSize = hugMain || !maxMain.isFinite
        ? (contentMain + padMain).clamp(minMain, maxMain).toDouble()
        : maxMain;
    final crossSize = hugCross || !maxCross.isFinite
        ? (contentCross + padCross).clamp(minCross, maxCross).toDouble()
        : maxCross;
    size = RenderCollection.sizeOf(mainSize, crossSize, axis);
    final container = math.max(contentMain, mainSize - padMain);

    var crossAt = vertical ? padding.left : padding.top;
    final mainStart = vertical ? padding.top : padding.left;
    for (final r in runs) {
      final rm = runMainOf(r), rc = runCrossOf(r);
      final free = math.max(0.0, container - rm);
      var lead = 0.0, between = spacing;
      switch (alignment) {
        case RunAlignment.start:
          break;
        case RunAlignment.end:
          lead = free;
        case RunAlignment.center:
          lead = free / 2;
        case RunAlignment.spaceBetween:
          between = r.length > 1 ? free / (r.length - 1) + spacing : spacing;
        case RunAlignment.spaceAround:
          between = free / r.length + spacing;
          lead = between / 2 - spacing / 2;
        case RunAlignment.spaceEvenly:
          between = free / (r.length + 1) + spacing;
          lead = between - spacing;
      }
      var at = mainStart + lead;
      for (final it in r) {
        final ic = RenderCollection.cross(it.size, axis);
        final cOff = (rc - ic) * (crossAlignment + 1) / 2;
        (it.parentData! as CollectionParentData).offset = RenderCollection.offsetOf(at, crossAt + cOff, axis);
        at += RenderCollection.main(it.size, axis) + between;
      }
      crossAt += rc + runSpacing;
    }
    return _anyChildOutside;
  }
}

/// Items layered in the box (a stacked list), each placed by [placeAt]
/// from its laid-out size and the box's size.
class RenderLayeredItems extends RenderCollection {
  /// Constraints for an item, from the box's size.
  BoxConstraints Function(Size box) itemConstraints = (box) => BoxConstraints.loose(box);

  /// Where an item of [item] size sits in a [box]-sized box.
  Offset Function(Size box, Size item) placeAt = (box, item) => Offset.zero;

  void changed() => markNeedsLayout();

  @override
  bool layoutItems() {
    size = constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;
    for (final it in children) {
      it.layout(itemConstraints(size), parentUsesSize: true);
      (it.parentData! as CollectionParentData).offset = placeAt(size, it.size);
    }
    return _anyChildOutside;
  }
}

/// A grid's cells as `GridView` lays them out at rest: [crossAxisCount]
/// cells (or as many as fit [maxCrossAxisExtent]) per row, each
/// [mainAxisExtent] long (else its width over [childAspectRatio]), or, with
/// [shrinkWrapRows], each row as long as its longest item.
class RenderGridItems extends RenderCollection {
  Axis axis = Axis.vertical;
  bool reverse = false;
  EdgeInsets padding = EdgeInsets.zero;
  int crossAxisCount = 2;
  double? maxCrossAxisExtent;
  double mainAxisSpacing = 0, crossAxisSpacing = 0, childAspectRatio = 1;
  double? mainAxisExtent;
  bool shrinkWrapRows = false;

  /// With [shrinkWrapRows]: cells stretch to their row's longest item.
  bool intrinsicRows = true;
  bool hugMain = false;
  int? itemCount;
  double cacheExtent = 250;

  void changed() => markNeedsLayout();

  int _columns(double crossInner) {
    final max = maxCrossAxisExtent;
    if (max == null) return math.max(1, crossAxisCount);
    if (shrinkWrapRows) return crossInner.isFinite ? math.max(1, (crossInner / (max + crossAxisSpacing)).ceil()) : 1;
    return math.max(1, (crossInner / (max + crossAxisSpacing)).ceil());
  }

  @override
  bool layoutItems() {
    final c = constraints;
    final vertical = axis == Axis.vertical;
    final padMain = vertical ? padding.vertical : padding.horizontal;
    final padCross = vertical ? padding.horizontal : padding.vertical;
    final padMainStart = vertical ? padding.top : padding.left;
    final padMainEnd = vertical ? padding.bottom : padding.right;
    final padCrossStart = vertical ? padding.left : padding.top;
    final maxMain = RenderCollection.main(c.biggest, axis);
    final maxCross = RenderCollection.cross(c.biggest, axis);
    final minMain = RenderCollection.main(c.smallest, axis);
    final crossSize = maxCross.isFinite ? maxCross : RenderCollection.cross(c.smallest, axis);
    final crossInner = math.max(0.0, crossSize - padCross);
    final cols = _columns(crossInner);
    final cellCross = math.max(0.0, crossInner - crossAxisSpacing * (cols - 1)) / cols;
    final viewportMain = hugMain || !maxMain.isFinite ? double.infinity : math.max(0.0, maxMain - padMain);

    final fixedRow = mainAxisExtent ?? cellCross / childAspectRatio;
    final endless = itemCount == null && viewportMain.isFinite;
    if (endless && !shrinkWrapRows && fixedRow + mainAxisSpacing >= 1) {
      // Rows of a known extent: as many as cover the viewport and cache.
      final rows = ((viewportMain + cacheExtent) / (fixedRow + mainAxisSpacing)).ceil() + 1;
      requestItems(rows * cols);
    }

    // Rows: their main extent, in order.
    var rowExtents = <double>[];
    var used = 0.0;
    while (true) {
      rowExtents = [];
      used = 0;
      final items = children;
      for (var start = 0; start < items.length; start += cols) {
        final row = items.sublist(start, math.min(items.length, start + cols));
        double extent;
        if (!shrinkWrapRows) {
          extent = fixedRow;
          for (final it in row) {
            it.layout(BoxConstraints.tight(RenderCollection.sizeOf(extent, cellCross, axis)), parentUsesSize: true);
          }
        } else {
          for (final it in row) {
            it.layout(
              RenderCollection.constraintsOf(
                minMain: 0,
                maxMain: double.infinity,
                minCross: cellCross,
                maxCross: cellCross,
                axis: axis,
              ),
              parentUsesSize: true,
            );
          }
          // IntrinsicHeight around the row: its longest item's intrinsic
          // extent at the cell's width.
          extent = intrinsicRows
              ? row.fold<double>(
                  0,
                  (s, it) =>
                      math.max(s, vertical ? it.getMaxIntrinsicHeight(cellCross) : it.getMaxIntrinsicWidth(cellCross)),
                )
              : row.fold<double>(0, (s, it) => math.max(s, RenderCollection.main(it.size, axis)));
          if (intrinsicRows) {
            for (final it in row) {
              it.layout(BoxConstraints.tight(RenderCollection.sizeOf(extent, cellCross, axis)), parentUsesSize: true);
            }
          }
        }
        if (rowExtents.isNotEmpty) used += mainAxisSpacing;
        rowExtents.add(extent);
        used += extent;
      }
      if (!endless || !shrinkWrapRows || used >= viewportMain + cacheExtent) break;
      if (childCount >= RenderCollection.maxEndlessItems) break;
      final per = rowExtents.isEmpty ? 0.0 : used / rowExtents.length;
      if (per < 1) break;
      final moreRows = ((viewportMain + cacheExtent - used) / (per + mainAxisSpacing)).ceil() + 1;
      if (!requestItems((rowExtents.length + moreRows) * cols)) break;
    }

    final mainSize = hugMain || !maxMain.isFinite ? (used + padMain).clamp(minMain, maxMain).toDouble() : maxMain;
    size = RenderCollection.sizeOf(mainSize, crossSize, axis);

    final items = children;
    var rowStart = 0.0;
    for (var r = 0; r < rowExtents.length; r++) {
      for (var col = 0; col < cols; col++) {
        final i = r * cols + col;
        if (i >= items.length) break;
        final it = items[i];
        final itemMainSize = RenderCollection.main(it.size, axis);
        final mainPos = reverse
            ? mainSize - math.min(padMainEnd, mainSize) - rowStart - itemMainSize
            : math.min(padMainStart, mainSize) + rowStart;
        final crossPos = padCrossStart + col * (cellCross + crossAxisSpacing);
        (it.parentData! as CollectionParentData).offset = RenderCollection.offsetOf(mainPos, crossPos, axis);
      }
      rowStart += rowExtents[r] + mainAxisSpacing;
    }
    return _anyChildOutside;
  }
}

/// A page view's pages at rest: each [viewportFraction] of the viewport
/// long, the viewport's thickness across, from [firstIndex] (the first
/// built page) on, scrolled to [initialPage].
class RenderPageItems extends RenderCollection {
  Axis axis = Axis.horizontal;
  bool reverse = false;
  double viewportFraction = 1;
  bool padEnds = true;
  int initialPage = 0;
  int firstIndex = 0;
  int? itemCount;

  void changed() => markNeedsLayout();

  /// The scroll offset at rest, in viewports, and the leading padding.
  static ({double offset, double pad}) restOf({
    required double viewportFraction,
    required bool padEnds,
    required int initialPage,
    required int? itemCount,
  }) {
    final f = viewportFraction;
    final pad = padEnds && f < 1 ? (1 - f) / 2 : 0.0;
    var offset = initialPage * f + math.max(0.0, (f - 1) / 2);
    if (itemCount != null) {
      final max = math.max(0.0, pad * 2 + itemCount * f - 1);
      offset = offset.clamp(0, max).toDouble();
    }
    return (offset: offset, pad: pad);
  }

  /// The pages a page view builds at rest (no cache extent unless
  /// [cache], one viewport).
  static (int, int) builtRange({
    required double viewportFraction,
    required bool padEnds,
    required int initialPage,
    required int? itemCount,
    required bool cache,
  }) {
    final rest = restOf(
      viewportFraction: viewportFraction,
      padEnds: padEnds,
      initialPage: initialPage,
      itemCount: itemCount,
    );
    final f = viewportFraction;
    final c = cache ? 1.0 : 0.0;
    final start = math.max(0.0, rest.offset - c - rest.pad);
    final end = rest.offset + 1 + c - rest.pad;
    var first = (start / f + precisionErrorTolerance).floor();
    var last = (end / f - precisionErrorTolerance).ceil() - 1;
    first = math.max(0, first);
    if (itemCount != null) last = math.min(last, itemCount - 1);
    if (last < first) return (first, first - 1);
    return (first, last);
  }

  @override
  bool layoutItems() {
    final c = constraints;
    size = c.biggest.isFinite ? c.biggest : c.constrain(Size.zero);
    final v = RenderCollection.main(size, axis);
    final cross = RenderCollection.cross(size, axis);
    final rest = restOf(
      viewportFraction: viewportFraction,
      padEnds: padEnds,
      initialPage: initialPage,
      itemCount: itemCount,
    );
    final page = v * viewportFraction;
    var i = firstIndex;
    for (final it in children) {
      it.layout(BoxConstraints.tight(RenderCollection.sizeOf(page, cross, axis)), parentUsesSize: true);
      final logical = rest.pad * v + i * page - rest.offset * v;
      final mainPos = reverse ? v - logical - page : logical;
      (it.parentData! as CollectionParentData).offset = RenderCollection.offsetOf(mainPos, 0, axis);
      i++;
    }
    return _anyChildOutside;
  }
}
