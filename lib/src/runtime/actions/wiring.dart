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
import 'package:collection/collection.dart' show DeepCollectionEquality;

import 'package:codelessly_api/core.dart' show InputDecoration, InputIcon, Json, Node, PropDef, SwitchProps, TriggerType, Trigger;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show EditableText, FocusManager;

import '../../render/custom_paint.dart' show customPaintEvent;
import '../../render/node_tree.dart';
import '../../render/visible_share.dart';
import '../../widgets/material.dart' show selfTappedTypes;
import '../contracts.dart';
import '../expressions/bindings.dart' show RenderTreeBinder;
import '../expressions/formula.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'context.dart';
import 'route_transition.dart' show RevealAnchor;
import 'runner.dart';
import 'key_matching.dart';

export '../../render/visible_share.dart' show visibleShare;

/// Wires the reactions of a [RenderTree]'s nodes ([RenderTree.interactions]):
/// each runs with [runner] in [context] (a list item's node in its item's
/// scope), and stops when its box leaves the tree.
class TreeReactions implements NodeInteractions {
  TreeReactions({required this.runner, required this.context}) {
    // A modal anchored to the pointer needs the press that fired it.
    RevealAnchor.track();
  }

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
    'choiceChip': 'props.selected',
    'filterChip': 'props.selected',
    'checkbox': 'props.value',
    'switch': 'props.value',
    'slider': 'props.value',
    'dropdown': 'props.value',
    'datePicker': 'props.value',
    'timePicker': 'props.value',
    'dateTimeInput': 'props.value',
    'signature': 'props.value',
    // Bars: the picked index (render/controls/{tab_bar,navigation_bar}.dart).
    'tabBar': 'props.initialIndex',
    'tabs': 'props.initialIndex',
    'navigationBar': 'props.selectedIndex',
    'bottomNavigationBar': 'props.selectedIndex',
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
    // Beside a `drag` reaction (and with no drag and drop on the node),
    // `dragStart` is the start of that one-finger drag: where a stroke
    // begins, which a pinch (a second finger) doesn't start.
    if (types.contains(TriggerType.dragStart) && types.contains(TriggerType.drag) && n.behaviors.draggable == null) {
      pointer.add(TriggerType.dragStart);
    }
    if (selfTappedTypes.contains(n.type)) pointer.remove(TriggerType.click);
    // A node with a drag drags itself: it fires its swipes when it flies
    // off, and its drag and drag end (gestures/drag_motion.dart,
    // render/drag_track.dart); a reorder handle's list takes its drag.
    final be = n.behaviors;
    if (be.track != null || be.dismissible != null || be.pan != null || be.reorderHandle) pointer.removeAll({...TriggerType.swipes, TriggerType.dragStart, TriggerType.drag, TriggerType.dragEnd});
    // A transform gesture that zooms on a double tap fires its doubleTap
    // (render/transform_gesture.dart).
    if (n.behaviors.transformGesture case final g? when g.zoom && g.doubleTapScale > 0) {
      pointer.remove(TriggerType.doubleTap);
    }
    final viewport = types.contains(TriggerType.enterViewport) || types.contains(TriggerType.exitViewport);
    if (pointer.isEmpty && !viewport) return;
    final g = n.behaviors.transformGesture;
    chain.add(box.obtain<RenderReactions>('reactions', RenderReactions.new)
      ..triggers = pointer
      // A plain drag is one finger: on a node that also pinches, a second
      // finger hands the gesture to the pinch.
      ..yieldsToPinch = types.contains(TriggerType.pinch) || (g != null && g.enabled && (g.zoom || g.rotate))
      ..holdMs = n.actions.firstWhere((r) => r.trigger.type == TriggerType.hold, orElse: () => n.actions.first).trigger.holdMs
      ..visibleFraction = viewport ? n.actions.firstWhere((r) => _isViewport(r.trigger.type)).trigger.visibleFraction : null
      ..visibleMs = viewport
          ? n.actions.firstWhere((r) => r.trigger.type == TriggerType.enterViewport, orElse: () => n.actions.first).trigger.visibleMs
          : 0
      ..onTrigger = (type, event) => fire(box, type.name, event: event));
  }

  static bool _isViewport(TriggerType t) => t == TriggerType.enterViewport || t == TriggerType.exitViewport;

  @override
  Future<void> fire(NodeBox box, String trigger, {Json event = const {}}) async {
    var node = box.node;
    if (node == null) return;
    // A tap on an input's prefix or suffix icon runs that icon's own
    // reactions (`InputIcon.actions`), as a click of the node.
    if (trigger == iconTapPrefix || trigger == iconTapSuffix) {
      final icon = _inputIcon(node, prefix: trigger == iconTapPrefix);
      if (icon == null || icon.actions.isEmpty) return;
      node = node.copyWith(actions: icon.actions);
      trigger = 'click';
    }
    // What a custom paint has under the pointer (render/custom_paint.dart).
    if (node.behaviors.customPaint != null) event = customPaintEvent(box, event);
    // What a modal anchored to its trigger (or the pointer) sits by.
    RevealAnchor.track();
    // The box as the screen shows it: its size scales with it too (a running
    // app inside a scaled preview), not only its origin.
    RevealAnchor.lastTrigger =
        box.attached && box.hasSize ? MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size) : null;
    final ctx = contextFor(box);
    if (trigger == 'changed' && event.containsKey('value')) _writeBack(node, event['value'], ctx);
    final state = _boxes[box];
    final r = runner;
    if (r is CoreActions) {
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
      if (r is CoreActions) {
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
    // A controlled input shows only its bound value: its reactions set it.
    if (node.type == 'switch' && node.prop(SwitchProps.controlled)) return;
    final bound = path == null ? null : node.bind[path];
    final variable = bound == null ? null : exactPath(bound);
    if (variable == null) return;
    if (setVariableIn(ctx.scope, variable, value)) return;
    if (ctx is! CoreActionContext) ctx.setVariable(variable, value);
  }

  /// [box]'s context: [context], in the scope of the list item it's in.
  ActionContext contextFor(NodeBox box) {
    final c = context;
    final binder = box.tree.binder;
    if (c is! ActionHost || binder == null) return c;
    final scope = binder.scopeFor(box.source, box.id, box.instance);
    return scope == null || identical(scope, c.scope) ? c : c.withScope(scope);
  }

  @override
  void released(NodeBox box) => _boxes.remove(box)?.dispose();

  /// A removed view stops its chains and timers. Conditional hiding only
  /// pauses screen triggers: the reaction that hid the node may finish.
  ///
  /// A box that leaves and comes back in the same frame (a layer added or
  /// taken away above it re-parents it, as a hover style adding a motion
  /// does) keeps its chains: whether it left is decided after the frame.
  @override
  void attachChanged(NodeBox box) {
    final state = _boxes[box];
    if (state == null) return;
    if (box.attached) {
      state.leaving = false;
      state.resume();
      return;
    }
    if (box.tree.preservingActions) {
      state.pause(cancelActions: false);
      return;
    }
    state.leaving = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!state.leaving || box.attached) return;
      state.leaving = false;
      state.pause();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
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

  /// Detached, waiting for the end of the frame to see whether it is back.
  bool leaving = false;

  /// Stops screen timers; a retained conditional subtree keeps its active
  /// reactions, whereas a removed view cancels them.
  void pause({bool cancelActions = true}) {
    if (cancelActions) {
      cancellation.cancel();
      cancellation = ActionCancellation();
    }
    _timer?.cancel();
    _timer = null;
    _intervalMs = null;
    _frames?.stop();
  }

  /// Back in the render tree.
  void resume() {
    final n = _node;
    if (n != null && _timer == null) _updateTimer(n, {for (final r in n.actions) r.trigger.type});
    if (n != null) _updateFrames(n, {for (final r in n.actions) r.trigger.type});
  }

  bool _loaded = false;
  Timer? _timer;
  int? _intervalMs;
  final Map<String, VoidCallback> _timerUnwatch = {};
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
    _updateFrames(n, types);
    _updateWatches(n, types);
    final keys = types.contains(TriggerType.keyDown) || types.contains(TriggerType.keyUp);
    if (keys != _keys) {
      _keys = keys;
      keys ? HardwareKeyboard.instance.addHandler(_key) : HardwareKeyboard.instance.removeHandler(_key);
    }
  }

  /// The one periodic timer of the node's timer triggers, at the shortest
  /// interval among those whose `when` holds (an interval may be an
  /// expression: it's worked out again when a name it reads changes).
  void _updateTimer(Node n, Set<TriggerType> types) {
    final ctx = owner.contextFor(box);
    final reads = <String>{};
    for (final r in n.actions) {
      if (r.trigger.type != TriggerType.timer) continue;
      for (final expression in [r.trigger.intervalMs.source ?? '', r.trigger.when]) {
        if (expression.trim().isEmpty) continue;
        reads.addAll(FormulaEvaluator.referencedPaths(FormulaEvaluator.exactExpression(expression) ?? exactPath(expression) ?? expression).map(rootOf));
      }
    }
    for (final name in _timerUnwatch.keys.toList()) {
      if (!reads.contains(name)) _timerUnwatch.remove(name)!();
    }
    for (final name in reads) {
      if (_timerUnwatch.containsKey(name)) continue;
      final watcher=watchName(ctx.scope,name);
      if (watcher==null) continue;
      void changed(){if(!_disposed && box.attached) _updateTimer(_node ?? n,types);}
      watcher.addListener(changed);
      _timerUnwatch[name]=()=>watcher.removeListener(changed);
    }
    int? ms;
    for (final r in n.actions) {
      if (r.trigger.type != TriggerType.timer) continue;
      final condition = r.trigger.when.trim();
      if (condition.isNotEmpty && !triggerWhenHolds(condition, ctx)) continue;
      final source = r.trigger.intervalMs.source;
      final every = source == null
          ? r.trigger.effectiveIntervalMs
          : Trigger.intervalMsOf(ctx.expressions.evaluate(source, ctx.scope));
      if (every != null) ms = math.min(ms ?? 1 << 30, every);
    }
    if (ms == _intervalMs) return;
    _timer?.cancel();
    _intervalMs = ms;
    if (ms == null) return;
    var tick = 0;
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (_disposed || !box.attached || !box.tree.runtimeVisible || !_onstage) return;
      owner.fire(box, 'timer', event: {'result': {'tick': tick++, 'waitMs': 0}});
    });
  }

  // --- the frame trigger: a Ticker -----------------------------------------------

  Ticker? _frames;
  Duration _lastFrame = Duration.zero;
  int _frameCount = 0;
  bool _frameRunning = false;

  /// Runs the node's frame reactions each frame while it's on stage
  /// (`${result.dt}`, `${result.elapsed}`, `${result.frame}`); a frame that
  /// comes while the chain still runs is skipped, its time added to the
  /// next dt. While no reaction's `when` holds, nothing runs and no time
  /// adds up.
  void _updateFrames(Node n, Set<TriggerType> types) {
    if (!types.contains(TriggerType.frame)) {
      _frames?.dispose();
      _frames = null;
      return;
    }
    if (_frames == null) {
      _frames = Ticker(_frame, debugLabel: 'frame trigger');
      _lastFrame = Duration.zero;
      _frameCount = 0;
    }
    if (box.attached && !_frames!.isActive) _frames!.start();
  }

  void _frame(Duration elapsed) {
    final n = _node;
    if (n == null || _disposed || !box.attached) return;
    if (!box.tree.runtimeVisible || !_onstage) {
      _lastFrame = elapsed;
      return;
    }
    if (_frameRunning) return;
    final ctx = owner.contextFor(box);
    final holds = n.actions.any((r) =>
        r.trigger.type == TriggerType.frame && (r.trigger.when.trim().isEmpty || triggerWhenHolds(r.trigger.when, ctx)));
    if (!holds) {
      _lastFrame = elapsed;
      return;
    }
    final dt = (elapsed - _lastFrame).inMicroseconds / 1000;
    _lastFrame = elapsed;
    _frameRunning = true;
    owner
        .fire(box, 'frame', event: {
          'result': {'dt': dt, 'elapsed': elapsed.inMicroseconds / 1000, 'frame': _frameCount++},
        })
        .whenComplete(() => _frameRunning = false);
  }

  bool get _onstage {
    for(RenderObject? current=box;current!=null;current=current.parent){
      if(current is RenderOffstage && current.offstage)return false;
    }
    return true;
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
      // Named computed watches can also be invalidated by a shared foreign
      // dependency (e.g. any async script result). Fire only when this path's
      // completed value changed; an unrelated completion must not restart a
      // counting animation, and an unresolved result is not a real null.
      (Object?, bool) readValue() {
        final scope = owner.contextFor(box).scope;
        final scripts = readPath(scope, 'script');
        final status = scripts is FormulaReadStatus ? scripts : null;
        final pendingBefore = status?.pendingReads;
        final value = readPath(scope, name);
        return (value, pendingBefore != status?.pendingReads);
      }

      final initial = readValue();
      var lastValue = initial.$1;
      var hasValue = !initial.$2;
      void changed() {
        if (_disposed || !box.attached) return;
        final (value, pending) = readValue();
        if (pending || hasValue && const DeepCollectionEquality().equals(value, lastValue)) return;
        lastValue = value;
        hasValue = true;
        owner.fire(box, 'valueChanged', event: {'result': value, 'changedVariable': name});
      }

      w.addListener(changed);
      _watched[name] = w;
      _unwatch[name] = () => w.removeListener(changed);
    }
  }

  bool _key(KeyEvent e) {
    final n = _node;
    if (n == null || _disposed || !box.attached) return false;
    final repeat = e is KeyRepeatEvent;
    final down = e is KeyDownEvent || repeat;
    final type = down ? TriggerType.keyDown : TriggerType.keyUp;
    // Keys belong to the field being typed in, except Escape, which leaves
    // it (`${result.typing}` tells the actions).
    final typing = isTyping();
    if (typing && e.logicalKey != LogicalKeyboardKey.escape) return false;
    final keys = HardwareKeyboard.instance;
    final meta = keys.isMetaPressed || keys.isControlPressed;
    final label = e.logicalKey.keyLabel;
    final character = e.character;
    // A key that types text goes to a focused text field, not a shortcut.
    if (!meta && !keys.isAltPressed && typesText(character) && _textFieldFocused()) return false;
    var handled = false;
    for (final r in n.actions) {
      if (r.trigger.type != type) continue;
      // A held key's repeats reach only keyDown reactions that ask for them.
      if (repeat && !r.trigger.repeat) continue;
      final combo = r.trigger.keyCombo;
      if (!runtimeKeyEventMatches(combo, label,
          character: character, meta: meta, shift: keys.isShiftPressed, alt: keys.isAltPressed)) {
        continue;
      }
      if (r.trigger.when.trim().isNotEmpty && !triggerWhenHolds(r.trigger.when, owner.contextFor(box))) continue;
      handled = true;
    }
    if (!handled) return false;
    owner.fire(box, type.name, event: {
      'result': {
        'key': label,
        'character': ?character,
        'shift': keys.isShiftPressed,
        'alt': keys.isAltPressed,
        'meta': meta,
        'repeat': repeat,
        'typing': typing,
      },
    });
    return true;
  }

  static bool _textFieldFocused() =>
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    for(final remove in _timerUnwatch.values){remove();}
    _timerUnwatch.clear();
    cancellation.cancel();
    _timer?.cancel();
    _frames?.dispose();
    _frames = null;
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
    markNeedsSemanticsUpdate();
  }

  int holdMs = 1200;

  /// A second finger cancels a plain drag (and its swipes), so a pinch on
  /// this node (a transform gesture's zoom, pinch reactions) wins.
  bool yieldsToPinch = false;
  final Set<int> _down = {};

  /// The visible share (0–1) that counts as in view; null: not watched.
  double? get visibleFraction => _visibleFraction;
  double? _visibleFraction;
  set visibleFraction(double? v) {
    if (v == _visibleFraction) return;
    _visibleFraction = v;
    v == null ? _ViewportWatcher.remove(this) : (attached ? _ViewportWatcher.add(this) : null);
  }

  /// How long (ms) it stays in view before enterViewport fires; leaving
  /// sooner doesn't fire it.
  int visibleMs = 0;
  Timer? _dwell;

  void Function(TriggerType type, Json event)? onTrigger;

  bool _has(TriggerType t) => _triggers.contains(t);
  void _fire(TriggerType t, [Json event = const {}]) => onTrigger?.call(t, event);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_has(TriggerType.click) || _has(TriggerType.longPress)) {
      config.isSemanticBoundary = true;
      config.isButton = true;
      if (_has(TriggerType.click)) config.onTap = () => _fire(TriggerType.click);
      if (_has(TriggerType.longPress)) config.onLongPress = () => _fire(TriggerType.longPress);
    }
  }

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
      // ${result.x} / ${result.y}: where the second tap went down (local).
      Json? at;
      _doubleTap = DoubleTapGestureRecognizer(debugOwner: this)
        ..onDoubleTapDown = ((d) => at = _where(d.localPosition, d.globalPosition))
        ..onDoubleTap = () => _fire(TriggerType.doubleTap, at ?? const {});
    }
    if (_longPress == null && _has(TriggerType.longPress)) {
      _longPress = LongPressGestureRecognizer(debugOwner: this)..onLongPress = () => _fire(TriggerType.longPress);
    }
    final swipes = TriggerType.swipes.any(_has) || _has(TriggerType.dragStart) || _has(TriggerType.drag) || _has(TriggerType.dragEnd);
    if (_pan == null && swipes) {
      _pan = _OneFingerPanGestureRecognizer(debugOwner: this)
        // Where the finger went down, not where the slop was crossed: a
        // stroke paints from its first cell.
        ..dragStartBehavior = DragStartBehavior.down
        ..onStart = ((d) {
          _dragStart = d.localPosition;
          // A stroke starts here (one finger: a pinch makes it stand down).
          if (_has(TriggerType.dragStart)) {
            final p = d.localPosition;
            final drag = {'dx': 0.0, 'dy': 0.0, 'x': p.dx, 'y': p.dy, 'startX': p.dx, 'startY': p.dy, 'pointerCount': 1};
            _fire(TriggerType.dragStart, {'result': drag, 'drag': drag});
          }
        })
        ..onUpdate = (_has(TriggerType.drag)
            ? (d) {
                // `${drag.x}` / `${drag.y}`: where the pointer is in the node
                // (painting on a board), `${drag.startX}` / `startY` where the
                // drag began, `dx` / `dy` this move; `${result}` holds the
                // same.
                final start = _dragStart ?? d.localPosition;
                final drag = {
                  'dx': d.delta.dx,
                  'dy': d.delta.dy,
                  'deltaX': d.delta.dx,
                  'deltaY': d.delta.dy,
                  'x': d.localPosition.dx,
                  'y': d.localPosition.dy,
                  'globalX': d.globalPosition.dx,
                  'globalY': d.globalPosition.dy,
                  'pointerCount': 1,
                  'startX': start.dx,
                  'startY': start.dy,
                };
                _fire(TriggerType.drag, {'result': drag, 'drag': drag});
              }
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

  /// Where the current drag began, in the node.
  Offset? _dragStart;

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

  Map<String, Object?> _pointerScope(PointerEvent event) => {
    'result': {
      'pointer': event.pointer,
      'kind': event.kind.name,
      'cancelled': event is PointerCancelEvent,
      'x': event.localPosition.dx,
      'y': event.localPosition.dy,
      'globalX': event.position.dx,
      'globalY': event.position.dy,
      'buttons': event.buttons,
    },
  };

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerUpEvent || event is PointerCancelEvent) _down.remove(event.pointer);
    if (event is PointerDownEvent) {
      _down.add(event.pointer);
      if (yieldsToPinch && _down.length > 1 && _pan != null) {
        // Disposing rejects its pointers in the arena; it is made again on
        // the next first finger.
        _pan!.dispose();
        _pan = null;
      }
      if (yieldsToPinch && _down.length > 1) {
        _tap?.addPointer(event);
        _doubleTap?.addPointer(event);
        _longPress?.addPointer(event);
        if (_has(TriggerType.pointerDown)) _fire(TriggerType.pointerDown, _pointerScope(event));
        return;
      }
      _ensureRecognizers();
      _tap?.addPointer(event);
      _doubleTap?.addPointer(event);
      _longPress?.addPointer(event);
      _pan?.addPointer(event);
      if (_has(TriggerType.pointerDown)) _fire(TriggerType.pointerDown, _pointerScope(event));
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
      if (_has(TriggerType.pointerUp)) _fire(TriggerType.pointerUp, _pointerScope(event));
    } else if (event is PointerScrollEvent && _has(TriggerType.wheel)) {
      _fire(TriggerType.wheel, {
        'result': {'deltaX': event.scrollDelta.dx, 'deltaY': event.scrollDelta.dy, 'x': event.localPosition.dx, 'y': event.localPosition.dy},
      });
    } else if (event is PointerScaleEvent && _has(TriggerType.pinch)) {
      _fire(TriggerType.pinch, {'result': {'scale': event.scale}});
    } else if (event is PointerHoverEvent && _has(TriggerType.hover) && _hovering) {
      // Hover fires on entry; moves over the node don't repeat it.
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
    if (_dwell != null) {
      // Not in view long enough: seen again, it waits again.
      _dwell!.cancel();
      _dwell = null;
      _inView = false;
    }
    _hold?.cancel();
    _hold = null;
    if (_hovering && _has(TriggerType.cursorExit)) _fire(TriggerType.cursorExit);
    _hovering = false;
    super.detach();
    // A chain rebuilt around this box (a pressed state adding a scale
    // layer on pointer down) detaches and re-attaches it in the same frame:
    // disposing the recognizers then lost the tap in progress, so a button
    // with press feedback never clicked. Dispose only if it stays detached.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached) _disposeRecognizers();
    });
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
    _dwell?.cancel();
    _dwell = null;
    if (inView && visibleMs > 0) {
      // It must stay in view that long: leaving first cancels it.
      _dwell = Timer(Duration(milliseconds: visibleMs), () {
        _dwell = null;
        if (_inView && attached) _fire(TriggerType.enterViewport);
      });
      return;
    }
    final t = inView ? TriggerType.enterViewport : TriggerType.exitViewport;
    if (_triggersAll.contains(t)) _fire(t);
  }

  /// The viewport triggers aren't pointer triggers: [triggers] holds pointer
  /// ones only, so both fire whenever watched.
  Set<TriggerType> get _triggersAll => const {TriggerType.enterViewport, TriggerType.exitViewport};
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

