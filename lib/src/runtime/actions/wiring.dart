// Triggers in the render tree: a node's reactions wired into its box while
// the tree is interactive. Pointer triggers (taps, double taps, long
// presses, holds, hover, swipes, drags, wheel) are gesture recognizers in a
// render object of the node's chain, hit tested like any box (the deepest
// node with a tap wins, as nested GestureDetectors do); screen triggers
// (load, timers, value changes, keys) live with the box; inputs report
// theirs (changed, submitted...) from their islands; viewport triggers
// watch what of the box is visible after each frame.
//
// A node with a click reaction is also a press target for the keyboard: a
// Tab stop of its root's focus order (render/controls/focus.dart) that
// shows the theme's focus ring when the keyboard brings the focus, and runs
// its click on Enter and Space. See [RenderReactions.configurePress] for
// which nodes are and are not.
import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart' show DeepCollectionEquality;

import 'package:codelessly_api/core.dart' show InputDecoration, InputIcon, Json, NavigationBarProps, Node, PropDef, Reaction, SwitchProps, TriggerType, Trigger;
import 'package:codelessly_api/core.dart' as api show WidgetState, OpenModalAction, OpenLinkAction, Reaction, HapticKind, kDefaultHoldMs;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../render/controls/focus.dart';
import '../../render/controls/kit.dart' show firstTextUnder, paintFocusRing;
import '../../render/controls/overlay.dart' show tooltipFocusChanged;
import '../../render/controls/root.dart' show RenderControlRoot;
import '../../render/controls/text_field.dart' show RenderTextField;
import '../../render/controls/tokens.dart' show ControlTokens;
import '../../render/convert.dart';

import '../../render/custom_paint.dart' show customPaintEvent;
import '../../render/node_tree.dart';
import '../../render/visible_share.dart';
import '../contracts.dart';
import '../expressions/bindings.dart' show RenderTreeBinder;
import '../expressions/formula.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'context.dart';
import 'reveal_anchor.dart' show RevealAnchor;
import 'runner.dart';
import 'ui.dart' show HoverCardUi;
import 'key_matching.dart';
import '../../render/components.dart' show componentInstanceOf;

export '../../render/visible_share.dart' show visibleShare;

