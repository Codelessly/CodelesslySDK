import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:collection/collection.dart';

/// The transform of a one-shot [EffectAnimationType] at progress [t]
/// (0 to 1) and strength [amount], as offsets in logical pixels, scales,
/// a rotation in radians and an opacity.
({double dx, double dy, double sx, double sy, double rotation, double opacity})
effectTransformAt(EffectAnimationType type, double t, double amount) {
  final double decay = 1 - t;
  switch (type) {
    case EffectAnimationType.shake:
      return (
        dx: math.sin(t * math.pi * 8) * 12 * amount * decay,
        dy: 0,
        sx: 1,
        sy: 1,
        rotation: 0,
        opacity: 1,
      );
    case EffectAnimationType.bounce:
      // Up fast, down, two smaller hops; squashes as it lands.
      final double hop = (math.sin(t * math.pi * 3) * decay).abs();
      final double squash = t > 0.3
          ? math.sin((t - 0.3) / 0.7 * math.pi * 3) * 0.08 * decay
          : 0.0;
      return (
        dx: 0,
        dy: -22 * amount * hop,
        sx: 1 + squash * amount,
        sy: 1 - squash * amount,
        rotation: 0,
        opacity: 1,
      );
    case EffectAnimationType.pop:
      final double s = 1 + math.sin(t * math.pi) * 0.22 * amount * (1 - t / 2);
      return (dx: 0, dy: 0, sx: s, sy: s, rotation: 0, opacity: 1);
    case EffectAnimationType.wiggle:
      return (
        dx: 0,
        dy: 0,
        sx: 1,
        sy: 1,
        rotation: math.sin(t * math.pi * 6) * 0.14 * amount * decay,
        opacity: 1,
      );
    case EffectAnimationType.jelly:
      final double w = math.sin(t * math.pi * 4) * 0.16 * amount * decay;
      return (dx: 0, dy: 0, sx: 1 + w, sy: 1 - w, rotation: 0, opacity: 1);
    case EffectAnimationType.flash:
      return (
        dx: 0,
        dy: 0,
        sx: 1,
        sy: 1,
        rotation: 0,
        opacity: 0.5 + math.cos(t * math.pi * 4) * 0.5,
      );
    case EffectAnimationType.spin:
      return (
        dx: 0,
        dy: 0,
        sx: 1,
        sy: 1,
        rotation: Curves.easeInOutCubic.transform(t) * 2 * math.pi * amount,
        opacity: 1,
      );
  }
}

/// The [NodePlayBox]es on screen, by node id, so a `playAnimation` action
/// can reach them.
abstract final class NodePlayRegistry {
  static final Map<String, Set<NodePlayBoxState>> _boxes = {};

  /// Plays [animation] (an [EffectAnimation.name], or
  /// [ParticleEmitter.animationName]) on every shown instance of [nodeId].
  /// Completes when the longest of them ends; at once when none is shown.
  static Future<void> play(String nodeId, String animation) async {
    final List<Future<void>> runs = [
      for (final NodePlayBoxState box in [...?_boxes[nodeId]])
        if (box.mounted) box.play(animation),
    ];
    await Future.wait(runs);
  }

  static void _add(String nodeId, NodePlayBoxState box) =>
      (_boxes[nodeId] ??= {}).add(box);

  static void _remove(String nodeId, NodePlayBoxState box) {
    _boxes[nodeId]?.remove(box);
    if (_boxes[nodeId]?.isEmpty ?? false) _boxes.remove(nodeId);
  }
}

/// Plays a node's [EffectAnimation]s and fires its [ParticleEmitter].
///
/// An effect plays when its entry in [playKeys] changes (not on the first
/// build), when [NodePlayRegistry.play] names it, or on appear with
/// [EffectAnimation.playOnAppear]. The particles use the key
/// [ParticleEmitter.animationName] in [playKeys]. [delays] override an
/// effect's [EffectAnimation.delayMs] by name.
///
/// Effects draw over the node's layout like a motion; particles draw over
/// the node and beyond it, never taking taps. Under a disabled
/// [TickerMode] (the design canvas) nothing plays.
class NodePlayBox extends StatefulWidget {
  /// Creates a [NodePlayBox].
  const NodePlayBox({
    super.key,
    required this.nodeId,
    required this.effects,
    required this.particles,
    required this.playKeys,
    required this.delays,
    required this.child,
  });