/// Whether a trigger's `when` holds: a `${path}` binding, a `${= formula}`,
/// or a bare path or formula, reading true (or `true` / 1).
bool triggerWhenHolds(String when, ActionContext context) {
  final t = when.trim();
  final Object? value;
  if (t.contains(r'${')) {
    value = context.expressions.evaluate(t, context.scope);
  } else {
    value = readPath(context.scope, t) ?? context.expressions.evaluate('\${= $t}', context.scope);
  }
  return value == true || value == 1 || value == 'true' || value == '1';
}

/// A drag reaction is a one-finger gesture: a second finger landing before
/// the drag starts makes it a pinch, so this gives up and the pinch (a
/// transform gesture around the node: zooming a board you paint on) takes
/// it. Flutter's pan adds up every finger's travel, so two fingers
/// spreading apart would otherwise win as a drag.
class _OneFingerPanGestureRecognizer extends PanGestureRecognizer {
  _OneFingerPanGestureRecognizer({super.debugOwner});

  int _tracked = 0;
  bool _accepted = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_tracked > 0 && !_accepted) {
      resolve(GestureDisposition.rejected);
      return;
    }
    _tracked++;
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _tracked = 0;
    _accepted = false;
    super.didStopTrackingLastPointer(pointer);
  }
}

/// Whether the keyboard focus is in a text field (someone is typing).
bool isTyping() {
  final focused = FocusManager.instance.primaryFocus?.context;
  return focused != null &&
      (focused.widget is EditableText || focused.findAncestorWidgetOfExactType<EditableText>() != null);
}

/// The trigger an input reports for a tap on its prefix icon.
const iconTapPrefix = 'prefixIconTap';

/// The trigger an input reports for a tap on its suffix icon.
const iconTapSuffix = 'suffixIconTap';

/// The prefix (or suffix) icon of [node]'s input decoration, if it has one.
InputIcon? _inputIcon(Node node, {required bool prefix}) {
  for (final def in node.spec?.props ?? const <PropDef<Object?>>[]) {
    final v = node.props.get(def);
    if (v is InputDecoration) return prefix ? v.prefixIcon : v.suffixIcon;
  }
  return null;
}
