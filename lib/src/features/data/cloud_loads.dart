// Live cloud data in variables: the load cloud data action (a document, a
// query's documents, or a number over a query, streamed into a variable),
// its reload, and cloud batches.
//
// * One variable has one live load. Loading it again (or reloading it)
//   replaces the subscription; it never adds a second one.
// * A load runs again by itself when a value its query reads changes
//   (`${auth.uid}`, a search text, a limit bound to a variable), never for
//   its own variable, and stops following if it keeps re-running.
// * A query loads at most its limit (by default kDefaultCloudLoadLimit),
//   reading one more document to say truthfully whether more match.
// * Joins attach another collection's documents to each item with a few
//   `in` queries (services/cloud/join.dart).
// * An aggregate is computed by the database and re-run on this app's
//   writes (and a timer), not streamed from the documents.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart' show VoidCallback, debugPrint, visibleForTesting;

import '../../runtime/actions/context.dart';
import '../../runtime/actions/runner.dart';
import '../../runtime/contracts.dart' show ValueScope;
import '../../runtime/expressions/engine.dart';
import '../../runtime/expressions/scopes.dart';
import '../../services/services.dart';

/// The live loads of a scope's variables, by variable name.
final Expando<Map<String, LiveCloudLoad>> _loads = Expando('cloudLoads');

/// The live load of [variable] as [scope] sees it (its declaring scope's).
LiveCloudLoad? liveCloudLoadOf(ValueScope scope, String variable) =>
    _loads[_ownerOf(scope, variable.trim())]?[variable.trim()];

Object _ownerOf(ValueScope scope, String variable) => variableOf(scope, variable)?.$1 ?? scope;

/// How many times a load may run again by itself within a second before it
/// stops following its values (its query likely reads what it writes).
const int _maxRerunsPerSecond = 20;

/// Runs a [LoadCloudDataAction]: replaces [a]'s variable's live load with
/// this one and waits for its first value.
Future<void> loadCloudData(LoadCloudDataAction a, ActionRun run) async {
  final cloud = run.require<CloudDatabase>('Cloud data');
  final variable = a.variable.trim();
  if (variable.isEmpty) return;
  final owner = _ownerOf(run.context.scope, variable);
  final byName = _loads[owner] ??= {};
  final load = byName[variable] ??= LiveCloudLoad._(variable, byName);
  await load._start(a, run, cloud);
}

/// Runs a [ReloadCloudDataAction]: its variable's live load subscribes
/// afresh and the chain waits for its first value.
Future<void> reloadCloudData(ReloadCloudDataAction a, ActionRun run) async {
  final load = liveCloudLoadOf(run.context.scope, a.variable);
  if (load == null) return;
  await load.reload();
}

/// [a]'s source as the app's shared data keeps it (`scope: app`): a key
/// naming what it reads now (the same key is the same data) and what opens
/// it, with the screen loads' limit, aggregate and joins. The documents come
/// trimmed to the limit.
({String key, Stream<Object?> Function() open}) appCloudSource(LoadCloudDataAction a, ActionRun run, CloudDatabase db) {
  final load = LiveCloudLoad._(a.variable.trim(), {})
    .._action = a
    .._run = run
    .._db = db;
  final r = load._resolve();
  return (
    key: r.signature,
    open: () => load._stream(r).map((data) {
          final limit = r.limit;
          return data is List && limit != null && data.length > limit ? data.sublist(0, limit) : data;
        }),
  );
}

/// A variable's live cloud data: what a [LoadCloudDataAction] streams in.
class LiveCloudLoad {
  LiveCloudLoad._(this.variable, this._registry);

  final String variable;

  /// Its scope's loads, which it leaves when closed.
  final Map<String, LiveCloudLoad> _registry;

  LoadCloudDataAction? _action;
  ActionRun? _run;
  CloudDatabase? _db;
  ActionHost? _host;

  StreamSubscription<Object?>? _sub;
  Completer<void>? _first;
  String? _signature;
  Object? _lastData;
  final List<VoidCallback> _unwatch = [];
  final List<DateTime> _reruns = [];
  bool _scheduled = false;
  bool _closed = false;

  /// How many subscriptions it opened (each replacing the one before).
  @visibleForTesting
  int subscriptions = 0;

  /// Whether a subscription is open.
  bool get isActive => _sub != null;

