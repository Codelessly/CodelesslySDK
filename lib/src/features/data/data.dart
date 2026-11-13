// The data feature: cloud documents, data, batches and files, live cloud
// data in variables (and the app's shared sources), API calls, device
// storage (the `setStorage` action and the `storage` value) and form
// submissions. The core runtime doesn't import this: `dataFeature`
// registers it through the plugin seam (runtime/actions/feature.dart).
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';

import '../../runtime/actions/action_error.dart' show CodedFailure;
import '../../runtime/actions/context.dart';
import '../../runtime/actions/feature.dart';
import '../../runtime/actions/files.dart';
import '../../runtime/actions/runner.dart';
import '../../runtime/actions/script_host.dart';
import '../../runtime/actions/values.dart';
import '../../runtime/contracts.dart';
import '../../runtime/expressions/paths.dart';
import '../../runtime/expressions/scopes.dart';
import '../../services/api.dart';
import '../../services/cloud/backend.dart';
import '../../services/cloud/database.dart';
import '../../services/cloud/fields.dart';
import '../../services/cloud/query.dart';
import '../../services/cloud/resolve.dart';
import '../../services/storage.dart';
import 'app_data_sources.dart';
import 'cloud_loads.dart';

/// Cloud data and files, API calls, device storage and form submissions.
const CodelesslyFeature dataFeature = CodelesslyFeature(
  name: 'data',
  actions: {
    CallApiAction.typeName: _callApi,
    SetStorageAction.typeName: _setStorage,
    CloudDocumentsAction.typeName: _cloudDocuments,
    CloudDataAction.typeName: _cloudDataAction,
    CloudBatchAction.typeName: _cloudBatch,
    CloudFilesAction.typeName: _cloudFiles,
    LoadCloudDataAction.typeName: _loadCloudData,
    ReloadCloudDataAction.typeName: _reloadCloudData,
    SubmitFormAction.typeName: _submitForm,
  },
  scopes: {'storage': _storageScope},
  catalog: dataCatalog,
);

// --- APIs ------------------------------------------------------------------------

Future<void> _callApi(ActionDef action, ActionRun run) async {
  final a = action as CallApiAction;
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

Future<void> _setStorage(ActionDef action, ActionRun run) async {
  final a = action as SetStorageAction;
  final storage = run.require<LocalStorage>('Storage');
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

Future<void> _cloudDataAction(ActionDef action, ActionRun run) => _cloudData(action as CloudDataAction, run);

Future<void> _cloudBatch(ActionDef action, ActionRun run) => cloudBatch(action as CloudBatchAction, run, _cloudData);

Future<void> _reloadCloudData(ActionDef action, ActionRun run) => reloadCloudData(action as ReloadCloudDataAction, run);

Future<void> _cloudData(CloudDataAction a, ActionRun run) async {
  final db = run.require<CloudDatabase>('Cloud data');
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


Future<void> _cloudDocuments(ActionDef action, ActionRun run) async {
  final a = action as CloudDocumentsAction;
  final db = run.require<CloudDatabase>('Cloud data');
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

/// [a] with `scope: app` on a host with app data goes to the app's shared
/// subscription ([AppDataSources], attached to the context by the app
/// shell); any other load is the screen's live load (cloud_loads.dart).
Future<void> _loadCloudData(ActionDef action, ActionRun run) async {
  final a = action as LoadCloudDataAction;
  final variable = a.variable.trim();
  if (variable.isEmpty) return;
  final appData = run.extension<AppDataSources>();
  if (a.scope == CloudDataScope.app && appData != null) {
    return _loadAppCloudData(a, run, run.require<CloudDatabase>('Cloud data'), appData, variable);
  }
  return loadCloudData(a, run);
}

/// [a] with `scope: app`: the app's one subscription to its source, shared
/// by every screen that loads the same ([AppDataSources]). Waits for the
/// first value; the subscription outlives the screen.
Future<void> _loadAppCloudData(LoadCloudDataAction a, ActionRun run, CloudDatabase db, AppDataSources sources, String variable) async {
  // The same limit, aggregate and joins as a screen's load (cloud_loads.dart).
  final source = appCloudSource(a, run, db);
  final loaded = sources.load(variable, source.key, source.open);
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

// --- files ---------------------------------------------------------------------------------

Future<void> _cloudFiles(ActionDef action, ActionRun run) async {
  final a = action as CloudFilesAction;
  final files = run.require<CloudFileStorage>('Cloud files');
  final folder = run.text(a.path).trim();
  if (a.operation == CloudFilesOperation.delete) {
    await files.delete(folder);
    return;
  }
  final picked = a.source.trim().isEmpty
      ? await pickFiles(run, images: a.kind == CloudFileKind.image, multiple: a.allowMultiple)
      : sourceFiles(run.evaluate(a.source), name: run.text(a.fileName).trim());
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

// --- forms ---------------------------------------------------------------------------

/// A form submission. Only the local service runs: an older layout's
/// built-in newsletter service (or an unknown one), decoded as
/// [FormService.unsupported], sends nothing and fails as
/// `unsupported_service` through the same result and callbacks.
///
/// Validation finishes before any response is stored. Persisting the
/// response variable uses the SDK's normal variable persistence. Nothing is
/// sent over the network.
Future<void> _submitForm(ActionDef action, ActionRun run) async {
  final a = action as SubmitFormAction;
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

/// 5 for 5.0, 2.5 for 2.5.
String _mb(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

// --- the `storage` value ------------------------------------------------------------------

NamedScope _storageScope(FeatureScopeHost host, ValueScope parent) => StorageScope(host.services, parent: parent);

/// `storage` in expressions: the app's [LocalStorage] values by key,
/// notifying its readers when any changes.
class StorageScope extends NamedScope {
  StorageScope(CodelesslyServices services, {super.parent}) : _store = services.lookup<LocalStorage>() {
    _store?.addListener(_storeChanged);
  }

  final LocalStorage? _store;

  void _storeChanged() => changed(const ['storage']);

  @override
  bool declares(String name) => name == 'storage';

  @override
  Object? valueOf(String name, ValueScope reader) => _store?.getAll() ?? const <String, Object?>{};

  @override
  void dispose() {
    _store?.removeListener(_storeChanged);
    super.dispose();
  }
}
