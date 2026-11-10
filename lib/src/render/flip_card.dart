// A two-sided card (SDK 8.x's NodeFlip): turned 0° or 180° about its axis
// with its motion's perspective, duration, curve and keyframed scale. A
// running app turns it when its variable (or `flipped`) changes, on a tap
// with `tapToFlip`, and with `dragToFlip` under the finger, settling on
// the nearer face (or the one a fling heads for) by its spring; a tap or a
// drag writes the variable. Inside it `${flip.flipped}` and
// `${flip.progress}` can be read.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../runtime/actions/context.dart' show setVariableIn, variableOf;
import '../runtime/contracts.dart';
import '../runtime/expressions/node_scopes.dart';
import '../runtime/expressions/scopes.dart';
import 'behaviours.dart' show RenderPose, motionMatrix;
import 'node_tree.dart';

class RenderFlip extends RenderPose {
  NodeBox? _box;
  api.FlipCard _flip = const api.FlipCard();
  api.Motion? _motion;
  bool _animates = false;
  ValueScope? _scope;
  Listenable? _watched;

  /// Whether the card is (or is turning to be) on its back.
  bool? _target;

  /// The turn: 0 front, 1 back.
  double _progress = 0;

  /// A curve-timed turn from [_start] since [_since], or a spring settle.
  bool _turning = false;
  double _start = 0;
  Duration? _since;
  Simulation? _spring;
  Ticker? _ticker;

  bool _dragging = false;
  double _dragStart = 0;
  TapGestureRecognizer? _tap;
  DragGestureRecognizer? _drag;

  /// Whether the back shows (or is turning to).
  bool get flipped => _target ?? false;

  /// The turn now: 0 front, 1 back.
  double get progress => _progress;

  void configure(NodeBox? box, api.FlipCard flip, api.Motion? motion, {required bool animates}) {
    _box = box;
    final axisChanged = flip.axis != _flip.axis;
    _flip = flip;
    _motion = motion;
    if (axisChanged) {
      _drag?.dispose();
      _drag = null;
    }
    if (animates != _animates) {
      _animates = animates;
      if (!animates) {
        _ticker?.stop();
        _dragging = false;
      }
    }
    _scope = box?.tree.binder?.scopeFor(box.tree.source, box.id, box.instance);
    _watch();
    final wanted = _wanted;
    if (_target == null || !_animates) {
      _target = wanted;
      _settle();
    } else if (wanted != _target && !_dragging) {
      turnTo(wanted);
    } else {
      _show();
    }
    _publishSoon();
  }

  /// The variable's value when it has one, else `flipped`.
  bool get _wanted => flipWantedIn(_flip, _scope);

  void _watch() {
    final name = _flip.variable.trim();
    final w = name.isEmpty || _scope == null ? null : watchName(_scope, rootOf(name));
    if (identical(w, _watched)) return;
    _watched?.removeListener(_onVariable);
    _watched = w;
    if (attached) _watched?.addListener(_onVariable);
  }

  bool _writing = false;

  void _onVariable() {
    if (_dragging || _writing) return;
    final wanted = _wanted;
    if (wanted != _target) turnTo(wanted);
  }

  void _settle() {
    _progress = (_target ?? false) ? 1 : 0;
    _turning = false;
    _spring = null;
    _ticker?.stop();
    _show();
  }

  /// Turns to the back ([back]) or the front over the motion's duration.
  void turnTo(bool back) {
    _target = back;
    if (!_animates || !attached) {
      _settle();
      return _publish();
    }
    _start = _progress;
    _spring = null;
    _turning = true;
    _since = null;
    _startTicker();
  }

  /// Turns the card over as a tap does: writes the variable when the card
  /// has one (which turns it), otherwise turns it.
  void toggle() => _set(!(_target ?? false));

  void _set(bool back) {
    if (_write(back) && _target == back) return;
    turnTo(back);
  }

  /// Writes [back] to the card's variable; false when it has none (or a
  /// computed one).
  bool _write(bool back) {
    final name = _flip.variable.trim();
    final scope = _scope;
    if (name.isEmpty || scope == null) return false;
    final found = variableOf(scope, name);
    if (found == null || found.$2.isComputed) return false;
    setVariableIn(scope, name, back);
    return true;
  }

  void _startTicker() {
    _ticker ??= Ticker(_tick, debugLabel: 'flip');
    _ticker!.stop();
    if (attached) _ticker!.start();
  }