  /// The node's id, for [NodePlayRegistry].
  final String nodeId;

  /// The node's one-shot effects.
  final List<EffectAnimation> effects;

  /// The node's particle emitter, if it has one.
  final ParticleEmitter? particles;

  /// The current value of each effect's play key, by effect name.
  final Map<String, String?> playKeys;

  /// Bound delays in milliseconds, by effect name.
  final Map<String, int> delays;

  /// The node's widget.
  final Widget child;

  @override
  State<NodePlayBox> createState() => NodePlayBoxState();
}

/// State of a [NodePlayBox]; [play] plays one of its animations.
class NodePlayBoxState extends State<NodePlayBox> with TickerProviderStateMixin {
  final Map<String, AnimationController> _controllers = {};
  final Map<String, Timer> _delays = {};
  final GlobalKey<_ParticleLayerState> _particles = GlobalKey();

  @override
  void initState() {
    super.initState();
    NodePlayRegistry._add(widget.nodeId, this);
    for (final EffectAnimation effect in widget.effects) {
      if (effect.playOnAppear) play(effect.name);
    }
    if (widget.particles?.playOnAppear ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) play(ParticleEmitter.animationName);
      });
    }
  }

  @override
  void didUpdateWidget(NodePlayBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId) {
      NodePlayRegistry._remove(oldWidget.nodeId, this);
      NodePlayRegistry._add(widget.nodeId, this);
    }
    for (final MapEntry(:key, :value) in widget.playKeys.entries) {
      if (oldWidget.playKeys.containsKey(key) &&
          oldWidget.playKeys[key] != value) {
        play(key);
      }
    }
  }

  /// Plays the effect named [name], or the particles; completes when it
  /// ends.
  Future<void> play(String name) {
    if (name == ParticleEmitter.animationName) {
      final ParticleEmitter? emitter = widget.particles;
      if (emitter == null) return Future.value();
      _particles.currentState?.fire();
      return Future.delayed(
        Duration(milliseconds: emitter.emitMs + emitter.lifetimeMs),
      );
    }
    final EffectAnimation? effect = widget.effects.firstWhereOrNull(
      (e) => e.name == name,
    );
    if (effect == null) return Future.value();
    final AnimationController controller = _controllers[name] ??=
        AnimationController(vsync: this)..addListener(() => setState(() {}));
    controller.duration = Duration(
      milliseconds: math.max(1, effect.durationMs),
    );
    final Completer<void> done = Completer();
    void start() {
      if (!mounted) return done.complete();
      controller.forward(from: 0).whenCompleteOrCancel(() {
        if (!done.isCompleted) done.complete();
      });
    }

    _delays.remove(name)?.cancel();
    final int delay = widget.delays[name] ?? effect.delayMs;
    if (delay > 0) {
      _delays[name] = Timer(Duration(milliseconds: delay), start);
    } else {
      start();
    }
    return done.future;
  }

  @override
  void dispose() {
    NodePlayRegistry._remove(widget.nodeId, this);
    for (final Timer timer in _delays.values) {
      timer.cancel();
    }
    for (final AnimationController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    for (final EffectAnimation effect in widget.effects) {
      final AnimationController? controller = _controllers[effect.name];
      if (controller == null || !controller.isAnimating) continue;
      final e = effectTransformAt(effect.type, controller.value, effect.amount);
      if (e.opacity < 1) {
        child = Opacity(opacity: e.opacity.clamp(0, 1), child: child);
      }
      child = Transform.translate(
        offset: Offset(e.dx, e.dy),
        child: Transform(
          alignment: Alignment(effect.originX, effect.originY),
          transform: Matrix4.identity()
            ..rotateZ(e.rotation)
            ..scaleByDouble(e.sx, e.sy, 1, 1),
          child: child,
        ),
      );
    }
    final ParticleEmitter? emitter = widget.particles;
    if (emitter != null) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: _ParticleLayer(key: _particles, emitter: emitter),
            ),
          ),
        ],
      );
    }
    return child;
  }
}

class _Particle {
  _Particle({
    required this.position,
    required this.velocity,
    required this.angle,
    required this.spin,
    required this.flutter,
    required this.color,
    required this.shape,
    required this.size,
  });

