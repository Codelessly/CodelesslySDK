import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import 'node_motion.dart';
import 'route_transition.dart';

/// Live values of the 3D behaviours around a node, read by bindings as
/// `${flip.flipped}`, `${flip.progress}`, `${tilt.x}`, `${tilt.y}` and
/// `${pageOffset}`. A scope adds its values to the ones above it.
class MotionValuesScope extends InheritedWidget {
  /// The values by variable name (`flip`, `tilt`, `pageOffset`).
  final Map<String, Object?> values;

  /// Creates a [MotionValuesScope].
  const MotionValuesScope({
    super.key,
    required this.values,
    required super.child,
  });

  /// The variable names a scope can hold, with the values they read
  /// outside one.
  static const Map<String, Object?> defaults = {
    'flip': {'flipped': false, 'progress': 0.0},
    'tilt': {'x': 0.0, 'y': 0.0, 'active': false},
    'pageOffset': 0.0,
  };

  /// [child] with [values] added to the scope above [context].
  static Widget add(
    BuildContext context, {
    required Map<String, Object?> values,
    required Widget child,
  }) {
    final Map<String, Object?> above =
        context.getInheritedWidgetOfExactType<MotionValuesScope>()?.values ??
        const {};
    return MotionValuesScope(values: {...above, ...values}, child: child);
  }

  /// The values above [context], registering a dependency on them.
  static Map<String, Object?> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionValuesScope>()?.values ??
      const {};

  @override
  bool updateShouldNotify(MotionValuesScope oldWidget) =>
      !_mapEquals(values, oldWidget.values);

  static bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final MapEntry<String, Object?> e in a.entries) {
      final Object? other = b[e.key];
      if (e.value is Map && other is Map) {
        final Map x = e.value as Map;
        if (x.length != other.length) return false;
        for (final key in x.keys) {
          if (x[key] != other[key]) return false;
        }
      } else if (e.value != other) {
        return false;
      }
    }
    return true;
  }
}

/// Tells the two faces of a flip card that they are faces: the front one
/// hides when turned away, the back one is turned over in advance.
class FlipFaceScope extends InheritedWidget {
  /// The flip card's node id.
  final String nodeId;

  /// Its first child (the front) and second child (the back).
  final List<String> faces;

  /// The card's axis.
  final FlipAxis axis;

  /// Creates a [FlipFaceScope].
  const FlipFaceScope({
    super.key,
    required this.nodeId,
    required this.faces,
    required this.axis,
    required super.child,
  });

  /// The nearest scope above [context].
  static FlipFaceScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FlipFaceScope>();

  /// [face] drawn as a face of the card above [context] when [node] is one
  /// of its two faces, else as is.
  static Widget wrapFace(BuildContext context, BaseNode node, Widget face) {
    final FlipFaceScope? scope = maybeOf(context);
    if (scope == null || node.parentID != scope.nodeId) return face;
    final int index = scope.faces.indexOf(node.id);
    if (index < 0 || index > 1) return face;
    final Widget hidden = BackfaceHidden(child: face);
    if (index == 0) return hidden;
    return Transform(
      alignment: Alignment.center,
      transform: scope.axis == FlipAxis.y
          ? (Matrix4.identity()..rotateY(math.pi))
          : (Matrix4.identity()..rotateX(math.pi)),
      child: hidden,
    );
  }

  @override
  bool updateShouldNotify(FlipFaceScope oldWidget) =>
      nodeId != oldWidget.nodeId ||
      axis != oldWidget.axis ||
      faces.join(',') != oldWidget.faces.join(',');
}

/// A two-sided card ([FlipModel]): turns its frame 0° or 180° with the
/// node's own [MotionModel] perspective, duration, curve and keyframes. A
/// tap or a drag can turn it, and it can follow a boolean variable.
class NodeFlip extends StatefulWidget {
  /// The node's id.
  final String nodeId;

  /// The node's children: front, back.
  final List<String> faces;

  /// The flip settings.
  final FlipModel flip;

  /// The node's motion, for perspective, timing and keyframes.
  final MotionModel? motion;

  /// Whether the back should show, resolved from the binding or the model.
  final bool flipped;

  /// The variable the card follows and writes, if any.
  final ValueNotifier<VariableData>? variable;

