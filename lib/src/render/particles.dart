// One-shot particle overlays. Kept outside the node shell so confetti is not
// clipped by its own rounded decoration; ancestor clips still apply.
import 'dart:async';
import 'dart:math' as math;
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

abstract final class ParticlePlayers {
  static final Map<String, Set<RenderParticles>> _nodes = {};
  static Future<void> play(String id, String name) async {
    if (name != 'particles') return;
    await Future.wait([
      for (final p in [...?_nodes[id]])
        if (p.attached) p.fire(),
    ]);
  }
}

/// Analytic trajectory: independent of frame rate and safe after a paused tab.
///
/// The velocity decays by e^(-[drag] t) while [gravity] pulls down; with a
/// [terminal] speed the fall is capped there (paper floats down at it once
/// reached). All closed form, so any moment can be drawn without stepping.
Offset particlePosition(
  Offset origin,
  Offset velocity,
  double gravity,
  double seconds, {
  double drag = 0,
  double terminal = 0,
}) {
  final t = seconds;
  final vx = velocity.dx, vy = velocity.dy, g = gravity;
  if (drag <= 0) {
    final x = vx * t;
    var y = vy * t + g * t * t / 2;
    if (terminal > 0 && g > 0 && vy + g * t > terminal) {
      final tc = math.max(0.0, (terminal - vy) / g);
      y = vy * tc + g * tc * tc / 2 + terminal * (t - tc);
    }
    return origin + Offset(x, y);
  }
  final k = drag;
  double yAt(double t) {
    final e = math.exp(-k * t);
    return vy * (1 - e) / k + g / k * (t - (1 - e) / k);
  }

  final e = math.exp(-k * t);
  final x = vx * (1 - e) / k;
  var y = yAt(t);
  final speed = vy * e + g / k * (1 - e);
  if (terminal > 0 && speed > terminal) {
    // When the fall reached the terminal speed: vy·e + g/k·(1 - e) = T.
    double tc = 0;
    final denom = vy - g / k;
    if (denom.abs() > 1e-9) {
      final ec = (terminal - g / k) / denom;
      if (ec > 0 && ec < 1) tc = -math.log(ec) / k;
    }
    tc = tc.clamp(0.0, t);
    y = yAt(tc) + terminal * (t - tc);
  }
  return origin + Offset(x, y);
}

class _Burst {
  _Burst(this.emitter, this.seed);
  final api.ParticleEmitter emitter;
  final int seed;
  Duration? start;
  double age = 0;
  final done = Completer<void>();
  void finish() {
    if (!done.isCompleted) done.complete();
  }
}

class RenderParticles extends RenderProxyBox {
  String _nodeId = '';
  set nodeId(String v) {
    if (v == _nodeId) return;
    if (attached) _unregister();
    _nodeId = v;
    if (attached) _register();
  }

  api.ParticleEmitter? _emitter;
  set emitter(api.ParticleEmitter v) {
    final old = _emitter;
    _emitter = v;
    if (old != null && old.playKey != v.playKey && attached) unawaited(fire());
  }

  final _bursts = <_Burst>[];
  Ticker? _ticker;
  int _seed = 0;
  bool _appeared = false;
  int get activeBursts => _bursts.length;
  void _register() => (ParticlePlayers._nodes[_nodeId] ??= {}).add(this);
  void _unregister() {
    final set = ParticlePlayers._nodes[_nodeId];
    set?.remove(this);
    if (set?.isEmpty ?? false) ParticlePlayers._nodes.remove(_nodeId);
  }

  Future<void> fire() {
    final e = _emitter;
    if (!attached || e == null || e.count <= 0 || e.lifetime <= 0) {
      return Future.value();
    }
    // Bound repeated cues so a held interaction cannot grow memory forever.
    if (_bursts.length >= 16) _bursts.removeAt(0).finish();
    final burst = _Burst(e, ++_seed);
    _bursts.add(burst);
    _ticker ??= Ticker(_tick);
    if (!_ticker!.isActive) _ticker!.start();
    markNeedsPaint();
    return burst.done.future;
  }

