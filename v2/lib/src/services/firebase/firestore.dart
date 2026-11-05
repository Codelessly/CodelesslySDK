// Cloud data on Cloud Firestore: a DocumentBackend, the project's data rules
// document, and where a project's data lives.
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api_v2/codelessly_api.dart' show DataRules, WhereOperator;

import '../cloud/backend.dart';
import '../cloud/fields.dart';
import '../cloud/query.dart';

/// Which published data an app reads.
enum DataSource {
  publish('data'),
  preview('preview_data'),
  template('template_data');

  const DataSource(this.collection);

  /// The Firestore collection holding each project's data document.
  final String collection;
}

/// The document a project's cloud data is under (`data/{projectId}`).
String firestoreRoot(String projectId, {DataSource source = DataSource.publish}) => '${source.collection}/$projectId';

/// The project's data rules (`data_rules/{projectId}`), now and on every
/// change.
Stream<DataRules> firestoreDataRules(FirebaseFirestore firestore, String projectId) => firestore
    .collection('data_rules')
    .doc(projectId)
    .snapshots()
    .map((snapshot) => DataRules.fromJson(snapshot.data()));

/// Creates the project's root document ([root]) when missing.
Future<void> ensureFirestoreRoot(FirebaseFirestore firestore, String root, String projectId) async {
  final ref = firestore.doc(root);
  if ((await ref.get()).exists) return;
  await ref.set({'project': projectId});
}

/// Whether [error] is Firestore saying a query needs an index it lacks.
bool isMissingIndexError(Object? error) => error is FirebaseException && error.code == 'failed-precondition';

/// A readable message for a cloud [error], with Firestore's code.
String describeCloudError(Object? error) => switch (error) {
      FirebaseException(:final code, :final message) => message == null || message.isEmpty ? code : '$message ($code)',
      CloudIndexMissing(:final message) => message,
      null => 'Unknown error',
      _ => '$error',
    };

/// Firestore values as the SDK's: timestamps as UTC DateTimes, blobs as
/// bytes, references as their path, geo points as `{latitude, longitude}`.
Object? fromFirestore(Object? value) => switch (value) {
      Timestamp() => value.toDate().toUtc(),
      Blob() => value.bytes,
      DocumentReference() => value.path,
      GeoPoint() => {'latitude': value.latitude, 'longitude': value.longitude},
      List() => [for (final v in value) fromFirestore(v)],
      Map() => {for (final e in value.entries) '${e.key}': fromFirestore(e.value)},
      _ => value,
    };

/// The SDK's values as Firestore's: [FieldOp]s as `FieldValue`s, bytes as
/// blobs.
Object? toFirestore(Object? value) => switch (value) {
      IncrementOp(:final by) => FieldValue.increment(by),
      ArrayUnionOp(:final items) => FieldValue.arrayUnion([for (final i in items) toFirestore(i)]),
      ArrayRemoveOp(:final items) => FieldValue.arrayRemove([for (final i in items) toFirestore(i)]),
      DeleteOp() => FieldValue.delete(),
      ServerTimeOp() => FieldValue.serverTimestamp(),
      Uint8List() => Blob(value),
      List() => [for (final v in value) toFirestore(v)],
      Map() => {for (final e in value.entries) '${e.key}': toFirestore(e.value)},
      _ => value,
    };

Map<String, Object?> _data(Map<String, dynamic>? data) => {
      for (final e in (data ?? const <String, dynamic>{}).entries) e.key: fromFirestore(e.value),
    };

/// A [DocumentBackend] on Cloud Firestore.
class FirestoreDocumentBackend implements DocumentBackend {
  FirestoreDocumentBackend(this.firestore, {this.onRead, this.onWrite});

  final FirebaseFirestore firestore;

  /// Counts reads and writes (usage stats), by operation.
  final void Function(String operation)? onRead;
  final void Function(String operation)? onWrite;

  @override
  int get maxBatchWrites => 500;

  @override
  Future<Map<String, Object?>?> get(String collection, String id) async {
    final snapshot = await firestore.collection(collection).doc(id).get();
    onRead?.call('get');
    return snapshot.exists ? _data(snapshot.data()) : null;
  }