  /// Whether the card animates (false on the design canvas).
  final bool animate;

  /// The card.
  final Widget child;

  /// Creates a [NodeFlip].
  const NodeFlip({
    super.key,
    required this.nodeId,
    required this.faces,
    required this.flip,
    this.motion,
    required this.flipped,
    this.variable,
    this.animate = true,
    required this.child,
  });

  /// The milliseconds a flip takes: the motion's duration, else 600.
  static int durationOf(MotionModel? motion) =>
      (motion?.durationMs ?? 0) > 0 ? motion!.durationMs : 600;

  @override
  State<NodeFlip> createState() => NodeFlipState();
}

/// The state of a [NodeFlip].
class NodeFlipState extends State<NodeFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    value: _wanted ? 1 : 0,
  );

  /// Whether the card is (or is turning to be) on its back.
  bool get flipped => _target;
  late bool _target = _wanted;
  bool _dragging = false;
  double _dragStart = 0;

  /// The progress of the turn: 0 front, 1 back.
  double get progress => _progress.value;

  bool get _wanted => _variableValue ?? widget.flipped;

  bool? get _variableValue {
    final VariableData? data = widget.variable?.value;
    if (data == null) return null;
    final Object? v = data.value;
    if (v is bool) return v;
    return '$v'.trim().toLowerCase() == 'true';
  }

  @override
  void initState() {
    super.initState();
    widget.variable?.addListener(_onVariable);
  }

  @override
  void didUpdateWidget(NodeFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variable != widget.variable) {
      oldWidget.variable?.removeListener(_onVariable);
      widget.variable?.addListener(_onVariable);
    }
    if (_wanted != _target && !_dragging) _turnTo(_wanted);
  }

  void _onVariable() {
    if (_dragging) return;
    final bool wanted = _wanted;
    if (wanted != _target) _turnTo(wanted);
  }

  void _turnTo(bool back) {
    _target = back;
    if (!widget.animate) {
      _progress.value = back ? 1 : 0;
      return;
    }
    final MotionModel? motion = widget.motion;
    final Curve curve = flutterCurveOf(
      motion?.curve ?? MotionCurve.easeInOutCubic,
    );
    _progress.animateTo(
      back ? 1 : 0,
      duration: Duration(milliseconds: NodeFlip.durationOf(motion)),
      curve: curve,
    );
  }

  /// Turns the card over, as a tap does: writes the variable when the card
  /// has one (which turns it), otherwise turns it.
  void toggle() => _set(!_target);

  void _set(bool back) {
    final ValueNotifier<VariableData>? variable = widget.variable;
    if (variable != null && !variable.value.isComputed) {
      variable.value = variable.value.copyWith(value: back);
      // The listener turns it; a variable already holding the value
      // doesn't notify.
      if (_target != back) _turnTo(back);
      return;
    }
    _turnTo(back);
  }

  double get _extent {
    final RenderObject? box = context.findRenderObject();
    final Size size = box is RenderBox && box.hasSize
        ? box.size
        : const Size(300, 300);
    return math.max(1, widget.flip.axis == FlipAxis.y ? size.width : size.height);
  }

  void _dragStarted(DragStartDetails details) {
    _progress.stop();
    _dragging = true;
    _dragStart = _progress.value;
  }

  void _dragUpdated(DragUpdateDetails details) {
    // Dragging toward the start of the axis (left, or up) turns it over.
    final double delta = widget.flip.axis == FlipAxis.y
        ? details.delta.dx
        : details.delta.dy;
    _progress.value = (_progress.value - delta / _extent).clamp(0.0, 1.0);
  }

  void _dragEnded(DragEndDetails details) {
    _dragging = false;
    final double pixels = widget.flip.axis == FlipAxis.y
        ? details.velocity.pixelsPerSecond.dx
        : details.velocity.pixelsPerSecond.dy;
    final double velocity = -pixels / _extent;
    final double moved = (_progress.value - _dragStart).abs();
    // Toward the other face: past halfway, or flung its way.
    final bool fromFront = _dragStart < 0.5;
    final bool commits = TransitionPhysics.commits(
      progress: moved,
      velocity: fromFront ? -pixels : pixels,
      distance: 0.5,
      flingVelocity: 500,
    );
    final bool back = commits ? fromFront : !fromFront;
    _progress.animateWith(
      TransitionPhysics.settle(
        widget.flip.spring,
        from: _progress.value,
        to: back ? 1 : 0,
        velocity: velocity,
      ),
    );
    if (back != _target) {
      _target = back;
      final ValueNotifier<VariableData>? variable = widget.variable;
      if (variable != null && !variable.value.isComputed) {
        widget.variable!.removeListener(_onVariable);
        variable.value = variable.value.copyWith(value: back);
        widget.variable!.addListener(_onVariable);
      }
    }
  }

  @override
  void dispose() {
    widget.variable?.removeListener(_onVariable);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FlipModel flip = widget.flip;
    Widget card = AnimatedBuilder(
      animation: _progress,
      child: FlipFaceScope(
        nodeId: widget.nodeId,
        faces: widget.faces,
        axis: flip.axis,
        child: widget.child,
      ),
      builder: (context, child) {
        final double t = _progress.value;
        final MotionModel? motion = widget.motion;
        final double scale =
            MotionModel.keyframedValue(
              motion?.keyframes ?? const [],
              'scale',
              1,
              1,
              t.clamp(0.0, 1.0),
            ) ??
            1;
        final MotionModel turn = MotionModel(
          rotateY: flip.axis == FlipAxis.y ? t * 180 : 0,
          rotateX: flip.axis == FlipAxis.x ? -t * 180 : 0,
          perspective: motion?.perspective ?? 1,
          scale: scale,
        );
        return MotionValuesScope.add(
          context,
          values: {
            'flip': {'flipped': _target, 'progress': t},
          },
          child: Transform(
            alignment: Alignment.center,
            transform: motionMatrix(turn),
            child: child,
          ),
        );
      },
    );
    if (flip.dragToFlip && widget.animate) {
      card = GestureDetector(
        onHorizontalDragStart: flip.axis == FlipAxis.y ? _dragStarted : null,
        onHorizontalDragUpdate: flip.axis == FlipAxis.y ? _dragUpdated : null,
        onHorizontalDragEnd: flip.axis == FlipAxis.y ? _dragEnded : null,
        onVerticalDragStart: flip.axis == FlipAxis.x ? _dragStarted : null,
        onVerticalDragUpdate: flip.axis == FlipAxis.x ? _dragUpdated : null,
        onVerticalDragEnd: flip.axis == FlipAxis.x ? _dragEnded : null,
        child: card,
      );
    }
    if (flip.tapToFlip && widget.animate) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: card,
      );
    }
    return card;
  }
}

