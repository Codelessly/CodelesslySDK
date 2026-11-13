// One typed handler per action type, over an ActionRun (the chain's scope
// and result, its context's services, UI and node tree), without
// BuildContext.
import 'dart:async';

import 'dart:convert';

import 'package:codelessly_api/core.dart';
import 'package:flutter/rendering.dart' as rendering show Axis;
import 'package:flutter/rendering.dart' show MatrixUtils, Rect, RenderObject, RenderViewportBase;
import 'package:flutter/scheduler.dart' show SchedulerBinding, timeDilation;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback, TextEditingValue, TextSelection;
import 'package:flutter/widgets.dart' show Cubic, Curve, Curves, ScrollPosition;

import '../../render/layout/design_scroll.dart' show RenderDesignScroll;
import '../../render/components.dart' show componentInstanceOf;
import '../../render/node_tree.dart' show NodeBox, RenderTree;
import '../../render/drag_track.dart' show DragTracks;
import '../../render/layout/design_scroll.dart';
import '../gestures/drag_motion.dart' show DragMotionControl;
import '../../render/transform_gesture.dart' show TransformGestures;
import '../../render/particles.dart' show ParticlePlayers;
import '../../scripting/formula_scripts.dart' show ScriptsScope;
import '../expressions/bindings.dart' show RenderTreeBinder;
import '../expressions/formula.dart';
import '../lists/paginate_action.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'context.dart';
import 'feedback_theme.dart' show Look;
import 'route_transition.dart' show RevealAnchor;
import 'runner.dart';
import 'script_host.dart';
import 'text_fields.dart';
import 'values.dart';
import 'variable_animator.dart';
export 'files.dart' show pickFiles, sourceFiles;
import '../font_loads.dart';

/// Runs [a] with its built-in handler: the core action types
/// ([CoreAction]). Every other declared type is a feature's: its handler is
/// registered by the feature (feature.dart) and runs before this is reached.
Future<void> handleAction(ActionDef a, ActionRun run) async {
  switch (a) {
    case CoreAction():
      await _handleCore(a, run);
    case UnknownAction():
      break;
    default:
      throw StateError("No handler for action '${a.type}': the feature that runs it isn't installed "
          '(CodelesslyActions installs the first-party features; CoreActions none).');
  }
}