  Offset position;
  Offset velocity;
  double angle;
  final double spin;
  final double flutter;
  final Color color;
  final ParticleShape shape;
  final double size;
  double age = 0;
}

class _ParticleLayer extends StatefulWidget {
  const _ParticleLayer({super.key, required this.emitter});

  final ParticleEmitter emitter;

  @override
  State<_ParticleLayer> createState() => _ParticleLayerState();
}

class _ParticleLayerState extends State<_ParticleLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final List<_Particle> _live = [];
  final math.Random _random = math.Random(7);
  Duration _last = Duration.zero;
  double _emitLeft = 0;
  double _owed = 0;
  bool _burst = false;
  Size _size = Size.zero;

  List<Color> get _colors {
    final List<Color> colors = [
      for (final String hex in widget.emitter.colors)
        if (_parseColor(hex) case final Color c) c,
    ];
    return colors.isEmpty ? const [Color(0xFFFFC83D)] : colors;
  }

  void fire() {
    if (widget.emitter.emitMs > 0) {
      _emitLeft = widget.emitter.emitMs / 1000;
    } else {
      _burst = true;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _spawn(int n) {
    if (_size.isEmpty || n <= 0) return;
    final ParticleEmitter e = widget.emitter;
    final Offset origin = Alignment(e.originX, e.originY).alongSize(_size);
    final List<Color> colors = _colors;
    final List<ParticleShape> shapes = e.shapes.isEmpty
        ? const [ParticleShape.square]
        : e.shapes;
    for (int i = 0; i < n; i++) {
      final double x =
          origin.dx + (_random.nextDouble() - 0.5) * e.originWidth * _size.width;
      final double a =
          (e.direction + (_random.nextDouble() * 2 - 1) * e.spread) *
          math.pi /
          180;
      final double v = e.speed * (0.55 + _random.nextDouble() * 0.6);
      _live.add(
        _Particle(
          position: Offset(x, origin.dy),
          velocity: Offset(math.sin(a) * v, -math.cos(a) * v),
          angle: _random.nextDouble() * math.pi * 2,
          spin: (_random.nextDouble() * 2 - 1) * 9,
          flutter: 4 + _random.nextDouble() * 8,
          color: colors[_random.nextInt(colors.length)],
          shape: shapes[_random.nextInt(shapes.length)],
          size: e.size * (0.7 + _random.nextDouble() * 0.6),
        ),
      );
    }
  }

  void _tick(Duration now) {
    final double dt = _last == Duration.zero
        ? 1 / 60
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    final ParticleEmitter e = widget.emitter;
    if (_burst) {
      _burst = false;
      _spawn(e.count);
    }
    if (_emitLeft > 0) {
      _emitLeft -= dt;
      _owed += e.count * dt;
      final int n = _owed.floor();
      _owed -= n;
      _spawn(n);
    }
    final double life = e.lifetimeMs / 1000;
    for (final _Particle p in _live) {
      p.age += dt;
      // Air slows the burst, gravity pulls it down, and paper drifts side
      // to side as it falls.
      p.velocity = Offset(
        p.velocity.dx * math.pow(0.35, dt),
        p.velocity.dy * math.pow(0.55, dt) + e.gravity * dt * 0.6,
      );
      p.position +=
          p.velocity * dt + Offset(math.sin(p.age * p.flutter) * 30 * dt, 0);
      p.angle += p.spin * dt;
    }
    _live.removeWhere((p) => p.age > life);
    if (_live.isEmpty && _emitLeft <= 0 && !_burst) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      return CustomPaint(
        size: constraints.biggest,
        painter: _ParticlePainter(_live, widget.emitter.lifetimeMs / 1000),
      );
    },
  );
}

