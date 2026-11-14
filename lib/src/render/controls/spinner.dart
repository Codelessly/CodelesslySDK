// Spinners as render objects on the tree's ticker: SSUI's arc (a loading
// button's icon, `circularProgressIndicator`) and the ticked wheel of
// `activityIndicator`. No widget, no Material or Cupertino: what
// `CircularProgressIndicator`, `CupertinoActivityIndicator` and SSUI's
// `SoftSaaSSpinner` draw, painted here.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// How a spinner is drawn.
enum SpinnerStyle {
  /// SSUI's arc: a ring filled to [RenderSpinner.value], or (null) a 0.6π
  /// arc turning once every [RenderSpinner.period].
  arc,

  /// Eight ticks round a wheel, the lead one darkest, stepping round
  /// (`CupertinoActivityIndicator`'s look).
  ticks,
}

/// A spinner or a determinate ring, in a square of the box's shortest side
/// (or [diameter] when it hugs), centered. It turns on its own ticker while
/// attached and [animating].
class RenderSpinner extends RenderBox {
  RenderSpinner({SpinnerStyle style = SpinnerStyle.arc}) : _style = style; // ignore: prefer_initializing_formals

  SpinnerStyle _style;
  SpinnerStyle get style => _style;
  set style(SpinnerStyle v) {
    if (v == _style) return;
    _style = v;
    markNeedsPaint();
  }

  double? _value;

