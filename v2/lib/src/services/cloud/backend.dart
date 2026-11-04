// The document store under a CloudDatabase: Firestore in an app
// (package:codelessly_sdk/firebase.dart), memory by default and in tests.
// Paths here are full collection paths (`data/project/tasks`); the
// CloudDatabase resolves the app's paths and applies the project's rules.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'fields.dart';
import 'query.dart';

/// A document: its id and data.
@immutable
class CloudDocument {
  const CloudDocument(this.id, this.data);

  final String id;
  final Map<String, Object?> data;

  @override
  String toString() => 'CloudDocument($id, $data)';
}

/// One write of a batch.
@immutable
sealed class DocumentWrite {
  const DocumentWrite(this.collection, this.id);

  /// The full collection path.
  final String collection;
  final String id;
}

/// Writes [data] (which may hold [FieldOp]s) to a document, replacing it or,
/// with [merge], merging into it.
final class SetDocument extends DocumentWrite {
  const SetDocument(super.collection, super.id, this.data, {this.merge = false});

  final Map<String, Object?> data;
  final bool merge;
}

/// Deletes a document.
final class DeleteDocument extends DocumentWrite {
  const DeleteDocument(super.collection, super.id);
}

/// What [DocumentBackend.aggregate] computes.
enum CloudAggregate { count, sum, average }

/// Thrown (or emitted) by a backend for a query that needs a composite index
/// it doesn't have; the database then runs the query in the app.
class CloudIndexMissing implements Exception {
  const CloudIndexMissing([this.message = 'The query needs an index.']);

  final String message;

  @override
  String toString() => 'CloudIndexMissing: $message';
}

/// A document store. Queries arrive planned: a backend runs exactly the
/// [CloudQuery] it gets (its filters, sorts, limit and `startAfter`).
abstract interface class DocumentBackend {
  /// The document [id] of [collection], or null when it doesn't exist.
  Future<Map<String, Object?>?> get(String collection, String id);

  /// The document, now and on every change (null while it doesn't exist).
  Stream<Map<String, Object?>?> watch(String collection, String id);

  /// The documents of [collection] that [query] selects.
  Future<List<CloudDocument>> query(String collection, CloudQuery query);

  /// [query]'s documents, now and on every change.
  Stream<List<CloudDocument>> watchQuery(String collection, CloudQuery query);

  /// [operation] over [query]'s documents ([field] for sum and average),
  /// computed by the store.
  Future<num?> aggregate(String collection, CloudQuery query, CloudAggregate operation, String field);

  /// A new, unused document id for [collection].
  String newId(String collection);

  /// Applies [writes] at once.
  Future<void> commit(List<DocumentWrite> writes);

  /// The most writes one [commit] takes.
  int get maxBatchWrites;
}

/// [operation] over [docs]: their count, or the sum or average of the
/// numbers in [field] (documents without a number there are skipped).
num? aggregateDocuments(Iterable<Map<String, Object?>> docs, CloudAggregate operation, String field) {
  if (operation == CloudAggregate.count) return docs.length;
  final numbers = [
    for (final doc in docs)
      if (readCloudField(doc, '', field).$2 case final num value) value,
  ];
  final total = numbers.fold<num>(0, (a, b) => a + b);
  if (operation == CloudAggregate.sum) return total;
  return numbers.isEmpty ? null : total / numbers.length;
}

/// A document store in memory: the default (data lives as long as the app
/// runs) and the fake for tests. With [requireIndexes], queries that need a
/// composite index not in [indexes] fail with [CloudIndexMissing], as
/// Firestore's do.
class MemoryDocumentBackend implements DocumentBackend {
  MemoryDocumentBackend({this.requireIndexes = false, Set<String>? indexes, DateTime Function()? now})
      : indexes = indexes ?? {},
        _now = now ?? DateTime.now;

  final bool requireIndexes;

  /// Keys of the composite indexes this store has.
  final Set<String> indexes;
  final DateTime Function() _now;

  /// Collection path → id → data.
  final Map<String, Map<String, Map<String, Object?>>> collections = {};

  /// Queries run (collection, query), for tests.
  final List<(String, CloudQuery)> queries = [];

  /// Commits made, for tests.
  int commits = 0;

  final _changes = StreamController<void>.broadcast(sync: true);
  final _random = math.Random();

