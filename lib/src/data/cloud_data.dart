import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';

import '../transformers/utils/property_value_delegate.dart';
import '../transformers/utils/scoped_values.dart';
import '../utils/utils.dart';
import 'cloud_database.dart';
import 'cloud_query.dart';
import 'data_rules.dart';

/// Turns field values written in the editor into what Firestore stores,
/// following a collection's [CollectionSchema]. Pure, so the same rules hold
/// for every write and are testable without Firestore.
abstract final class CloudFieldValues {
  /// [value] converted to a field of [type]: numbers from text, yes/no from
  /// `true`/`yes`/`1`, dates (text, milliseconds or `now`) as timestamps, a
  /// referenced document's id from the document, lists and objects from
  /// JSON text. Empty text clears a non-text field. Without a [type] the
  /// value is kept as is.
  static Object? convert(Object? value, SchemaFieldType? type) {
    if (type == null) return value;
    if (value is String &&
        value.trim().isEmpty &&
        type != SchemaFieldType.text) {
      return null;
    }
    switch (type) {
      case SchemaFieldType.text:
      case SchemaFieldType.image:
      case SchemaFieldType.file:
        return value?.toString();
      case SchemaFieldType.reference:
        return switch (value) {
          Map() when value['id'] != null => value['id'].toString(),
          null => null,
          _ => value.toString(),
        };
      case SchemaFieldType.number:
        return switch (value) {
          num() => value,
          String() => num.tryParse(value.trim()),
          bool() => value ? 1 : 0,
          _ => null,
        };
      case SchemaFieldType.boolean:
        return switch (value) {
          bool() => value,
          num() => value != 0,
          String() => const {
            'true',
            'yes',
            '1',
            'on',
          }.contains(value.trim().toLowerCase()),
          _ => value != null,
        };
      case SchemaFieldType.date:
        return switch (value) {
          Timestamp() => value,
          DateTime() => Timestamp.fromDate(value),
          int() => Timestamp.fromMillisecondsSinceEpoch(value),
          String() when value.trim().toLowerCase() == 'now' => Timestamp.now(),
          String() => switch (DateTime.tryParse(value.trim())) {
            final DateTime date => Timestamp.fromDate(date),
            null => null,
          },
          _ => null,
        };
      case SchemaFieldType.list:
        return switch (value) {
          List() => value,
          String() => switch (_tryJson(value)) {
            final List list => list,
            _ => [
              for (final String part in value.split(','))
                if (part.trim().isNotEmpty) part.trim(),
            ],
          },
          null => null,
          _ => [value],
        };
      case SchemaFieldType.object:
        return switch (value) {
          Map() => value,
          String() => switch (_tryJson(value)) {
            final Map map => map,
            _ => null,
          },
          _ => null,
        };
    }
  }

  static Object? _tryJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  /// The data a create or update writes for [fields], each value read by
  /// [evaluate] and converted to its type in [schema]. A create also gets
  /// the defaults of the schema's fields it doesn't write, and fails with a
  /// [StateError] naming a required field that has no value.
  static Map<String, dynamic> buildWrite({
    required List<CloudFieldWrite> fields,
    required CollectionSchema? schema,
    required Object? Function(String value) evaluate,
    required bool create,
  }) {
    final Map<String, dynamic> data = {};
    for (final CloudFieldWrite write in fields) {
      final String field = write.field.trim();
      if (field.isEmpty) continue;
      final SchemaFieldType? type = schema?.field(field)?.type;
      data[field] = switch (write.operation) {
        CloudFieldOperation.set => convert(evaluate(write.value), type),
        CloudFieldOperation.increment => FieldValue.increment(
          convert(evaluate(write.value), SchemaFieldType.number) as num? ?? 0,
        ),
        CloudFieldOperation.arrayAdd => FieldValue.arrayUnion(
          _elements(evaluate(write.value)),
        ),
        CloudFieldOperation.arrayRemove => FieldValue.arrayRemove(
          _elements(evaluate(write.value)),
        ),
        CloudFieldOperation.delete => create ? null : FieldValue.delete(),
        CloudFieldOperation.serverTime => FieldValue.serverTimestamp(),
      };
    }
    if (create) {
      data.removeWhere((key, value) => value == null);
      for (final SchemaField field in schema?.fields ?? const <SchemaField>[]) {
        if (data.containsKey(field.name)) continue;
        final Object? fallback = field.defaultValue == null
            ? null
            : convert(field.defaultValue, field.type);
        if (fallback != null) {
          data[field.name] = fallback;
        } else if (field.required) {
          throw StateError('${field.name} is required.');
        }
      }
    }
    return data;
  }

  /// A list operation's elements: a list adds each of its items.
  static List<Object?> _elements(Object? value) =>
      value is List ? value : [value];
}

/// Reads and writes documents for [CloudDataAction]s and [CloudBatchAction]s
/// on a [FirestoreCloudDatabase], applying its [DataRules]: owner stamps on
/// writes, owner filters on reads and the collection schemas.
class CloudDataRunner {
  /// The database of the app.
  final FirestoreCloudDatabase database;

