// A running list that pages, as render objects: its items in a
// [RenderDataItems] inside the SDK's own scroll box, its footer (loading,
// error with retry, end of list) after them. What the list knows and
// decides is its [DataListModel]; this file only draws and reports.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../render/controls/spinner.dart';
import '../render/layout/design_scroll.dart';
import '../render/node_tree.dart';
import 'collections_data_list_model.dart';
import 'collections_layout.dart';
import 'collections_list_runtime.dart';

/// What a sliver list builds past its viewport: items this far out of view
/// count as shown, so the next page loads before the end comes into view.
const double _kAhead = 250;

/// The items of a paging list, every loaded one laid in a line. It owns the
/// list's [DataListModel]: when the model changes (a page came, an item
/// went), [onItems] puts the model's items in as its children, inside
/// layout.
class RenderDataItems extends RenderListItems {
  DataListModel? _model;
  DataListModel get model => _model!;

  /// Puts the model's items in as this box's children (and its footer in
  /// the box around).
  VoidCallback? onItems;

  /// The scroll box around, when the list scrolls.
  RenderDesignScroll? _scroll;

  bool _stale = false;

  /// The list was built: its runtime and data as of now.
  void bind(ListRuntime runtime, List<Object?>? data, RenderDesignScroll? scroll) {
    final model = _model;
    if (model == null) {
      _model = DataListModel(runtime, data)..addListener(_changed);
    } else {
      model.update(runtime, data);
    }
    if (!identical(scroll, _scroll)) {
      _scroll?.removeScrollListener(_scrolled);
      _scroll = scroll;
      if (attached) scroll?.addScrollListener(_scrolled);
    }
    _report();
  }

  String? _reported;
  void _report() {
    final status = _model?.controller?.status;
    if (status == null || status == _reported) return;
    _reported = status;
    model.runtime.reportStatus(status);
  }

  void _changed() {
    _report();
    _stale = true;
    // A change heard while the frame is laying out waits for the next one.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) markNeedsLayout();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    } else if (attached) {
      markNeedsLayout();
    }
  }

  void _scrolled() {
    final scroll = _scroll;
    if (scroll == null || !scroll.hasSize) return;
    model.onScrollExtents(scroll.pixels, math.max(0, scroll.maxScrollExtent - scroll.pixels));
    _near(scroll.pixels, scroll.viewportExtent);
  }

  /// Tells the model the last item within reach of the view, so it loads
  /// the next page as the list nears its end.
  void _near(double pixels, double viewport) {
    final count = childCount;
    if (count == 0) {
      model.onItemBuilt(0, 0);
      return;
    }
    final reach = viewport.isFinite ? pixels + viewport + _kAhead : double.infinity;
    var at = axis == Axis.vertical ? padding.top : padding.left;
    var last = 0, i = 0;
    for (var child = firstChild; child != null; child = childAfter(child), i++) {
      if (at > reach) break;
      last = i;
      at += RenderCollection.main(child.size, axis) + gap;
    }
    model.onItemBuilt(last, count);
  }

  /// The viewport's extent along the list, as the scroll box last gave it.
  double viewport = double.infinity;

  @override
  bool layoutItems() {
    if (_stale) {
      _stale = false;
      final sync = onItems;
      if (sync != null) invokeLayoutCallback<BoxConstraints>((_) => sync());
    }
    final out = super.layoutItems();
    _near(_scroll?.pixels ?? 0, _scroll == null ? double.infinity : viewport);
    model.forgetGone();
    return out;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll?.addScrollListener(_scrolled);
  }

  @override
  void detach() {
    _scroll?.removeScrollListener(_scrolled);
    super.detach();
  }

  @override
  void dispose() {
    _model
      ?..removeListener(_changed)
      ..dispose();
    _model = null;
    super.dispose();
  }
}