/// The core action types, one case each: exhaustive, so a core type added
/// to the API without a handler doesn't compile.
Future<void> _handleCore(CoreAction a, ActionRun run) async {
  switch (a) {
    case NavigateAction():
      await run.host.ui.navigate(a, params: run.json(a.params), baseParams: run.json(a.baseParams));
    case OpenModalAction():
      if (a.anchor == ModalAnchor.node) RevealAnchor.named = await _namedAnchor(a, run);
      final result = await run.host.ui.openModal(a, params: run.json(a.params));
      if (result != null) run.result = result;
    case CloseModalAction():
      run.host.ui.closeModal(a.result == null ? null : run.evaluateJson(a.result));
    case RetryFailedAction():
      if (run.host case final CoreActionContext context) context.failed.retry();
    case ComponentEventAction():
      await fireComponentEvent(a, run);
    case OpenLinkAction():
      final url = run.text(a.url).trim();
      if (url.isNotEmpty) await run.context.services.openUrl(url);
    case SetValueAction():
      _setValue(a.node, a.values, run);
    case SetVariantAction():
      _setValue(a.node, [NodeValue('props.current', value: a.variant)], run);
    case SetVariableAction():
      await _setVariable(a, run);
    case AnimateAction():
      await _animate(a, run);
    case HapticAction():
      _haptic(a.kind);
    case RunScriptAction():
      await runScriptAction(a, run);
    case CallFunctionAction():
      final f = run.host.functions[a.name];
      if (f != null) {
        run.result = await f(run.context, run.json(a.params));
      } else if (run.function(a.name) case final builtIn?) {
        // A feature's function (`media.probe`); the app's own came first.
        run.result = await builtIn(a, run);
      } else if (a.optional) {
        // The app hasn't registered it: the chain goes on without it.
        run.result = null;
      } else {
        throw StateError('No function named [${a.name}]');
      }
    case IfAction():
      // A condition reading a script formula waits for its answer.
      final holds = a.condition != null && await _withScripts(run, () => run.expressions.test(a.condition!, run.scope));
      await run.run(holds ? a.then : a.orElse);
    case ForEachAction():
      await _forEach(a, run);
    case ShowToastAction():
      final runner = run.nested(run.result);
      final label = run.text(a.actionLabel);
      final offset = Look(a.style).string('offset')?.trim() ?? '';
      run.host.ui.showToast(
        a,
        message: run.text(a.message),
        title: run.text(a.title),
        actionLabel: label,
        bound: {
          for (final e in a.variables.entries) e.key: run.evaluate(e.value),
          if (offset.isNotEmpty) 'offset': run.evaluate(offset),
        },
        // The button's actions run on the chain that showed the toast,
        // whenever it's pressed, with its `${result}` then.
        onAction: label.trim().isEmpty ? null : () => unawaited(_deferred(a.actions, runner)),
      );
    case ConfirmAction():
      final outcome = await run.host.ui.confirm(
        a,
        title: run.text(a.title),
        message: run.text(a.message),
        caption: run.text(a.caption),
        confirmLabel: run.text(a.confirmLabel),
        cancelLabel: run.text(a.cancelLabel),
        bound: {for (final e in a.variables.entries) e.key: run.evaluate(e.value)},
        params: run.json(a.params),
      );
      // What a dialog screen gave back (a reason typed into it) is the
      // `${result}` its confirm actions read.
      if (outcome.values case final Map<Object?, Object?> v when v.isNotEmpty) run.result = v;
      await run.run(outcome.confirmed ? a.actions : a.cancelActions);
    case DelayAction():
      // On the animation clock, as the motion it's usually timed against:
      // slowed animations (timeDilation) slow the chain with them.
      await run.wait(Duration(milliseconds: delayMilliseconds(a, run)) * timeDilation);
    case CopyToClipboardAction():
      await Clipboard.setData(ClipboardData(text: run.text(a.text)));
    case EditTextAction():
      _editText(a, run);
    case FocusAction():
      await _focus(a, run);
    case ScrollToAction():
      await _scrollTo(a, run);
    case ControlTrackAction(command: TrackCommand.step):
      // Turns a track by its steps, as if dragged (render/drag_track.dart).
      final tree = run.host.tree;
      final steps = double.tryParse(run.text(a.steps).trim())?.round() ?? 0;
      if (tree != null) await DragTracks.step(tree, a.node, steps);
    case ControlTrackAction(command: TrackCommand.animateTo):
      // Moves a track to a value, reporting it as a whole change.
      final tree = run.host.tree;
      final value = numberOfExpression(a.value, run);
      if (tree != null && value != null) await DragTracks.animateTo(tree, a.node, value.toDouble());
    case ControlTransformAction(command: TransformCommand.reset) when TransformGestures.hasIn(run.host.tree, a.node):
      // A node with a transform gesture springs back to its rest pose.
      await TransformGestures.reset(run.host.tree!, a.node);
    case ControlTransformAction(command: TransformCommand.reset):
      // No transform gesture: a dismissible or pan springs back (the legacy
      // controlDrag reset, which named either).
      await _controlFollow(run, a.node, DismissCommand.reset, DragDirection.right);
    case ControlTransformAction(command: TransformCommand.scaleBy):
      // Zoom buttons: scale a transform gesture about its viewport's middle.
      final tree = run.host.tree;
      final factor = double.tryParse(run.text(a.value).trim());
      if (tree != null && factor != null) await TransformGestures.zoom(tree, a.node, factor);
    case ControlTransformAction(command: TransformCommand.animateTo):
      // Spring a transform gesture to a pose: {x, y, scale, rotation...}.
      final tree = run.host.tree;
      final pose = _poseOf(a.value.trim().startsWith(r'${') ? await _withScripts(run, () => run.evaluate(a.value)) : a.value);
      if (tree != null && pose.isNotEmpty) await TransformGestures.moveTo(tree, a.node, pose);
    case ControlDismissibleAction():
      // A node that follows the pointer (gestures/drag_motion.dart): fling it
      // off, bring it back from a side, or reset or shake it.
      await _controlFollow(run, a.node, a.command, a.direction);
    case PaginateAction():
      await paginateAction(a, run);
  }
}

