// One typed handler per action type, over an ActionRun (the chain's scope
// and result, its context's services, UI and node tree), without
// BuildContext.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart' as rendering show Axis;
import 'package:flutter/rendering.dart' show RenderObject, RenderViewportBase;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback, TextEditingValue, TextSelection;
import 'package:flutter/widgets.dart' show Cubic, Curve, Curves, ScrollPosition;
import 'package:just_audio/just_audio.dart' as audio;

import 'action_error.dart' show CodedFailure;
import '../../render/layout/design_scroll.dart' show RenderDesignScroll;
import '../../render/node_tree.dart' show NodeBox, NodeTree;
import '../../render/drag_track.dart' show DragTracks;
import '../../render/layout/design_scroll.dart';
import '../gestures/drag_motion.dart' show DragMotionControl;
import '../../render/transform_gesture.dart' show TransformGestures;
import '../../render/play.dart' show EffectPlayers;
import '../../render/particles.dart' show ParticlePlayers;
import '../../scripting/formula_scripts.dart' show ScriptsScope;
import '../../services/services.dart';
import '../expressions/formula.dart';
import '../lists/paginate_action.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'app_data_sources.dart';
import 'context.dart';
import 'feedback_theme.dart' show Look;
import 'runner.dart';
import 'script_host.dart';
import 'text_fields.dart';
import 'values.dart';
import 'variable_animator.dart';
import 'printing.dart';

/// Runs one action of a chain. Throws to stop the chain.
typedef ActionHandler = FutureOr<void> Function(ActionDef action, ActionRun run);