  @override
  int get maxBatchWrites => 500;

  /// Puts documents in [collection] directly (test setup).
  void seed(String collection, Map<String, Map<String, Object?>> docs) {
    collections.putIfAbsent(collection, () => {}).addAll({for (final e in docs.entries) e.key: {...e.value}});
    _changes.add(null);
  }

  @override
  Future<Map<String, Object?>?> get(String collection, String id) async => _copy(collections[collection]?[id]);

  @override
  Stream<Map<String, Object?>?> watch(String collection, String id) =>
      _watch(() => _copy(collections[collection]?[id]), (a, b) => mapEquals(a, b));

  @override
  Future<List<CloudDocument>> query(String collection, CloudQuery query) async => _run(collection, query);

  @override
  Stream<List<CloudDocument>> watchQuery(String collection, CloudQuery query) =>
      _watch(() => _run(collection, query), _sameDocs);

  @override
  Future<num?> aggregate(String collection, CloudQuery query, CloudAggregate operation, String field) async =>
      aggregateDocuments(_run(collection, query).map((d) => d.data), operation, field);

  @override
  String newId(String collection) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(List.generate(20, (_) => chars.codeUnitAt(_random.nextInt(chars.length))));
  }

  @override
  Future<void> commit(List<DocumentWrite> writes) async {
    if (writes.length > maxBatchWrites) throw StateError('A batch takes at most $maxBatchWrites writes.');
    commits++;
    for (final write in writes) {
      final docs = collections.putIfAbsent(write.collection, () => {});
      switch (write) {
        case DeleteDocument():
          docs.remove(write.id);
        case SetDocument(:final data, :final merge):
          final current = merge ? {...?docs[write.id]} : <String, Object?>{};
          for (final e in data.entries) {
            final applied = _apply(current[e.key], e.value);
            if (identical(applied, FieldOp.delete)) {
              current.remove(e.key);
            } else {
              current[e.key] = applied;
            }
          }
          docs[write.id] = current;
      }
    }
    _changes.add(null);
  }

  Object? _apply(Object? current, Object? value) => switch (value) {
        IncrementOp(:final by) => (current is num ? current : 0) + by,
        ArrayUnionOp(:final items) => [
            ...?(current is List ? current : null),
            for (final item in items)
              if (!(current is List && current.any((c) => cloudValuesEqual(c, item)))) item,
          ],
        ArrayRemoveOp(:final items) => [
            for (final c in (current is List ? current : const []))
              if (!items.any((item) => cloudValuesEqual(c, item))) c,
          ],
        DeleteOp() => FieldOp.delete,
        ServerTimeOp() => _now().toUtc(),
        final Map m => {for (final e in m.entries) '${e.key}': _apply(null, e.value)},
        _ => value,
      };

  List<CloudDocument> _run(String collection, CloudQuery query) {
    queries.add((collection, query));
    if (requireIndexes && !query.runsOnServer && !indexes.contains(query.requiredIndex?.key)) {
      throw CloudIndexMissing('The query on $collection needs the index ${query.requiredIndex?.key}.');
    }
    final plan = query.plan(forceClient: true);
    final docs = [
      for (final e in (collections[collection] ?? const <String, Map<String, Object?>>{}).entries)
        if (plan.server.filters.every((f) => f.matches(e.value, e.key))) CloudDocument(e.key, _copy(e.value)!),
    ];
    return plan.finish(docs, data: (d) => d.data, id: (d) => d.id);
  }

  Stream<T> _watch<T>(T Function() read, bool Function(T a, T b) same) {
    late StreamController<T> controller;
    StreamSubscription<void>? sub;
    T? last;
    var hasLast = false;
    void emit() {
      try {
        final value = read();
        if (hasLast && same(last as T, value)) return;
        last = value;
        hasLast = true;
        controller.add(value);
      } catch (error, stack) {
        controller.addError(error, stack);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        scheduleMicrotask(emit);
        sub = _changes.stream.listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  static bool _sameDocs(List<CloudDocument> a, List<CloudDocument> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i].id == b[i].id && _deepEquals(a[i].data, b[i].data)].every((x) => x);

  static bool _deepEquals(Object? a, Object? b) => cloudValuesEqual(a, b);

  static Map<String, Object?>? _copy(Map<String, Object?>? data) => data == null ? null : {...data};

  void dispose() => _changes.close();
}