/// The types whose control takes a tap itself and reports it as the node's
/// `click` (the node's own tap layer leaves it to them).
const Set<String> _selfTappedTypes = {
  'elevatedButton', 'filledButton', 'textButton', 'outlinedButton', 'iconButton', 'floatingActionButton', //
  'chip', 'actionChip', 'choiceChip', 'filterChip', 'inputChip',
};

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
    if (_selfTappedTypes.contains(n.type)) pointer.remove(TriggerType.click);
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
    final states = box.tree.statesOf(box.id, instance: box.instance);
    final clicks = pointer.contains(TriggerType.click);
    chain.add(box.obtain<RenderReactions>('reactions', RenderReactions.new)
      ..triggers = pointer
      ..configurePress(
        // The document's opt-out, and a node that lets the pointer through
        // or is disabled: not the keyboard's either.
        focusable: clicks && n.behaviors.focusable && !n.behaviors.ignorePointer && !states.contains(api.WidgetState.disabled),
        // Whether a click would run now: a reaction whose `when` holds.
        enabled: clicks ? () => _clickHolds(box) : null,
        selected: states.contains(api.WidgetState.selected),
        label: n.behaviors.tooltip,
        ringColor: clicks ? ControlTokens.of(box).focusBorder : null,
        ringRadius: n.decoration.radius.flutter,
        onFocused: (on) {
          box.tree.setState(box.id, api.WidgetState.focused, on, instance: box.instance);
          if (on && n.actions.any((r) => r.trigger.type == TriggerType.hover &&
              r.actions.any((a) => a is api.OpenModalAction && a.hoverCard))) {
            fire(box, 'hover');
          }
        },
      )
      // A plain drag is one finger: on a node that also pinches, a second
      // finger hands the gesture to the pinch.
      ..yieldsToPinch = types.contains(TriggerType.pinch) || (g != null && g.enabled && (g.zoom || g.rotate))
      ..holdMs = n.actions.firstWhere((r) => r.trigger.type == TriggerType.hold, orElse: () => n.actions.first).trigger.holdMs
      // A long press held for its own time (holdMs written), and the point a
      // long press or a hold becomes the node's (commitMs).
      ..longPressMs = switch (n.actions.where((r) => r.trigger.type == TriggerType.longPress).firstOrNull?.trigger.holdMs) {
        final ms? when ms != api.kDefaultHoldMs && ms > 0 => ms,
        _ => null,
      }
      ..commitMs = n.actions
              .where((r) => (r.trigger.type == TriggerType.longPress || r.trigger.type == TriggerType.hold) && r.trigger.commitMs > 0)
              .firstOrNull
              ?.trigger
              .commitMs ??
          0
      ..haptics = {
        for (final r in n.actions.reversed)
          if (r.trigger.haptic != null) r.trigger.type: r.trigger.haptic!,
      }
      ..repeatDelayMs = n.actions.where((r) => r.trigger.type == TriggerType.click && r.trigger.repeat).firstOrNull?.trigger.holdMs
      ..repeatIntervalMs = n.actions.where((r) => r.trigger.type == TriggerType.click && r.trigger.repeat).firstOrNull?.trigger.effectiveIntervalMs
      ..visibleFraction = viewport ? n.actions.firstWhere((r) => _isViewport(r.trigger.type)).trigger.visibleFraction : null
      ..visibleMs = viewport
          ? n.actions.firstWhere((r) => r.trigger.type == TriggerType.enterViewport, orElse: () => n.actions.first).trigger.visibleMs
          : 0
      ..onTrigger = (type, event) => fire(box, type.name, event: event));
  }

  static bool _isViewport(TriggerType t) => t == TriggerType.enterViewport || t == TriggerType.exitViewport;

  /// Whether a click on [box] would run a reaction now: it has one whose
  /// `when` holds (a menu row dimmed by `when: props.enabled` has none).
  bool _clickHolds(NodeBox box) {
    final n = box.node;
    if (n == null || !box.attached) return false;
    ActionContext? ctx;
    for (final r in n.actions) {
      if (r.trigger.type != TriggerType.click) continue;
      final when = r.trigger.when.trim();
      if (when.isEmpty) return true;
      try {
        if (triggerWhenHolds(when, ctx ??= contextFor(box))) return true;
      } catch (_) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> fire(NodeBox box, String trigger, {Json event = const {}}) async {
    var node = box.node;
    if (node == null) return;
    // A disabled node runs no actions of the pointer (its `disabled`
    // binding: api WidgetState.disabled): a box written `disabled`.
    if (TriggerType.pointer.any((t) => t.name == trigger) && box.tree.statesOf(box.id, instance: box.instance).contains(api.WidgetState.disabled)) return;
    // A tap on an input's prefix or suffix icon runs that icon's own
    // reactions (`InputIcon.actions`), as a click of the node.
    if (trigger == iconTapPrefix || trigger == iconTapSuffix) {
      final icon = _inputIcon(node, prefix: trigger == iconTapPrefix);
      if (icon == null || icon.actions.isEmpty) return;
      node = node.copyWith(actions: icon.actions);
      trigger = 'click';
    }
    // A destination picked in a navigation bar runs its own reactions
    // (`NavigationDestination.actions`), as a click, after the bar's
    // `changed`.
    if (trigger == _destinationTap) {
      final i = event['value'];
      final destinations = node.prop(NavigationBarProps.destinations);
      if (i is! int || i < 0 || i >= destinations.length || destinations[i].actions.isEmpty) return;
      node = node.copyWith(actions: destinations[i].actions);
      trigger = 'click';
    }
    // A link in a text (a run's `link`) runs the text's linkTap reactions;
    // a text with none opens the link.
    if (trigger == TriggerType.linkTap.name && !node.actions.any((r) => r.trigger.type == TriggerType.linkTap)) {
      final link = switch (event['result']) {
        final Map<Object?, Object?> m => '${m['link'] ?? ''}',
        _ => '',
      };
      if (link.isEmpty) return;
      node = node.copyWith(actions: [
        api.Reaction(trigger: const Trigger(TriggerType.linkTap), actions: [api.OpenLinkAction(url: link)]),
      ]);
    }
    // A held press repeats only click reactions that opted in; a node may
    // also have a one-shot click reaction (for example, opening a panel).
    if (trigger == 'click' && event['repeat'] == true) {
      node = node.copyWith(actions: node.actions.where((r) => r.trigger.type == TriggerType.click && r.trigger.repeat).toList());
      if (node.actions.isEmpty) return;
    }
    // What a custom paint has under the pointer (render/custom_paint.dart).
    if (node.behaviors.customPaint != null) event = customPaintEvent(box, event);
    // What a modal anchored to its trigger (or the pointer) sits by.
    RevealAnchor.track();
    // The box as the screen shows it: its size scales with it too (a running
    // app inside a scaled preview), not only its origin.
    RevealAnchor.lastTrigger =
        box.attached && box.hasSize ? MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size) : null;
    final ctx = chainContextFor(box);
    if (trigger == 'cursorExit' && node.actions.any((r) => r.actions.any((a) => a is api.OpenModalAction && a.hoverCard))) {
      final anchor = RevealAnchor.lastTrigger;
      if (anchor != null && ctx is ActionHost && ctx.ui is HoverCardUi) {
        (ctx.ui as HoverCardUi).hoverAnchorExit(anchor);
      }
    }
    if (trigger == 'changed' && event.containsKey('value')) _writeBack(node, event['value'], ctx);
    final picked = trigger == 'changed' && (node.type == 'navigationBar' || node.type == 'bottomNavigationBar') && event['value'] is int;
    final state = _boxes[box];
    final r = runner;
    if (r is CoreActions) {
      // The root of a component instance carries its definition's reactions
      // and then its call's (`seamCall`). The call's were written by the
      // caller: they run in the caller's scope, as its event reactions do,
      // so a script or an expression there reads the page's variables.
      final ci = componentInstanceOf(box.instance);
      final own = ci != null && box.tree.isInstanceRoot(box.id, box.instance) ? box.tree.sourceOf(box.instance).node(box.id) : null;
      final split = own == null ? -1 : own.actions.length;
      if (ci != null && split >= 0 && split < node.actions.length) {
        final callSource = box.tree.sourceOf(ci.outer);
        final scope = box.tree.binder?.scopeFor(callSource, ci.call, ci.outer);
        final caller = scope == null || ctx is! ActionHost ? ctx : ctx.withScope(scope);
        if (split > 0) {
          await r.run(node.copyWith(actions: node.actions.sublist(0, split)), trigger, ctx,
              event: event, cancellation: state?.cancellation, instance: box.instance);
        }
        await r.run(node.copyWith(actions: node.actions.sublist(split)), trigger, caller,
            event: event, cancellation: state?.cancellation, instance: ci.outer);
      } else {
        await r.run(node, trigger, ctx, event: event, cancellation: state?.cancellation, instance: box.instance);
      }
    } else {
      await r.trigger(node, trigger, ctx, event: event).catchError((Object e, StackTrace s) {
        if (ctx is ActionHost) ctx.reportError(e, s, action: trigger);
      });
    }
    if (picked) await fire(box, _destinationTap, event: event);
  }

  /// [fire], finishing when the reactions have run (a list's pull to
  /// refresh shows until then).
  Future<void> fireAndWait(NodeBox box, String trigger, {Json event = const {}}) async {
    final node = box.node;
    if (node == null) return;
    final ctx = chainContextFor(box);
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

  /// [contextFor], for a chain of actions about to run: the list item it
  /// starts on is kept while it runs ([ChainItemScope]).
  ActionContext chainContextFor(NodeBox box) {
    final c = contextFor(box);
    if (c is! ActionHost) return c;
    final kept = ChainItemScope.over(c.scope);
    return identical(kept, c.scope) ? c : c.withScope(kept);
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

/// The timers of the screens that are counting: a timer of a short interval
/// (a quarter of a second or less) whose every reaction that holds says when
/// it runs and writes a name that condition reads (`every 40 when tick<50`
/// with `tick=tick+1`: a count-up, a bar that fills). Such a timer ends by
/// itself; a clock, a carousel that turns while it is not paused and a
/// countdown of seconds are not among them. For what takes a picture of a
/// screen (the render command, a preview's camera): it lets these arrive,
/// as it lets `animateTo` counters ([VariableAnimator.anyPlaying]), so the
/// picture shows the numbers they end at.
abstract final class ScreenTimers {
  static int _counting = 0;

  /// Whether a timer that counts to its end is running in any screen.
  static bool get anyCounting => _counting > 0;

  /// The longest interval of a timer that counts.
  static const int countingIntervalMs = 250;
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
    _setCounting(false);
    _frames?.stop();
  }

  /// Whether this box's timer is one that counts to its end ([ScreenTimers]).
  bool _counting = false;

  void _setCounting(bool value) {
    if (value == _counting) return;
    _counting = value;
    ScreenTimers._counting += value ? 1 : -1;
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
    // Whether every reaction that holds ends itself: it says when it runs
    // and writes a name that condition reads.
    var ends = true;
    for (final r in n.actions) {
      if (r.trigger.type != TriggerType.timer) continue;
      final condition = r.trigger.when.trim();
      if (condition.isNotEmpty && !triggerWhenHolds(condition, ctx)) continue;
      final source = r.trigger.intervalMs.source;
      final every = source == null
          ? r.trigger.effectiveIntervalMs
          : Trigger.intervalMsOf(ctx.expressions.evaluate(source, ctx.scope));
      if (every != null) {
        ms = math.min(ms ?? 1 << 30, every);
        ends = ends && condition.isNotEmpty && _writesWhatItReads(r, condition);
      }
    }
    _setCounting(ms != null && ms <= ScreenTimers.countingIntervalMs && ends);
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

  /// Whether reaction [r] sets a variable its [condition] reads.
  static bool _writesWhatItReads(Reaction r, String condition) {
    final reads = FormulaEvaluator.referencedPaths(FormulaEvaluator.exactExpression(condition) ?? exactPath(condition) ?? condition).map(rootOf).toSet();
    if (reads.isEmpty) return false;
    var writes = false;
    void walk(Object? v) {
      if (writes) return;
      if (v is Map) {
        if (v['type'] == 'setVariable' && v['variable'] is String && reads.contains(rootOf(v['variable'] as String))) {
          writes = true;
          return;
        }
        v.values.forEach(walk);
      } else if (v is List) {
        v.forEach(walk);
      }
    }

    walk([for (final a in r.actions) a.toJson()]);
    return writes;
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
    // What is under an open overlay takes no key (the overlays' contract):
    // a page's shortcuts, and an App's onKeyDown, wait while a dialog, a
    // sheet or a menu is over it (round 10, R13: a page's Enter ran while a
    // chooser was open). The overlay's own keys run.
    if (!_onTopLayer()) return false;
    final repeat = e is KeyRepeatEvent;
    final down = e is KeyDownEvent || repeat;
    final type = down ? TriggerType.keyDown : TriggerType.keyUp;
    // Plain keys belong to the focused field. A canvas shortcut with Ctrl,
    // Cmd or Alt still runs while typing (for example Mod+K opens search).
    // The field's own ArrowDown and Escape reactions continue to work.
    final typing = isTyping();
    final keys = HardwareKeyboard.instance;
    final meta = keys.isMetaPressed || keys.isControlPressed;
    final modified = meta || keys.isAltPressed;
    final fieldOwns = typing && _ownsFocusedField();
    if (typing && e.logicalKey != LogicalKeyboardKey.escape && !fieldOwns && !(n.type == 'canvas' && modified)) return false;
    final label = e.logicalKey.keyLabel;
    final character = e.character;
    // A key that types text goes to a focused text field, not a shortcut.
    if (!meta && !keys.isAltPressed && typesText(character) && _textFieldFocused()) return false;
    var handled = false;
    bool? focused;
    for (final r in n.actions) {
      if (r.trigger.type != type) continue;
      // A held key's repeats reach only keyDown reactions that ask for them.
      if (repeat && !r.trigger.repeat) continue;
      final combo = r.trigger.keyCombo;
      // A wildcard or a bare letter must never steal input from a field.
      if (typing && !fieldOwns && e.logicalKey != LogicalKeyboardKey.escape &&
          (combo == null || (!combo.meta && !combo.alt))) {
        continue;
      }
      if (!runtimeKeyEventMatches(combo, label,
          character: character, meta: meta, shift: keys.isShiftPressed, alt: keys.isAltPressed)) {
        continue;
      }
      // A control of one's own takes its keys only while it has the focus.
      if (r.trigger.focused && !(focused ??= _hasFocusInside())) continue;
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
        'focused': focused ??= _hasFocusInside(),
      },
    });
    return true;
  }

  /// Whether the keyboard focus is on this node or on a control inside it.
  bool _hasFocusInside() {
    for (RenderObject? at = ControlFocusScope.focusedScope?.focused?.owner; at != null; at = at.parent) {
      if (identical(at, box)) return true;
    }
    return false;
  }

  /// Whether this node is on the overlay that holds the keyboard
  /// ([ControlFocusLayer.top]), or on the page when none is open.
  bool _onTopLayer() {
    final top = ControlFocusLayer.top;
    if (top == null) return true;
    for (RenderObject? at = box; at != null; at = at.parent) {
      if (at is RenderControlRoot) return identical(at.focus.layer, top);
    }
    return true;
  }

  /// Whether the field being typed in is this node's.
  bool _ownsFocusedField() {
    for (RenderObject? at = RenderTextField.focused; at != null; at = at.parent) {
      if (identical(at, box)) return true;
      if (at is NodeBox) return false;
    }
    return false;
  }

  static bool _textFieldFocused() =>
      RenderTextField.focused != null;

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _setCounting(false);
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

  int? _longPressMs;

  /// How long a long press is held (its trigger's holdMs); null: the
  /// platform's.
  int? get longPressMs => _longPressMs;
  set longPressMs(int? v) {
    if (v == _longPressMs) return;
    _longPressMs = v;
    _longPress?.dispose();
    _longPress = null;
  }

  int _commitMs = 0;

  /// From this many ms after the press, a long press or a hold is the
  /// node's: letting go no longer cancels it, nothing else takes the press.
  /// 0: none.
  int get commitMs => _commitMs;
  set commitMs(int v) {
    if (v == _commitMs) return;
    _commitMs = v;
    _longPress?.dispose();
    _longPress = null;
  }

  /// The buzz of each trigger that has one ([Trigger.haptic]): at the
  /// commit point of a long press or a hold that has one, else as it fires.
  Map<TriggerType, api.HapticKind> haptics = const {};

  static void _buzz(api.HapticKind kind) {
    unawaited(switch (kind) {
      api.HapticKind.selection => HapticFeedback.selectionClick(),
      api.HapticKind.light => HapticFeedback.lightImpact(),
      api.HapticKind.medium => HapticFeedback.mediumImpact(),
      api.HapticKind.heavy => HapticFeedback.heavyImpact(),
      api.HapticKind.vibrate => HapticFeedback.vibrate(),
    });
  }

  /// The haptic of [t] when it fires (not one buzzed at a commit point).
  void _buzzOnFire(TriggerType t) {
    final kind = haptics[t];
    if (kind == null) return;
    if (_commitMs > 0 && (t == TriggerType.longPress || t == TriggerType.hold)) return;
    _buzz(kind);
  }

  /// The commit point's buzz: a long press's, else a hold's.
  void _buzzOnCommit() {
    final kind = haptics[TriggerType.longPress] ?? haptics[TriggerType.hold];
    if (kind != null) _buzz(kind);
  }

  /// A click with `repeat: true` repeats after this delay at this interval.
  /// Null disables repetition; the short-tap click is unchanged.
  int? repeatDelayMs;
  int? repeatIntervalMs;
  Timer? _repeatDelay;
  Timer? _repeatTimer;
  Offset? _repeatStart;
  bool _repeated = false;

  void _stopRepeat() {
    _repeatDelay?.cancel();
    _repeatTimer?.cancel();
    _repeatDelay = _repeatTimer = null;
    _repeatStart = null;
  }

  /// A second finger cancels a plain drag (and its swipes), so a pinch on
  /// this node (a transform gesture's zoom, pinch reactions) wins.
  bool yieldsToPinch = false;
  final Set<int> _down = {};

  /// Where each finger down is (local), for a two-finger pinch.
  final Map<int, Offset> _fingers = {};

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
  void _fire(TriggerType t, [Json event = const {}]) {
    _buzzOnFire(t);
    onTrigger?.call(t, event);
  }

  // --- the keyboard: a press target ---------------------------------------------

  ControlFocusNode? _focus;

  /// Its place in the Tab order when it is pressed (a node with a click
  /// reaction); null when it takes no focus.
  ControlFocusNode? get pressFocus => _focus;

  /// Its place in the root's focus order while it is a press target; null
  /// otherwise.
  ControlFocusNode? get focusNode => _focus;

  bool _focusable = false;
  bool Function()? _enabled;
  bool _selected = false;
  String _label = '';
  Color? _ringColor;
  BorderRadius _ringRadius = BorderRadius.zero;
  void Function(bool focused)? _onFocused;

  /// Makes the node a press target for the keyboard, or not.
  ///
  /// A node is one when it has a `click` reaction (hover, long press, drag
  /// and the other triggers alone do not make one) and [focusable]: the
  /// document did not opt it out (`"focusable": false`), it does not let
  /// the pointer through (`ignorePointer`) and it is not `disabled`. It
  /// is skipped while [enabled] says no click would run (every click
  /// reaction's `when` fails), while something around it ignores the
  /// pointer or hides it, and when the node is itself a control with a
  /// focus of its own (a text field with a click reaction is one stop, the
  /// field). A press target around other stops (a card with a button in
  /// it) stays one, reached before them.
  ///
  /// Focused from the keyboard it paints the focus ring: [ringColor] (the
  /// theme's `focusBorder`, as the controls' ring) just outside its box,
  /// with the node's corners ([ringRadius]); and [onFocused] puts the node
  /// in its `focused` state, so its `states.focused` patch applies. A
  /// pointer never shows either. [label] names it when it has no text
  /// (its `tooltip`); [selected] is its bound `selected`.
  void configurePress({
    required bool focusable,
    bool Function()? enabled,
    bool selected = false,
    String label = '',
    Color? ringColor,
    BorderRadius ringRadius = BorderRadius.zero,
    void Function(bool focused)? onFocused,
  }) {
    _enabled = enabled;
    _onFocused = onFocused;
    if (ringColor != _ringColor || ringRadius != _ringRadius) {
      _ringColor = ringColor;
      _ringRadius = ringRadius;
      if (_focus?.showsHighlight ?? false) markNeedsPaint();
    }
    if (selected != _selected || label != _label || focusable != _focusable) {
      _selected = selected;
      _label = label;
      markNeedsSemanticsUpdate();
    }
    if (focusable == _focusable) return;
    _focusable = focusable;
    if (!focusable) {
      _focus?.leave();
      _focus = null;
      return;
    }
    final node = _focus = ControlFocusNode(this, onActivate: _activate, onFocusChange: (_) => _focusChanged())
      ..onHighlightChange = _focusChanged
      ..focusableWhen = _canFocus
      ..selected = (() => _selected)
      ..label = (() => _label.isNotEmpty ? _label : firstTextUnder(this));
    if (attached) {
      final root = RenderControlRoot.of(this);
      if (root != null) node.join(root.focus);
    }
  }

  /// Whether a click would run now (its reaction's `when` holds).
  bool get pressEnabled => _enabled?.call() ?? true;

  bool _canFocus() => pressEnabled && !_isOwnControl;

  // Whether the node is itself a control with a focus of its own (another
  // focus node inside its box and no other node's): worked out again when
  // the scope's nodes change.
  bool _ownControl = false;
  int _ownControlStamp = -1;

  bool get _isOwnControl {
    final scope = _focus?.scope;
    if (scope == null) return false;
    final stamp = scope.nodes.length;
    if (stamp == _ownControlStamp) return _ownControl;
    _ownControlStamp = stamp;
    final mine = _boxAround(this);
    _ownControl = false;
    for (final n in scope.nodes) {
      if (identical(n, _focus) || n.owner is RenderReactions) continue;
      if (identical(_boxAround(n.owner), mine)) {
        _ownControl = true;
        break;
      }
    }
    return _ownControl;
  }

  static NodeBox? _boxAround(RenderObject o) {
    for (RenderObject? p = o; p != null; p = p.parent) {
      if (p is NodeBox) return p;
    }
    return null;
  }

  /// Whether other stops are inside it (a card with a button): its
  /// semantics then keep theirs apart.
  bool get _hasStopsInside {
    final scope = _focus?.scope;
    if (scope == null) return false;
    for (final n in scope.nodes) {
      if (identical(n, _focus)) continue;
      for (RenderObject? p = n.owner.parent; p != null; p = p.parent) {
        if (identical(p, this)) return true;
      }
    }
    return false;
  }

  // Enter or Space: the click, at its center.
  void _activate() {
    if (!attached || !hasSize || !pressEnabled) return;
    final center = size.center(Offset.zero);
    _fire(TriggerType.click, _where(center, localToGlobal(center)));
  }

  bool _shownFocused = false;

  void _focusChanged() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    if (_focus case final node?) tooltipFocusChanged(node);
    final shown = _focus?.showsHighlight ?? false;
    if (shown == _shownFocused) return;
    _shownFocused = shown;
    // The node's `focused` state re-applies its box: after the key handler.
    final cb = _onFocused;
    if (cb != null) scheduleMicrotask(() => cb(shown));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final color = _ringColor;
    if (color != null && (_focus?.showsHighlight ?? false)) {
      paintFocusRing(context.canvas, _ringRadius.toRRect(offset & size), color);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_has(TriggerType.click) || _has(TriggerType.longPress)) {
      config.isSemanticBoundary = true;
      config.isButton = true;
      if (_label.isNotEmpty) {
        config
          ..label = _label
          ..textDirection = TextDirection.ltr;
      }
      if (_selected) config.isSelected = true;
      final focus = _focus;
      final enabled = pressEnabled;
      if (_has(TriggerType.click)) {
        config.isEnabled = enabled;
        if (enabled) {
          config.onTap = () {
            if (focus != null) ControlFocusScope.noteActivation(focus, keyboard: false);
            _fire(TriggerType.click);
          };
        }
      }
      if (_has(TriggerType.longPress)) config.onLongPress = () => _fire(TriggerType.longPress);
      if (focus != null && enabled && !_isOwnControl) {
        config
          ..isFocused = focus.hasFocus
          ..onFocus = () => focus.requestFocus();
        // One node a screen reader reads as a whole (a row's icon, title
        // and note), unless other stops inside it must stay apart.
        if (!_hasStopsInside) config.isMergingSemanticsOfDescendants = true;
      }
    }
  }

  TapGestureRecognizer? _tap;
  DoubleTapGestureRecognizer? _doubleTap;
  GestureRecognizer? _longPress;
  PanGestureRecognizer? _pan;
  Timer? _hold;
  Timer? _holdCommit;
  bool _holdCommitted = false;
  Offset? _holdStart;

  Json _where(Offset local, Offset global) {
    final keys = HardwareKeyboard.instance;
    return {
      'result': {
        'x': local.dx,
        'y': local.dy,
        'globalX': global.dx,
        'globalY': global.dy,
        // Control or Command (the platform's modifier for "add to"), and
        // Control alone: a writer reaches for result.ctrl.
        'meta': keys.isMetaPressed || keys.isControlPressed,
        'ctrl': keys.isControlPressed,
        'shift': keys.isShiftPressed,
        'alt': keys.isAltPressed,
      },
    };
  }

  void _ensureRecognizers() {
    if (_tap == null && (_has(TriggerType.click) || _has(TriggerType.secondaryClick))) {
      Json? at;
      final click = _has(TriggerType.click);
      // A node that reacts to the secondary button only takes no part in a
      // primary press: a callback of the primary button makes the
      // recognizer enter the arena for it, and the innermost one wins, so a
      // row's right-click menu took the press from the selectable list's
      // item around it (nothing was chosen).
      _tap = TapGestureRecognizer(debugOwner: this)
        ..onTapDown = (click ? ((d) => at = _where(d.localPosition, d.globalPosition)) : null)
        ..onTapUp = (click ? ((_) {}) : null)
        ..onTap = (click
            ? () {
                if (_repeated) return;
                // What an overlay this press opens gives the focus back to.
                if (_focus case final f?) ControlFocusScope.noteActivation(f, keyboard: false);
                _fire(TriggerType.click, at ?? const {});
              }
            : null)
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
      final ms = _longPressMs;
      _longPress = _commitMs > 0
          // Held to its commit point, the press is the node's: the reaction
          // runs at its end whether the finger stays or not.
          ? (_CommittedHoldRecognizer(
              debugOwner: this,
              commit: Duration(milliseconds: _commitMs),
              hold: Duration(milliseconds: ms ?? kLongPressTimeout.inMilliseconds),
            )
            ..onCommit = _buzzOnCommit
            ..onHeld = () {
              if (attached) _fire(TriggerType.longPress);
            })
          : (LongPressGestureRecognizer(debugOwner: this, duration: ms == null ? null : Duration(milliseconds: ms))
            ..onLongPress = () => _fire(TriggerType.longPress));
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
          // `${result.cancelled}`: the drag was taken away (the system
          // cancelled the pointer), not let go.
          final pan = _pan;
          final cancelled = pan is _OneFingerPanGestureRecognizer && pan.lastCancelled;
          if (_has(TriggerType.dragEnd)) _fire(TriggerType.dragEnd, {'result': {'vx': v.dx, 'vy': v.dy, 'cancelled': cancelled}});
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
    _holdCommit?.cancel();
    _holdCommit = null;
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
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _down.remove(event.pointer);
      _fingers.remove(event.pointer);
      _stopRepeat();
    }
    if (event is PointerMoveEvent && _fingers.containsKey(event.pointer)) {
      if (_fingers.length > 1 && _has(TriggerType.pinch)) {
        _touchPinch(event);
      } else {
        _fingers[event.pointer] = event.localPosition;
      }
    }
    if (event is PointerDownEvent) {
      _down.add(event.pointer);
      _repeated = false;
      if (_has(TriggerType.click) && repeatDelayMs != null && _down.length == 1) {
        _repeatStart = event.position;
        _repeatDelay = Timer(Duration(milliseconds: repeatDelayMs!), () {
          if (!attached || !_down.contains(event.pointer) || !pressEnabled) return;
          _repeated = true;
          _fire(TriggerType.click, const {'repeat': true});
          _repeatTimer = Timer.periodic(Duration(milliseconds: repeatIntervalMs ?? 120), (_) {
            if (!attached || !_down.contains(event.pointer) || !pressEnabled) {
              _stopRepeat();
            } else {
              _fire(TriggerType.click, const {'repeat': true});
            }
          });
        });
      }
      if (event.kind == PointerDeviceKind.touch) _fingers[event.pointer] = event.localPosition;
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
        _holdCommit?.cancel();
        _holdCommitted = false;
        _hold = Timer(Duration(milliseconds: holdMs), () {
          _hold = null;
          _holdCommit?.cancel();
          if (attached) _fire(TriggerType.hold);
        });
        if (_commitMs > 0 && _commitMs < holdMs) {
          // From here letting go or moving no longer cancels the hold.
          _holdCommit = Timer(Duration(milliseconds: _commitMs), () {
            _holdCommit = null;
            _holdCommitted = true;
            if (!_has(TriggerType.longPress)) _buzzOnCommit();
          });
        }
      }
    } else if (event is PointerMoveEvent) {
      if (_repeatStart case final start? when (event.position - start).distance > kTouchSlop) _stopRepeat();
      final start = _holdStart;
      if (_hold != null && !_holdCommitted && start != null && (event.position - start).distance > kTouchSlop) {
        _hold?.cancel();
        _hold = null;
        _holdCommit?.cancel();
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (!_holdCommitted) {
        _hold?.cancel();
        _hold = null;
      }
      _holdCommit?.cancel();
      if (_has(TriggerType.pointerUp)) _fire(TriggerType.pointerUp, _pointerScope(event));
    } else if (event is PointerScrollEvent && _has(TriggerType.wheel)) {
      _fire(TriggerType.wheel, {
        'result': {'deltaX': event.scrollDelta.dx, 'deltaY': event.scrollDelta.dy, 'x': event.localPosition.dx, 'y': event.localPosition.dy},
      });
    } else if (event is PointerScaleEvent && _has(TriggerType.pinch)) {
      // A trackpad pinch (or ctrl + wheel on the web): the scale of this
      // step, about the pointer.
      _fire(TriggerType.pinch, {
        'result': {'scale': event.scale, 'x': event.localPosition.dx, 'y': event.localPosition.dy, 'pointerCount': 2},
      });
    } else if (event is PointerHoverEvent && _has(TriggerType.hover) && _hovering) {
      // Hover fires on entry; moves over the node don't repeat it.
    }
  }

  /// Two fingers on a touch screen: each move of one fires `pinch` with the
  /// scale of this step (how much the distance between the first two
  /// fingers changed) about the point between them, as a trackpad pinch
  /// does, so one reaction zooms about the pinch point for both.
  void _touchPinch(PointerMoveEvent event) {
    final ids = _fingers.keys.take(2).toList();
    final before = [for (final id in ids) _fingers[id]!];
    _fingers[event.pointer] = event.localPosition;
    if (!ids.contains(event.pointer)) return;
    final after = [for (final id in ids) _fingers[id]!];
    final d0 = (before[0] - before[1]).distance, d1 = (after[0] - after[1]).distance;
    if (d0 < 1 || d1 < 1) return;
    final focal = (after[0] + after[1]) / 2;
    _fire(TriggerType.pinch, {
      'result': {'scale': d1 / d0, 'x': focal.dx, 'y': focal.dy, 'pointerCount': _fingers.length},
    });
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
    if (_focus case final f?) {
      final root = RenderControlRoot.of(this);
      if (root != null) f.join(root.focus);
    }
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
    _stopRepeat();
    if (_hovering && _has(TriggerType.cursorExit)) _fire(TriggerType.cursorExit);
    _hovering = false;
    super.detach();
    // A chain rebuilt around this box (a pressed state adding a scale
    // layer on pointer down) detaches and re-attaches it in the same frame:
    // disposing the recognizers then lost the tap in progress, so a button
    // with press feedback never clicked. Dispose only if it stays detached.
    // Its place in the focus order too: a state style that adds a layer as
    // the focus arrives must not take the focus away.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) return;
      _disposeRecognizers();
      _focus?.leave();
    });
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _focus?.leave();
    super.dispose();
  }

  // --- viewport --------------------------------------------------------------------------

  bool _inView = false;

  void _checkViewport() {
    final fraction = _visibleFraction;
    if (fraction == null || !attached || !hasSize || viewportTriggersPaused) return;
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

/// While true, no box enters or leaves the viewport: what is in view stays
/// as it was. A full-page capture (tool/render) scrolls the page through the
/// window to draw it; a list that loads more when its end comes into view
/// would load again at every slice, and the page it draws grow under it.
bool viewportTriggersPaused = false;

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

/// A long press with a commit point ([Trigger.commitMs]): held to [commit]
/// it wins the arena (a scroll can no longer take the press) and [onCommit]
/// runs (its buzz); [onHeld] runs at [hold], whether the finger is still
/// down or not. Let go, or moved past the slop, before [commit]: nothing.
class _CommittedHoldRecognizer extends PrimaryPointerGestureRecognizer {
  _CommittedHoldRecognizer({super.debugOwner, required this.commit, required this.hold})
      : super(deadline: commit, preAcceptSlopTolerance: kTouchSlop, postAcceptSlopTolerance: null);

  final Duration commit, hold;
  VoidCallback? onCommit;
  VoidCallback? onHeld;
  Timer? _rest;

  @override
  void didExceedDeadline() {
    resolve(GestureDisposition.accepted);
    onCommit?.call();
    final left = hold - commit;
    _rest?.cancel();
    if (left <= Duration.zero) {
      onHeld?.call();
      return;
    }
    _rest = Timer(left, () {
      _rest = null;
      onHeld?.call();
    });
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    // Let go before the commit point: not a long press.
    if ((event is PointerUpEvent || event is PointerCancelEvent) && state == GestureRecognizerState.possible) {
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    _rest = null;
    super.dispose();
  }

  // Winning the arena by default (no other member) is not the commit: the
  // deadline is (as Flutter's long press).
  @override
  void acceptGesture(int pointer) {}

  @override
  String get debugDescription => 'committed hold';
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

  /// Whether the pointer the drag ended with was cancelled (taken away by
  /// the system), not lifted.
  bool lastCancelled = false;

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) lastCancelled = false;
    if (event is PointerCancelEvent) lastCancelled = true;
    super.handleEvent(event);
  }

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
  return RenderTextField.focused != null;
}

/// What [TreeReactions.fire] runs after a navigation bar's `changed`: the
/// picked destination's own reactions.
const _destinationTap = 'destinationTap';

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
