// Triggers in the render tree: a node's reactions wired into its box while
// the tree is interactive. Pointer triggers (taps, double taps, long
// presses, holds, hover, swipes, drags, wheel) are gesture recognizers in a
// render object of the node's chain, hit tested like any box (the deepest
// node with a tap wins, as nested GestureDetectors do); screen triggers
// (load, timers, value changes, keys) live with the box; inputs report
// theirs (changed, submitted...) from their islands; viewport triggers
// watch what of the box is visible after each frame.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api_v2/codelessly_api.dart' show Json, Node, TriggerType;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../render/node_tree.dart';
import '../../widgets/material.dart' show selfTappedTypes;
import '../contracts.dart';
import '../expressions/formula.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'context.dart';
import 'runner.dart';

/// Wires the reactions of a [NodeTree]'s nodes ([NodeTree.interactions]):
/// each runs with [runner] in [context] (a list item's node in its item's
/// scope), and stops when its box leaves the tree.
class TreeReactions implements NodeInteractions {
  TreeReactions({required this.runner, required this.context});

  final ActionRunner runner;

  /// The screen's context.
  ActionContext context;

  final Map<NodeBox, _BoxReactions> _boxes = {};

  /// The input value paths a `changed` writes back to (the variable the
  /// value is bound to), by type.
  static const Map<String, String> valuePaths = {
    'textField': 'props.initialValue',
    'radio': 'props.groupValue',
    'segmentedButton': 'props.selected',
    'checkbox': 'props.value',
    'switch': 'props.value',
    'slider': 'props.value',
    'dropdown': 'props.value',
    'datePicker': 'props.value',
    'timePicker': 'props.value',
    'dateTimeInput': 'props.value',
    'signature': 'props.value',
  };

  @override
  void addLayers(NodeBox box, Node n, List<RenderBox> chain) {
    final types = {for (final r in n.actions) r.trigger.type};
    if (types.isEmpty) {
      _boxes.remove(box)?.dispose();
      return;
    }
    final state = _boxes[box] ??= _BoxReactions(this, box);
    state.update(n, types);
    final pointer = types.intersection(TriggerType.pointer);
    if (selfTappedTypes.contains(n.type)) pointer.remove(TriggerType.click);
    // A node with a drag drags itself: it fires its swipes when it flies
    // off, and its drag and drag end (gestures/drag_motion.dart).
    if (n.behaviours.drag != null) pointer.removeAll({...TriggerType.swipes, TriggerType.drag, TriggerType.dragEnd});
    // A transform gesture that zooms on a double tap fires its doubleTap
    // (render/transform_gesture.dart).
    if (n.behaviours.effectiveTransformGesture case final g? when g.zoom && g.doubleTapScale > 0) {
      pointer.remove(TriggerType.doubleTap);
    }
    final viewport = types.contains(TriggerType.enterViewport) || types.contains(TriggerType.exitViewport);
    if (pointer.isEmpty && !viewport) return;
    chain.add(box.obtain<RenderReactions>('reactions', RenderReactions.new)
      ..triggers = pointer
      ..holdMs = n.actions.firstWhere((r) => r.trigger.type == TriggerType.hold, orElse: () => n.actions.first).trigger.holdMs
      ..visibleFraction = viewport ? n.actions.firstWhere((r) => _isViewport(r.trigger.type)).trigger.visibleFraction : null
      ..onTrigger = (type, event) => fire(box, type.name, event: event));
  }

  static bool _isViewport(TriggerType t) => t == TriggerType.enterViewport || t == TriggerType.exitViewport;

  @override
  Future<void> fire(NodeBox box, String trigger, {Json event = const {}}) async {
    final node = box.node;
    if (node == null) return;
    final ctx = contextFor(box);
    if (trigger == 'changed' && event.containsKey('value')) _writeBack(node, event['value'], ctx);
    final state = _boxes[box];
    final r = runner;
    if (r is CodelesslyActions) {
      await r.run(node, trigger, ctx, event: event, cancellation: state?.cancellation, instance: box.instance);
    } else {
      await r.trigger(node, trigger, ctx, event: event).catchError((Object e, StackTrace s) {
        if (ctx is ActionHost) ctx.reportError(e, s, action: trigger);
      });
    }
  }