/// Runs [command] on each of the comma-separated nodes [ids] that follows
/// the pointer.
Future<void> _controlFollow(ActionRun run, String ids, DismissCommand command, DragDirection direction) async {
  final tree = run.host.tree;
  await Future.wait([
    for (final id in ids.split(','))
      if (id.trim().isNotEmpty) DragMotionControl.control(id.trim(), command, direction, tree: tree),
  ]);
}

/// Runs [actions] later on [run] (a toast's button), reporting a failure.
Future<void> _deferred(List<ActionDef> actions, ActionRun run) async {
  try {
    await run.run(actions);
  } on ActionsCanceled {
    // The screen went.
  } catch (e, s) {
    run.host.reportError(e, s);
  }
}

// --- delay ---------------------------------------------------------------------

/// How long [a] waits: its duration formula when that gives a number, else
/// its fixed time.
int delayMilliseconds(DelayAction a, ActionRun run) {
  if (a.duration.trim().isEmpty) return a.ms;
  final v = numberOfExpression(a.duration, run);
  return v == null || v < 0 ? a.ms : v.round();
}

/// The number [text] gives: a `${...}` expression's value as it is (a
/// number stays a number, never formatted text such as "24,000"), else the
/// interpolated text read as a number. Null when it gives none.
double? numberOfExpression(String text, ActionRun run) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (t.startsWith(r'${') && t.endsWith('}') && t.indexOf(r'${', 2) < 0) {
    try {
      final v = run.evaluate(t);
      if (v is num) return v.isFinite ? v.toDouble() : null;
      if (v is String) return double.tryParse(v.trim());
    } catch (_) {}
  }
  final n = double.tryParse(run.text(t).trim());
  return n != null && n.isFinite ? n : null;
}

// --- variables and values ----------------------------------------------------------

Future<void> _setVariable(SetVariableAction a, ActionRun run) async {
  final written = a.variable.trim();
  if (written.isEmpty) return;
  // A component's `variable` parameter (`props.open`) names the caller's.
  final (target, name) = referencedVariable(run.context.scope, written);
  final found = variableOf(target, name);
  if (found == null) {
    // Not one of the screen's variables: the app's (a context with its own
    // variables), set as is.
    if (run.host is! CoreActionContext) run.context.setVariable(name, run.evaluate(a.write.value));
    return;
  }
  final (scope, variable) = found;
  if (variable.isComputed) return;
  final path = ValuePath.parse(name);
  if (path == null) return;
  (Object?, VariableType, Object?) calculate() {
    final whole = scope.valueOf(path.root, scope);
    final current = path.keys.isEmpty ? whole : path.readFrom(whole);
    // Re-read the current value after awaiting a worker result.
    final type = path.keys.isEmpty ? variable.type : typeOf(current);
    final next = path.keys.isNotEmpty && a.write.op == WriteOp.set
        ? evaluateValue(a.write.value, run.expressions, run.scope)
        : applyWrite(current, type, a.write, run.expressions, run.scope);
    return (current, type, next);
  }
  final scripts = readPath(run.scope, 'script');
  final (current, type, next) = scripts is ScriptsScope ? await scripts.resolve(calculate) : calculate();
  if (run.isCanceled) return;
  // A number glides to its new value over animateMs.
  final ms = a.animateMs.trim().isEmpty ? 0 : (double.tryParse(run.text(a.animateMs).trim()) ?? 0).round();
  final number = type == VariableType.integer || type == VariableType.decimal;
  if (ms > 0 && number && path.keys.isEmpty && current is num && next is num) {
    if (next == current) return;
    final done = VariableAnimator.play(scope, path.root,
        from: current.toDouble(), to: next.toDouble(), duration: Duration(milliseconds: ms), curve: a.curve, glide: true);
    // The chain stops (its node left): so does the glide.
    final remove = run.onCancel(() => VariableAnimator.stopGlide(scope, path.root));
    await done;
    remove();
    return;
  }
  // A plain set takes over from a glide.
  VariableAnimator.stopGlide(scope, path.root);
  setVariableIn(target, name, next);
}

