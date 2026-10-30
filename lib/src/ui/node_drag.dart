import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import 'node_motion.dart';

/// The live state of a drag, as the `drag` variable shows it.
@immutable
class DragValues {
  /// How far the node has moved from rest, in logical pixels.
  final Offset offset;

  /// Progress toward dismissing each way, 0 to 1 (1 is at the threshold).
  final double left, right, up, down;

  /// Whether a pointer is dragging the node now.
  final bool dragging;

  /// Whether the node has flown off.
  final bool dismissed;

  /// Creates [DragValues].
  const DragValues({
    this.offset = Offset.zero,
    this.left = 0,
    this.right = 0,
    this.up = 0,
    this.down = 0,
    this.dragging = false,
    this.dismissed = false,
  });

  /// At rest.
  static const DragValues rest = DragValues();

  /// The largest progress in any direction.
  double get progress => math.max(math.max(left, right), math.max(up, down));

  /// The direction with the most progress, or '' at rest.
  String get direction {
    final double p = progress;
    if (p <= 0) return '';
    if (p == left) return 'left';
    if (p == right) return 'right';
    if (p == up) return 'up';
    return 'down';
  }

  /// The values as the `drag` variable reads them.
  Map<String, dynamic> toMap() => {
    'dx': offset.dx,
    'dy': offset.dy,
    'left': left,
    'right': right,
    'up': up,
    'down': down,
    'progress': progress,
    'direction': direction,
    'dragging': dragging,
    'dismissed': dismissed,
  };

  @override
  bool operator ==(Object other) =>
      other is DragValues &&
      other.offset == offset &&
      other.left == left &&
      other.right == right &&
      other.up == up &&
      other.down == down &&
      other.dragging == dragging &&
      other.dismissed == dismissed;

  @override
  int get hashCode =>
      Object.hash(offset, left, right, up, down, dragging, dismissed);
}

/// Shares the drag of the nearest [NodeDrag] with the nodes inside it, which
/// read it as the `drag` variable.
class DragScope extends InheritedWidget {
  /// The drag's live values.
  final DragValues values;

  /// Creates a [DragScope].
  const DragScope({super.key, required this.values, required super.child});

  /// The values of the nearest drag above [context], or null outside one.
  static DragValues? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DragScope>()?.values;

  @override
  bool updateShouldNotify(DragScope oldWidget) => values != oldWidget.values;
}

/// Makes [child] draggable as [drag] describes: it follows the pointer as a
/// transform over its layout, tilts by [DragModel.rotateFactor], and on
/// release springs back, stays, or flies off and calls [onDismissed].
///
/// [isEnabled] is asked when a drag starts (the `drag.enabled` binding can
/// change any time). [onEnd] gets the drag's result when the pointer lifts.
/// Every instance registers under [nodeId], so [NodeDrag.control] can fling,
/// return or reset it from an action.
class NodeDrag extends StatefulWidget {
  /// Creates a [NodeDrag].
  const NodeDrag({
    super.key,
    required this.nodeId,
    required this.drag,
    required this.child,
    this.isEnabled,
    this.order = 0,
    this.onDismissed,
    this.onEnd,
    this.onValues,
  });

  /// The node this drag belongs to.
  final String nodeId;

  /// How the node drags.
  final DragModel drag;

  /// Whether the drag works now; [DragModel.enabled] when null.
  final bool Function()? isEnabled;

  /// Where this instance stands among the node's instances: lower goes
  /// first when an action picks one (the list index of a card).
  final int order;

  /// Called when the node has flown off toward a direction. The node stays
  /// off until its future completes and the next frame is built, then comes
  /// back to rest (unless it was removed meanwhile, as a dismissed card is).
  final FutureOr<void> Function(DragDirection direction)? onDismissed;

  /// Called when the pointer lifts after a drag, with `dx`, `dy`,
  /// `velocityX`, `velocityY`, `dismissed` and `direction`.
  final void Function(Map<String, dynamic> result)? onEnd;

  /// Called with the live values whenever they change (see
  /// [DragModel.shareAs]).
  final ValueChanged<DragValues>? onValues;

  /// The node.
  final Widget child;

  static final Map<String, List<NodeDragState>> _instances = {};
  static final Map<String, DragDirection> _pendingReturns = {};