  /// [fire], finishing when the reactions have run (a list's pull to
  /// refresh shows until then).
  Future<void> fireAndWait(NodeBox box, String trigger, {Json event = const {}}) async {
    final node = box.node;
    if (node == null) return;
    final ctx = contextFor(box);
    final state = _boxes[box];
    final r = runner;
    try {
      if (r is CodelesslyActions) {
        await r.run(node, trigger, ctx, event: event, cancellation: state?.cancellation, instance: box.instance);
      } else {
        await r.trigger(node, trigger, ctx, event: event);
      }
    } catch (e, s) {
      if (ctx is ActionHost) ctx.reportError(e, s, action: trigger);
    }
  }

  /// An input's new value goes to the variable its value is bound to.
  void _writeBack(Node node, Object? value, ActionContext ctx) {
    final path = valuePaths[node.type];
    final bound = path == null ? null : node.bind[path];
    final variable = bound == null ? null : exactPath(bound);
    if (variable == null) return;
    if (setVariableIn(ctx.scope, variable, value)) return;
    if (ctx is! RuntimeActionContext) ctx.setVariable(variable, value);
  }

  /// [box]'s context: [context], in the scope of the list item it's in.
  ActionContext contextFor(NodeBox box) {
    final c = context;
    final binder = box.tree.binder;
    if (c is! ActionHost || binder == null) return c;
    final scope = binder.scopeFor(box.tree.source, box.id, box.instance);
    return scope == null || identical(scope, c.scope) ? c : c.withScope(scope);
  }

  @override
  void released(NodeBox box) => _boxes.remove(box)?.dispose();

  /// A box out of the render tree (its view went) stops its chains and
  /// timers; they start again when it's back.
  @override
  void attachChanged(NodeBox box) {
    final state = _boxes[box];
    if (state == null) return;
    if (box.attached) {
      state.resume();
    } else {
      state.pause();
    }
  }

  /// Stops everything the boxes run.
  void dispose() {
    for (final s in _boxes.values) {
      s.dispose();
    }
    _boxes.clear();
  }
}

/// The screen triggers of one box: load (once), timers, value changes and
/// keys; and the cancellation of the chains it started.
class _BoxReactions {
  _BoxReactions(this.owner, this.box);

  final TreeReactions owner;
  final NodeBox box;
  ActionCancellation cancellation = ActionCancellation();

  /// Out of the render tree: cancels the running chains (later ones run
  /// on) and stops the timer.
  void pause() {
    cancellation.cancel();
    cancellation = ActionCancellation();
    _timer?.cancel();
    _timer = null;
    _intervalMs = null;
  }

  /// Back in the render tree.
  void resume() {
    final n = _node;
    if (n != null && _timer == null) _updateTimer(n, {for (final r in n.actions) r.trigger.type});
  }

  bool _loaded = false;
  Timer? _timer;
  int? _intervalMs;
  final Map<String, Listenable> _watched = {};
  final Map<String, VoidCallback> _unwatch = {};
  bool _keys = false;
  Node? _node;