/// Runs an `AnimationController` command: on node [AnimateAction.node]'s
/// animation, on every shown instance (and its particles, by their reserved
/// name, for `forward`), or on a number variable's timeline. The chain waits
/// for it to end.
Future<void> _animate(AnimateAction a, ActionRun run) async {
  if (a.variable.trim().isNotEmpty) return _animateVariable(a, run);
  final name = run.text(a.animation).trim();
  final named = run.text(a.node).trim();
  final id = named.isEmpty ? (run.node?.id ?? '') : named;
  double? number(String text) => text.trim().isEmpty ? null : numberOfExpression(text, run);
  final from = number(a.from), target = number(a.target), ms = number(a.duration)?.round();
  final tree = run.host.tree;
  final plays = <Future<void>>[];
  if (tree != null) {
    var boxes = scopedBoxesOf(tree, id, run.instance);
    // A node key names it too.
    if (boxes.isEmpty) boxes = [for (final b in tree.boxes.toList()) if (b.node?.key == id) b];
    for (final b in boxes) {
      final player = b.animations;
      if (player == null || !b.attached) continue;
      plays.add(player.command(name, a.command, from: from, target: target, durationMs: ms, curve: a.curve, spring: a.spring));
    }
  }
  if (a.command == AnimateCommand.forward && named.isNotEmpty) plays.add(ParticlePlayers.play(id, name));
  await Future.wait(plays);
}

/// `animate` on a number variable: its timeline (an unbounded controller)
/// plays to a target (`animateTo`, `animateBack`), holds (`stop`), carries
/// on (`forward`: what it holds, else to the target from where it is) or
/// jumps (`set`). A variable that isn't there (or is computed) is skipped.
Future<void> _animateVariable(AnimateAction a, ActionRun run) async {
  final found = variableOf(run.context.scope, a.variable.trim());
  if (found == null || found.$2.isComputed) return;
  final (scope, variable) = found;
  final name = variable.name;
  double? number(String text) => text.trim().isEmpty ? null : numberOfExpression(text, run);
  final target = number(a.target);
  Duration duration() {
    final ms = number(a.duration);
    return Duration(milliseconds: ms != null && ms >= 0 ? ms.round() : 300);
  }

  switch (a.command) {
    case AnimateCommand.forward:
      if (VariableAnimator.resume(scope, name) || VariableAnimator.isPlaying(scope, name)) {
        await VariableAnimator.of(scope, name)?.done.future;
        return;
      }
      // Nothing to carry on: to the target from where the value is.
      if (target == null) return;
      await VariableAnimator.play(scope, name,
          from: number(a.from), to: target, duration: duration(), curve: a.curve ?? AnimationCurve.linear, fromCurrentPlace: true);
    case AnimateCommand.animateTo || AnimateCommand.animateBack:
      if (target == null) return;
      if (variable.type != VariableType.integer && variable.type != VariableType.decimal) {
        // Not a number: nothing to glide through; it takes the value.
        setVariableIn(run.context.scope, name, run.evaluate(a.target));
        return;
      }
      // Setting a value stops its timeline (`controller.value =`): a plain
      // set takes over from an animateTo, as it did from a set's glide.
      final done = VariableAnimator.play(scope, name,
          from: number(a.from),
          to: target,
          duration: duration(),
          curve: a.curve ?? AnimationCurve.linear,
          glide: true,
          spring: a.spring);
      // The chain stops (its node left): so does the timeline.
      final remove = run.onCancel(() => VariableAnimator.stopGlide(scope, name));
      await done;
      remove();
    case AnimateCommand.stop:
      VariableAnimator.pause(scope, name);
    case AnimateCommand.set:
      if (target != null) VariableAnimator.seek(scope, name, target);
    case AnimateCommand.reset:
      VariableAnimator.stop(scope, name);
      if (number(a.from) case final double from) VariableAnimator.write(scope, name, from);
    case AnimateCommand.reverse || AnimateCommand.toggle || AnimateCommand.repeat:
      // A variable's timeline has no bounds to reverse or repeat between.
      break;
  }
}

