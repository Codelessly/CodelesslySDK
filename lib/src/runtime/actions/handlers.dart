// One typed handler per action type, over an ActionRun (the chain's scope
// and result, its context's services, UI and node tree), without
// BuildContext.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart' as rendering show Axis;
import 'package:flutter/rendering.dart' show RenderObject, RenderViewportBase;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback, TextEditingValue, TextSelection;
import 'package:flutter/widgets.dart' show Curve, Curves, ScrollPosition;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' as audio;

import '../../render/drag_track.dart' show DragTracks;
import '../gestures/drag_motion.dart' show DragMotionControl;
import '../../render/transform_gesture.dart' show TransformGestures;
import '../../render/play.dart' show EffectPlayers;
import '../../services/services.dart';
import '../expressions/formula.dart';
import '../lists/paginate_action.dart';
import '../expressions/paths.dart';
import '../expressions/scopes.dart';
import 'context.dart';
import 'feedback_theme.dart' show Look;
import 'runner.dart';
import 'script_host.dart';
import 'text_fields.dart';
import 'values.dart';
import 'variable_animator.dart';

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
      if (f == null) throw StateError('No function named [${a.name}]');
      run.result = await f(run.context, run.json(a.params));
    case CallApiAction():
      await _callApi(a, run);
    case SetStorageAction():
      await _setStorage(a, run);
    case CloudDocumentsAction():
      await _cloudDocuments(a, run);
    case LoadCloudDataAction():
      _loadCloudData(a, run);
    case AuthAction():
      await _auth(a, run);
    case IfAction():
      final holds = a.condition != null && run.expressions.test(a.condition!, run.scope);
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
      // for it. (Particles aren't drawn yet.)
      await EffectPlayers.play(a.node, a.animation);
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
  } on ActionsCancelled {
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
  final v = num.tryParse(run.text(a.duration).trim());
  return v == null || v < 0 ? a.ms : v.round();
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
  final whole = scope.valueOf(path.root, scope);
  final current = path.keys.isEmpty ? whole : path.readFrom(whole);
  // A part of a list or map takes the type of what it holds now.
  final type = path.keys.isEmpty ? variable.type : typeOf(current);
  final next = path.keys.isNotEmpty && a.write.op == WriteOp.set
      ? evaluateValue(a.write.value, run.expressions, run.scope)
      : applyWrite(current, type, a.write, run.expressions, run.scope);
  // A number glides to its new value over animateMs.
  final ms = a.animateMs.trim().isEmpty ? 0 : (double.tryParse(run.text(a.animateMs).trim()) ?? 0).round();
  final number = type == VariableType.integer || type == VariableType.decimal;
  if (ms > 0 && number && path.keys.isEmpty && current is num && next is num) {
    if (next == current) return;
    final done = VariableAnimator.play(scope, path.root,
        from: current.toDouble(), to: next.toDouble(), duration: Duration(milliseconds: ms), curve: a.curve, glide: true);
    // The chain stops (its node left): so does the glide.
    final remove = run.cancellation.onCancel(() => VariableAnimator.stopGlide(scope, path.root));
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
  double? number(String text) {
    if (text.trim().isEmpty) return null;
    final n = double.tryParse(run.text(text).trim());
    return n != null && n.isFinite ? n : null;
  }

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
void _loadCloudData(LoadCloudDataAction a, ActionRun run) {
  final db = _require(run, 'Cloud data').cloud;
  final scope = run.context.scope;
  final variable = a.variable.trim();
  if (variable.isEmpty) return;
  void put(String status, {Object? data, Object? error}) => setVariableIn(scope, variable, {
        'status': status,
        'isLoading': status == 'loading',
        'data': data,
        'error': ?error,
      });
  put('loading');
  final path = resolveCollectionPath(a.query, run.expressions, run.scope);
  final Stream<Object?> stream = a.single
      ? db.watchDocument(path, run.text(a.id).trim())
      : db.watchQuery(path, resolveCloudQuery(a.query, run.expressions, run.scope), loadRelated: a.query.loadRelated);
  final sub = stream.listen(
    (data) => put('loaded', data: data),
    onError: (Object e) => put('error', error: '$e'),
  );
  run.host.onDispose(sub.cancel);
}

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
        await auth.updateProfile(displayName: run.text(a.displayName), photoUrl: run.text(a.photoUrl));
      case AuthOperation.updatePhoto:
        await auth.updateProfile(photoUrl: run.text(a.photoUrl));
      case AuthOperation.sendPasswordResetEmail:
        await auth.sendPasswordResetEmail(email);
      case AuthOperation.sendEmailVerification:
        await auth.sendEmailVerification();
      case AuthOperation.updatePassword:
        await auth.updatePassword(password);
      case AuthOperation.deleteAccount:
        await auth.deleteAccount();
      case AuthOperation.signInWithGoogle:
        run.result = (await auth.signInWithProvider(AuthProviderKind.google)).uid;
      case AuthOperation.signInWithApple:
        run.result = (await auth.signInWithProvider(AuthProviderKind.apple)).uid;
      case AuthOperation.sendSignInLink:
        await auth.sendSignInLink(email, continueUrl: Uri.base.toString());
      case AuthOperation.completeSignInLink:
        run.result = (await auth.signInWithLink(email, Uri.base.toString())).uid;
    }
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
    if (f.bytes.length > a.maxSizeMB * 1024 * 1024) throw StateError('${f.name} is larger than ${a.maxSizeMB} MB');
    if (a.progressVariable.isNotEmpty) setVariableIn(run.context.scope, a.progressVariable, i / picked.length);
    final uploaded = await files.upload(folder.isEmpty ? f.name : '$folder/${f.name}', f.bytes, contentType: f.contentType);
    await run.nested({'url': uploaded.url, 'path': uploaded.path, 'name': uploaded.name, 'index': i}).run(a.actions);
  }
  if (a.progressVariable.isNotEmpty && picked.isNotEmpty) setVariableIn(run.context.scope, a.progressVariable, 1);
}

