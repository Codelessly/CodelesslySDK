// Nodes that follow the scroll of the view they are in: a sticky node
// (api.Sticky, CSS `position: sticky`) and a node's view progress
// (api.ViewProgress, `${view.progress}`).
//
// Both find the nearest scrolling ancestor: a scrolling row or column
// (RenderDesignScroll) or a Flutter viewport (lists, page views); with
// none, the screen is the view.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show ScrollPosition;

import 'layout/design_scroll.dart';
import 'node_tree.dart' show NodeBox;

/// The view a node scrolls in: its render object, its axis, and how to
/// listen to it.
class ScrollHost {
  ScrollHost._(this.box, this.axis, this._listenable, this._design);

  /// The nearest scrolling ancestor of [from]; null when there is none (the
  /// screen is the view).
  static ScrollHost? of(RenderObject from) {
    for (var p = from.parent; p != null; p = p.parent) {
      if (p is RenderDesignScroll && p.interactive) return ScrollHost._(p, p.axis, null, p);
      if (p is RenderViewportBase && p.offset is ScrollPosition) {
        // A list laid out whole inside a scrolling column (shrink-wrapped,
        // nothing to scroll) isn't the view: look further out.
        final pos = p.offset as ScrollPosition;
        if (pos.hasContentDimensions && pos.maxScrollExtent <= pos.minScrollExtent && p is RenderShrinkWrappingViewport) continue;
        return ScrollHost._(p, p.axis, p.offset, null);
      }
    }
    return null;
  }

  final RenderBox box;
  final Axis axis;
  final Listenable? _listenable;
  final RenderDesignScroll? _design;

  void addListener(VoidCallback l) {
    _design?.addScrollListener(l);
    _listenable?.addListener(l);
  }

  void removeListener(VoidCallback l) {
    _design?.removeScrollListener(l);
    _listenable?.removeListener(l);
  }

  double get extent => box.hasSize ? (axis == Axis.vertical ? box.size.height : box.size.width) : 0;

  /// [target]'s leading edge along the axis, from the view's leading edge.
  double leadOf(RenderBox target) {
    final o = MatrixUtils.transformPoint(target.getTransformTo(box), Offset.zero);
    return axis == Axis.vertical ? o.dy : o.dx;
  }
}

double _extentOf(RenderBox b, Axis axis) => b.hasSize ? (axis == Axis.vertical ? b.size.height : b.size.width) : 0;

/// Recomputes after every frame's layout while attached, and on scroll.
mixin _FollowsScroll on RenderProxyBox {
  ScrollHost? _host;
  bool _scheduled = false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _schedule();
  }

  @override
  void detach() {
    _host?.removeListener(_schedule);
    _host = null;
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _schedule();
  }

  void _schedule() {
    if (_scheduled || !attached) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached || !hasSize) return;
      final host = ScrollHost.of(this);
      if (host?.box != _host?.box) {
        _host?.removeListener(_schedule);
        _host = host;
        _host?.addListener(_schedule);
      }
      update();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Reads the view again.
  void update();
}

/// `${view.progress}` and `${view.visible}`: how far the node has scrolled
/// through its view ([api.ViewProgress]), told to [onValues] (its node
/// scope) and written to the progress's variable.
class RenderViewProgress extends RenderProxyBox with _FollowsScroll {
  api.ViewProgress _model = const api.ViewProgress();
  NodeBox? _node;
  bool _interactive = false;
  void Function(Map<String, Object?> values)? onValues;
  double? _last;
  bool? _lastVisible;

  void configure(NodeBox? node, api.ViewProgress model, {required bool interactive}) {
    final changed = model != _model || interactive != _interactive;
    _node = node;
    _model = model;
    _interactive = interactive;
    if (changed) {
      _last = null;
      _schedule();
    }
  }

  /// The progress now (1 on a design canvas, which doesn't scroll: the
  /// finished state).
  double progress() {
    if (!_interactive) return 1;
    final host = _host;
    if (host == null) {
      // the screen is the view
      final o = localToGlobal(Offset.zero);
      final view = owner?.rootNode is RenderView ? (owner!.rootNode! as RenderView).size : Size.zero;
      return _model.progressAt(o.dy, size.height, view.height);
    }
    return _model.progressAt(host.leadOf(this), _extentOf(this, host.axis), host.extent);
  }

  bool _visibleNow() {
    if (!_interactive) return true;
    final host = _host;
    if (host == null) return true;
    final lead = host.leadOf(this);
    return lead < host.extent && lead + _extentOf(this, host.axis) > 0;
  }

  @override
  void update() {
    final p = (progress() * 1000).roundToDouble() / 1000;
    final visible = _visibleNow();
    if (p == _last && visible == _lastVisible) return;
    _last = p;
    _lastVisible = visible;
    onValues?.call({'progress': p, 'visible': visible});
    final name = _model.variable.trim();
    final scope = _node?.tree.bindings?.valuesFor(_node!.tree.source, _node!.id, _node!.instance);
    if (_interactive && name.isNotEmpty && scope != null) {
      final key = _model.key.trim();
      scope.write(key.isEmpty ? name : '$name.$key', p);
    }
  }
}