/// A list and its footer after it: the footer is the list's last entry,
/// inside the list's padding (the end-of-list line sits above the bottom
/// padding). Its child is the list; [footer], when there, the footer.
class RenderListWithFooter extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  Axis _axis = Axis.vertical;
  set axis(Axis v) {
    if (v == _axis) return;
    _axis = v;
    markNeedsLayout();
  }

  bool _reverse = false;
  set reverse(bool v) {
    if (v == _reverse) return;
    _reverse = v;
    markNeedsLayout();
  }

  EdgeInsets _padding = EdgeInsets.zero;
  set padding(EdgeInsets v) {
    if (v == _padding) return;
    _padding = v;
    markNeedsLayout();
  }

  /// The footer now ([RenderListFooter]), or none.
  RenderBox? get footer => _footer;
  RenderBox? _footer;
  set footer(RenderBox? box) {
    final old = _footer;
    if (identical(old, box)) return;
    if (old != null) {
      dropChild(old);
      old.dispose();
    }
    _footer = box;
    if (box != null) adoptChild(box);
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _footer?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _footer?.detach();
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    if (_footer case final f?) redepthChild(f);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    if (_footer case final f?) visitor(f);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() => [
        if (child case final c?) c.toDiagnosticsNode(name: 'list'),
        if (_footer case final f?) f.toDiagnosticsNode(name: 'footer'),
      ];

  @override
  void dispose() {
    final f = _footer;
    _footer = null;
    if (f != null) {
      dropChild(f);
      f.dispose();
    }
    super.dispose();
  }

  static Offset _at(RenderBox box) => (box.parentData! as BoxParentData).offset;

  @override
  void performLayout() {
    final list = child;
    if (list == null) {
      size = constraints.smallest;
      return;
    }
    final vertical = _axis == Axis.vertical;
    list.layout(constraints, parentUsesSize: true);
    final foot = _footer;
    if (foot == null) {
      (list.parentData! as BoxParentData).offset = Offset.zero;
      size = constraints.constrain(list.size);
      return;
    }
    final cross = vertical ? list.size.width - _padding.horizontal : list.size.height - _padding.vertical;
    foot.layout(
      vertical
          ? BoxConstraints.tightFor(width: math.max(0, cross))
          : BoxConstraints.tightFor(height: math.max(0, cross)),
      parentUsesSize: true,
    );
    final extent = vertical ? foot.size.height : foot.size.width;
    final listMain = vertical ? list.size.height : list.size.width;
    // Reversed, the list's last entry is at the start of its box.
    final atStart = _reverse;
    final footMain = atStart ? (vertical ? _padding.top : _padding.left) : listMain - (vertical ? _padding.bottom : _padding.right);
    final listAt = atStart ? extent : 0.0;
    (list.parentData! as BoxParentData).offset = vertical ? Offset(0, listAt) : Offset(listAt, 0);
    (foot.parentData! as BoxParentData).offset =
        vertical ? Offset(_padding.left, footMain) : Offset(footMain, _padding.top);
    size = constraints.constrain(vertical ? Size(list.size.width, listMain + extent) : Size(listMain + extent, list.size.height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => child?.getMinIntrinsicWidth(height) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) => child?.getMaxIntrinsicWidth(height) ?? 0;
  @override
  double computeMinIntrinsicHeight(double width) => child?.getMinIntrinsicHeight(width) ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) => child?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child case final c?) context.paintChild(c, offset + _at(c));
    if (_footer case final f?) context.paintChild(f, offset + _at(f));
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final at = _at(child as RenderBox);
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final box in [_footer, child]) {
      if (box == null) continue;
      final hit = result.addWithPaintOffset(
        offset: _at(box),
        position: position,
        hitTest: (result, at) => box.hitTest(result, position: at),
      );
      if (hit) return true;
    }
    return false;
  }
}

/// A paging list's footer: the list's own slot node, or the default one
/// (a spinner while a page loads; "Couldn't load more." with "Tap to
/// retry"). With [onTap], a tap anywhere on it calls it (retry).
class RenderListFooter extends RenderProxyBox {
  RenderListFooter(this.kind);

  /// Which footer this is.
  final DataListFooter kind;

  /// The list's slot node shown, when it has one.
  NodeBox? _node;

  /// Shows the list's own node box for this footer.
  void showNode(NodeBox box) {
    if (identical(_node, box)) return;
    final old = _node;
    if (box.parent != null) box.detachFromParent();
    _node = box;
    child = box;
    if (old != null) old.tree.orphan(old);
  }

  /// Shows the default loading footer: a turning arc.
  void showSpinner(Color color) {
    final spinner = _spinner ??= RenderSpinner()
      ..strokeWidth = 2.5
      ..diameter = 24;
    spinner.color = color;
    if (child == null) {
      child = RenderPadding(padding: const EdgeInsets.all(16), child: RenderPositionedBox(heightFactor: 1, child: spinner));
    }
  }

  RenderSpinner? _spinner;

  /// Shows the default error footer, in [style] with its retry line in
  /// [accent].
  void showError(TextStyle style, Color accent) {
    final text = TextSpan(style: style, children: [
      const TextSpan(text: "Couldn't load more.\n"),
      TextSpan(text: 'Tap to retry', style: TextStyle(color: accent, height: 1.6)),
    ]);
    final paragraph = _message;
    if (paragraph != null) {
      paragraph.text = text;
      return;
    }
    final made = _message = RenderParagraph(text, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    child = RenderPadding(padding: const EdgeInsets.all(16), child: RenderPositionedBox(heightFactor: 1, child: made));
  }

  RenderParagraph? _message;

  VoidCallback? _onTap;
  TapGestureRecognizer? _tap;
  set onTap(VoidCallback? v) {
    _onTap = v;
    if (v == null) {
      _tap?.dispose();
      _tap = null;
    } else {
      (_tap ??= TapGestureRecognizer(debugOwner: this)).onTap = () => _onTap?.call();
    }
  }

  @override
  bool hitTestSelf(Offset position) => _onTap != null;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) _tap?.addPointer(event);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final tap = _onTap;
    if (tap == null) return;
    config
      ..isSemanticBoundary = true
      ..onTap = tap;
  }

  @override
  void dispose() {
    _tap?.dispose();
    final node = _node;
    _node = null;
    if (node != null) {
      child = null;
      node.tree.orphan(node);
    }
    super.dispose();
  }
}