  Future<void> _start(LoadCloudDataAction a, ActionRun run, CloudDatabase db) async {
    _closed = false;
    _action = a;
    _run = run;
    _db = db;
    if (!identical(_host, run.host)) {
      final host = _host = run.host;
      // The screen that ran it goes: so does the load (unless another
      // screen's run took it over since).
      host.onDispose(() {
        if (identical(_host, host)) close();
      });
    }
    _watchValues();
    final first = _subscribe();
    final removeCancellation = run.onCancel(() {
      // The node left before the first value: nothing keeps it.
      if (identical(_first, first) && !first.isCompleted) close();
    });
    try {
      await first.future;
    } finally {
      removeCancellation();
    }
  }

  /// Subscribes afresh with the values its query reads now; completes with
  /// the first value.
  Future<void> reload() {
    if (_action == null || _closed) return Future.value();
    return _subscribe().future;
  }

  /// Ends the load: its subscription, its watches.
  void close() {
    _closed = true;
    _cancelSubscription(closing: true);
    for (final u in _unwatch) {
      u();
    }
    _unwatch.clear();
    if (identical(_registry[variable], this)) _registry.remove(variable);
  }

  void _cancelSubscription({bool closing = false}) {
    final sub = _sub;
    _sub = null;
    if (sub != null) unawaited(sub.cancel());
    final first = _first;
    if (first == null || first.isCompleted) return;
    // A chain waiting on a replaced subscription carries on; on a closed
    // load (the screen went) it stops.
    if (closing) {
      first.completeError(const ActionsCanceled());
    } else {
      first.complete();
    }
  }

  // --- what it loads ----------------------------------------------------------------

  /// [a] resolved now: where, what, and a signature that changes when any
  /// of it does.
  _Resolved _resolve() {
    final a = _action!, run = _run!;
    final path = resolveCollectionPath(a.query, run.expressions, run.scope);
    final id = run.text(a.id).trim();
    final aggregate = a.aggregate != CloudLoadAggregate.none;
    // The limit: the action's (a number or expression), the query's, or
    // the default; 0 or less loads everything.
    int? limit;
    var defaulted = false;
    final given = a.limit.trim();
    final bound = given.isEmpty ? null : num.tryParse(run.text(given).trim());
    if (bound != null) {
      limit = bound <= 0 ? null : bound.round();
    } else if (a.query.limit != null) {
      limit = a.query.limit;
    } else {
      limit = kDefaultCloudLoadLimit;
      defaulted = true;
    }
    final resolved = a.single && !aggregate ? null : resolveCloudQuery(a.query, run.expressions, run.scope);
    final query = resolved == null
        ? null
        : aggregate
            ? CloudQuery(filters: resolved.filters)
            : CloudQuery(filters: resolved.filters, orderBy: resolved.orderBy, limit: limit == null ? null : limit + 1);
    final joins = [
      for (final j in a.query.joins)
        (j, run.expressions.interpolate(j.collection, run.scope).trim()),
    ];
    // What the join keys read besides the item (`${auth.uid}`): a change
    // re-reads the matches.
    final joinValues = [
      for (final (j, _) in joins)
        for (final read in Expressions.readsOf(j.id))
          if (rootOf(read) != 'item') '$read=${readPath(run.scope, read)}',
    ];
    return _Resolved(
      path: path,
      id: id,
      query: query,
      limit: aggregate || a.single ? null : limit,
      defaultedLimit: defaulted,
      joins: joins,
      signature: [
        path, a.single, id, query, a.aggregate.name, a.aggregateField, //
        for (final (j, c) in joins) '${j.toJson()}@$c',
        ...joinValues,
      ].join('|'),
    );
  }

  Stream<Object?> _stream(_Resolved r) {
    final a = _action!, run = _run!, db = _db!;
    if (a.aggregate != CloudLoadAggregate.none) {
      final op = switch (a.aggregate) {
        CloudLoadAggregate.sum => CloudAggregate.sum,
        CloudLoadAggregate.average => CloudAggregate.average,
        _ => CloudAggregate.count,
      };
      final every = a.refreshSeconds > 0 ? Duration(seconds: a.refreshSeconds) : null;
      final field = a.aggregateField.trim();
      if (db is BackendCloudDatabase) return db.watchAggregate(r.path, r.query!, op, field: field, every: every);
      return _polled(() => db.aggregate(r.path, r.query!, op, field: field), every);
    }
    if (a.single) return db.watchDocument(r.path, r.id);
    final docs = db.watchQuery(r.path, r.query!, loadRelated: a.query.loadRelated);
    if (r.joins.isEmpty) return docs;
    return watchJoined(db, docs, [
      for (final (j, collection) in r.joins)
        CloudJoinSpec(
          collection: collection,
          as: j.as,
          foreignField: j.foreignField,
          many: j.many,
          keyOf: j.id.trim().isNotEmpty
              ? (item) => run.expressions.interpolate(j.id, ValuesScope({'item': item}, run.scope))
              : (item) => j.localField.trim() == 'id' || j.localField.trim().isEmpty
                  ? item['id']
                  : readCloudField(item, '${item['id']}', j.localField.trim()).$2,
        ),
    ]);
  }