/// A node pinned in its scrolling view ([api.Sticky]): once its leading
/// edge reaches the offset from the view's leading edge it stays there
/// until its parent's trailing edge pushes it on. While pinned the view
/// paints and hit tests it after (above) its content
/// ([RenderDesignScroll.paintPinned]); here it paints nothing.
class RenderSticky extends RenderProxyBox with _FollowsScroll {
  api.Sticky _model = const api.Sticky();
  bool _interactive = false;

  /// How far it's moved along the view's axis to stay pinned (0: in place).
  double shift = 0;
  void Function(bool stuck)? onStuck;
  bool? _lastStuck;

  void configure(api.Sticky model, {required bool interactive}) {
    _model = model;
    if (interactive != _interactive) {
      _interactive = interactive;
      if (!interactive) shift = 0;
    }
    _schedule();
  }

  RenderDesignScroll? get _design => _host?.box is RenderDesignScroll ? _host!.box as RenderDesignScroll : null;

  /// The box it's pinned within: its node's parent node's box.
  RenderBox? _container() {
    var seenOwn = false;
    for (var p = parent; p != null; p = p.parent) {
      if (p is NodeBox) {
        if (seenOwn) return p;
        seenOwn = true;
      }
    }
    return null;
  }

  RenderDesignScroll? _registered;

  @override
  void detach() {
    _registered?.unregisterPinned(this);
    _registered = null;
    super.detach();
  }

  @override
  void update() {
    final host = _host;
    double next = 0;
    if (_interactive && host != null) {
      final lead = host.leadOf(this);
      final extent = _extentOf(this, host.axis);
      next = math.max(0, _model.offset - lead);
      final container = _container();
      if (container != null && next > 0) {
        final end = host.leadOf(container) + _extentOf(container, host.axis);
        next = math.min(next, math.max(0, end - (lead + extent)));
      }
    }
    final design = _design;
    if (design != _registered) {
      _registered?.unregisterPinned(this);
      _registered = design;
      _registered?.registerPinned(this);
    }
    if (next != shift) {
      shift = next;
      markNeedsPaint();
      _registered?.markNeedsPaint();
    }
    final stuck = shift > 0;
    if (stuck != _lastStuck) {
      _lastStuck = stuck;
      onStuck?.call(stuck);
    }
  }

  Axis get _axis => _host?.axis ?? Axis.vertical;
  Offset get _delta => _axis == Axis.vertical ? Offset(0, shift) : Offset(shift, 0);

  /// Whether the view paints it ([shift] > 0 inside a scrolling row or
  /// column); a Flutter viewport can't, so there it moves in place.
  bool get paintedByView => shift > 0 && _registered != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (paintedByView) return;
    if (shift > 0 && child != null) {
      context.paintChild(child!, offset + _delta);
      return;
    }
    super.paint(context, offset);
  }

  /// Paints it pinned, at [offset] in the view's coordinates.
  void paintPinned(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null || !paintedByView) return;
    context.paintChild(c, offset + _delta);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_delta.dx, _delta.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (paintedByView) return false; // the view tests it first
    final c = child;
    if (c == null) return false;
    return result.addWithPaintOffset(offset: _delta, position: position, hitTest: (r, p) => c.hitTest(r, position: p));
  }

  /// Hit tests it pinned: [position] in the view's coordinates.
  bool hitTestPinned(BoxHitTestResult result, Offset position, RenderBox view) {
    final c = child;
    if (c == null || !paintedByView) return false;
    final m = c.getTransformTo(view);
    return result.addWithPaintTransform(transform: m, position: position, hitTest: (r, p) => c.hitTest(r, position: p));
  }
}

/// Writes where its node is laid out ([api.Measure]) to a variable after
/// each layout: `{x, y, width, height, centerX, centerY}` in the box of the
/// ancestor node `relativeTo` (else the screen), rounded to 0.5 px.
class RenderMeasure extends RenderProxyBox {
  api.Measure _model = const api.Measure();
  NodeBox? _node;
  bool _scheduled = false;
  Map<String, double>? _last;

  void configure(NodeBox? node, api.Measure model) {
    if (model != _model) _last = null;
    _node = node;
    _model = model;
    _schedule();
  }

  @override
  void performLayout() {
    super.performLayout();
    _schedule();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _last = null;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || !attached) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (attached && hasSize) _write();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// The ancestor node box named [api.Measure.relativeTo], else null (the
  /// screen).
  RenderBox? _ancestor() {
    final id = _model.relativeTo.trim();
    if (id.isEmpty) return null;
    for (var p = parent; p != null; p = p.parent) {
      if (p is NodeBox && p.id == id) return p.contentBox ?? p;
    }
    return null;
  }

  void _write() {
    final node = _node;
    final name = _model.variable.trim();
    if (node == null || name.isEmpty) return;
    final rect = MatrixUtils.transformRect(getTransformTo(_ancestor()), Offset.zero & size);
    double r(double v) => (v * 2).roundToDouble() / 2;
    final value = <String, double>{
      'x': r(rect.left),
      'y': r(rect.top),
      'width': r(rect.width),
      'height': r(rect.height),
      'centerX': r(rect.center.dx),
      'centerY': r(rect.center.dy),
    };
    if (mapEquals(value, _last)) return;
    _last = value;
    final scope = node.tree.bindings?.valuesFor(node.tree.source, node.id, node.instance);
    if (scope == null) return;
    final key = _model.key.trim();
    scope.write(key.isEmpty ? name : '$name.$key', value);
  }
}