  void _tick(Duration elapsed) {
    final since = _since ??= elapsed;
    final spring = _spring;
    if (spring != null) {
      final t = (elapsed - since).inMicroseconds / 1e6;
      _progress = spring.x(t);
      if (spring.isDone(t)) {
        _progress = (_target ?? false) ? 1 : 0;
        _spring = null;
        _ticker?.stop();
      }
    } else if (_turning) {
      final ms = (elapsed - since).inMicroseconds / 1000;
      final d = api.FlipCard.durationOf(_motion);
      final curve = _motion?.curve ?? api.AnimationCurve.easeInOutCubic;
      final to = (_target ?? false) ? 1.0 : 0.0;
      if (ms >= d) {
        _progress = to;
        _turning = false;
        _ticker?.stop();
      } else {
        _progress = _start + (to - _start) * curve.transform(ms / d);
      }
    } else {
      _ticker?.stop();
    }
    _show();
    _publish();
  }

  void _show() {
    final t = _progress;
    final keyframes = _motion?.keyframes ?? const <api.MotionKeyframe>[];
    final scale = api.Motion.keyframed(keyframes, 'scale', 1, 1, t.clamp(0.0, 1.0)) ?? 1;
    transform = motionMatrix(
      api.Motion(
        rotateY: _flip.axis == api.FlipAxis.y ? t * 180 : 0,
        rotateX: _flip.axis == api.FlipAxis.x ? -t * 180 : 0,
        perspective: _motion?.perspective ?? 1,
        scale: scale,
      ),
    );
    origin = Alignment.center;
  }

  Map<String, Object?>? _published;
  bool _publishScheduled = false;

  void _publishSoon() {
    if (_publishScheduled) return;
    _publishScheduled = true;
    scheduleMicrotask(() {
      _publishScheduled = false;
      _publish();
    });
  }

  void _publish() {
    final box = _box;
    if (box == null) return;
    final values = {'flipped': _target ?? false, 'progress': _progress};
    if (mapEquals(values, _published)) return;
    _published = values;
    box.tree.binder?.nodeScope(box.tree.source, box.id, instance: box.instance)?.update('flip', values);
  }

  // --- the pointer ------------------------------------------------------------------------

  double get _extent => math.max(1, !hasSize ? 300 : (_flip.axis == api.FlipAxis.y ? size.width : size.height));

  void _dragStarted(DragStartDetails d) {
    _ticker?.stop();
    _turning = false;
    _spring = null;
    _dragging = true;
    _dragStart = _progress;
  }

  void _dragUpdated(DragUpdateDetails d) {
    // Dragging toward the start of the axis (left, or up) turns it over.
    final delta = _flip.axis == api.FlipAxis.y ? d.delta.dx : d.delta.dy;
    _progress = (_progress - delta / _extent).clamp(0.0, 1.0);
    _show();
    _publish();
  }

  void _dragEnded(DragEndDetails d) {
    _dragging = false;
    final pixels = _flip.axis == api.FlipAxis.y ? d.velocity.pixelsPerSecond.dx : d.velocity.pixelsPerSecond.dy;
    final velocity = -pixels / _extent;
    final moved = (_progress - _dragStart).abs();
    // Toward the other face: past halfway, or flung its way.
    final fromFront = _dragStart < 0.5;
    final towards = fromFront ? -pixels : pixels;
    final commits = towards.abs() >= 500 ? towards > 0 : moved >= 0.5;
    final back = commits ? fromFront : !fromFront;
    final s = _flip.spring;
    _spring = SpringSimulation(
      SpringDescription(
        mass: s.mass <= 0 ? 1 : s.mass,
        stiffness: s.stiffness <= 0 ? 1 : s.stiffness,
        damping: s.damping < 0 ? 0 : s.damping,
      ),
      _progress,
      back ? 1 : 0,
      velocity,
      tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
    );
    _since = null;
    _turning = false;
    if (back != _target) {
      _target = back;
      _writing = true;
      try {
        _write(back);
      } finally {
        _writing = false;
      }
    }
    _startTicker();
  }

  bool get _takesPointer => _animates && (_flip.tapToFlip || _flip.dragToFlip);

  @override
  bool hitTestSelf(Offset position) => _takesPointer;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hit = super.hitTest(result, position: position);
    // The card takes the pointer anywhere on it, whichever face shows.
    if (hitTestSelf(position) && size.contains(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return hit;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent || !_takesPointer) return;
    if (_flip.tapToFlip) (_tap ??= TapGestureRecognizer(debugOwner: this)..onTap = toggle).addPointer(event);
    if (_flip.dragToFlip) {
      (_drag ??= (_flip.axis == api.FlipAxis.y
                  ? HorizontalDragGestureRecognizer(debugOwner: this)
                  : VerticalDragGestureRecognizer(debugOwner: this))
            ..onStart = _dragStarted
            ..onUpdate = _dragUpdated
            ..onEnd = _dragEnded
            ..onCancel = () => _dragging = false)
          .addPointer(event);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _watched?.addListener(_onVariable);
    if (_turning || _spring != null) _startTicker();
  }

  @override
  void detach() {
    _watched?.removeListener(_onVariable);
    _ticker?.stop();
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _tap?.dispose();
    _drag?.dispose();
    super.dispose();
  }
}