// --- forms and text fields -------------------------------------------------------------

String _fieldText(ActionRun run, String nodeId) {
  final tree = run.host.tree;
  if (tree == null || nodeId.isEmpty) return '';
  return TextFieldHandle.of(tree, nodeId)?.controller.text ?? '';
}

Future<void> _submitForm(SubmitFormAction a, ActionRun run) async {
  final email = _fieldText(run, a.emailField).trim();
  if (email.isEmpty) throw StateError('No email to submit');
  final response = await http.post(
    Uri.parse('https://${a.dataCenter}.api.mailchimp.com/3.0/lists/${a.listId}/members'),
    headers: {
      'Authorization': 'Basic ${base64Encode(utf8.encode('codelessly:${a.apiKey}'))}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email_address': email,
      'status': 'subscribed',
      'merge_fields': {
        if (a.firstNameField.isNotEmpty) 'FNAME': _fieldText(run, a.firstNameField),
        if (a.lastNameField.isNotEmpty) 'LNAME': _fieldText(run, a.lastNameField),
      },
    }),
  );
  if (response.statusCode >= 300) throw StateError('Submit failed: ${response.statusCode}');
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

/// Scrolls the scroll views around node [ScrollToAction.node] (those
/// along [ScrollToAction.axis] only, when it's set) so the node sits at
/// its alignment, less its offset: each view reveals the one inside it.
Future<void> _scrollTo(ScrollToAction a, ActionRun run) async {
  final box = run.host.tree?.boxOf(run.text(a.node).trim());
  if (box == null || !box.attached) return;
  final target = box.contentBox ?? box;
  final duration = Duration(milliseconds: a.durationMs);
  final Curve curve = switch (AnimationCurve.parse(a.curve)) {
    AnimationCurve.linear => Curves.linear,
    AnimationCurve.easeIn => Curves.easeIn,
    AnimationCurve.easeOut => Curves.easeOut,
    AnimationCurve.fastOutSlowIn => Curves.fastOutSlowIn,
    AnimationCurve.easeOutCubic => Curves.easeOutCubic,
    AnimationCurve.easeInOutCubic => Curves.easeInOutCubic,
    AnimationCurve.decelerate => Curves.decelerate,
    _ => Curves.easeInOut,
  };
  final scrolls = <Future<void>>[];
  var viewports = 0;
  RenderObject revealed = target;
  for (var p = target.parent; p != null; p = p.parent) {
    if (p is! RenderViewportBase) continue;
    final position = p.offset;
    if (position is! ScrollPosition) continue;
    viewports++;
    final along = a.axis == null || (p.axis == rendering.Axis.horizontal) == (a.axis == ScrollAxis.horizontal);
    if (along && position.hasContentDimensions) {
      final to = (p.getOffsetToReveal(revealed, a.alignment).offset - a.offset)
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

void _playSound(PlaySoundAction a, ActionRun run) {
  double? number(String v) => double.tryParse(run.text(v).trim());
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
      await session.purchase(slot: a.slot);
    case PaywallOperation.restore:
      await session.restore();
    case PaywallOperation.selectProduct:
      if (a.slot != null) session.selectProduct(a.slot!);
    default:
  }
}

/// Whether [text] holds `${...}` (an expression, not a literal).
bool isExpression(String text) => text.contains(r'${') || FormulaEvaluator.exactExpression(text) != null;