  void update(Node n, Set<TriggerType> types) {
    _node = n;
    if (types.contains(TriggerType.load) && !_loaded) {
      _loaded = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) owner.fire(box, 'load');
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    }
    _updateTimer(n, types);
    _updateWatches(n, types);
    final keys = types.contains(TriggerType.keyDown) || types.contains(TriggerType.keyUp);
    if (keys != _keys) {
      _keys = keys;
      keys ? HardwareKeyboard.instance.addHandler(_key) : HardwareKeyboard.instance.removeHandler(_key);
    }
  }

  void _updateTimer(Node n, Set<TriggerType> types) {
    int? ms;
    for (final r in n.actions) {
      if (r.trigger.type == TriggerType.timer) ms = math.min(ms ?? 1 << 30, r.trigger.effectiveIntervalMs);
      if (r.trigger.type == TriggerType.clock) {
        final every = num.tryParse(r.trigger.every.trim());
        if (every != null && every > 0) ms = math.min(ms ?? 1 << 30, every.round());
      }
    }
    if (ms == _intervalMs) return;
    _timer?.cancel();
    _intervalMs = ms;
    if (ms == null) return;
    var tick = 0;
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (_disposed || !box.attached) return;
      if (types.contains(TriggerType.timer)) owner.fire(box, 'timer');
      if (types.contains(TriggerType.clock)) owner.fire(box, 'clock', event: {'result': {'tick': tick++, 'waitMs': 0}});
    });
  }

  void _updateWatches(Node n, Set<TriggerType> types) {
    final names = {
      for (final r in n.actions)
        if (r.trigger.type == TriggerType.valueChanged && r.trigger.variable.trim().isNotEmpty) r.trigger.variable.trim(),
    };
    for (final k in _watched.keys.toList()) {
      if (!names.contains(k)) _unwatch.remove(k)?.call();
    }
    _watched.removeWhere((k, _) => !names.contains(k));
    for (final name in names) {
      if (_watched.containsKey(name)) continue;
      final w = watchName(owner.contextFor(box).scope, rootOf(name));
      if (w == null) continue;
      void changed() {
        if (!_disposed && box.attached) owner.fire(box, 'valueChanged', event: {'result': readPath(owner.contextFor(box).scope, name)});
      }

      w.addListener(changed);
      _watched[name] = w;
      _unwatch[name] = () => w.removeListener(changed);
    }
  }

  bool _key(KeyEvent e) {
    final n = _node;
    if (n == null || _disposed || !box.attached || e is KeyRepeatEvent) return false;
    final down = e is KeyDownEvent;
    final type = down ? TriggerType.keyDown : TriggerType.keyUp;
    final keys = HardwareKeyboard.instance;
    final meta = keys.isMetaPressed || keys.isControlPressed;
    final label = e.logicalKey.keyLabel;
    var handled = false;
    for (final r in n.actions) {
      if (r.trigger.type != type) continue;
      final combo = r.trigger.keyCombo;
      if (combo != null && !combo.matches(label, meta: meta, shift: keys.isShiftPressed, alt: keys.isAltPressed)) continue;
      if (r.trigger.when.trim().isNotEmpty) {
        final ok = FormulaEvaluator.exactExpression(r.trigger.when) != null
            ? owner.contextFor(box).expressions.evaluate(r.trigger.when, owner.contextFor(box).scope)
            : readPath(owner.contextFor(box).scope, r.trigger.when);
        if (ok != true) continue;
      }
      handled = true;
    }
    if (!handled) return false;
    owner.fire(box, type.name, event: {
      'result': {'key': label, 'shift': keys.isShiftPressed, 'alt': keys.isAltPressed, 'meta': meta},
    });
    return true;
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    cancellation.cancel();
    _timer?.cancel();
    for (final u in _unwatch.values) {
      u();
    }
    _unwatch.clear();
    _watched.clear();
    if (_keys) HardwareKeyboard.instance.removeHandler(_key);
    _keys = false;
  }
}

/// A node's pointer triggers: recognizers fed from its hit tests, the
/// mouse cursor and hover over it, and what of it is visible.
class RenderReactions extends RenderProxyBoxWithHitTestBehavior implements MouseTrackerAnnotation {
  RenderReactions() : super(behavior: HitTestBehavior.opaque);

  Set<TriggerType> _triggers = const {};
  Set<TriggerType> get triggers => _triggers;
  set triggers(Set<TriggerType> value) {
    if (setEquals(value, _triggers)) return;
    _triggers = value;
    _disposeRecognizers();
    behavior = value.isEmpty ? HitTestBehavior.deferToChild : HitTestBehavior.opaque;
    markNeedsPaint();
  }

  int holdMs = 1200;

  /// The visible share (0–1) that counts as in view; null: not watched.
  double? get visibleFraction => _visibleFraction;
  double? _visibleFraction;
  set visibleFraction(double? v) {
    if (v == _visibleFraction) return;
    _visibleFraction = v;
    v == null ? _ViewportWatcher.remove(this) : (attached ? _ViewportWatcher.add(this) : null);
  }

  void Function(TriggerType type, Json event)? onTrigger;

  bool _has(TriggerType t) => _triggers.contains(t);
  void _fire(TriggerType t, [Json event = const {}]) => onTrigger?.call(t, event);