  static Stream<num?> _polled(Future<num?> Function() read, Duration? every) async* {
    yield await read();
    if (every == null) return;
    while (true) {
      await Future<void>.delayed(every);
      yield await read();
    }
  }

  Completer<void> _subscribe([_Resolved? resolved]) {
    _cancelSubscription();
    final first = _first = Completer<void>();
    final a = _action!, run = _run!;
    final scope = run.context.scope;
    final found = variableOf(scope, variable);
    final type = found?.$2.type;

    void put(String status, {Object? data, Object? error, bool? hasMore}) {
      // A list variable holds the documents, a number variable the number;
      // any other the whole state.
      if (type == VariableType.list || ((type == VariableType.integer || type == VariableType.decimal) && a.aggregate != CloudLoadAggregate.none)) {
        if (status == 'loaded') setVariableIn(scope, variable, data);
        return;
      }
      setVariableIn(scope, variable, {
        'status': status,
        'isLoading': status == 'loading',
        'data': data,
        'error': ?error,
        'hasMore': ?hasMore,
      });
    }

    late _Resolved r;
    late Stream<Object?> stream;
    try {
      r = resolved ?? _resolve();
      _signature = r.signature;
      // Reloading keeps what it showed until the new value comes.
      put('loading', data: _lastData);
      stream = _stream(r);
    } catch (error, stack) {
      put('error', error: '$error');
      first.completeError(error, stack);
      return first;
    }
    var active = true;
    subscriptions++;
    _sub = stream.listen(
      (value) {
        if (!active || !identical(_first, first)) return;
        var data = value;
        bool? hasMore;
        final limit = r.limit;
        if (data is List && !a.single && a.aggregate == CloudLoadAggregate.none) {
          hasMore = limit != null && data.length > limit;
          if (hasMore) data = data.sublist(0, limit);
          if (hasMore && r.defaultedLimit) _warnDefaultLimit(r.path);
        }
        _lastData = data;
        put('loaded', data: data, hasMore: hasMore);
        if (!first.isCompleted) first.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!active || !identical(_first, first)) return;
        active = false;
        _sub = null;
        put('error', error: '$error');
        if (!first.isCompleted) {
          first.completeError(error, stack);
        } else {
          // A later subscription error has no awaited action to throw
          // through. Stop this invocation's remaining actions, report once.
          run.stop();
          run.host.reportError(ActionFailed(a.type, error, nodeId: run.node?.id), stack, action: a.type);
        }
      },
      onDone: () {
        if (active && identical(_first, first) && !first.isCompleted) {
          active = false;
          final error = StateError('Cloud data stream closed before a value');
          put('error', error: '$error');
          first.completeError(error);
        }
      },
      cancelOnError: true,
    );
    return first;
  }

  static final Set<String> _warned = {};

  static void _warnDefaultLimit(String path) {
    if (!_warned.add(path)) return;
    debugPrint('Codelessly: a load of "$path" stopped at $kDefaultCloudLoadLimit documents (the default limit). '
        'Set the load\'s limit (0 for all) or page it; its variable\'s hasMore is true.');
  }

  // --- following its values ------------------------------------------------------------

  /// Watches the names its query reads (not its own variable), to run again
  /// when one changes.
  void _watchValues() {
    for (final u in _unwatch) {
      u();
    }
    _unwatch.clear();
    final a = _action!, run = _run!;
    if (!a.reactive) return;
    final texts = [
      a.query.collectionPath, a.id, a.limit, //
      for (final w in a.query.where) ...[w.field, w.value],
      for (final o in a.query.orderBy) o.field,
      for (final j in a.query.joins) j.collection,
    ];
    final roots = {
      for (final t in texts)
        for (final read in Expressions.readsOf(t)) rootOf(read),
      for (final j in a.query.joins)
        for (final read in Expressions.readsOf(j.id))
          if (rootOf(read) != 'item') rootOf(read),
    }..removeAll({rootOf(variable), 'result', 'loop'});
    for (final root in roots) {
      final w = watchName(run.scope, root);
      if (w == null) continue;
      w.addListener(_changed);
      _unwatch.add(() => w.removeListener(_changed));
    }
  }

  void _changed() {
    if (_scheduled || _closed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_closed || _action == null) return;
      final _Resolved r;
      try {
        r = _resolve();
      } catch (_) {
        return;
      }
      if (r.signature == _signature) return;
      final now = DateTime.now();
      _reruns
        ..add(now)
        ..removeWhere((t) => now.difference(t) > const Duration(seconds: 1));
      if (_reruns.length > _maxRerunsPerSecond) {
        for (final u in _unwatch) {
          u();
        }
        _unwatch.clear();
        final run = _run!;
        run.host.reportError(
            ActionFailed(LoadCloudDataAction.typeName,
                StateError('The load of "$variable" ran again $_maxRerunsPerSecond times in a second: it no longer '
                    'follows the values its query reads. Does its query read a value that changes as it loads?'),
                nodeId: run.node?.id),
            StackTrace.current,
            action: LoadCloudDataAction.typeName);
        return;
      }
      final first = _subscribe(r);
      // Nobody awaits a re-run: its failure is reported by the listener.
      first.future.ignore();
    });
  }
}