  void _tick(Duration elapsed) {
    for (final b in [..._bursts]) {
      b.start ??= elapsed;
      b.age = (elapsed - b.start!).inMicroseconds / 1e6;
      if (b.age >= (b.emitter.delay + b.emitter.emit + b.emitter.lifetime) / 1000) {
        _bursts.remove(b);
        b.finish();
      }
    }
    if (_bursts.isEmpty) _ticker?.stop();
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
    if (!_appeared && (_emitter?.playOnAppear ?? false)) {
      _appeared = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) unawaited(fire());
      });
    }
  }

  @override
  void detach() {
    _unregister();
    _ticker?.stop();
    for (final b in _bursts) {
      b.finish();
    }
    _bursts.clear();
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    for (final tp in _glyphs.values) {
      tp.dispose();
    }
    _glyphs.clear();
    super.dispose();
  }

  final _glyphs = <String, TextPainter>{};

  /// [glyph] laid out at 48 px, drawn scaled (emoji particles).
  TextPainter _glyph(String glyph) => _glyphs.putIfAbsent(
    glyph,
    () => TextPainter(
      text: TextSpan(text: glyph, style: const TextStyle(fontSize: 48, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!hasSize || size.isEmpty) return;
    final canvas = context.canvas;
    for (final b in _bursts) {
      final e = b.emitter;
      final random = math.Random(b.seed);
      final colors = e.colors.isEmpty
          ? api.ParticleEmitter.defaultColors
          : e.colors;
      final shapes = e.shapes.isEmpty
          ? const [api.ParticleShape.square]
          : e.shapes;
      final life = e.lifetime / 1000;
      final age = b.age - e.delay / 1000;
      for (var i = 0; i < math.min(e.count, 2000); i++) {
        // The first draws keep the order older bursts used.
        final jitter = (random.nextDouble() - .5) * e.originWidth * size.width;
        final angleRandom = random.nextDouble() * 2 - 1;
        final speed = e.speed * (.55 + random.nextDouble() * .6);
        final spin = (random.nextDouble() * 2 - 1) * e.spin * math.pi / 180;
        final s = e.size.abs() * (.7 + random.nextDouble() * .6);
        final flutterRate = e.flutter * (.55 + random.nextDouble() * .45);
        final flutterPhase = random.nextDouble() * math.pi * 2;
        final swayPhase = random.nextDouble() * math.pi * 2;
        final mirrored = e.mirror && i.isOdd;
        final originX = mirrored ? -e.originX : e.originX;
        final direction = mirrored ? -e.direction : e.direction;
        final x = mirrored ? -jitter : jitter;
        final angle = (direction + angleRandom * e.spread) * math.pi / 180;
        final t = age - (e.emit / 1000 * i / math.max(1, e.count - 1));
        if (t < 0 || t >= life) continue;
        final origin = Alignment(originX, e.originY).alongSize(size) + offset;
        var point = particlePosition(
          origin + Offset(x, 0),
          Offset(math.sin(angle) * speed, -math.cos(angle) * speed),
          e.gravity,
          t,
          drag: e.drag,
          terminal: e.terminalVelocity,
        );
        if (e.sway != 0) point += Offset(e.sway * math.sin(t * 3.2 + swayPhase), 0);
        final color = colors[i % colors.length];
        final fade = e.fadeOut <= 0 ? 1.0 : ((life - t) / (e.fadeOut / 1000)).clamp(0.0, 1.0);
        final paint = Paint()
          ..color = Color(color.value).withValues(alpha: fade * ((color.value >> 24) / 255));
        final shape = shapes[i % shapes.length];
        canvas
          ..save()
          ..translate(point.dx, point.dy)
          ..rotate(spin * t);
        if (shape != api.ParticleShape.emoji && e.flutter > 0) {
          // Turning over: one axis squashed as the piece rotates edge-on.
          final turn = math.cos(t * flutterRate + flutterPhase);
          canvas.scale(1, .2 + .8 * turn.abs());
        }
        switch (shape) {
          case api.ParticleShape.circle:
            canvas.drawCircle(Offset.zero, s / 2, paint);
          case api.ParticleShape.square:
            canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s), paint);
          case api.ParticleShape.strip:
            canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s * .4, height: s * 1.6), paint);
          case api.ParticleShape.star:
            final path = Path();
            for (var j = 0; j < 10; j++) {
              final a = -math.pi / 2 + j * math.pi / 5;
              final r = s * (j.isEven ? .75 : .36);
              if (j == 0) {
                path.moveTo(math.cos(a) * r, math.sin(a) * r);
              } else {
                path.lineTo(math.cos(a) * r, math.sin(a) * r);
              }
            }
            canvas.drawPath(path..close(), paint);
          case api.ParticleShape.triangle:
            canvas.drawPath(
              Path()
                ..moveTo(0, -s * .55)
                ..lineTo(s * .5, s * .4)
                ..lineTo(-s * .5, s * .4)
                ..close(),
              paint,
            );
          case api.ParticleShape.squiggle:
            final path = Path()..moveTo(-s * .8, 0);
            for (var j = 0; j < 4; j++) {
              path.quadraticBezierTo(-s * .6 + j * s * .4, j.isEven ? -s * .45 : s * .45, -s * .4 + j * s * .4, 0);
            }
            canvas.drawPath(
              path,
              paint
                ..style = PaintingStyle.stroke
                ..strokeWidth = math.max(1.5, s * .26)
                ..strokeCap = StrokeCap.round,
            );
          case api.ParticleShape.emoji:
            if (e.glyph.isNotEmpty) {
              final tp = _glyph(e.glyph);
              final k = s / 48;
              canvas.scale(k);
              if (fade < 1) {
                canvas.saveLayer(
                  Rect.fromCenter(center: Offset.zero, width: tp.width + 8, height: tp.height + 8),
                  Paint()..color = Color.fromRGBO(0, 0, 0, fade),
                );
              }
              tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
              if (fade < 1) canvas.restore();
            }
        }
        canvas.restore();
      }
    }
  }
}