Color? _parseColor(String hex) {
  String h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final int? value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.life);

  final List<_Particle> particles;
  final double life;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (final _Particle p in particles) {
      final double fade = ((life - p.age) / 0.5).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: p.color.a * fade);
      canvas
        ..save()
        ..translate(p.position.dx, p.position.dy)
        ..rotate(p.angle)
        // Paper turning over squashes it.
        ..scale(1, math.cos(p.age * p.flutter).abs() * 0.8 + 0.2);
      final double s = p.size;
      switch (p.shape) {
        case ParticleShape.square:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s, height: s),
              const Radius.circular(2),
            ),
            paint,
          );
        case ParticleShape.circle:
          canvas.drawCircle(Offset.zero, s / 2, paint);
        case ParticleShape.strip:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * 0.45,
                height: s * 1.6,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
        case ParticleShape.star:
          canvas.drawPath(starPath(s * 0.75), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

/// A five-pointed star centred on the origin with outer radius [r].
Path starPath(double r, {double inner = 0.48}) {
  final Path path = Path();
  for (int i = 0; i < 10; i++) {
    final double radius = i.isEven ? r : r * inner;
    final double a = -math.pi / 2 + i * math.pi / 5;
    final Offset point = Offset(math.cos(a) * radius, math.sin(a) * radius);
    i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

// ---------------------------------------------------------------------------
// Flights: shared-element moves between nodes with the same flight key.

class _FlightRecord {
  _FlightRecord(this.rect, this.time, this.owner);

  Rect rect;
  DateTime time;

  /// The box that drew it, or null for a dropped drag copy.
  final RenderFlightProbe? owner;
}

/// Where each flight key was last seen, by every box that has it, plus
/// where dragged copies were let go.
abstract final class FlightRegistry {
  static final Map<String, List<_FlightRecord>> _records = {};

  /// Remembers that a dragged copy with [key] was let go at [rect] (global
  /// coordinates), so the node that shows the drop next flies from there.
  static void recordDrop(String key, Rect rect) {
    if (key.isEmpty) return;
    final List<_FlightRecord> list = _records[key] ??= [];
    list.removeWhere((r) => r.owner == null);
    list.add(_FlightRecord(rect, DateTime.now(), null));
  }

  static void _paint(RenderFlightProbe probe, String key, Rect rect) {
    final List<_FlightRecord> list = _records[key] ??= [];
    final _FlightRecord? mine = list.firstWhereOrNull((r) => r.owner == probe);
    if (mine == null) {
      list.add(_FlightRecord(rect, DateTime.now(), probe));
    } else {
      mine
        ..rect = rect
        ..time = DateTime.now();
    }
  }

  static void _forget(RenderFlightProbe probe, String key) {
    final List<_FlightRecord>? list = _records[key];
    if (list == null) return;
    // A box that goes away keeps its last place for a moment, so the node
    // that replaces it can fly from there.
    for (final _FlightRecord r in list) {
      if (r.owner == probe) {
        list
          ..remove(r)
          ..add(_FlightRecord(r.rect, DateTime.now(), null));
        break;
      }
    }
  }

  /// Where a node with [key] that [probe] now shows should fly from: the
  /// most recent place another holder of the key was seen that is not on
  /// screen any more (hidden, removed, or a drag let go). Null when there
  /// is none, or it was more than two seconds ago for a removed one.
  static Rect? _source(RenderFlightProbe probe, String key) {
    final List<_FlightRecord>? list = _records[key];
    if (list == null) return null;
    final DateTime now = DateTime.now();
    list.removeWhere(
      (r) => r.owner == null && now.difference(r.time).inSeconds >= 2,
    );
    _FlightRecord? best;
    for (final _FlightRecord r in list) {
      if (r.owner == probe) continue;
      if (r.owner != null && r.owner!.isShowing) continue;
      if (best == null || r.time.isAfter(best.time)) best = r;
    }
    // Where it was last drawn: a hidden box may since have been moved
    // (an offstage one collapses).
    return best?.rect;
  }

  /// Clears every record; for tests.
  @visibleForTesting
  static void reset() => _records.clear();
}

/// Records where its child is drawn under [flightKey] for [FlightRegistry],
/// and reports its first placement to [onFirstPaint].
class FlightProbe extends SingleChildRenderObjectWidget {
  /// Creates a [FlightProbe].
  const FlightProbe({
    super.key,
    required this.flightKey,
    required this.record,
    required this.onPlaced,
    super.child,
  });

  /// The node's flight key.
  final String flightKey;

  /// Whether to record where it is drawn (false for a drag ghost).
  final bool record;

  /// Called after the first paint (and after each key change) with the
  /// box's global rect and the place it should fly from, if any.
  final void Function(Rect rect, Rect? from) onPlaced;

  @override
  RenderFlightProbe createRenderObject(BuildContext context) =>
      RenderFlightProbe(flightKey, record, onPlaced);

  @override
  void updateRenderObject(BuildContext context, RenderFlightProbe renderObject) {
    renderObject
      ..flightKey = flightKey
      ..record = record
      ..onPlaced = onPlaced;
  }
}

/// The render object of [FlightProbe].
class RenderFlightProbe extends RenderProxyBox {
  /// Creates a [RenderFlightProbe].
  RenderFlightProbe(this._flightKey, this.record, this.onPlaced);

  String _flightKey;
  bool _placed = false;

  /// Whether to record where it is drawn.
  bool record;

  /// See [FlightProbe.onPlaced].
  void Function(Rect rect, Rect? from) onPlaced;

  /// The key it records under.
  String get flightKey => _flightKey;
  set flightKey(String value) {
    if (value == _flightKey) return;
    FlightRegistry._forget(this, _flightKey);
    _flightKey = value;
    _placed = false;
    markNeedsPaint();
  }

  /// Whether it is on screen: attached, and not under an offstage or fully
  /// transparent ancestor.
  bool get isShowing {
    if (!attached) return false;
    RenderObject? node = this;
    while (node != null) {
      if (node is RenderOffstage && node.offstage) return false;
      if (node is RenderOpacity && node.opacity == 0) return false;
      if (node is RenderAnimatedOpacity && node.opacity.value == 0) {
        return false;
      }
      node = node.parent;
    }
    return true;
  }

  @override
  void detach() {
    if (_flightKey.isNotEmpty) FlightRegistry._forget(this, _flightKey);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_flightKey.isEmpty || !record || !hasSize) return;
    final Rect rect = localToGlobal(Offset.zero) & size;
    if (!_placed) {
      _placed = true;
      final Rect? from = FlightRegistry._source(this, _flightKey);
      onPlaced(rect, from);
    }
    FlightRegistry._paint(this, _flightKey, rect);
  }
}

/// Flies its child in from where another node with the same [flightKey]
/// was ([BaseNode.flightKey]), with a spring.
class FlightBox extends StatefulWidget {
  /// Creates a [FlightBox].
  const FlightBox({
    super.key,
    required this.flightKey,
    required this.child,
    this.spring = const SpringDescription(mass: 1, stiffness: 420, damping: 24),
    this.animate = true,
  });

  /// The node's flight key; empty for none.
  final String flightKey;

  /// The spring the flight follows.
  final SpringDescription spring;

  /// Whether flights run (false on the design canvas).
  final bool animate;

  /// The node's widget.
  final Widget child;

  @override
  State<FlightBox> createState() => _FlightBoxState();
}

class _FlightBoxState extends State<FlightBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addListener(() => setState(() {}));
  Offset _fromOffset = Offset.zero;
  double _fromScale = 1;

  void _placed(Rect rect, Rect? from) {
    if (!widget.animate || from == null || from == rect) return;
    // Starts in the next frame: this one is being painted.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fromOffset = from.center - rect.center;
        _fromScale = rect.width > 0 ? from.width / rect.width : 1;
      });
      _flight
        ..value = 0
        ..animateWith(SpringSimulation(widget.spring, 0, 1, 0));
    });
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool record = !FlightSuppress.of(context);
    // The probe stays outermost and the transform inside it is always
    // there, so a flight starting doesn't remount the probe (which would
    // count as appearing again) and the probe records the node's layout
    // place, not where the flight draws it.
    final double rest = 1 - _flight.value;
    return FlightProbe(
      flightKey: widget.flightKey,
      record: record,
      onPlaced: _placed,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.translationValues(
          _fromOffset.dx * rest,
          _fromOffset.dy * rest,
          0,
        )..scaleByDouble(
            1 + (_fromScale - 1) * rest,
            1 + (_fromScale - 1) * rest,
            1,
            1,
          ),
        child: widget.child,
      ),
    );
  }
}

/// Stops [FlightBox]es below it from recording where they are drawn: the
/// ghost a draggable leaves in its place shouldn't be where a drop flies
/// from.
class FlightSuppress extends InheritedWidget {
  /// Creates a [FlightSuppress].
  const FlightSuppress({super.key, required super.child});

  /// Whether [context] is under a [FlightSuppress].
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FlightSuppress>() != null;

  @override
  bool updateShouldNotify(FlightSuppress oldWidget) => false;
}