  TapGestureRecognizer? _tap;
  DoubleTapGestureRecognizer? _doubleTap;
  LongPressGestureRecognizer? _longPress;
  PanGestureRecognizer? _pan;
  Timer? _hold;
  Offset? _holdStart;

  Json _where(Offset local, Offset global) {
    final keys = HardwareKeyboard.instance;
    return {
      'result': {
        'x': local.dx,
        'y': local.dy,
        'globalX': global.dx,
        'globalY': global.dy,
        'meta': keys.isMetaPressed || keys.isControlPressed,
        'shift': keys.isShiftPressed,
        'alt': keys.isAltPressed,
      },
    };
  }

  void _ensureRecognizers() {
    if (_tap == null && (_has(TriggerType.click) || _has(TriggerType.secondaryClick))) {
      Json? at;
      _tap = TapGestureRecognizer(debugOwner: this)
        ..onTapDown = ((d) => at = _where(d.localPosition, d.globalPosition))
        ..onTapUp = ((_) {})
        ..onTap = (_has(TriggerType.click) ? () => _fire(TriggerType.click, at ?? const {}) : null)
        ..onSecondaryTapUp = _has(TriggerType.secondaryClick)
            ? (d) => _fire(TriggerType.secondaryClick, {
                  'result': {'x': d.globalPosition.dx, 'y': d.globalPosition.dy},
                })
            : null;
    }
    if (_doubleTap == null && _has(TriggerType.doubleTap)) {
      _doubleTap = DoubleTapGestureRecognizer(debugOwner: this)..onDoubleTap = () => _fire(TriggerType.doubleTap);
    }
    if (_longPress == null && _has(TriggerType.longPress)) {
      _longPress = LongPressGestureRecognizer(debugOwner: this)..onLongPress = () => _fire(TriggerType.longPress);
    }
    final swipes = TriggerType.swipes.any(_has) || _has(TriggerType.drag) || _has(TriggerType.dragEnd);
    if (_pan == null && swipes) {
      _pan = PanGestureRecognizer(debugOwner: this)
        ..onUpdate = (_has(TriggerType.drag)
            ? (d) => _fire(TriggerType.drag, {
                  'result': {'dx': d.delta.dx, 'dy': d.delta.dy, 'x': d.localPosition.dx, 'y': d.localPosition.dy},
                })
            : null)
        ..onEnd = (d) {
          final v = d.velocity.pixelsPerSecond;
          if (_has(TriggerType.dragEnd)) _fire(TriggerType.dragEnd, {'result': {'vx': v.dx, 'vy': v.dy}});
          if (v.distance < kMinFlingVelocity) return;
          final TriggerType swipe = v.dx.abs() > v.dy.abs()
              ? (v.dx < 0 ? TriggerType.swipeLeft : TriggerType.swipeRight)
              : (v.dy < 0 ? TriggerType.swipeUp : TriggerType.swipeDown);
          if (_has(swipe)) _fire(swipe);
        };
    }
  }

  void _disposeRecognizers() {
    _tap?.dispose();
    _doubleTap?.dispose();
    _longPress?.dispose();
    _pan?.dispose();
    _tap = _doubleTap = null;
    _longPress = null;
    _pan = null;
    _hold?.cancel();
    _hold = null;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      _ensureRecognizers();
      _tap?.addPointer(event);
      _doubleTap?.addPointer(event);
      _longPress?.addPointer(event);
      _pan?.addPointer(event);
      if (_has(TriggerType.pointerDown)) _fire(TriggerType.pointerDown);
      if (_has(TriggerType.hold)) {
        _holdStart = event.position;
        _hold?.cancel();
        _hold = Timer(Duration(milliseconds: holdMs), () {
          _hold = null;
          _fire(TriggerType.hold);
        });
      }
    } else if (event is PointerMoveEvent) {
      final start = _holdStart;
      if (_hold != null && start != null && (event.position - start).distance > kTouchSlop) {
        _hold?.cancel();
        _hold = null;
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _hold?.cancel();
      _hold = null;
      if (_has(TriggerType.pointerUp)) _fire(TriggerType.pointerUp);
    } else if (event is PointerScrollEvent && _has(TriggerType.wheel)) {
      _fire(TriggerType.wheel, {
        'result': {'deltaX': event.scrollDelta.dx, 'deltaY': event.scrollDelta.dy, 'x': event.localPosition.dx, 'y': event.localPosition.dy},
      });
    } else if (event is PointerScaleEvent && _has(TriggerType.pinch)) {
      _fire(TriggerType.pinch, {'result': {'scale': event.scale}});
    } else if (event is PointerHoverEvent && _has(TriggerType.hover) && _hovering) {
      // Hover fires on entry (SDK 8.x); moves over the node don't repeat it.
    }
  }