// --- haptics -------------------------------------------------------------------------

void _haptic(HapticKind kind) {
  unawaited(switch (kind) {
    HapticKind.selection => HapticFeedback.selectionClick(),
    HapticKind.light => HapticFeedback.lightImpact(),
    HapticKind.medium => HapticFeedback.mediumImpact(),
    HapticKind.heavy => HapticFeedback.heavyImpact(),
    HapticKind.vibrate => HapticFeedback.vibrate(),
  });
}

/// Sets node values: a property bound to one variable sets the variable;
/// others go in the context's node values. Inside a component instance the
/// node is that instance's (ids are local to its definition): its values are
/// set on that instance's box only.
void _setValue(String nodeId, List<NodeValue> values, ActionRun run) {
  final tree = run.host.tree;
  final inInstance = tree == null
      ? const <NodeBox>[]
      : [for (final b in scopedBoxesOf(tree, nodeId, run.instance)) if (componentInstanceOf(b.instance) != null) b];
  if (inInstance.isNotEmpty) return _setInstanceValues(tree!, nodeId, inInstance, values, run);
  final node = tree?.resolve(nodeId) ?? tree?.source.node(nodeId);
  for (final v in values) {
    Object? value;
    switch (v.mode) {
      case NodeValueMode.set:
        value = v.value is String ? run.evaluate(v.value! as String) : v.value;
      case NodeValueMode.toggle:
        final current = node == null ? null : readJsonPath(node.toJson(), v.path);
        value = !(current == true || current == 'true');
      case NodeValueMode.sync:
        value = run.value;
    }
    final bound = node?.bind[v.path];
    final variable = bound == null ? null : exactPath(bound);
    if (variable != null && variableOf(run.context.scope, variable) != null) {
      setVariableIn(run.context.scope, variable, value);
      continue;
    }
    run.host.nodeValues?.set(nodeId, v.path, value);
  }
}

void _setInstanceValues(RenderTree tree, String nodeId, List<NodeBox> boxes, List<NodeValue> values, ActionRun run) {
  for (final box in boxes) {
    final node = tree.resolve(nodeId, instance: box.instance);
    for (final v in values) {
      Object? value;
      switch (v.mode) {
        case NodeValueMode.set:
          value = v.value is String ? run.evaluate(v.value! as String) : v.value;
        case NodeValueMode.toggle:
          final current = node == null ? null : readJsonPath(node.toJson(), v.path);
          value = !(current == true || current == 'true');
        case NodeValueMode.sync:
          value = run.value;
      }
      // A property bound to one variable sets that variable, where the node
      // reads it (the instance's own variables, a `variable` parameter).
      final bound = box.source.node(nodeId)?.bind[v.path];
      final variable = bound == null ? null : exactPath(bound);
      final scope = tree.binder?.scopeFor(box.source, nodeId, box.instance);
      if (variable != null && scope != null && variableOf(scope, variable) != null) {
        setVariableIn(scope, variable, value);
        continue;
      }
      tree.setInstanceValue(nodeId, box.instance, v.path, value);
    }
  }
}

// --- flow --------------------------------------------------------------------------------