  /// The data `${...}` paths and formulas read.
  final ScopedValues scopedValues;

  CloudDataRunner({required this.database, required this.scopedValues});

  /// Reads a value written in the editor: a value that is exactly one
  /// `${path}` or formula keeps its type; other text has its data
  /// substituted.
  Object? evaluate(String value) =>
      PropertyValueDelegate.substituteJsonValue(value, scopedValues);

  /// Reads text written in the editor, with data substituted.
  String substitute(String text) => PropertyValueDelegate.substituteVariables(
    text,
    scopedValues: scopedValues,
    nullSubstitutionMode: NullSubstitutionMode.emptyString,
  );

  DataRules get _rules => database.rules;

  /// Runs [action]; returns its result: the created id, the document, the
  /// documents or the number. Throws on failure.
  Future<Object?> run(CloudDataAction action) async {
    final String path = substitute(action.collection);
    final String documentId = substitute(action.documentId).trim();
    final CollectionReference<Map<String, dynamic>> collection = database
        .getCollectionPath(path);
    final String? uid = database.currentUserId();
    switch (action.operation) {
      case CloudDataOperation.create:
        final DocumentReference<Map<String, dynamic>> ref = documentId.isEmpty
            ? collection.doc()
            : collection.doc(documentId);
        await ref.set(_prepareWrite(path, action, create: true, uid: uid));
        return ref.id;
      case CloudDataOperation.update:
        await collection
            .doc(_requireId(documentId))
            .update(_prepareWrite(path, action, create: false, uid: uid));
        return documentId;
      case CloudDataOperation.delete:
        final DocumentReference<Map<String, dynamic>> ref = collection.doc(
          _requireId(documentId),
        );
        for (final String sub in action.deleteSubcollections) {
          await _deleteCollection(ref.collection(sub.trim()));
        }
        await ref.delete();
        return documentId;
      case CloudDataOperation.get:
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await collection
            .doc(_requireId(documentId))
            .get();
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) return null;
        final Map<String, dynamic> doc = sanitizeCloudDataForUse(
          data,
          docId: snapshot.id,
        );
        return (await _loadRelated(path, [doc], action.loadRelated)).first;
      case CloudDataOperation.query:
        final List<Map<String, dynamic>> docs = await _query(
          path,
          collection,
          action,
          uid,
        );
        return _loadRelated(path, docs, action.loadRelated);
      case CloudDataOperation.count:
      case CloudDataOperation.sum:
      case CloudDataOperation.average:
        return _aggregate(path, collection, action, uid);
    }
  }

  /// Runs the writes of [batch] together.
  Future<void> runBatch(CloudBatchAction batch) async {
    final String? uid = database.currentUserId();
    final List<
      ({
        DocumentReference<Map<String, dynamic>> ref,
        CloudDataAction step,
        Map<String, dynamic>? data,
      })
    >
    writes = [
      for (final CloudDataAction step in batch.steps)
        if (step.operation.writes) _batchWrite(step, uid),
    ];
    if (batch.transaction) {
      await database.firestore.runTransaction((transaction) async {
        for (final write in writes) {
          switch (write.step.operation) {
            case CloudDataOperation.create:
              transaction.set(write.ref, write.data!);
            case CloudDataOperation.update:
              transaction.update(write.ref, write.data!);
            default:
              transaction.delete(write.ref);
          }
        }
      });
      return;
    }
    final WriteBatch writeBatch = database.firestore.batch();
    for (final write in writes) {
      switch (write.step.operation) {
        case CloudDataOperation.create:
          writeBatch.set(write.ref, write.data!);
        case CloudDataOperation.update:
          writeBatch.update(write.ref, write.data!);
        default:
          writeBatch.delete(write.ref);
      }
    }
    await writeBatch.commit();
  }

  ({
    DocumentReference<Map<String, dynamic>> ref,
    CloudDataAction step,
    Map<String, dynamic>? data,
  })
  _batchWrite(CloudDataAction step, String? uid) {
    final String path = substitute(step.collection);
    final String id = substitute(step.documentId).trim();
    final CollectionReference<Map<String, dynamic>> collection = database
        .getCollectionPath(path);
    final bool create = step.operation == CloudDataOperation.create;
    return (
      ref: create && id.isEmpty
          ? collection.doc()
          : collection.doc(_requireId(id)),
      step: step,
      data: step.operation == CloudDataOperation.delete
          ? null
          : _prepareWrite(path, step, create: create, uid: uid),
    );
  }

  Map<String, dynamic> _prepareWrite(
    String path,
    CloudDataAction action, {
    required bool create,
    required String? uid,
  }) {
    final Map<String, dynamic> data = CloudFieldValues.buildWrite(
      fields: action.fields,
      schema: _rules.schemaFor(path),
      evaluate: evaluate,
      create: create,
    );
    return _rules.prepareWrite(path, data, uid);
  }

  static String _requireId(String id) {
    if (id.isEmpty) {
      throw StateError('Which document? The document id is empty.');
    }
    return id;
  }

  CloudQuery _cloudQuery(String path, CloudDataAction action, String? uid) {
    final List<CloudWhereFilter>? readFilters = _rules.readFilters(path, uid);
    if (readFilters == null) throw StateError('Sign in to see this.');
    return resolveCloudQuery(
      baseFilters: readFilters,
      whereFilters: action.whereFilters,
      orderByOperations: action.orderByFilters,
      limit: action.operation == CloudDataOperation.query ? action.limit : null,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
  }

  Future<List<Map<String, dynamic>>> _query(
    String path,
    CollectionReference<Map<String, dynamic>> collection,
    CloudDataAction action,
    String? uid,
  ) async {
    final CloudQueryPlan plan = _cloudQuery(
      path,
      action,
      uid,
    ).plan(readyIndexes: _rules.readyIndexesFor(path));
    final QuerySnapshot<Map<String, dynamic>> snapshot = await plan
        .applyTo(collection)
        .get();
    return [
      for (final doc in plan.finish(
        snapshot.docs,
        data: (doc) => doc.data(),
        id: (doc) => doc.id,
      ))
        sanitizeCloudDataForUse(doc.data(), docId: doc.id),
    ];
  }

  Future<num?> _aggregate(
    String path,
    CollectionReference<Map<String, dynamic>> collection,
    CloudDataAction action,
    String? uid,
  ) async {
    final CloudQueryPlan plan = _cloudQuery(
      path,
      action,
      uid,
    ).plan(readyIndexes: _rules.readyIndexesFor(path));
    final String field = action.aggregateField.trim();
    if (action.operation != CloudDataOperation.count && field.isEmpty) {
      throw StateError('Pick the number field to ${action.operation.name}.');
    }
    if (!plan.runsOnClient) {
      final Query<Map<String, dynamic>> query = plan.applyTo(collection);
      final AggregateQuerySnapshot result = await switch (action.operation) {
        CloudDataOperation.sum => query.aggregate(sum(field)).get(),
        CloudDataOperation.average => query.aggregate(average(field)).get(),
        _ => query.count().get(),
      };
      return switch (action.operation) {
        CloudDataOperation.sum => result.getSum(field),
        CloudDataOperation.average => result.getAverage(field),
        _ => result.count,
      };
    }
    // Needs an index Firestore doesn't have: aggregate in the app.
    final List<Map<String, dynamic>> docs = await _query(
      path,
      collection,
      action,
      uid,
    );
    return aggregateDocuments(docs, action.operation, field);
  }

  /// [operation] over [docs]: their count, or the sum or average of the
  /// numbers in [field] (documents without a number there are skipped).
  static num? aggregateDocuments(
    List<Map<String, dynamic>> docs,
    CloudDataOperation operation,
    String field,
  ) {
    if (operation == CloudDataOperation.count) return docs.length;
    final List<num> numbers = [
      for (final Map<String, dynamic> doc in docs)
        if (doc[field] case final num value) value,
    ];
    final num total = numbers.fold<num>(0, (a, b) => a + b);
    if (operation == CloudDataOperation.sum) return total;
    return numbers.isEmpty ? null : total / numbers.length;
  }

  /// [docs] with each of their [fields] that is a reference replaced by the
  /// referenced document's data, read from the collection the schema of
  /// [path] names for it.
  Future<List<Map<String, dynamic>>> _loadRelated(
    String path,
    List<Map<String, dynamic>> docs,
    List<String> fields,
  ) async {
    if (fields.isEmpty || docs.isEmpty) return docs;
    final CollectionSchema? schema = _rules.schemaFor(path);
    for (final String name in fields) {
      final SchemaField? field = schema?.field(name);
      final String? target = field?.referenceCollection;
      if (target == null || target.isEmpty) continue;
      final CollectionReference<Map<String, dynamic>> ref = database
          .getCollectionPath(target);
      final Set<String> ids = {
        for (final Map<String, dynamic> doc in docs)
          if (doc[name] case final String id when id.isNotEmpty) id,
      };
      final Map<String, Map<String, dynamic>> related = {};
      await Future.wait([
        for (final String id in ids)
          ref.doc(id).get().then((snapshot) {
            final Map<String, dynamic>? data = snapshot.data();
            if (data != null) {
              related[id] = sanitizeCloudDataForUse(data, docId: id);
            }
          }),
      ]);
      for (final Map<String, dynamic> doc in docs) {
        if (doc[name] case final String id when related.containsKey(id)) {
          doc[name] = related[id];
        }
      }
    }
    return docs;
  }

  /// Deletes every document of [collection], a few hundred at a time.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> page = await collection
          .limit(300)
          .get();
      if (page.docs.isEmpty) return;
      final WriteBatch batch = database.firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