  /// Runs [command] on the enabled instance of [nodeId] that comes first.
  /// For [DragCommand.returnFrom] an instance built in the next frame (the
  /// card an undo puts back) starts off-screen instead of flashing at rest.
  static Future<void> control(
    String nodeId,
    DragCommand command,
    DragDirection direction,
  ) async {
    if (command == DragCommand.returnFrom) {
      _pendingReturns[nodeId] = direction;
      await WidgetsBinding.instance.endOfFrame;
      // Consumed by an instance built in that frame.
      if (_pendingReturns.remove(nodeId) == null) return;
    }
    final NodeDragState? target = instanceOf(nodeId);
    if (target == null) return;
    switch (command) {
      case DragCommand.fling:
        await target.fling(direction);
      case DragCommand.returnFrom:
        await target.returnFrom(direction);
      case DragCommand.reset:
        await target.reset();
    }
  }

  /// The instance of [nodeId] an action moves: the first enabled one by
  /// [order], or the first one when none is enabled.
  static NodeDragState? instanceOf(String nodeId) {
    final List<NodeDragState> all = [
      for (final state in _instances[nodeId] ?? const <NodeDragState>[])
        if (state.mounted && !state._dismissed) state,
    ]..sort((a, b) => a.widget.order.compareTo(b.widget.order));
    if (all.isEmpty) return null;
    return all.firstWhere((s) => s._enabled, orElse: () => all.first);
  }

  @override
  State<NodeDrag> createState() => NodeDragState();
}

/// The state of a [NodeDrag]; see [NodeDrag.control].
class NodeDragState extends State<NodeDrag> with TickerProviderStateMixin {
  Offset _offset = Offset.zero;
  bool _dragging = false;
  bool _dismissed = false;
  bool _active = false;
  late final AnimationController _anim = AnimationController(vsync: this)
    ..addListener(_onTick);
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Curve _curve = Curves.linear;
  double _shake = 0;

  DragModel get _model => widget.drag;

  bool get _enabled => widget.isEnabled?.call() ?? _model.enabled;

  Size get _size {
    final RenderObject? box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size;
    return const Size(300, 400);
  }