Future<void> _forEach(ForEachAction a, ActionRun run) async {
  final path = a.items.trim();
  if (path.isEmpty) return;
  var value = path.contains(r'${') ? run.evaluate(path) : readPath(run.scope, path);
  // A cloud variable keeps its documents under `data`.
  if (value is Map && value['data'] is List) value = value['data'];
  if (value is! List) return;
  final items = List<Object?>.of(value);
  for (var i = 0; i < items.length; i++) {
    // `${loop.*}` holds for the whole turn; `${result.*}` until an action
    // of the turn gives a result of its own.
    final turn = {'item': items[i], 'index': i};
    await run.nested(turn, names: {'loop': turn}).run(a.actions);
  }
}

// --- forms and text fields -------------------------------------------------------------

Future<void> _focus(FocusAction a, ActionRun run) async {
  final tree = run.host.tree;
  TextFieldHandle? find() => tree == null || a.node.isEmpty ? null : TextFieldHandle.near(tree, a.node, run.instance);
  var handle = find();
  if (a.unfocus) {
    handle == null ? TextFieldHandle.unfocusAll() : handle.focusNode.unfocus();
    return;
  }
  // A field the same tap reveals (an inline "Add card") is built in the
  // frames that follow: wait for it, a few frames at most.
  for (var frame = 0; handle == null && frame < 8 && !run.isCanceled; frame++) {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    handle = find();
  }
  if (handle == null) return;
  handle.focusNode.requestFocus();
  if (a.selectAll) {
    handle.controller.selection = TextSelection(baseOffset: 0, extentOffset: handle.controller.text.length);
  }
}

void _editText(EditTextAction a, ActionRun run) {
  final tree = run.host.tree;
  final handle = tree == null ? null : TextFieldHandle.near(tree, a.node, run.instance);
  if (handle == null) return;
  final c = handle.controller;
  final v = c.value;
  final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
  String text(String t) => run.text(t);
  TextEditingValue replace(int start, int end, String with_, {int? cursor}) => TextEditingValue(
        text: v.text.replaceRange(start, end, with_),
        selection: TextSelection.collapsed(offset: cursor ?? start + with_.length),
      );
  switch (a.operation) {
    case EditTextOperation.insert:
      c.value = replace(sel.start, sel.end, text(a.text));
    case EditTextOperation.setText:
      c.value = TextEditingValue(text: text(a.text), selection: TextSelection.collapsed(offset: text(a.text).length));
    case EditTextOperation.clear:
      c.clear();
    case EditTextOperation.focus:
      handle.focusNode.requestFocus();
    case EditTextOperation.wrap:
      final before = text(a.before), after = text(a.after ?? a.before);
      final inner = v.text.substring(sel.start, sel.end);
      c.value = TextEditingValue(
        text: v.text.replaceRange(sel.start, sel.end, '$before$inner$after'),
        selection: TextSelection(baseOffset: sel.start + before.length, extentOffset: sel.start + before.length + inner.length),
      );
    case EditTextOperation.replaceWord:
      var start = sel.start;
      while (start > 0 && !RegExp(r'\s').hasMatch(v.text[start - 1])) {
        start--;
      }
      c.value = replace(start, sel.end, text(a.text));
    case EditTextOperation.toggleList:
      final lineStart = v.text.lastIndexOf('\n', sel.start == 0 ? 0 : sel.start - 1) + 1;
      final marker = a.numbered ? '1. ' : '- ';
      final listed = v.text.startsWith(marker, lineStart);
      c.value = listed
          ? replace(lineStart, lineStart + marker.length, '', cursor: (sel.start - marker.length).clamp(lineStart, v.text.length))
          : replace(lineStart, lineStart, marker, cursor: sel.start + marker.length);
  }
}

/// Node [id]'s boxes as an action run in [instance] names it: ids are local
/// to a component's definition, so inside an instance, that instance's own
/// (two cards of one component each scroll, animate and focus their own
/// nodes); on a page, the page's. When none is there, every box of that id
/// (a page action naming a node inside a component).
List<NodeBox> scopedBoxesOf(RenderTree tree, String id, Object? instance) {
  final all = tree.boxesOf(id).toList();
  final here = componentInstanceOf(instance);
  final own = [for (final b in all) if (componentInstanceOf(b.instance) == here) b];
  return own.isNotEmpty ? own : all;
}