/// Tilts its child toward the pointer ([TiltModel]): the edge under the
/// pointer tips away by [MotionModel.rotateX] / [MotionModel.rotateY] of
/// [TiltModel.max], and it grows to its scale while hovered. Children read
/// `${tilt.x}` and `${tilt.y}` (-1 to 1) for parallax.
class NodeTilt extends StatefulWidget {
  /// The tilt settings.
  final TiltModel tilt;

  /// Whether it reacts at all (false on the design canvas).
  final bool enabled;

  /// The node.
  final Widget child;

  /// Creates a [NodeTilt].
  const NodeTilt({
    super.key,
    required this.tilt,
    this.enabled = true,
    required this.child,
  });

  @override
  State<NodeTilt> createState() => NodeTiltState();
}

/// The state of a [NodeTilt].
class NodeTiltState extends State<NodeTilt> with TickerProviderStateMixin {
  Offset _pointer = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  double _activeFrom = 0;
  double _activeTo = 0;
  late final AnimationController _anim = AnimationController(vsync: this)
    ..addListener(() => setState(() {}));
  Curve _curve = Curves.easeOut;

  /// The pointer's place over the node now, -1 to 1 on each axis (0 at
  /// rest), eased.
  Offset get position =>
      Offset.lerp(_from, _to, _curve.transform(_anim.value))!;

  double get _active =>
      _activeFrom +
      (_activeTo - _activeFrom) * _curve.transform(_anim.value);