  // --- mouse ---------------------------------------------------------------------------

  bool _hovering = false;

  bool get _taps => _has(TriggerType.click) || _has(TriggerType.doubleTap) || _has(TriggerType.longPress);

  @override
  MouseCursor get cursor => _taps ? SystemMouseCursors.click : MouseCursor.defer;

  @override
  PointerEnterEventListener? get onEnter => (_) {
        _hovering = true;
        if (_has(TriggerType.cursorEnter)) _fire(TriggerType.cursorEnter);
        if (_has(TriggerType.hover)) _fire(TriggerType.hover);
      };

  @override
  PointerExitEventListener? get onExit => (_) {
        _hovering = false;
        if (_has(TriggerType.cursorExit)) _fire(TriggerType.cursorExit);
      };

  @override
  bool get validForMouseTracker => attached && _triggers.isNotEmpty;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_triggers.isEmpty) return hitTestChildren(result, position: position);
    return super.hitTest(result, position: position);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_visibleFraction != null) _ViewportWatcher.add(this);
  }

  @override
  void detach() {
    _ViewportWatcher.remove(this);
    _disposeRecognizers();
    if (_hovering && _has(TriggerType.cursorExit)) _fire(TriggerType.cursorExit);
    _hovering = false;
    super.detach();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  // --- viewport --------------------------------------------------------------------------

  bool _inView = false;

  void _checkViewport() {
    final fraction = _visibleFraction;
    if (fraction == null || !attached || !hasSize) return;
    final visible = visibleShare(this);
    final inView = fraction <= 0 ? visible > 0 : visible >= fraction - 1e-6;
    if (inView == _inView) return;
    _inView = inView;
    final t = inView ? TriggerType.enterViewport : TriggerType.exitViewport;
    if (_triggersAll.contains(t)) _fire(t);
  }

  /// The viewport triggers aren't pointer triggers: [triggers] holds pointer
  /// ones only, so both fire whenever watched.
  Set<TriggerType> get _triggersAll => const {TriggerType.enterViewport, TriggerType.exitViewport};
}

/// The share (0–1) of [box] visible on screen, inside every clip around it.
/// A box larger than the view counts as wholly visible when it covers it.
double visibleShare(RenderBox box) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return 0;
  var rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
  final full = rect;
  RenderObject child = box;
  for (var p = box.parent; p != null; p = p.parent) {
    final clip = p.describeApproximatePaintClip(child);
    if (clip != null) {
      final global = MatrixUtils.transformRect(p.getTransformTo(null), clip);
      rect = rect.intersect(global);
      if (rect.isEmpty) return 0;
    }
    child = p;
  }
  final root = child;
  if (root is RenderView) {
    final screen = Offset.zero & root.size;
    rect = rect.intersect(screen);
    if (rect.width <= 0 || rect.height <= 0) return 0;
    final view = full.intersect(screen);
    if (view.width >= screen.width - 0.5 && view.height >= screen.height - 0.5) return 1;
  }
  if (rect.width <= 0 || rect.height <= 0) return 0;
  return (rect.width * rect.height) / (full.width * full.height);
}

/// Checks the watched boxes after each frame.
abstract final class _ViewportWatcher {
  static final Set<RenderReactions> _boxes = {};
  static bool _scheduled = false;

  static void add(RenderReactions box) {
    _boxes.add(box);
    _schedule();
  }

  static void remove(RenderReactions box) => _boxes.remove(box);

  static void _schedule() {
    if (_scheduled || _boxes.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      for (final b in _boxes.toList()) {
        b._checkViewport();
      }
      _schedule();
    }, debugLabel: 'ViewportWatcher');
  }
}
