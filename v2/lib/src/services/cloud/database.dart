// The app's cloud database: documents and collection queries under the
// project's root, with its data rules applied (who reads and writes what),
// on a pluggable DocumentBackend.
import 'dart:async';

import 'package:codelessly_api_v2/codelessly_api.dart' show DataRule, DataRules, Json, WhereOperator;
import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'fields.dart';
import 'query.dart';

/// Reads and writes the app's cloud data. Paths are the app's: a collection
/// path (`tasks`, `users/u1/tasks`, `.` or `/` separated) under the
/// project's root. Notifies its listeners when [rules] change.
abstract interface class CloudDatabase implements Listenable {
  /// The project's data rules, schemas and indexes.
  DataRules get rules;

  /// The document [id] of [path] as the app reads it ([documentForUse]),
  /// or null when it doesn't exist.
  Future<Json?> getDocument(String path, String id);

  /// The document, now and on every change.
  Stream<Json?> watchDocument(String path, String id);

  /// [query]'s documents, each with its `id`. [loadRelated] reference
  /// fields hold the referenced document instead of its id. Throws a
  /// [StateError] when the rules need a signed-in user and there is none.
  Future<List<Json>> query(String path, CloudQuery query, {List<String> loadRelated = const []});

  /// [query]'s documents, now and on every change: what a data-bound list
  /// shows. Emits an empty list when the reader may not read [path].
  Stream<List<Json>> watchQuery(String path, CloudQuery query, {List<String> loadRelated = const []});

  /// [operation] over [query]'s documents ([field] for sum and average).
  Future<num?> aggregate(String path, CloudQuery query, CloudAggregate operation, {String field = ''});

  /// Adds a document and returns its id: [id], else a generated one. When
  /// [id] exists already, [skipIfExists] leaves it, else it's replaced.
  Future<String> addDocument(String path, Json value, {String? id, bool skipIfExists = true});

  /// Merges [value] into document [id] (creating it).
  Future<void> updateDocument(String path, String id, Json value);

  /// Removes document [id]; false when it didn't exist.
  Future<bool> removeDocument(String path, String id);

  /// Removes [ids], or the documents matching [filters] (all, without),
  /// in as few batches as the backend allows; returns how many.
  Future<int> removeDocuments(String path, {Iterable<String>? ids, List<CloudWhereFilter> filters = const []});

  /// Writes [documents] at once (each's id is its [idField], else
  /// generated), replacing each or, with [merge], merging. With
  /// [replaceCollection] the collection's other documents go. Returns how
  /// many were written.
  Future<int> setDocuments(String path, List<Json> documents,
      {String idField = 'id', bool merge = false, bool replaceCollection = false});

  void dispose();
}