/// Runs [a] with its built-in handler.
Future<void> handleAction(ActionDef a, ActionRun run) async {
  switch (a) {
    case NavigateAction():
      await run.host.ui.navigate(a, params: run.json(a.params), baseParams: run.json(a.baseParams));
    case OpenModalAction():
      final result = await run.host.ui.openModal(a, params: run.json(a.params));
      if (result != null) run.result = result;
    case CloseModalAction():
      run.host.ui.closeModal(a.result.isEmpty ? null : run.json(a.result));
    case PrintAction():
      await printNodeAction(a.node, run);
    case OpenLinkAction():
      final url = run.text(a.url).trim();
      if (url.isNotEmpty) await run.context.services.openUrl(url);
    case SubmitFormAction():
      await _submitForm(a, run);
    case SetValueAction():
      _setValue(a.node, a.values, run);
    case SetVariantAction():
      _setValue(a.node, [NodeValue('props.current', value: a.variant)], run);
    case SetVariableAction():
      await _setVariable(a, run);
    case AnimateVariableAction():
      await _animateVariable(a, run);
    case HapticAction():
      _haptic(a.kind);
    case RunScriptAction():
      await runScriptAction(a, run);
    case CallFunctionAction():
      final f = run.host.functions[a.name];
      if (f != null) {
        run.result = await f(run.context, run.json(a.params));
      } else if (a.name == 'media.probe' || a.name == 'media.import') {
        run.result = await _mediaImport(a, run);
      } else if (a.name == 'media.export' || a.name == 'media.cancelExport') {
        run.result = await _mediaExport(a, run);
      } else {
        throw StateError('No function named [${a.name}]');
      }
    case CallApiAction():
      await _callApi(a, run);
    case SetStorageAction():
      await _setStorage(a, run);
    case CloudDocumentsAction():
      await _cloudDocuments(a, run);
    case LoadCloudDataAction():
      await _loadCloudData(a, run);
    case AuthAction():
      await _auth(a, run);
    case IfAction():
      // A condition reading a script formula waits for its answer.
      final holds = a.condition != null && await _withScripts(run, () => run.expressions.test(a.condition!, run.scope));
      await run.run(holds ? a.then : a.orElse);
    case ForEachAction():
      await _forEach(a, run);
    case CloudFilesAction():
      await _cloudFiles(a, run);
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
      await run.wait(Duration(milliseconds: delayMilliseconds(a, run)));
    case CloudDataAction():
      await _cloudData(a, run);
    case CloudBatchAction():
      for (final step in a.steps) {
        await _cloudData(step, run);
      }
    case DownloadFileAction():
      final services = run.host.services;
      if (services is! Services) throw StateError('downloadFile needs Services.');
      run.result = {'saved': await services.exports.saveText(fileName: run.text(a.fileName), text: run.text(a.text), mimeType: run.text(a.mimeType))};
    case CopyToClipboardAction():
      await Clipboard.setData(ClipboardData(text: run.text(a.text)));
    case EditTextAction():
      _editText(a, run);
    case PaywallAction():
      await _paywall(a, run);
    case FocusAction():
      _focus(a, run);
    case SpeakAction():
      _speak(a, run);
    case ScrollToAction():
      await _scrollTo(a, run);
    case PlaySoundAction():
      _playSound(a, run);
    case ControlDragAction(command: DragCommand.step):
      // Turns a drag track by its steps, as if dragged (render/drag_track.dart).
      final tree = run.host.tree;
      final steps = double.tryParse(run.text(a.steps).trim())?.round() ?? 0;
      if (tree != null) await DragTracks.step(tree, a.node, steps);
    case ControlDragAction(command: DragCommand.reset) when TransformGestures.hasIn(run.host.tree, a.node):
      // A node with a transform gesture springs back to its rest pose.
      await TransformGestures.reset(run.host.tree!, a.node);
    case ControlDragAction(command: DragCommand.zoom):
      // Zoom buttons: scale a transform gesture about its viewport's middle.
      final tree = run.host.tree;
      final factor = double.tryParse(run.text(a.value).trim());
      if (tree != null && factor != null) await TransformGestures.zoom(tree, a.node, factor);
    case ControlDragAction(command: DragCommand.pose):
      // Spring a transform gesture to a pose: {x, y, scale, rotation...}.
      final tree = run.host.tree;
      final pose = _poseOf(a.value.trim().startsWith(r'${') ? await _withScripts(run, () => run.evaluate(a.value)) : a.value);
      if (tree != null && pose.isNotEmpty) await TransformGestures.moveTo(tree, a.node, pose);
    case ControlDragAction():
      // A node that follows the pointer (gestures/drag_motion.dart): fling it
      // off, bring it back from a side, or reset or shake it; each of the
      // comma-separated nodes.
      final tree = run.host.tree;
      await Future.wait([
        for (final id in a.node.split(','))
          if (id.trim().isNotEmpty) DragMotionControl.control(id.trim(), a.command, a.direction, tree: tree),
      ]);
    case PlayAnimationAction():
      // A node's one-shot effect, on every shown instance; the chain waits
      // for it, including a particle burst with the reserved particles name.
      await Future.wait([EffectPlayers.play(a.node, a.animation), ParticlePlayers.play(a.node, a.animation)]);

      break;
    case PaginateAction():
      await paginateAction(a, run);
    case UnknownAction():
      break;
  }
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

Services? _services(ActionRun run) => switch (run.context.services) {
      final Services s => s,
      _ => null,
    };

Services _require(ActionRun run, String what) =>
    _services(run) ?? (throw StateError('$what needs the app\'s Services.'));

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
  final name = a.variable.trim();
  if (name.isEmpty) return;
  final found = variableOf(run.context.scope, name);
  if (found == null) {
    // Not one of the screen's variables: the app's (a context with its own
    // variables), set as is.
    if (run.host is! RuntimeActionContext) run.context.setVariable(name, run.evaluate(a.write.value));
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
  setVariableIn(run.context.scope, name, next);
}

/// Plays, pauses, resumes, stops or seeks a number variable's timeline.
/// A play or a resume completes when the
/// timeline ends; a variable that isn't there (or is computed) is skipped.
Future<void> _animateVariable(AnimateVariableAction a, ActionRun run, {bool fromCurrentPlace = false}) async {
  final found = variableOf(run.context.scope, a.variable.trim());
  if (found == null || found.$2.isComputed) return;
  final (scope, variable) = found;
  final name = variable.name;
  double? number(String text) => numberOfExpression(text, run);

  switch (a.mode) {
    case AnimateVariableMode.resume:
      if (VariableAnimator.resume(scope, name) || VariableAnimator.isPlaying(scope, name)) {
        await VariableAnimator.of(scope, name)?.done.future;
        return;
      }
      // Nothing to resume: play from where the value is.
      return _animateVariable(
        AnimateVariableAction(
            variable: a.variable, from: a.from, to: a.to, durationMs: a.durationMs, duration: a.duration, curve: a.curve),
        run,
        fromCurrentPlace: true,
      );
    case AnimateVariableMode.play:
      final to = number(a.to);
      if (to == null) return;
      var ms = a.durationMs;
      if (a.duration.trim().isNotEmpty) {
        final bound = number(a.duration);
        if (bound != null && bound >= 0) ms = bound.round();
      }
      await VariableAnimator.play(scope, name,
          from: number(a.from),
          to: to,
          duration: Duration(milliseconds: ms),
          curve: a.curve,
          fromCurrentPlace: fromCurrentPlace);
    case AnimateVariableMode.pause:
      VariableAnimator.pause(scope, name);
    case AnimateVariableMode.stop:
      VariableAnimator.stop(scope, name);
    case AnimateVariableMode.seek:
      final to = number(a.to);
      if (to != null) VariableAnimator.seek(scope, name, to);
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
/// others go in the context's node values.
void _setValue(String nodeId, List<NodeValue> values, ActionRun run) {
  final tree = run.host.tree;
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

// --- APIs ------------------------------------------------------------------------

Future<void> _callApi(CallApiAction a, ActionRun run) async {
  final params = {for (final e in a.params.entries) e.key: e.value.trim().isEmpty ? null : run.evaluate(e.value)}
    ..removeWhere((_, v) => v == null);
  Object? response;
  var ok = true;
  try {
    response = await run.context.services.callApi(a.api, params: params);
    if (response case {'isSuccess': final bool success}) ok = success;
  } on ApiRequestFailed catch (failed) {
    if (a.onError.isEmpty) rethrow;
    ok = false;
    response = failed.response.toValue();
  }
  run.result = response;
  if (ok) {
    await run.run(a.onSuccess);
  } else {
    await run.run(a.onError);
  }
}

// --- storage ----------------------------------------------------------------------

Future<void> _setStorage(SetStorageAction a, ActionRun run) async {
  final storage = _require(run, 'Storage').storage;
  if (a.operation == StorageOperation.clear) return storage.clear();
  final key = run.text(a.key).trim();
  final path = ValuePath.parse(key);
  if (key.isEmpty) return;
  if (a.operation == StorageOperation.remove) {
    if (path == null || path.keys.isEmpty) return storage.remove(key);
    return storage.put(path.root, removeAtPath(storage.get(path.root), path.keys));
  }
  final nested = path != null && path.keys.isNotEmpty;
  final current = nested ? path.readFrom(storage.get(path.root)) : storage.get(key);
  if (a.skipIfExists && current != null) return;
  final next = applyWrite(current, a.valueType, a.write, run.expressions, run.scope);
  if (!nested) return storage.put(key, next);
  final root = setAtPath(storage.get(path.root), path.keys, next);
  if (root != null) await storage.put(path.root, root);
}

// --- cloud data ---------------------------------------------------------------------

CloudQuery _query(List<WhereFilter> where, List<OrderBy> orderBy, int? limit, ActionRun run) => resolveCloudQuery(
      CloudQueryDef(enabled: true, where: where, orderBy: orderBy, limit: limit),
      run.expressions,
      run.scope,
    );

Future<void> _cloudData(CloudDataAction a, ActionRun run) async {
  final db = _require(run, 'Cloud data').cloud;
  final path = run.text(a.collection).trim();
  final id = run.text(a.id).trim();
  Json fields({required bool create}) => CloudFieldValues.buildWrite(
        fields: a.fields,
        schema: db.rules.schemaFor(path),
        evaluate: run.evaluate,
        create: create,
      );
  final Object? result = switch (a.operation) {
    CloudDataOperation.create => await db.addDocument(path, fields(create: true), id: id.isEmpty ? null : id, skipIfExists: false),
    CloudDataOperation.update => await db.updateDocument(path, id, fields(create: false)).then((_) => id),
    CloudDataOperation.delete => await db.removeDocument(path, id),
    CloudDataOperation.get => await db.getDocument(path, id),
    CloudDataOperation.query =>
      await db.query(path, _query(a.where, a.orderBy, a.limit, run), loadRelated: a.loadRelated),
    CloudDataOperation.count => await db.aggregate(path, _query(a.where, const [], null, run), CloudAggregate.count),
    CloudDataOperation.sum =>
      await db.aggregate(path, _query(a.where, const [], null, run), CloudAggregate.sum, field: a.aggregateField),
    CloudDataOperation.average =>
      await db.aggregate(path, _query(a.where, const [], null, run), CloudAggregate.average, field: a.aggregateField),
  };
  run.result = result;
  if (a.resultVariable.isNotEmpty) setVariableIn(run.context.scope, a.resultVariable, result);
}


Future<void> _cloudDocuments(CloudDocumentsAction a, ActionRun run) async {
  final db = _require(run, 'Cloud data').cloud;
  final path = run.text(a.path).trim();
  final id = run.text(a.id).trim();
  Object? document() => a.raw ? parseLoose(a.value) : evaluateValue(a.value, run.expressions, run.scope);
  switch (a.operation) {
    case CloudDocumentsOperation.add:
      final value = document();
      final doc = value is Map ? {for (final e in value.entries) '${e.key}': e.value} : <String, Object?>{'value': value};
      run.result = await db.addDocument(path, doc, id: a.autoId || id.isEmpty ? null : id, skipIfExists: a.skipIfExists);
    case CloudDocumentsOperation.update:
      final current = await db.getDocument(path, id);
      final field = run.text(a.field).trim();
      final fieldPath = ValuePath.parse(field);
      final old = fieldPath?.readFrom(current?[fieldPath.root]);
      final write = a.raw ? ValueWrite(op: a.write.op, value: a.value, index: a.write.index, mapKey: a.write.mapKey) : a.write;
      final next = applyWrite(old, a.valueType, write, run.expressions, run.scope);
      if (fieldPath == null) return;
      final value = fieldPath.keys.isEmpty ? next : setAtPath(current?[fieldPath.root], fieldPath.keys, next);
      await db.updateDocument(path, id, {fieldPath.root: value});
      run.result = id;
    case CloudDocumentsOperation.remove:
      run.result = await db.removeDocument(path, id);
    case CloudDocumentsOperation.removeMany:
      final ids = run.evaluate(a.ids);
      final list = switch (ids) {
        final List l => [for (final x in l) '$x'],
        final String s when s.trim().isNotEmpty => [for (final x in s.split(',')) if (x.trim().isNotEmpty) x.trim()],
        _ => null,
      };
      run.result = await db.removeDocuments(path,
          ids: list, filters: list != null ? const [] : _query(a.where, const [], null, run).filters);
    case CloudDocumentsOperation.setMany:
      final value = document();
      final docs = [
        if (value is List)
          for (final d in value)
            if (d is Map) {for (final e in d.entries) '${e.key}': e.value},
      ];
      run.result = await db.setDocuments(path, docs,
          idField: a.idField, merge: a.merge, replaceCollection: a.replaceCollection);
  }
}

/// Streams [a]'s document or query into its variable until the screen goes:
/// `{status, isLoading, data, error}`.
Future<void> _loadCloudData(LoadCloudDataAction a, ActionRun run) async {
  final db = _require(run, 'Cloud data').cloud;
  final scope = run.context.scope;
  final variable = a.variable.trim();
  if (variable.isEmpty) return;
  final host = run.host;
  if (a.scope == CloudDataScope.app && host is RuntimeActionContext && host.appData != null) {
    return _loadAppCloudData(a, run, db, host.appData!, variable);
  }
  void put(String status, {Object? data, Object? error}) => setVariableIn(scope, variable, {
        'status': status,
        'isLoading': status == 'loading',
        'data': data,
        'error': ?error,
      });
  put('loading');
  late final Stream<Object?> stream;
  try {
    final path = resolveCollectionPath(a.query, run.expressions, run.scope);
    stream = a.single
        ? db.watchDocument(path, run.text(a.id).trim())
        : db.watchQuery(path, resolveCloudQuery(a.query, run.expressions, run.scope), loadRelated: a.query.loadRelated);
  } catch (error) {
    put('error', error: '$error');
    rethrow;
  }
  final first = Completer<void>();
  var active = true;
  late final StreamSubscription<Object?> sub;
  try {
    sub = stream.listen(
    (data) {
      if (!active) return;
      put('loaded', data: data);
      if (!first.isCompleted) first.complete();
    },
    onError: (Object error, StackTrace stack) {
      if (!active) return;
      active = false;
      put('error', error: '$error');
      if (!first.isCompleted) {
        first.completeError(error, stack);
      } else {
        // A later subscription error has no awaited action to throw through.
        // Stop this invocation's remaining actions, report once and close it.
        run.stop();
        run.host.reportError(ActionFailed(a.type, error, nodeId: run.node?.id), stack, action: a.type);
      }
    },
    onDone: () {
      if (active && !first.isCompleted) {
        active = false;
        final error = StateError('Cloud data stream closed before a value');
        put('error', error: '$error');
        first.completeError(error);
      }
    },
    cancelOnError: true,
    );
  } catch (error) {
    active = false;
    put('error', error: '$error');
    rethrow;
  }
  void cancel() {
    active = false;
    unawaited(sub.cancel());
    if (!first.isCompleted) first.completeError(const ActionsCanceled());
  }
  final removeCancellation = run.onCancel(cancel);
  run.host.onDispose(cancel);
  try {
    await first.future;
  } finally {
    removeCancellation();
  }
}

/// [a] with `scope: app`: the app's one subscription to its source, shared
/// by every screen that loads the same ([AppDataSources]). Waits for the
/// first value; the subscription outlives the screen.
Future<void> _loadAppCloudData(LoadCloudDataAction a, ActionRun run, CloudDatabase db, AppDataSources sources, String variable) async {
  final path = resolveCollectionPath(a.query, run.expressions, run.scope);
  final id = a.single ? run.text(a.id).trim() : '';
  final query = a.single ? null : resolveCloudQuery(a.query, run.expressions, run.scope);
  final key = [
    a.single ? 'document' : 'query',
    path,
    id,
    if (query != null) _cloudQueryKey(query),
    ...a.query.loadRelated,
  ].join('\u0000');
  final loaded = sources.load(
    variable,
    key,
    () => query == null ? db.watchDocument(path, id) : db.watchQuery(path, query, loadRelated: a.query.loadRelated),
  );
  // Stopping this run stops waiting, not the app's subscription.
  final waiting = Completer<void>();
  loaded.then((_) {
    if (!waiting.isCompleted) waiting.complete();
  }, onError: (Object error, StackTrace stack) {
    if (!waiting.isCompleted) waiting.completeError(error, stack);
  });
  final removeCancellation = run.onCancel(() {
    if (!waiting.isCompleted) waiting.completeError(const ActionsCanceled());
  });
  try {
    await waiting.future;
  } finally {
    removeCancellation();
  }
}

/// [q] as text: the same query gives the same text.
String _cloudQueryKey(CloudQuery q) => [
      for (final f in q.filters) '${f.field} ${f.operator.name} ${jsonEncode(f.value, toEncodable: (v) => '$v')}',
      for (final o in q.orderBy) '${o.field} ${o.descending ? 'desc' : 'asc'}',
      'limit ${q.limit}',
      'after ${q.startAfter}',
    ].join(';');

// --- auth -----------------------------------------------------------------------------

Future<void> _auth(AuthAction a, ActionRun run) async {
  final auth = _require(run, 'Auth').auth;
  final email = run.text(a.email).trim(), password = run.text(a.password);
  if (a.errorVariable.isNotEmpty) setVariableIn(run.context.scope, a.errorVariable, '');
  try {
    switch (a.operation) {
      case AuthOperation.signIn:
        run.result = (await auth.signIn(email: email, password: password)).uid;
      case AuthOperation.signUp:
        run.result = (await auth.signUp(email: email, password: password, displayName: run.text(a.displayName))).uid;
      case AuthOperation.signOut:
        await auth.signOut();
      case AuthOperation.updateProfile:
        // Empty authored fields are omitted, not destructive updates. A
        // supplied expression resolving to empty still explicitly clears it.
        await auth.updateProfile(
          displayName: a.displayName.isEmpty ? null : run.text(a.displayName),
          photoUrl: a.photoUrl.isEmpty ? null : run.text(a.photoUrl),
        );
      case AuthOperation.updatePhoto:
        await auth.updateProfile(photoUrl: run.text(a.photoUrl));
      case AuthOperation.sendPasswordResetEmail:
        await auth.sendPasswordResetEmail(email);
      case AuthOperation.sendEmailVerification:
        await auth.sendEmailVerification();
      case AuthOperation.updatePassword:
        if (a.currentPassword.isNotEmpty) await auth.reauthenticate(run.text(a.currentPassword));
        await auth.updatePassword(password);
      case AuthOperation.deleteAccount:
        if (a.currentPassword.isNotEmpty) await auth.reauthenticate(run.text(a.currentPassword));
        await auth.deleteAccount();
      case AuthOperation.signInWithGoogle:
        run.result = (await auth.signInWithProvider(AuthProviderKind.google)).uid;
      case AuthOperation.signInWithApple:
        run.result = (await auth.signInWithProvider(AuthProviderKind.apple)).uid;
      case AuthOperation.sendSignInLink:
        await auth.sendSignInLink(email, continueUrl: Uri.base.toString());
      case AuthOperation.completeSignInLink:
        run.result = (await auth.signInWithLink(email, Uri.base.toString())).uid;
      case AuthOperation.signInAnonymously:
        run.result = (await auth.signInAsGuest()).uid;
    }
    final host = run.host;
    if (host is RuntimeActionContext) host.refreshAuthValues?.call(a.operation);
  } catch (error) {
    if (a.errorVariable.isNotEmpty) {
      setVariableIn(run.context.scope, a.errorVariable, error is AuthFailure ? error.message : '$error');
    }
    rethrow;
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

// --- files ---------------------------------------------------------------------------------

Future<void> _cloudFiles(CloudFilesAction a, ActionRun run) async {
  final files = _require(run, 'Cloud files').files;
  final folder = run.text(a.path).trim();
  if (a.operation == CloudFilesOperation.delete) {
    await files.delete(folder);
    return;
  }
  final picked = await run.host.ui.pickFiles(images: a.kind == CloudFileKind.image, multiple: a.allowMultiple);
  for (final (i, f) in picked.indexed) {
    if (f.bytes.length > a.maxSizeMB * 1024 * 1024) {
      throw CodedFailure('file-too-large', '${f.name} is larger than ${_mb(a.maxSizeMB)} MB');
    }
    final type = f.contentType ?? '';
    if (a.kind == CloudFileKind.image && type.isNotEmpty && !type.startsWith('image/')) {
      throw CodedFailure('invalid-file-type', '${f.name} is not an image');
    }
    void progress(double sent) {
      if (a.progressVariable.isNotEmpty) {
        setVariableIn(run.context.scope, a.progressVariable, (i + sent.clamp(0, 1)) / picked.length);
      }
    }

    progress(0);
    final uploaded = await files.upload(folder.isEmpty ? f.name : '$folder/${f.name}', f.bytes,
        contentType: f.contentType, onProgress: progress);
    await run.nested({'url': uploaded.url, 'path': uploaded.path, 'name': uploaded.name, 'index': i}).run(a.actions);
  }
  if (a.progressVariable.isNotEmpty && picked.isNotEmpty) setVariableIn(run.context.scope, a.progressVariable, 1);
}

// --- forms and text fields -------------------------------------------------------------

/// A form submission. Only the local service runs: an older layout's
/// built-in newsletter service (or an unknown one), decoded as
/// [FormService.unsupported], sends nothing and fails as
/// `unsupported_service` through the same result and callbacks.
///
/// Validation finishes before any response is stored. Persisting the
/// response variable uses the SDK's normal variable persistence. Nothing is
/// sent over the network.
Future<void> _submitForm(SubmitFormAction a, ActionRun run) async {
  Json outcome;
  try {
    if (a.service != FormService.local) {
      throw const _FormSubmissionFailure('unsupported_service',
          'This form uses a submission service that is no longer supported. Nothing was sent.');
    }
    final destination = a.responseVariable.trim();
    if (destination.isNotEmpty) {
      final found = variableOf(run.context.scope, destination);
      if (found == null || found.$2.isComputed || found.$2.type != VariableType.list ||
          (ValuePath.parse(destination)?.keys.isNotEmpty ?? true)) {
        throw const _FormSubmissionFailure('invalid_response_variable', 'The response variable must be a mutable list.');
      }
    }
    Object? payload = a.payload.trim().isEmpty ? <String, Object?>{} : run.evaluate(a.payload);
    if (a.validationScript.trim().isNotEmpty) {
      await runScriptAction(RunScriptAction(script: a.validationScript, arguments: a.validationArguments), run);
      final validation = readMap(run.result);
      if (validation == null || validation['valid'] is! bool) {
        throw const _FormSubmissionFailure('invalid_validation_result', 'The validator must return {valid, errors?, payload?}.');
      }
      if (validation['valid'] != true) {
        throw _FormSubmissionFailure('validation_failed', 'Please check the form answers.', readMap(validation['errors']) ?? const {});
      }
      if (validation.containsKey('payload')) payload = validation['payload'];
    }
    if (payload is! Map) throw const _FormSubmissionFailure('invalid_payload', 'The submission payload must be a JSON object.');
    // Copy at the boundary: the response is a snapshot, not an alias of answers.
    final snapshot = (jsonDecode(jsonEncode(payload)) as Map).cast<String, Object?>();
    if (run.isCanceled) return;
    if (destination.isNotEmpty) {
      final current = run.context.scope.read(destination);
      final rows = current is List ? [...current] : <Object?>[];
      a.prepend ? rows.insert(0, snapshot) : rows.add(snapshot);
      setVariableIn(run.context.scope, destination, rows);
    }
    outcome = {'ok': true, 'value': snapshot, 'error': null, 'errors': <String, Object?>{}};
  } on _FormSubmissionFailure catch (e) {
    outcome = {'ok': false, 'value': null, 'error': {'code': e.code, 'message': e.message}, 'errors': e.errors};
  } on ScriptFailed catch (e) {
    outcome = {'ok': false, 'value': null, 'error': {'code': 'validation_script_failed', 'message': e.message}, 'errors': <String, Object?>{}};
  } catch (e) {
    outcome = {'ok': false, 'value': null, 'error': {'code': 'invalid_payload', 'message': '$e'}, 'errors': <String, Object?>{}};
  }
  run.result = outcome;
  if (a.resultVariable.trim().isNotEmpty) setVariableIn(run.context.scope, a.resultVariable.trim(), outcome);
  if (outcome['ok'] == true) {
    await run.run(a.onSuccess);
  } else if (a.onError.isNotEmpty) {
    await run.run(a.onError);
  } else {
    throw StateError((outcome['error'] as Map)['message'] as String);
  }
}

class _FormSubmissionFailure implements Exception {
  const _FormSubmissionFailure(this.code, this.message, [this.errors = const {}]);
  final String code, message;
  final Json errors;
}

void _focus(FocusAction a, ActionRun run) {
  final tree = run.host.tree;
  final handle = tree == null || a.node.isEmpty ? null : TextFieldHandle.of(tree, a.node);
  if (a.unfocus) {
    handle == null ? TextFieldHandle.unfocusAll() : handle.focusNode.unfocus();
    return;
  }
  if (handle == null) return;
  handle.focusNode.requestFocus();
  if (a.selectAll) {
    handle.controller.selection = TextSelection(baseOffset: 0, extentOffset: handle.controller.text.length);
  }
}

void _editText(EditTextAction a, ActionRun run) {
  final tree = run.host.tree;
  final handle = tree == null ? null : TextFieldHandle.of(tree, a.node);
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

/// The copy of repeated node [id] that a list built for its item [item]:
/// the one whose `${item.id}` (or `${item.key}`, or the item itself, as
/// text) reads [item], else the one whose `${index}` is [item]. Each copy is
/// asked in its own scope, so a node inside an item template matches too.
NodeBox? repeatOf(NodeTree tree, String id, String item) {
  final binder = tree.binder;
  if (binder == null) return null;
  NodeBox? byIndex;
  final index = int.tryParse(item);
  for (final b in tree.boxesOf(id)) {
    if (!b.attached) continue;
    final scope = binder.scopeFor(tree.source, b.id, b.instance);
    if (scope == null) continue;
    final value = readPath(scope, 'item');
    final key = value is Map ? (value['id'] ?? value['key']) : value;
    if (key != null && '$key' == item) return b;
    if (index != null && byIndex == null && readPath(scope, 'index') == index) byIndex = b;
  }
  return byIndex;
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
  final box = tree == null ? null : (item.isEmpty ? tree.boxOf(id) : repeatOf(tree, id, item)) ?? tree.boxOf(id);
  if (box == null || !box.attached) return;
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

// --- sound, speech, purchases ---------------------------------------------------------------

void _speak(SpeakAction a, ActionRun run) {
  final speech = _require(run, 'Speech').speech;
  if (a.stop) return speech.stop();
  double number(String text, double min, double max) =>
      (double.tryParse(run.text(text).trim()) ?? 1).clamp(min, max).toDouble();
  unawaited(speech.speak(run.text(a.text),
      language: run.text(a.language).trim(),
      rate: number(a.rate, 0.1, 10),
      pitch: a.pitch.isEmpty ? 1 : number(a.pitch, 0.5, 2)));
}

/// The latest timed start of each voice id (see [_playSound]).
final Map<String, Object> _soundTokens = {};

void _playSound(PlaySoundAction a, ActionRun run) {
  double? number(String v) => double.tryParse(run.text(v).trim());
  final service = _require(run, 'Sound').sound;
  switch (a.operation) {
    case 'start':
      final id = run.text(a.voiceId).trim();
      final note = a.note.isEmpty ? null : number(a.note);
      final frequency = note != null ? midiToHz(note) : number(a.frequency) ?? 440;
      service.startNoteWithWaveform(id, frequency: frequency, volume: number(a.volume) ?? 1, waveform: run.text(a.waveform).trim());
      // A voice with a duration releases itself, unless something started
      // another voice under its id in the meantime.
      final ms = a.duration.isEmpty ? null : number(a.duration);
      if (ms != null && ms >= 0) {
        final token = _soundTokens[id] = Object();
        Timer(Duration(milliseconds: ms.round()), () {
          if (identical(_soundTokens[id], token)) {
            _soundTokens.remove(id);
            service.stopNote(id);
          }
        });
      } else {
        _soundTokens.remove(id);
      }
      return;
    case 'stop':
      service.stopNote(run.text(a.voiceId).trim());
      return;
    case 'stopAll':
      service.stopAllNotes();
      return;
  }
  final url = run.text(a.url).trim();
  if (url.isNotEmpty) {
    unawaited(_playFile(url, (number(a.volume) ?? 1).clamp(0, 1).toDouble()));
    return;
  }
  final at = run.text(a.at).trim();
  _require(run, 'Sound').sound.play(
        SoundVoice.named(run.text(a.sound)),
        time: at.isEmpty ? null : double.tryParse(at),
        volume: number(a.volume) ?? 1,
        pitch: number(a.pitch) ?? 1,
      );
}

Future<void> _playFile(String url, double volume) async {
  final player = audio.AudioPlayer();
  try {
    await player.setUrl(url);
    await player.setVolume(volume);
    await player.play();
  } catch (_) {
    // A sound that can't play is skipped.
  } finally {
    await player.dispose();
  }
}

Future<void> _paywall(PaywallAction a, ActionRun run) async {
  final host = run.host;
  final session = host is RuntimeActionContext ? host.paywall : null;
  switch (a.operation) {
    case PaywallOperation.openPaywall:
      final placement = run.text(a.placement ?? '').trim();
      final open = host is RuntimeActionContext ? host.openPaywall : null;
      if (placement.isEmpty || open == null) throw StateError('No paywall placement presenter');
      final result = await open(placement);
      run.result = {'outcome': result.outcome.name, 'entitlementId': result.entitlementId};
      return;
    case PaywallOperation.openLegalLink:
      final url = run.text(a.url ?? '').trim();
      if (!url.startsWith('https://')) throw StateError('Invalid legal URL');
      await run.context.services.openUrl(url);
      return;
    case PaywallOperation.closePaywall:
      session?.close();
      host.ui.closeModal(null);
      return;
    default:
  }
  if (session == null) throw StateError('Paywall action outside a paywall');
  switch (a.operation) {
    case PaywallOperation.purchase:
      final preference = run.text(a.offer ?? 'storeDefault').trim();
      final offer = PurchaseOfferPreference.values.where((value) => value.name == preference).firstOrNull;
      if (offer == null) throw StateError('Unknown purchase offer preference');
      final result = await session.purchaseAndWait(slot: a.slot, offer: offer);
      _paywallOutcome(result, run);
    case PaywallOperation.restore:
      final result = await session.restoreAndWait();
      _paywallOutcome(result, run);
    case PaywallOperation.selectProduct:
      if (a.slot != null) session.selectProduct(a.slot!);
    default:
  }
}

void _paywallOutcome(PaywallResult result, ActionRun run) {
  run.result = {'outcome': result.outcome.name, 'entitlementId': result.entitlementId};
  switch (result.outcome) {
    case PaywallOutcome.purchased || PaywallOutcome.restored:
      return;
    // Closing the paywall or nothing to show ends the chain quietly. A
    // cancelled purchase and an empty restore end it too, without an error,
    // but the screen's actionError reaction hears them
    // (`${result.error.code}`) to say so.
    case PaywallOutcome.closed || PaywallOutcome.skipped:
      throw const ActionsCanceled();
    case PaywallOutcome.canceled:
      throw const ActionsStopped('purchase-cancelled', 'Purchase cancelled');
    case PaywallOutcome.restoreNothing:
      throw const ActionsStopped('nothing-to-restore', 'No purchase to restore');
    case PaywallOutcome.failed:
      throw CodedFailure(result.code.isEmpty ? 'purchase-failed' : result.code, result.error ?? 'Purchase failed');
  }
}

/// Whether [text] holds `${...}` (an expression, not a literal).
bool isExpression(String text) => text.contains(r'${') || FormulaEvaluator.exactExpression(text) != null;

// Built-in callFunction names keep media encoding in the runtime host,
// never in the script sandbox. An app may override them in functions.
Future<Object?> _mediaExport(CallFunctionAction action, ActionRun run) async {
  final services = run.context.services;
  if (services is! Services) return {'ok': false, 'error': 'Video export is unavailable'};
  final service = services.mediaExport;
  if (action.name == 'media.cancelExport') {
    service.cancel();
    return {'cancelled': true};
  }
  final params = run.json(action.params);
  final progress = params['progressVariable'] as String? ?? '';
  try {
    final raw = params['project'];
    if (raw is! Map) throw ArgumentError('Export needs a project with source clips');
    final request = MediaExportRequest.fromJson(raw.cast<String,Object?>(),
      fileName: params['fileName'] as String? ?? 'video.webm',
      width: (params['width'] as num?)?.toInt() ?? 640,
      height: (params['height'] as num?)?.toInt() ?? 360);
    final previousGeneration = service.generation;
    final operation = service.export(request, onProgress: (value) {
      if (progress.isNotEmpty) run.context.setVariable(progress, value);
    });
    final generation = service.generation;
    if (generation != previousGeneration) {
      run.host.onDispose(() { if (service.running && service.generation == generation) service.cancel(); });
    }
    final result = await operation;
    return {'ok': true, ...result};
  } catch (error) {
    return {'ok': false, 'error': '$error', 'cancelled': error is MediaExportCancelled};
  }
}

// Imported bytes are inspected before uploading. Public URL probing keeps the
// same HTTPS/MP4 restriction as the player; neither exposes DOM to scripts.
Future<Object?> _mediaImport(CallFunctionAction action, ActionRun run) async {
  try {
    final params = run.json(action.params);
    if (action.name == 'media.probe') {
      return {'ok': true, ...await probeMedia(params['url'] as String? ?? '')};
    }
    final files = _require(run, 'Video import').files;
    if (files is MemoryFileStorage) {
      throw StateError(
        'Connect cloud file storage before choosing a device video. You can import a public HTTPS MP4 URL instead.',
      );
    }
    final picked = await run.host.ui.pickFiles(images: false, multiple: false);
    if (run.isCanceled || picked.isEmpty) {
      return {'ok': false, 'cancelled': true};
    }
    final file = picked.first;
    final metadata = await probePickedVideo(file.name, file.bytes, contentType: file.contentType);
    if (run.isCanceled) {
      return {'ok': false, 'cancelled': true};
    }
    final name = file.name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final uploaded = await files.upload(
      'cutroom/imports/${DateTime.now().microsecondsSinceEpoch}-$name',
      file.bytes,
      contentType: 'video/mp4',
    );
    return {'ok': true, ...metadata, 'url': uploaded.url, 'name': file.name};
  } catch (error) {
    return {'ok': false, 'error': '$error'};
  }
}

/// 5 for 5.0, 2.5 for 2.5.
String _mb(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

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