  /// The filled fraction (0–1); null spins.
  double? get value => _value;
  set value(double? v) {
    if (v == _value) return;
    _value = v;
    _syncTicker();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Color _color = const Color(0xFF2563EB);
  Color get color => _color;
  set color(Color v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  Color? _track;

  /// The ring behind the arc (null: none).
  Color? get track => _track;
  set track(Color? v) {
    if (v == _track) return;
    _track = v;
    markNeedsPaint();
  }

  double? _strokeWidth;

  /// The arc's width (null: SSUI's 2, an eighth of a ring larger than 16).
  set strokeWidth(double? v) {
    if (v == _strokeWidth) return;
    _strokeWidth = v;
    markNeedsPaint();
  }

  double _strokeAlign = -1;

  /// -1 inside the box, 0 centered on its edge, 1 outside (Flutter's
  /// `strokeAlign`); SSUI's arc is inside.
  set strokeAlign(double v) {
    if (v == _strokeAlign) return;
    _strokeAlign = v;
    markNeedsPaint();
  }

  StrokeCap _cap = StrokeCap.round;
  set strokeCap(StrokeCap v) {
    if (v == _cap) return;
    _cap = v;
    markNeedsPaint();
  }

  double _trackGap = 0;

  /// A gap between the arc and the track (Flutter's `trackGap`), in pixels.
  set trackGap(double v) {
    if (v == _trackGap) return;
    _trackGap = v;
    markNeedsPaint();
  }

  double _diameter = 16;

  /// Its size when nothing sizes it.
  set diameter(double v) {
    if (v == _diameter) return;
    _diameter = v;
    markNeedsLayout();
  }

  /// How much of the ring a spinning arc covers (SSUI's spinner: 0.3; a
  /// loading button's: a quarter).
  double sweep = .3;

  /// One turn (SSUI's spinner: 900 ms; the button's: 1 s; the ticks: 1 s).
  Duration period = const Duration(milliseconds: 900);

  bool _animating = true;

  /// Whether it turns (a design canvas, or `animating: false`, holds it).
  set animating(bool v) {
    if (v == _animating) return;
    _animating = v;
    _syncTicker();
    markNeedsPaint();
  }

  String? semanticsLabel;

  Ticker? _ticker;
  double _turns = 0;

  /// How far round it is (0–1): where the next frame paints it.
  double get turns => _turns;

  bool get spinning => _ticker?.isActive ?? false;

  void _syncTicker() {
    final want = attached && _animating && (_value == null || _style == SpinnerStyle.ticks);
    if (want) {
      final t = _ticker ??= Ticker(_tick, debugLabel: 'spinner');
      if (!t.isActive) t.start();
    } else {
      _ticker?.stop();
    }
  }

  void _tick(Duration elapsed) {
    final us = period.inMicroseconds;
    if (us <= 0) return;
    _turns = (elapsed.inMicroseconds % us) / us;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncTicker();
  }

  @override
  void detach() {
    _ticker?.stop();
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (constraints.isTight) return constraints.smallest;
    return constraints.constrain(Size.square(_diameter));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _diameter;
  @override
  double computeMaxIntrinsicWidth(double height) => _diameter;
  @override
  double computeMinIntrinsicHeight(double width) => _diameter;
  @override
  double computeMaxIntrinsicHeight(double width) => _diameter;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final center = offset + size.center(Offset.zero);
    if (_style == SpinnerStyle.ticks) {
      paintTicks(context.canvas, center, side / 2, _color, _animating ? _turns : 0);
      return;
    }
    paintArc(context.canvas, center, side,
        color: _color,
        track: _track,
        strokeWidth: _strokeWidth ?? math.max(2.0, side / 8),
        strokeAlign: _strokeAlign,
        cap: _cap,
        value: _value,
        turns: _turns,
        sweep: sweep,
        trackGap: _trackGap);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (semanticsLabel != null) config.label = semanticsLabel!;
    if (_value != null) config.value = '${(_value!.clamp(0.0, 1.0) * 100).round()}%';
    config.textDirection = TextDirection.ltr;
  }
}

/// SSUI's spinner arc in a square of [side] round [center]: the [track]
/// ring, then the arc filled to [value] from 12 o'clock, or (null) an arc
/// over [sweep] of the ring, [turns] of the way round.
void paintArc(Canvas canvas, Offset center, double side,
    {required Color color,
    Color? track,
    double strokeWidth = 2,
    double strokeAlign = -1,
    StrokeCap cap = StrokeCap.round,
    double? value,
    double turns = 0,
    double sweep = .3,
    double trackGap = 0}) {
  // The stroke's center line, by its alignment (-1: inside the square).
  final d = side + strokeWidth * strokeAlign;
  if (d <= 0) return;
  final rect = Rect.fromCenter(center: center, width: d, height: d);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = cap;
  const top = -math.pi / 2;
  if (value == null) {
    if (track != null) canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    canvas.drawArc(rect, top + turns * math.pi * 2, math.pi * 2 * sweep, false, paint..color = color);
    return;
  }
  final v = value.clamp(0.0, 1.0);
  final arc = math.pi * 2 * v;
  if (track != null) {
    // The track is the rest of the ring, less a gap at each end.
    final gap = v <= 0 || v >= 1 || trackGap <= 0 ? 0.0 : (trackGap + (cap == StrokeCap.butt ? 0 : strokeWidth)) / (d / 2);
    final rest = math.pi * 2 - arc - gap * 2;
    if (rest > 0) {
      final under = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = cap
        ..color = track;
      canvas.drawArc(rect, top + arc + gap, rest, false, under);
    }
  }
  if (v > 0) canvas.drawArc(rect, top, arc, false, paint..color = color);
}

/// Eight ticks round [center] at [radius], the one [turns] of the way round
/// at full [color] and the rest fading behind it.
void paintTicks(Canvas canvas, Offset center, double radius, Color color, double turns) {
  const count = 8;
  final lead = (turns * count).floor() % count;
  final width = radius / 4.5;
  final paint = Paint()..strokeCap = StrokeCap.round;
  for (var i = 0; i < count; i++) {
    final behind = (lead - i) % count;
    final alpha = .9 - behind * (.75 / (count - 1));
    final angle = -math.pi / 2 + i * math.pi * 2 / count;
    final dir = Offset(math.cos(angle), math.sin(angle));
    paint
      ..color = color.withValues(alpha: color.a * alpha)
      ..strokeWidth = width;
    canvas.drawLine(center + dir * (radius * .5), center + dir * (radius - width / 2), paint);
  }
}