/// A [CloudDatabase] on a [DocumentBackend]. Documents live under [root]
/// (a document path such as `data/{projectId}`); [rules] come from
/// [rulesSource] (they change without a publish); [userId] is the signed-in
/// user, for owner stamps and owner-only reads.
class BackendCloudDatabase extends ChangeNotifier implements CloudDatabase {
  BackendCloudDatabase({
    required this.backend,
    this.root = 'data/default',
    this._rules = const DataRules(),
    Stream<DataRules>? rulesSource,
    String? Function()? userId,
    DateTime Function()? now,
    this.onError,
  })  : userId = userId ?? _nobody,
        _now = now ?? DateTime.now {
    _rulesSubscription = rulesSource?.listen((r) {
      _rules = r;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => onError?.call(error, stack));
  }

  static String? _nobody() => null;

  final DocumentBackend backend;

  /// The document all of the app's collections are under.
  final String root;
  final String? Function() userId;
  final DateTime Function() _now;

  /// Reports errors that don't reach a caller (rules stream).
  final void Function(Object error, StackTrace stack)? onError;

  DataRules _rules;
  StreamSubscription<DataRules>? _rulesSubscription;

  @override
  DataRules get rules => _rules;

  set rules(DataRules value) {
    if (value == _rules) return;
    _rules = value;
    notifyListeners();
  }

  static final _separator = RegExp(r'[./]');

  /// The full collection path of the app's [path]: segments alternate
  /// collection/document under [root]; a path ending at a document gets a
  /// `default` collection, and an empty path is `default`.
  String collectionPath(String path) {
    final parts = [
      for (final p in path.trim().split(_separator))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (parts.isEmpty) return '$root/default';
    if (parts.length.isEven) parts.add('default');
    return '$root/${parts.join('/')}';
  }

  static String _docId(String? id) => id == null || id.trim().isEmpty ? 'default' : id.trim();

  /// The filters that keep reads of [path] to what the signed-in user may
  /// read: none for shared collections, the owner filter for owner-only
  /// ones; null when nobody is signed in and the rules need someone.
  List<CloudWhereFilter>? readFilters(String path) {
    final rule = rules.ruleFor(path);
    if (!rule.readsOwnOnly && rule != DataRule.signedIn) return const [];
    final uid = userId();
    if (uid == null || uid.isEmpty) return null;
    if (!rule.readsOwnOnly) return const [];
    return [CloudWhereFilter(DataRules.ownerField, WhereOperator.equal, uid)];
  }

  /// [value] ready to write under [path]: owned collections record the
  /// signed-in user as the owner. Throws a [StateError] when the collection
  /// needs a signed-in user and there is none.
  Json prepareWrite(String path, Json value) {
    final rule = rules.ruleFor(path);
    final uid = userId();
    if (rule.writeNeedsSignIn && (uid == null || uid.isEmpty)) throw StateError('Sign in to save this.');
    if (!rule.stampsOwner) return value;
    return {...value, DataRules.ownerField: uid};
  }

  @override
  Future<Json?> getDocument(String path, String id) async {
    final docId = _docId(id);
    final data = await backend.get(collectionPath(path), docId);
    return data == null ? null : documentForUse(data, id: docId);
  }

  @override
  Stream<Json?> watchDocument(String path, String id) {
    final docId = _docId(id);
    return backend.watch(collectionPath(path), docId).map((d) => d == null ? null : documentForUse(d, id: docId));
  }

  CloudQuery _withRules(String path, CloudQuery query) {
    final filters = readFilters(path);
    if (filters == null) throw StateError('Sign in to see this.');
    return filters.isEmpty ? query : query.copyWith(filters: [...filters, ...query.filters]);
  }

  @override
  Future<List<Json>> query(String path, CloudQuery query, {List<String> loadRelated = const []}) async {
    final docs = await _runQuery(collectionPath(path), _withRules(path, query), path);
    return _loadRelated(path, docs, loadRelated);
  }

  Future<List<Json>> _runQuery(String collection, CloudQuery query, String path) async {
    var plan = query.plan(readyIndexes: rules.readyIndexesFor(path));
    List<CloudDocument> docs;
    try {
      docs = await backend.query(collection, plan.server);
    } on CloudIndexMissing {
      plan = query.plan(forceClient: true);
      docs = await backend.query(collection, plan.server);
    }
    return [for (final d in plan.finish(docs, data: (d) => d.data, id: (d) => d.id)) documentForUse(d.data, id: d.id)];
  }

  @override
  Stream<List<Json>> watchQuery(String path, CloudQuery query, {List<String> loadRelated = const []}) {
    final filters = readFilters(path);
    if (filters == null) return Stream.value(const []);
    final full = filters.isEmpty ? query : query.copyWith(filters: [...filters, ...query.filters]);
    final collection = collectionPath(path);
    late StreamController<List<Json>> controller;
    StreamSubscription<List<CloudDocument>>? sub;

    void listen({required bool forceClient}) {
      final plan = full.plan(forceClient: forceClient, readyIndexes: rules.readyIndexesFor(path));
      sub = backend.watchQuery(collection, plan.server).listen(
        (docs) async {
          final out = [
            for (final d in plan.finish(docs, data: (d) => d.data, id: (d) => d.id)) documentForUse(d.data, id: d.id),
          ];
          try {
            final related = await _loadRelated(path, out, loadRelated);
            if (!controller.isClosed) controller.add(related);
          } catch (error, stack) {
            if (!controller.isClosed) controller.addError(error, stack);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!forceClient && error is CloudIndexMissing) {
            sub?.cancel();
            listen(forceClient: true);
            return;
          }
          controller.addError(error, stack);
        },
      );
    }

    controller = StreamController<List<Json>>(
      onListen: () => listen(forceClient: false),
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<num?> aggregate(String path, CloudQuery query, CloudAggregate operation, {String field = ''}) async {
    if (operation != CloudAggregate.count && field.trim().isEmpty) {
      throw StateError('Pick the number field to ${operation.name}.');
    }
    final full = _withRules(path, query);
    final plan = full.plan(readyIndexes: rules.readyIndexesFor(path));
    if (!plan.runsOnClient) {
      try {
        return await backend.aggregate(collectionPath(path), plan.server, operation, field.trim());
      } on CloudIndexMissing {
        // Aggregated in the app below.
      }
    }
    final docs = await _runQuery(collectionPath(path), full, path);
    return aggregateDocuments(docs, operation, field.trim());
  }

  @override
  Future<String> addDocument(String path, Json value, {String? id, bool skipIfExists = true}) async {
    final collection = collectionPath(path);
    final prepared = prepareWrite(path, value);
    final docId = id == null ? backend.newId(collection) : _docId(id);
    if (id != null && skipIfExists && await backend.get(collection, docId) != null) return docId;
    await backend.commit([
      SetDocument(collection, docId, resolveFieldOperations(documentToSend(prepared, id: docId, now: _now), now: _now)),
    ]);
    return docId;
  }

  @override
  Future<void> updateDocument(String path, String id, Json value) async {
    final docId = _docId(id);
    final data = documentToSend(prepareWrite(path, value), id: docId, keepCreatedAt: true, now: _now);
    await backend.commit([SetDocument(collectionPath(path), docId, resolveFieldOperations(data, now: _now), merge: true)]);
  }

  @override
  Future<bool> removeDocument(String path, String id) async {
    final collection = collectionPath(path);
    final docId = _docId(id);
    if (await backend.get(collection, docId) == null) return false;
    await backend.commit([DeleteDocument(collection, docId)]);
    return true;
  }

  @override
  Future<int> removeDocuments(String path, {Iterable<String>? ids, List<CloudWhereFilter> filters = const []}) async {
    final collection = collectionPath(path);
    final targets = ids != null
        ? {
            for (final id in ids)
              if (id.trim().isNotEmpty) id.trim(),
          }.toList()
        : [for (final d in await _matching(path, filters)) d['id'] as String];
    await _commitInBatches([for (final id in targets) DeleteDocument(collection, id)]);
    return targets.length;
  }

  @override
  Future<int> setDocuments(String path, List<Json> documents,
      {String idField = 'id', bool merge = false, bool replaceCollection = false}) async {
    final collection = collectionPath(path);
    final written = <String>{};
    final writes = <DocumentWrite>[];
    for (final document in documents) {
      final given = document[idField]?.toString().trim() ?? '';
      final id = given.isEmpty ? backend.newId(collection) : given;
      written.add(id);
      final data = documentToSend(prepareWrite(path, document), id: id, keepCreatedAt: merge, now: _now);
      writes.add(SetDocument(collection, id, resolveFieldOperations(data, now: _now), merge: merge));
    }
    if (replaceCollection) {
      for (final doc in await _matching(path, const [])) {
        final id = doc['id'] as String;
        if (!written.contains(id)) writes.add(DeleteDocument(collection, id));
      }
    }
    await _commitInBatches(writes);
    return documents.length;
  }

  /// The documents of [path] passing [filters] and the read rules, the
  /// query run in the app past its `==` filters, so no index is needed.
  Future<List<Json>> _matching(String path, List<CloudWhereFilter> filters) async {
    final readable = readFilters(path);
    if (readable == null) return const [];
    final plan = CloudQuery(filters: [...readable, ...filters]).plan(forceClient: true);
    final docs = await backend.query(collectionPath(path), plan.server);
    return [for (final d in plan.finish(docs, data: (d) => d.data, id: (d) => d.id)) documentForUse(d.data, id: d.id)];
  }

  Future<void> _commitInBatches(List<DocumentWrite> writes) async {
    final size = backend.maxBatchWrites;
    for (var start = 0; start < writes.length; start += size) {
      await backend.commit(writes.sublist(start, (start + size).clamp(0, writes.length)));
    }
  }

  /// [docs] with each of their [fields] that is a reference replaced by the
  /// referenced document, read from the collection the schema names.
  Future<List<Json>> _loadRelated(String path, List<Json> docs, List<String> fields) async {
    if (fields.isEmpty || docs.isEmpty) return docs;
    final schema = rules.schemaFor(path);
    for (final name in fields) {
      final target = schema?.field(name)?.referenceCollection;
      if (target == null || target.isEmpty) continue;
      final ids = {
        for (final doc in docs)
          if (doc[name] case final String id when id.isNotEmpty) id,
      };
      final related = <String, Json>{};
      await Future.wait([
        for (final id in ids)
          getDocument(target, id).then((data) {
            if (data != null) related[id] = data;
          }),
      ]);
      for (final doc in docs) {
        if (doc[name] case final String id when related.containsKey(id)) doc[name] = related[id];
      }
    }
    return docs;
  }

  @override
  void dispose() {
    _rulesSubscription?.cancel();
    super.dispose();
  }
}
