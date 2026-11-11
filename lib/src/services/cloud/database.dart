// The app's cloud database: documents and collection queries under the
// project's root, with its data rules applied (who reads and writes what),
// on a pluggable DocumentBackend.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show DataRule, DataRules, Json, WhereOperator;
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

/// What one write of [BackendCloudDatabase.commitBatch] does.
enum CloudBatchOperation {
  /// Creates (or replaces) a document: a generated id when none is given.
  create,

  /// Merges fields into a document, creating it.
  update,

  /// Deletes a document.
  delete,
}

/// One write of [BackendCloudDatabase.commitBatch]: [data] may hold
/// [FieldOp]s (an increment, the server time).
@immutable
class CloudBatchWrite {
  const CloudBatchWrite(this.operation, this.path, {this.id, this.data = const {}});

  final CloudBatchOperation operation;

  /// The app's collection path.
  final String path;
  final String? id;
  final Json data;
}

/// A [CloudDatabase] on a [DocumentBackend]. Documents live under [root]
/// (a document path such as `data/{projectId}`); [rules] come from
/// [rulesSource] (they change without a publish); [userId] is the signed-in
/// user, for owner stamps and owner-only reads.
///
/// [userChanges] tells it the user may have changed (signed in or out):
/// live queries whose rules read the user ([watchQuery], [watchAggregate])
/// subscribe again with the new user's filter.
class BackendCloudDatabase extends ChangeNotifier implements CloudDatabase {
  BackendCloudDatabase({
    required this.backend,
    this.root = 'data/default',
    this._rules = const DataRules(),
    Stream<DataRules>? rulesSource,
    String? Function()? userId,
    Stream<Object?>? userChanges,
    this.audience,
    DateTime Function()? now,
    this.onError,
  })  : userId = userId ?? _nobody,
        _now = now ?? DateTime.now {
    _rulesSubscription = rulesSource?.listen((r) {
      _rules = r;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => onError?.call(error, stack));
    _userSubscription = userChanges?.listen((_) => _userChanged.add(null),
        onError: (Object error, StackTrace stack) => onError?.call(error, stack));
  }

  StreamSubscription<Object?>? _userSubscription;
  final _userChanged = StreamController<void>.broadcast();
  final _written = StreamController<String>.broadcast();

  /// The full collection paths this database writes to, as it commits:
  /// what a live aggregate re-runs on.
  Stream<String> get writtenCollections => _written.stream;

  void _wrote(Iterable<DocumentWrite> writes) {
    for (final collection in {for (final w in writes) w.collection}) {
      if (!_written.isClosed) _written.add(collection);
    }
  }

  Future<void> _commit(List<DocumentWrite> writes) async {
    await backend.commit(writes);
    _wrote(writes);
  }

  /// Whether reads of [path] depend on who is signed in (an audience
  /// collection: also on their role).
  bool _readsUser(String path) {
    final rule = rules.ruleFor(path);
    return rule.readsOwnOnly || rule.readsAudience || rule == DataRule.signedIn;
  }

  /// Who is reading, as far as the read filters go: the user and, with
  /// [audience], the entries they match (a role can change without a new
  /// user).
  String _readerKey() => '${userId()}|${audience?.call().join(',') ?? ''}';

  static String? _nobody() => null;

  final DocumentBackend backend;

  /// The document all of the app's collections are under.
  final String root;
  final String? Function() userId;

  /// The entries of an `audience` list the signed-in user matches
  /// ([DataRules.audienceOf]: everyone, the user, their role, signed-in
  /// users). Without it: everyone and the user.
  final List<String> Function()? audience;
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
  /// ones, the audience filter for audience ones, and the expiry bound
  /// (`field > now`) for expiring ones; null when nobody is signed in and
  /// the rules need someone.
  List<CloudWhereFilter>? readFilters(String path) {
    final rule = rules.ruleFor(path);
    final expiry = _expiryFilters(path);
    if (!rule.readsOwnOnly && !rule.readsAudience && rule != DataRule.signedIn) return expiry;
    final uid = userId();
    if (uid == null || uid.isEmpty) return null;
    if (rule.readsOwnOnly) return [CloudWhereFilter(DataRules.ownerField, WhereOperator.equal, uid), ...expiry];
    if (rule.readsAudience) {
      final audience = this.audience?.call() ?? DataRules.audienceOf(uid);
      return [CloudWhereFilter(DataRules.audienceField, WhereOperator.arrayContainsAny, audience), ...expiry];
    }
    return expiry;
  }

  List<CloudWhereFilter> _expiryFilters(String path) {
    final field = rules.expiryFieldFor(path);
    if (field == null) return const [];
    return [CloudWhereFilter(field, WhereOperator.greaterThan, _nowText())];
  }

  String _nowText() =>
      DateTime.fromMillisecondsSinceEpoch(_now().millisecondsSinceEpoch, isUtc: true).toIso8601String();

  /// The rule filters the database must run itself, because its rules check
  /// them on every query: the audience filter and the expiry bound (with the
  /// owner filter beside them). Empty for the other collections, whose
  /// queries the app may finish as before.
  List<CloudWhereFilter> _serverFilters(String path, List<CloudWhereFilter> ruleFilters) =>
      rules.expiryFieldFor(path) != null || rules.ruleFor(path).readsAudience ? ruleFilters : const [];

  /// [docs] without those past their expiry at this moment: a live query's
  /// bound was set when it started.
  List<Json> _withoutExpired(String path, List<Json> docs) {
    final field = rules.expiryFieldFor(path);
    if (field == null) return docs;
    final now = _nowText();
    return [
      for (final doc in docs)
        if (doc[field] case final String at when at.compareTo(now) > 0) doc,
    ];
  }

  /// [value] ready to write under [path]: owned collections record the
  /// signed-in user as the owner. In an expiring collection the expiry
  /// field is written as ISO text, and an empty one (or, when [create], a
  /// missing one) as [DataRules.neverExpires]. Throws a [StateError] when
  /// the collection needs a signed-in user and there is none.
  Json prepareWrite(String path, Json value, {bool create = false}) {
    final rule = rules.ruleFor(path);
    final uid = userId();
    if (rule.writeNeedsSignIn && (uid == null || uid.isEmpty)) throw StateError('Sign in to save this.');
    final out = _withExpiry(path, value, create: create);
    if (!rule.stampsOwner) return out;
    return {...out, DataRules.ownerField: uid};
  }

  Json _withExpiry(String path, Json value, {required bool create}) {
    final field = rules.expiryFieldFor(path);
    if (field == null || value.isEmpty) return value;
    if (!value.containsKey(field)) return create ? {...value, field: DataRules.neverExpires} : value;
    final raw = value[field];
    if (raw == null || (raw is String && raw.trim().isEmpty)) return {...value, field: DataRules.neverExpires};
    if (raw is DateTime || raw is int) return {...value, field: cloudDateText(raw)};
    return value;
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
    return _loadRelated(path, _withoutExpired(path, docs), loadRelated);
  }

  Future<List<Json>> _runQuery(String collection, CloudQuery query, String path) async {
    final pinned = _serverFilters(path, readFilters(path) ?? const []);
    var plan = query.plan(readyIndexes: rules.readyIndexesFor(path), keepOnServer: pinned);
    List<CloudDocument> docs;
    try {
      docs = await backend.query(collection, plan.server);
    } on CloudIndexMissing {
      plan = query.plan(forceClient: true, keepOnServer: pinned);
      docs = await backend.query(collection, plan.server);
    }
    return [for (final d in plan.finish(docs, data: (d) => d.data, id: (d) => d.id)) documentForUse(d.data, id: d.id)];
  }

  /// Emits an empty list while the reader may not read [path] (signed out
  /// of an owner-only collection); when the user changes, a query whose
  /// rules read the user subscribes again, so it follows sign in and out.
  @override
  Stream<List<Json>> watchQuery(String path, CloudQuery query, {List<String> loadRelated = const []}) {
    final collection = collectionPath(path);
    late StreamController<List<Json>> controller;
    StreamSubscription<List<CloudDocument>>? sub;
    StreamSubscription<void>? users;
    String? reader;
    // Bumped by every subscription: what an earlier one still delivers is
    // dropped.
    var generation = 0;

    void listen({required bool forceClient}) {
      sub?.cancel();
      sub = null;
      final current = ++generation;
      reader = _readerKey();
      final filters = readFilters(path);
      if (filters == null) {
        controller.add(const []);
        return;
      }
      final full = filters.isEmpty ? query : query.copyWith(filters: [...filters, ...query.filters]);
      final pinned = _serverFilters(path, filters);
      final plan = full.plan(forceClient: forceClient, readyIndexes: rules.readyIndexesFor(path), keepOnServer: pinned);
      sub = backend.watchQuery(collection, plan.server).listen(
        (docs) async {
          final out = _withoutExpired(path, [
            for (final d in plan.finish(docs, data: (d) => d.data, id: (d) => d.id)) documentForUse(d.data, id: d.id),
          ]);
          try {
            final related = await _loadRelated(path, out, loadRelated);
            if (!controller.isClosed && current == generation) controller.add(related);
          } catch (error, stack) {
            if (!controller.isClosed && current == generation) controller.addError(error, stack);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (current != generation) return;
          if (!forceClient && error is CloudIndexMissing) {
            listen(forceClient: true);
            return;
          }
          controller.addError(error, stack);
        },
      );
    }

    controller = StreamController<List<Json>>(
      onListen: () {
        listen(forceClient: false);
        users = _userChanged.stream.listen((_) {
          if (_readerKey() != reader && _readsUser(path)) listen(forceClient: false);
        });
      },
      onCancel: () {
        generation++;
        users?.cancel();
        return sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// [operation] over [query]'s documents, now and again after this
  /// database writes to [path]'s collection, when the user changes, and
  /// every [every] (writes made elsewhere): computed by the store (with
  /// Firestore, a count costs one read per 1000 documents counted), so no
  /// document is downloaded and no listener holds them. A count of a
  /// collection the reader may not read is 0.
  Stream<num?> watchAggregate(String path, CloudQuery query, CloudAggregate operation,
      {String field = '', Duration? every}) {
    final collection = collectionPath(path);
    late StreamController<num?> controller;
    final subs = <StreamSubscription<Object?>>[];
    Timer? timer;
    var running = false, again = false, scheduled = false;

    Future<void> run() async {
      if (running) {
        again = true;
        return;
      }
      running = true;
      try {
        do {
          again = false;
          final num? value = readFilters(path) == null
              ? (operation == CloudAggregate.count ? 0 : null)
              : await aggregate(path, CloudQuery(filters: query.filters), operation, field: field);
          if (!controller.isClosed) controller.add(value);
        } while (again && !controller.isClosed);
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      } finally {
        running = false;
      }
    }

    // A burst (a batch's writes, a write and a sign in) runs it once.
    void soon() {
      if (scheduled) return;
      scheduled = true;
      scheduleMicrotask(() {
        scheduled = false;
        if (!controller.isClosed) run();
      });
    }

    controller = StreamController<num?>(
      onListen: () {
        run();
        subs.add(_written.stream.listen((written) {
          if (written == collection) soon();
        }));
        subs.add(_userChanged.stream.listen((_) {
          if (_readsUser(path)) soon();
        }));
        if (every != null && every > Duration.zero) timer = Timer.periodic(every, (_) => soon());
      },
      onCancel: () {
        timer?.cancel();
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Commits [writes] at once (with the rules' owner stamps and the
  /// documents' dates, like the single writes) and returns the ids written.
  /// More than [DocumentBackend.maxBatchWrites] go in commits of that size,
  /// each all or none; with [atomic] they throw a [StateError] before
  /// anything is written.
  Future<List<String>> commitBatch(List<CloudBatchWrite> writes, {bool atomic = false}) async {
    final max = backend.maxBatchWrites;
    if (atomic && writes.length > max) {
      throw StateError('A batch writes at most $max documents at once; this one has ${writes.length}.');
    }
    final ids = <String>[];
    final out = <DocumentWrite>[];
    for (final w in writes) {
      final collection = collectionPath(w.path);
      switch (w.operation) {
        case CloudBatchOperation.create:
          final given = w.id?.trim() ?? '';
          final id = given.isEmpty ? backend.newId(collection) : given;
          final data = documentToSend(prepareWrite(w.path, w.data, create: true), id: id, now: _now);
          out.add(SetDocument(collection, id, resolveFieldOperations(data, now: _now)));
          ids.add(id);
        case CloudBatchOperation.update:
          final id = _docId(w.id);
          final data = documentToSend(prepareWrite(w.path, w.data), id: id, keepCreatedAt: true, now: _now);
          out.add(SetDocument(collection, id, resolveFieldOperations(data, now: _now), merge: true));
          ids.add(id);
        case CloudBatchOperation.delete:
          final id = _docId(w.id);
          out.add(DeleteDocument(collection, id));
          ids.add(id);
      }
    }
    await _commitInBatches(out);
    return ids;
  }

  @override
  Future<num?> aggregate(String path, CloudQuery query, CloudAggregate operation, {String field = ''}) async {
    if (operation != CloudAggregate.count && field.trim().isEmpty) {
      throw StateError('Pick the number field to ${operation.name}.');
    }
    final full = _withRules(path, query);
    final plan = full.plan(readyIndexes: rules.readyIndexesFor(path), keepOnServer: _serverFilters(path, readFilters(path)!));
    if (!plan.runsOnClient) {
      try {
        return await backend.aggregate(collectionPath(path), plan.server, operation, field.trim());
      } on CloudIndexMissing {
        // Aggregated in the app below.
      }
    }
    final docs = await _runQuery(collectionPath(path), full, path);
    return aggregateDocuments(_withoutExpired(path, docs), operation, field.trim());
  }

  @override
  Future<String> addDocument(String path, Json value, {String? id, bool skipIfExists = true}) async {
    final collection = collectionPath(path);
    final prepared = prepareWrite(path, value, create: true);
    final docId = id == null ? backend.newId(collection) : _docId(id);
    if (id != null && skipIfExists && await backend.get(collection, docId) != null) return docId;
    await _commit([
      SetDocument(collection, docId, resolveFieldOperations(documentToSend(prepared, id: docId, now: _now), now: _now)),
    ]);
    return docId;
  }

  @override
  Future<void> updateDocument(String path, String id, Json value) async {
    final docId = _docId(id);
    final data = documentToSend(prepareWrite(path, value), id: docId, keepCreatedAt: true, now: _now);
    await _commit([SetDocument(collectionPath(path), docId, resolveFieldOperations(data, now: _now), merge: true)]);
  }

  @override
  Future<bool> removeDocument(String path, String id) async {
    final collection = collectionPath(path);
    final docId = _docId(id);
    if (await backend.get(collection, docId) == null) return false;
    await _commit([DeleteDocument(collection, docId)]);
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
      final data = documentToSend(prepareWrite(path, document, create: !merge), id: id, keepCreatedAt: merge, now: _now);
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
    final plan = CloudQuery(filters: [...readable, ...filters])
        .plan(forceClient: true, keepOnServer: _serverFilters(path, readable));
    final docs = await backend.query(collectionPath(path), plan.server);
    return [for (final d in plan.finish(docs, data: (d) => d.data, id: (d) => d.id)) documentForUse(d.data, id: d.id)];
  }

  Future<void> _commitInBatches(List<DocumentWrite> writes) async {
    final size = backend.maxBatchWrites;
    for (var start = 0; start < writes.length; start += size) {
      await _commit(writes.sublist(start, (start + size).clamp(0, writes.length)));
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
    _userSubscription?.cancel();
    _userChanged.close();
    _written.close();
    super.dispose();
  }
}