  void _moveTo(Offset target, double active, {required bool reset}) {
    _from = position;
    _activeFrom = _active;
    _to = target;
    _activeTo = active;
    _curve = reset ? flutterCurveOf(widget.tilt.curve) : Curves.easeOut;
    _anim.duration = Duration(
      milliseconds: reset ? math.max(1, widget.tilt.resetMs) : 90,
    );
    _anim.forward(from: 0);
  }

  void _track(Offset local) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final Size size = box.size;
    _pointer = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
    _moveTo(_pointer, 1, reset: false);
  }

  void _release() => _moveTo(Offset.zero, 0, reset: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MotionModel max = widget.tilt.max;
    final Offset p = position;
    final double active = _active;
    final MotionModel pose = MotionModel(
      rotateX: p.dy * max.rotateX,
      rotateY: -p.dx * max.rotateY,
      perspective: max.perspective,
      scale: 1 + (max.scale - 1) * active,
      translateX: max.translateX * active,
      translateY: max.translateY * active,
      originX: max.originX,
      originY: max.originY,
    );
    Widget child = MotionValuesScope.add(
      context,
      values: {
        'tilt': {'x': p.dx, 'y': p.dy, 'active': active > 0.5},
      },
      child: Transform(
        alignment: Alignment(max.originX, max.originY),
        transform: motionMatrix(pose),
        child: widget.child,
      ),
    );
    if (!widget.enabled) return child;
    if (widget.tilt.drag) {
      child = Listener(
        onPointerDown: (e) => _track(e.localPosition),
        onPointerMove: (e) => _track(e.localPosition),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: child,
      );
    }
    if (widget.tilt.hover) {
      child = MouseRegion(
        onHover: (e) => _track(e.localPosition),
        onExit: (_) => _release(),
        child: child,
      );
    }
    return child;
  }
}

/// [motion] (the values one page to the right) for a page [offset] pages
/// from the current one: rest at 0, interpolated by the distance (up to
/// two pages) and mirrored for pages on the left.
MotionModel pageMotionAt(MotionModel motion, double offset) {
  final double distance = offset.abs().clamp(0.0, 2.0);
  final MotionModel scaled = motionTowards(motion, distance);
  if (offset >= 0) return scaled;
  return scaled.copyWith(
    translateX: -scaled.translateX,
    shiftX: -scaled.shiftX,
    rotate: -scaled.rotate,
    rotateY: -scaled.rotateY,
    originX: -scaled.originX,
  );
}

/// Draws a page of a page view with [PageViewProperties.pageMotion] at its
/// offset from [controller]'s current page, and gives it `${pageOffset}`.
class PageMotionItem extends StatelessWidget {
  /// The page view's controller.
  final PageController controller;

  /// This page's index.
  final int index;

  /// The values one page to the right; null only exposes the offset.
  final MotionModel? motion;

  /// Whether pages scroll vertically (mirrors on Y instead of X).
  final bool vertical;

  /// The page.
  final Widget child;

  /// Creates a [PageMotionItem].
  const PageMotionItem({
    super.key,
    required this.controller,
    required this.index,
    required this.motion,
    this.vertical = false,
    required this.child,
  });

  double _offset() {
    if (!controller.hasClients ||
        controller.positions.length != 1 ||
        !controller.position.haveDimensions) {
      return index - controller.initialPage.toDouble();
    }
    return index - (controller.page ?? controller.initialPage.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final double offset = _offset();
        Widget out = child!;
        final MotionModel? m = motion;
        if (m != null) {
          MotionModel pose = pageMotionAt(m, offset);
          if (vertical) {
            // A vertical pager turns around X and moves along Y.
            pose = pose.copyWith(
              rotateX: -pose.rotateY,
              rotateY: 0,
              translateY: pose.translateX,
              translateX: 0,
              shiftY: pose.shiftX,
              shiftX: 0,
              originY: pose.originX,
              originX: 0,
            );
          }
          out = Opacity(
            opacity: pose.opacity.clamp(0.0, 1.0),
            child: FractionalTranslation(
              translation: Offset(pose.shiftX, pose.shiftY),
              child: Transform(
                alignment: Alignment(pose.originX, pose.originY),
                transform: motionMatrix(pose),
                child: out,
              ),
            ),
          );
        }
        return MotionValuesScope.add(
          context,
          values: {'pageOffset': offset},
          child: out,
        );
      },
    );
  }
}