  @override
  Stream<Map<String, Object?>?> watch(String collection, String id) =>
      firestore.collection(collection).doc(id).snapshots().map((s) {
        onRead?.call('watch');
        return s.exists ? _data(s.data()) : null;
      });

  static Object _field(String field) => field == cloudDocumentIdField ? FieldPath.documentId : field;

  /// [ref] narrowed by [query]'s filters, sorts and limit.
  static Query<Map<String, dynamic>> applyQuery(Query<Map<String, dynamic>> ref, CloudQuery query) {
    var q = ref;
    for (final f in query.filters) {
      final field = _field(f.field);
      final value = toFirestore(f.value);
      final values = value is List ? value : null;
      q = switch (f.operator) {
        WhereOperator.equal => q.where(field, isEqualTo: value),
        WhereOperator.notEqual => q.where(field, isNotEqualTo: value),
        WhereOperator.lessThan => q.where(field, isLessThan: value),
        WhereOperator.lessThanOrEqual => q.where(field, isLessThanOrEqualTo: value),
        WhereOperator.greaterThan => q.where(field, isGreaterThan: value),
        WhereOperator.greaterThanOrEqual => q.where(field, isGreaterThanOrEqualTo: value),
        WhereOperator.arrayContains => q.where(field, arrayContains: value),
        WhereOperator.arrayContainsAny => q.where(field, arrayContainsAny: values),
        WhereOperator.inArray => q.where(field, whereIn: values),
        WhereOperator.notInArray => q.where(field, whereNotIn: values),
      };
    }
    for (final o in query.orderBy) {
      q = q.orderBy(_field(o.field), descending: o.descending);
    }
    if (query.limit case final int limit) q = q.limit(limit);
    return q;
  }

  Future<Query<Map<String, dynamic>>> _query(String collection, CloudQuery query) async {
    final ref = firestore.collection(collection);
    var q = applyQuery(ref, query);
    if (query.startAfter case final String after) {
      final last = await ref.doc(after).get();
      if (last.exists) q = q.startAfterDocument(last);
    }
    return q;
  }

  static List<CloudDocument> _docs(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      [for (final d in snapshot.docs) CloudDocument(d.id, _data(d.data()))];

  static Object _error(Object error) => isMissingIndexError(error) ? CloudIndexMissing(describeCloudError(error)) : error;

  @override
  Future<List<CloudDocument>> query(String collection, CloudQuery query) async {
    try {
      final snapshot = await (await _query(collection, query)).get();
      onRead?.call('query');
      return _docs(snapshot);
    } catch (error, stack) {
      Error.throwWithStackTrace(_error(error), stack);
    }
  }

  @override
  Stream<List<CloudDocument>> watchQuery(String collection, CloudQuery query) => Stream.fromFuture(_query(collection, query))
      .asyncExpand((q) => q.snapshots())
      .map((snapshot) {
        onRead?.call('watchQuery');
        return _docs(snapshot);
      })
      .handleError((Object error, StackTrace stack) => Error.throwWithStackTrace(_error(error), stack));

  @override
  Future<num?> aggregate(String collection, CloudQuery query, CloudAggregate operation, String field) async {
    try {
      final q = await _query(collection, query);
      onRead?.call('aggregate');
      switch (operation) {
        case CloudAggregate.count:
          return (await q.count().get()).count;
        case CloudAggregate.sum:
          return (await q.aggregate(sum(field)).get()).getSum(field);
        case CloudAggregate.average:
          return (await q.aggregate(average(field)).get()).getAverage(field);
      }
    } catch (error, stack) {
      Error.throwWithStackTrace(_error(error), stack);
    }
  }

  @override
  String newId(String collection) => firestore.collection(collection).doc().id;

  @override
  Future<void> commit(List<DocumentWrite> writes) async {
    final batch = firestore.batch();
    for (final w in writes) {
      final ref = firestore.collection(w.collection).doc(w.id);
      switch (w) {
        case SetDocument(:final data, :final merge):
          batch.set(ref, {for (final e in data.entries) e.key: toFirestore(e.value)}, SetOptions(merge: merge));
        case DeleteDocument():
          batch.delete(ref);
      }
    }
    await batch.commit();
    onWrite?.call('commit');
  }
}