/// The copy of repeated node [id] that a list built for its item [item]:
/// the one whose `${item.id}` (or `${item.key}`, or the item itself, as
/// text) reads [item], else the one whose `${index}` is [item]. Each copy is
/// asked in its own scope, so a node inside an item template matches too.
NodeBox? repeatOf(RenderTree tree, String id, String item, {Object? instance}) {
  final binder = tree.binder;
  if (binder == null) return null;
  NodeBox? byIndex;
  final index = int.tryParse(item);
  for (final b in scopedBoxesOf(tree, id, instance)) {
    if (!b.attached) continue;
    final scope = binder.scopeFor(b.source, b.id, b.instance);
    if (scope == null) continue;
    final value = readPath(scope, 'item');
    final key = value is Map ? (value['id'] ?? value['key']) : value;
    if (key != null && '$key' == item) return b;
    if (index != null && byIndex == null && readPath(scope, 'index') == index) byIndex = b;
  }
  return byIndex;
}

/// The box (global) of the node [OpenModalAction.anchorNode] names, in a
/// list the copy built for [OpenModalAction.anchorItem]. Opened from a
/// screen's `load`, the node may not be laid out yet: give it a few frames.
Future<Rect?> _namedAnchor(OpenModalAction a, ActionRun run) async {
  final tree = run.host.tree;
  final id = run.text(a.anchorNode).trim();
  final item = run.text(a.anchorItem).trim();
  if (tree == null || id.isEmpty) return null;
  NodeBox? find() => (item.isEmpty ? tree.boxOf(id) ?? tree.boxesOf(id).firstOrNull : repeatOf(tree, id, item));
  var box = find();
  for (var i = 0; i < 6 && (box == null || !box.attached || !box.hasSize); i++) {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    box = find();
  }
  if (box == null || !box.attached || !box.hasSize) return null;
  return MatrixUtils.transformRect(box.getTransformTo(null), Rect.fromLTWH(0, 0, box.size.width, box.size.height));
}

/// Whether the scrolling rows and columns around [box] have laid out
/// something to scroll (or there are none).
bool _scrollsLaidOut(RenderObject box) {
  for (var p = box.parent; p != null; p = p.parent) {
    if (p is RenderDesignScroll && p.interactive) return p.hasSize && p.maxScrollExtent > 0;
  }
  return true;
}