class _Resolved {
  const _Resolved({
    required this.path,
    required this.id,
    required this.query,
    required this.limit,
    required this.defaultedLimit,
    required this.joins,
    required this.signature,
  });

  final String path, id;
  final CloudQuery? query;

  /// The most documents shown (the query reads one more); null: all.
  final int? limit;
  final bool defaultedLimit;
  final List<(CloudJoin, String)> joins;
  final String signature;
}

// --- cloud batches -------------------------------------------------------------------

/// Runs a [CloudBatchAction]: its write steps, once or per item of its
/// `forEach`, committed together ([BackendCloudDatabase.commitBatch]);
/// `${result}` is the ids written. A batch with a read step, or on a
/// database that isn't a [BackendCloudDatabase], runs its steps one by one
/// with [single].
Future<void> cloudBatch(CloudBatchAction a, ActionRun run, Future<void> Function(CloudDataAction step, ActionRun run) single) async {
  final turns = <ActionRun>[];
  final each = a.forEach.trim();
  if (each.isEmpty) {
    turns.add(run);
  } else {
    var value = each.contains(r'${') ? run.evaluate(each) : readPath(run.scope, each);
    // A cloud data variable keeps its documents under `data`.
    if (value is Map && value['data'] is List) value = value['data'];
    if (value is! List) return;
    for (final (i, item) in List<Object?>.of(value).indexed) {
      final turn = {'item': item, 'index': i};
      turns.add(run.nested(turn, names: {'loop': turn}));
    }
  }
  const writes = {CloudDataOperation.create, CloudDataOperation.update, CloudDataOperation.delete};
  final db = run.service<CloudDatabase>();
  if (db is! BackendCloudDatabase || a.steps.any((s) => !writes.contains(s.operation))) {
    for (final turn in turns) {
      for (final step in a.steps) {
        if (!step.enabled || (step.when != null && !turn.expressions.test(step.when!, turn.scope))) continue;
        await single(step, turn);
      }
    }
    return;
  }
  final batch = <CloudBatchWrite>[];
  for (final turn in turns) {
    for (final step in a.steps) {
      if (!step.enabled || (step.when != null && !turn.expressions.test(step.when!, turn.scope))) continue;
      final path = turn.text(step.collection).trim();
      final id = turn.text(step.id).trim();
      final create = step.operation == CloudDataOperation.create;
      final data = step.operation == CloudDataOperation.delete
          ? const <String, Object?>{}
          : CloudFieldValues.buildWrite(
              fields: step.fields, schema: db.rules.schemaFor(path), evaluate: turn.evaluate, create: create);
      batch.add(CloudBatchWrite(
        switch (step.operation) {
          CloudDataOperation.create => CloudBatchOperation.create,
          CloudDataOperation.update => CloudBatchOperation.update,
          _ => CloudBatchOperation.delete,
        },
        path,
        id: id.isEmpty ? null : id,
        data: data,
      ));
    }
  }
  run.result = batch.isEmpty ? const <String>[] : await db.commitBatch(batch, atomic: a.transaction);
}