  @override
  void initState() {
    super.initState();
    (NodeDrag._instances[widget.nodeId] ??= []).add(this);
    final DragDirection? back = NodeDrag._pendingReturns.remove(widget.nodeId);
    if (back != null) {
      _offset = _offscreen(back, const Size(300, 400));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) returnFrom(back);
      });
    }
  }

  @override
  void didUpdateWidget(NodeDrag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId) {
      NodeDrag._instances[oldWidget.nodeId]?.remove(this);
      (NodeDrag._instances[widget.nodeId] ??= []).add(this);
    }
  }

  @override
  void dispose() {
    NodeDrag._instances[widget.nodeId]?.remove(this);
    _anim.dispose();
    super.dispose();
  }

  void _onTick() {
    final double t = _curve.transform(_anim.value);
    setState(() {
      if (_shake > 0) {
        // A damped sideways wiggle.
        _offset = Offset(
          math.sin(_anim.value * math.pi * 6) * _shake * (1 - _anim.value),
          0,
        );
      } else {
        _offset = Offset.lerp(_from, _to, t)!;
        if (_spinTo != 0) {
          _spin = _spinTo * t;
        } else if (_spinFrom != 0) {
          _spin = _spinFrom * (1 - t);
        }
      }
    });
  }

  double _spinFrom = 0;

  Future<void> _animateTo(Offset to, int ms, Curve curve) async {
    _shake = 0;
    if (_spinTo == 0 && _spin != 0) {
      // Unwind any turn left over (a returning card).
      _spinFrom = _spin;
    } else {
      _spinFrom = 0;
    }
    _from = _offset;
    _to = to;
    _curve = curve;
    _anim.duration = Duration(milliseconds: math.max(1, ms));
    _active = true;
    try {
      await _anim.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Interrupted by a new drag or command.
    } finally {
      _active = false;
    }
  }

  // ---- Values -------------------------------------------------------------

  double _thresholdFor(DragDirection direction, Size size) {
    final double extent =
        direction == DragDirection.left || direction == DragDirection.right
        ? size.width
        : size.height;
    return math.max(1, extent * _model.distanceThreshold);
  }

  DragValues get values {
    final Size size = _size;
    double p(double distance, DragDirection d) =>
        (distance / _thresholdFor(d, size)).clamp(0, 1).toDouble();
    return DragValues(
      offset: _offset,
      left: p(-_offset.dx, DragDirection.left),
      right: p(_offset.dx, DragDirection.right),
      up: p(-_offset.dy, DragDirection.up),
      down: p(_offset.dy, DragDirection.down),
      dragging: _dragging,
      dismissed: _dismissed,
    );
  }

  /// Whether the pointer may pull toward [direction] freely.
  bool _free(DragDirection direction) {
    final bool onAxis = switch (_model.axis) {
      DragAxis.free => true,
      DragAxis.horizontal =>
        direction == DragDirection.left || direction == DragDirection.right,
      DragAxis.vertical =>
        direction == DragDirection.up || direction == DragDirection.down,
    };
    if (!onAxis) return false;
    if (_model.release != DragRelease.dismiss) return true;
    return _model.directions.contains(direction);
  }

  /// [raw] pointer travel turned into node travel: locked off its axis,
  /// held back by resistance toward directions that can't dismiss.
  Offset _resist(Offset raw) {
    double along(double v, DragDirection neg, DragDirection pos) {
      final DragDirection d = v < 0 ? neg : pos;
      if (_free(d)) return v;
      final bool onAxis = switch (_model.axis) {
        DragAxis.free => true,
        DragAxis.horizontal =>
          d == DragDirection.left || d == DragDirection.right,
        DragAxis.vertical => d == DragDirection.up || d == DragDirection.down,
      };
      if (!onAxis) return 0;
      final double r = _model.resistance.clamp(0, 1).toDouble();
      if (r >= 1) return 0;
      // Rubber band: moves less and less the further it is pulled.
      const double reach = 120;
      final double k = 1 - r;
      return v.sign * reach * k * (1 - math.exp(-v.abs() / reach));
    }

    return Offset(
      along(raw.dx, DragDirection.left, DragDirection.right),
      along(raw.dy, DragDirection.up, DragDirection.down),
    );
  }

  // ---- Gestures -----------------------------------------------------------

  Offset _raw = Offset.zero;

  /// Whether the current drag is of a disabled node, which only follows by
  /// [DragModel.disabledFollow] and always springs back.
  bool _blocked = false;

  void _onStart(DragStartDetails details) {
    if (_dismissed) return;
    _blocked = !_enabled;
    if (_blocked && _model.disabledFollow <= 0) {
      if (_model.shakeWhenDisabled && !_anim.isAnimating) _shakeOnce();
      widget.onEnd?.call({'blocked': true, 'dismissed': false, 'direction': ''});
      return;
    }
    _anim.stop();
    _shake = 0;
    _raw = _offset;
    setState(() => _dragging = true);
  }

  void _onUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _raw += details.delta;
    setState(
      () => _offset = _blocked
          ? _raw * _model.disabledFollow.clamp(0, 1).toDouble()
          : _resist(_raw),
    );
  }

  void _onEnd(DragEndDetails details) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    final Offset velocity = details.velocity.pixelsPerSecond;
    if (_blocked) {
      widget.onEnd?.call({
        'dx': _offset.dx,
        'dy': _offset.dy,
        'velocityX': velocity.dx,
        'velocityY': velocity.dy,
        'dismissed': false,
        'direction': '',
        'blocked': true,
      });
      _animateTo(
        Offset.zero,
        _model.snapBackMs,
        flutterCurveOf(_model.snapCurve),
      ).then((_) {
        if (mounted && _model.shakeWhenDisabled) _shakeOnce();
      });
      return;
    }
    final DragDirection? direction = _dismissDirection(velocity);
    widget.onEnd?.call({
      'dx': _offset.dx,
      'dy': _offset.dy,
      'velocityX': velocity.dx,
      'velocityY': velocity.dy,
      'dismissed': direction != null,
      'direction': direction?.name ?? '',
      'blocked': false,
    });
    if (direction != null) {
      _flyOff(direction, velocity);
    } else if (_model.release != DragRelease.stay) {
      _animateTo(
        Offset.zero,
        _model.snapBackMs,
        flutterCurveOf(_model.snapCurve),
      );
    }
  }

  static DragDirection _directionOf(Offset v) => v.dx.abs() >= v.dy.abs()
      ? (v.dx < 0 ? DragDirection.left : DragDirection.right)
      : (v.dy < 0 ? DragDirection.up : DragDirection.down);

  /// The direction a release at [velocity] dismisses toward, if any.
  DragDirection? _dismissDirection(Offset velocity) {
    if (_model.release != DragRelease.dismiss) return null;
    final Size size = _size;
    if (_offset != Offset.zero) {
      final DragDirection d = _directionOf(_offset);
      final double travel = switch (d) {
        DragDirection.left => -_offset.dx,
        DragDirection.right => _offset.dx,
        DragDirection.up => -_offset.dy,
        DragDirection.down => _offset.dy,
      };
      if (_model.canDismiss(d) && travel >= _thresholdFor(d, size)) return d;
    }
    if (velocity.distance >= _model.velocityThreshold) {
      final DragDirection d = _directionOf(velocity);
      final (double ux, double uy) = d.unit;
      final double along = velocity.dx * ux + velocity.dy * uy;
      if (_model.canDismiss(d) && along >= _model.velocityThreshold) return d;
    }
    return null;
  }

  static Size get _screenSize {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return const Size(1200, 900);
    return view.physicalSize / view.devicePixelRatio;
  }

  Offset _offscreen(DragDirection direction, Size size, [Offset? along]) {
    final Size screen = _screenSize;
    final double far =
        math.max(screen.width, screen.height) + size.longestSide * 1.2;
    final (double ux, double uy) = direction.unit;
    // Keep going the way it was thrown, mostly along the direction.
    Offset heading = Offset(ux, uy);
    if (along != null && along.distance > 0) {
      final Offset a = along / along.distance;
      heading = Offset(ux + a.dx * 0.5, uy + a.dy * 0.5);
      heading = heading / heading.distance;
    }
    return _offset + heading * far;
  }

  /// Extra turn while flying off, in degrees, eased in with the flight.
  double _spin = 0;
  double _spinTo = 0;

  Future<void> _flyOff(DragDirection direction, [Offset? velocity]) async {
    _spinTo = switch (direction) {
      DragDirection.left || DragDirection.up => -_model.flyOutRotate,
      DragDirection.right || DragDirection.down => _model.flyOutRotate,
    };
    final Offset target = _offscreen(
      direction,
      _size,
      velocity == null || velocity == Offset.zero ? _offset : velocity,
    );
    await _animateTo(target, _model.flyOutMs, Curves.easeIn);
    if (!mounted) return;
    setState(() => _dismissed = true);
    await widget.onDismissed?.call(direction);
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_dismissed) return;
    // Still here: the node shows its next content, back at rest.
    setState(() {
      _dismissed = false;
      _offset = Offset.zero;
      _spin = _spinTo = 0;
    });
  }

  void _shakeOnce() {
    _shake = 12;
    _curve = Curves.linear;
    _anim.duration = const Duration(milliseconds: 420);
    _anim.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _shake = 0;
        _offset = Offset.zero;
      });
    });
  }

  // ---- Commands -----------------------------------------------------------

  /// Flies off toward [direction] as if swiped, then reports it.
  Future<void> fling(DragDirection direction) async {
    if (_dismissed || _active && _to != Offset.zero) return;
    _anim.stop();
    await _flyOff(direction);
  }

  /// Flies in from off-screen toward [direction] to rest.
  Future<void> returnFrom(DragDirection direction) async {
    _anim.stop();
    // Comes back unwinding the turn it left with.
    final double turn = switch (direction) {
      DragDirection.left || DragDirection.up => -_model.flyOutRotate,
      DragDirection.right || DragDirection.down => _model.flyOutRotate,
    };
    setState(() {
      _dismissed = false;
      _offset = _offscreen(direction, _size) - _offset;
      _spin = turn;
      _spinTo = 0;
    });
    await _animateTo(
      Offset.zero,
      math.max(_model.flyOutMs, 380),
      Curves.easeOutCubic,
    );
  }

  /// Springs back to rest.
  Future<void> reset() async {
    _anim.stop();
    setState(() => _dismissed = false);
    await _animateTo(
      Offset.zero,
      _model.snapBackMs,
      flutterCurveOf(_model.snapCurve),
    );
  }

  DragValues? _shared;

  @override
  Widget build(BuildContext context) {
    final Size size = _size;
    final double angle =
        _offset.dx / math.max(1, size.width) * _model.rotateFactor + _spin;
    final DragValues current = values;
    if (widget.onValues != null && current != _shared) {
      _shared = current;
      // Shared after the frame: writing a variable rebuilds other nodes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onValues!(current);
      });
    }
    Widget child = DragScope(values: current, child: widget.child);
    if (_offset != Offset.zero || angle != 0) {
      child = Transform(
        alignment: Alignment(_model.originX, _model.originY),
        transform: Matrix4.translationValues(_offset.dx, _offset.dy, 0)
          ..rotateZ(angle * math.pi / 180),
        child: child,
      );
    }
    if (_dismissed) {
      child = IgnorePointer(child: Opacity(opacity: 0, child: child));
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onStart,
      onPanUpdate: _onUpdate,
      onPanEnd: _onEnd,
      onPanCancel: () {
        if (_dragging) _onEnd(DragEndDetails());
      },
      child: child,
    );
  }
}