/// Scrolls the scroll views around node [ScrollToAction.node] (those
/// along [ScrollToAction.axis] only, when it's set) so the node sits at
/// its alignment, less its offset: each view reveals the one inside it.
Future<void> _scrollTo(ScrollToAction a, ActionRun run) async {
  final tree = run.host.tree;
  final id = run.text(a.node).trim();
  final item = run.text(a.item).trim();
  NodeBox? named() => tree == null ? null : (tree.boxOf(id, instance: run.instance) ?? scopedBoxesOf(tree, id, run.instance).lastOrNull);
  final box = tree == null ? null : (item.isEmpty ? named() : repeatOf(tree, id, item, instance: run.instance)) ?? named();
  if (box == null || !box.attached) {
    // Nothing to reveal: said, not skipped silently (the chain goes on).
    if (tree != null) {
      run.host.reportError(
          ActionFailed(a.type, 'no node "$id"${item.isEmpty ? '' : ' (item $item)'} is on screen to scroll to${a.node.contains(r'${') ? ' ("${a.node}" gave "$id")' : ''}',
              nodeId: run.node?.id),
          StackTrace.current,
          action: a.type);
    }
    return;
  }
  // Fonts still loading (a layout shows after waiting a while for them)
  // re-measure the text above the target when they arrive: wait for them,
  // so a jump from a screen's `load` lands where it means.
  if (FontLoads.loading) {
    await FontLoads.settled.timeout(const Duration(seconds: 10), onTimeout: () {});
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    if (!box.attached) return;
  }
  // Run from a screen's `load`, the views around it may not have their
  // content's extent yet: give layout a few frames.
  for (var i = 0; i < 4 && !_scrollsLaidOut(box); i++) {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }
  if (!box.attached) return;
  final target = box.contentBox ?? box;
  final offset = a.offsetFormula.isEmpty ? a.offset : (double.tryParse(run.text(a.offsetFormula).trim()) ?? a.offset);
  final duration = Duration(milliseconds: a.durationMs);
  final Curve curve = switch (AnimationCurve.parse(a.curve)) {
    AnimationCurve.linear => Curves.linear,
    AnimationCurve.easeIn => Curves.easeIn,
    AnimationCurve.easeOut => Curves.easeOut,
    AnimationCurve.fastOutSlowIn => Curves.fastOutSlowIn,
    AnimationCurve.easeOutCubic => Curves.easeOutCubic,
    AnimationCurve.easeInOutCubic => Curves.easeInOutCubic,
    AnimationCurve.decelerate => Curves.decelerate,
    AnimationCurve.emphasized => const Cubic(0.2, 0, 0, 1),
    _ => Curves.easeInOut,
  };
  final scrolls = <Future<void>>[];
  var viewports = 0;
  RenderObject revealed = target;
  for (var p = target.parent; p != null; p = p.parent) {
    if (p is RenderDesignScroll && p.interactive) {
      viewports++;
      final along=a.axis==null || (p.axis==rendering.Axis.horizontal)==(a.axis==ScrollAxis.horizontal);
      if(along){
        final to=(p.getOffsetToReveal(revealed,a.alignment)-offset).clamp(0.0,p.maxScrollExtent);
        if(a.durationMs<=0){p.jumpTo(to);}else{scrolls.add(p.animateTo(to,duration:duration,curve:curve));}
      }
      revealed=p;
      continue;
    }
    if (p is! RenderViewportBase) continue;
    final position = p.offset;
    if (position is! ScrollPosition) continue;
    viewports++;
    final along = a.axis == null || (p.axis == rendering.Axis.horizontal) == (a.axis == ScrollAxis.horizontal);
    if (along && position.hasContentDimensions) {
      final to = (p.getOffsetToReveal(revealed, a.alignment).offset - offset)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((to - position.pixels).abs() >= 0.5) {
        if (a.durationMs <= 0) {
          position.jumpTo(to);
        } else {
          scrolls.add(position.animateTo(to, duration: duration, curve: curve));
        }
      }
    }
    revealed = p;
  }
  // No scroll view of its own around it: as the render tree reveals it.
  if (viewports == 0 && a.axis == null) target.showOnScreen(duration: duration, curve: curve);
  await Future.wait(scrolls);
}

/// Whether [text] holds `${...}` (an expression, not a literal).
bool isExpression(String text) => text.contains(r'${') || FormulaEvaluator.exactExpression(text) != null;

/// A pose from an action's value: a map, or its JSON text; numbers only.
Map<String, double> _poseOf(Object? v) {
  if (v is String) {
    try {
      v = jsonDecode(v);
    } catch (_) {
      return const {};
    }
  }
  if (v is! Map) return const {};
  return {
    for (final e in v.entries)
      if (const {'x', 'y', 'scale', 'rotation', 'scaleX', 'scaleY'}.contains(e.key))
        if (e.value is num) '${e.key}': (e.value as num).toDouble() else if (double.tryParse('${e.value}') case final double d) '${e.key}': d,
  };
}

/// [evaluate] once the script formulas it reads have answered (a worker on
/// the web answers null at first), as a setVariable's value does.
Future<T> _withScripts<T>(ActionRun run, T Function() evaluate) async {
  final scripts = readPath(run.scope, 'script');
  return scripts is ScriptsScope ? await scripts.resolve(evaluate) : evaluate();
}
