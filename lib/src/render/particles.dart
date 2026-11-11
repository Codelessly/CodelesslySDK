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
Offset particlePosition(
  Offset origin,
  Offset velocity,
  double gravity,
  double seconds,
) => origin + velocity * seconds + Offset(0, gravity * seconds * seconds / 2);

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
      if (b.age >= (b.emitter.emit + b.emitter.lifetime) / 1000) {
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
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!hasSize || size.isEmpty) return;
    final canvas = context.canvas;
    for (final b in _bursts) {
      final e = b.emitter;
      final random = math.Random(b.seed);
      final origin = Alignment(e.originX, e.originY).alongSize(size) + offset;
      final colors = e.colors.isEmpty
          ? api.ParticleEmitter.defaultColors
          : e.colors;
      final shapes = e.shapes.isEmpty
          ? const [api.ParticleShape.square]
          : e.shapes;
      for (var i = 0; i < math.min(e.count, 2000); i++) {
        final x = (random.nextDouble() - .5) * e.originWidth * size.width;
        final angle =
            (e.direction + (random.nextDouble() * 2 - 1) * e.spread) *
            math.pi /
            180;
        final speed = e.speed * (.55 + random.nextDouble() * .6);
        final spin = (random.nextDouble() * 2 - 1) * 9;
        final s = e.size.abs() * (.7 + random.nextDouble() * .6);
        final t = b.age - (e.emit / 1000 * i / math.max(1, e.count - 1));
        if (t < 0 || t >= e.lifetime / 1000) continue;
        final point = particlePosition(
          origin + Offset(x, 0),
          Offset(math.sin(angle) * speed, -math.cos(angle) * speed),
          e.gravity,
          t,
        );
        final color = colors[i % colors.length];
        final paint = Paint()
          ..color = Color(color.value).withValues(
            alpha:
                (((e.lifetime / 1000 - t) / .5).clamp(0.0, 1.0)) *
                ((color.value >> 24) / 255),
          );
        canvas
          ..save()
          ..translate(point.dx, point.dy)
          ..rotate(spin * t)
          ..scale(1, .2 + .8 * math.cos(t * 8).abs());
        switch (shapes[i % shapes.length]) {
          case api.ParticleShape.circle:
            canvas.drawCircle(Offset.zero, s / 2, paint);
          case api.ParticleShape.square:
            canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: s, height: s),
              paint,
            );
          case api.ParticleShape.strip:
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * .4,
                height: s * 1.6,
              ),
              paint,
            );
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
        }
        canvas.restore();
      }
    }
  }
}
