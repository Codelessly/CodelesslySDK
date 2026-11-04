// What a cloud write stores: values converted to their schema types, field
// operations (increment, array union...) as backend-neutral sentinels, and
// the private fields every document carries. Pure, so the same rules hold
// for every backend and are testable without one.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart'
    show CloudFieldOperation, CloudFieldWrite, CollectionSchema, SchemaField, SchemaFieldType;
import 'package:flutter/foundation.dart';

/// Fields every document gets: its id and when it was created and updated
/// (ISO 8601 UTC text).
abstract final class DocumentFields {
  static const id = 'id';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
  static const all = [id, createdAt, updatedAt];
}

/// A field operation in a write: a backend applies it to the stored value
/// (Firestore's `FieldValue`s).
@immutable
sealed class FieldOp {
  const FieldOp();

  /// Adds [by] to a number (a missing field counts as 0).
  const factory FieldOp.increment(num by) = IncrementOp;

  /// Adds [items] not in the list yet.
  const factory FieldOp.arrayUnion(List<Object?> items) = ArrayUnionOp;

  /// Removes [items] from the list.
  const factory FieldOp.arrayRemove(List<Object?> items) = ArrayRemoveOp;

  /// Removes the field (updates only).
  static const FieldOp delete = DeleteOp();

  /// The time the backend stores the write.
  static const FieldOp serverTime = ServerTimeOp();
}

final class IncrementOp extends FieldOp {
  const IncrementOp(this.by);
  final num by;
  @override
  bool operator ==(Object other) => other is IncrementOp && other.by == by;
  @override
  int get hashCode => by.hashCode;
  @override
  String toString() => 'increment($by)';
}

final class ArrayUnionOp extends FieldOp {
  const ArrayUnionOp(this.items);
  final List<Object?> items;
  @override
  bool operator ==(Object other) => other is ArrayUnionOp && listEquals(other.items, items);
  @override
  int get hashCode => Object.hashAll(items);
  @override
  String toString() => 'arrayUnion($items)';
}

final class ArrayRemoveOp extends FieldOp {
  const ArrayRemoveOp(this.items);
  final List<Object?> items;
  @override
  bool operator ==(Object other) => other is ArrayRemoveOp && listEquals(other.items, items);
  @override
  int get hashCode => Object.hashAll(items);
  @override
  String toString() => 'arrayRemove($items)';
}

final class DeleteOp extends FieldOp {
  const DeleteOp();
  @override
  String toString() => 'delete';
}

final class ServerTimeOp extends FieldOp {
  const ServerTimeOp();
  @override
  String toString() => 'serverTime';
}



/// Converts written values to what the collection's schema says they are.
abstract final class CloudFieldValues {
  /// [value] as a field of [type]: numbers from text, yes/no from
  /// `true`/`yes`/`1`/`on`, dates (text, milliseconds or `now`) as UTC
  /// [DateTime]s, a referenced document's id from the document, lists and
  /// objects from JSON text. Empty text clears a non-text field. Without a
  /// [type] the value is kept. [now] is the clock (tests).
  static Object? convert(Object? value, SchemaFieldType? type, {DateTime Function() now = DateTime.now}) {
    if (type == null) return value;
    if (value is String && value.trim().isEmpty && type != SchemaFieldType.text) return null;
    switch (type) {
      case SchemaFieldType.text || SchemaFieldType.image || SchemaFieldType.file:
        return value?.toString();
      case SchemaFieldType.reference:
        return switch (value) {
          Map() when value['id'] != null => '${value['id']}',
          null => null,
          _ => '$value',
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
          String() => const {'true', 'yes', '1', 'on'}.contains(value.trim().toLowerCase()),
          _ => value != null,
        };
      case SchemaFieldType.date:
        return switch (value) {
          DateTime() => value.toUtc(),
          int() => DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
          String() when value.trim().toLowerCase() == 'now' => now().toUtc(),
          String() => DateTime.tryParse(value.trim())?.toUtc(),
          _ => null,
        };
      case SchemaFieldType.list:
        return switch (value) {
          List() => value,
          String() => switch (_tryJson(value)) {
              final List list => list,
              _ => [
                  for (final part in value.split(','))
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
    } on FormatException {
      return null;
    }
  }

  /// What a create or update writes for [fields], each value read by
  /// [evaluate] and converted to its type in [schema]. A create also gets
  /// the schema's defaults for fields it doesn't write, and fails with a
  /// [StateError] naming a required field without a value.
  static Map<String, Object?> buildWrite({
    required List<CloudFieldWrite> fields,
    required CollectionSchema? schema,
    required Object? Function(String value) evaluate,
    required bool create,
    DateTime Function() now = DateTime.now,
  }) {
    final data = <String, Object?>{};
    for (final write in fields) {
      final field = write.field.trim();
      if (field.isEmpty) continue;
      final type = schema?.field(field)?.type;
      data[field] = switch (write.operation) {
        CloudFieldOperation.set => convert(evaluate(write.value), type, now: now),
        CloudFieldOperation.increment =>
          FieldOp.increment(convert(evaluate(write.value), SchemaFieldType.number) as num? ?? 0),
        CloudFieldOperation.arrayAdd => FieldOp.arrayUnion(_elements(evaluate(write.value))),
        CloudFieldOperation.arrayRemove => FieldOp.arrayRemove(_elements(evaluate(write.value))),
        CloudFieldOperation.delete => create ? null : FieldOp.delete,
        CloudFieldOperation.serverTime => FieldOp.serverTime,
      };
    }
    if (create) {
      data.removeWhere((key, value) => value == null);
      for (final SchemaField field in schema?.fields ?? const []) {
        if (data.containsKey(field.name)) continue;
        final fallback = field.defaultValue == null ? null : convert(field.defaultValue, field.type, now: now);
        if (fallback != null) {
          data[field.name] = fallback;
        } else if (field.required) {
          throw StateError('${field.name} is required.');
        }
      }
    }
    return data;
  }

  static List<Object?> _elements(Object? value) => value is List ? value : [value];
}

/// [data] with JSON field operation markers turned into [FieldOp]s, so
/// actions can write them from JSON: `{"$increment": 1}`,
/// `{"$arrayUnion": [...]}`, `{"$arrayRemove": [...]}`, `{"$delete": true}`,
/// and `{"$now": true}` (the current time as ISO 8601 text).
Map<String, Object?> resolveFieldOperations(Map<String, Object?> data, {DateTime Function() now = DateTime.now}) => {
      for (final e in data.entries) e.key: _resolveFieldOperation(e.value, now),
    };

Object? _resolveFieldOperation(Object? value, DateTime Function() now) {
  if (value is List) return [for (final v in value) _resolveFieldOperation(v, now)];
  if (value is! Map) return value;
  if (value.length == 1) {
    final entry = value.entries.first;
    List<Object?> items() => entry.value is List ? List<Object?>.of(entry.value as List) : [entry.value];
    switch (entry.key) {
      case r'$increment':
        final v = entry.value;
        return FieldOp.increment(v is num ? v : num.tryParse('$v') ?? 0);
      case r'$arrayUnion':
        return FieldOp.arrayUnion(items());
      case r'$arrayRemove':
        return FieldOp.arrayRemove(items());
      case r'$delete':
        return FieldOp.delete;
      case r'$now':
        return now().toUtc().toIso8601String();
    }
  }
  return {for (final e in value.entries) '${e.key}': _resolveFieldOperation(e.value, now)};
}

/// [value] (a DateTime, ISO text or milliseconds) as ISO 8601 UTC text.
String? cloudDateText(Object? value) => cloudDate(value)?.toIso8601String();

/// [value] (a DateTime, ISO text or milliseconds) as a UTC DateTime.
DateTime? cloudDate(Object? value) => switch (value) {
      final DateTime d => d.toUtc(),
      final String s => DateTime.tryParse(s)?.toUtc(),
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      _ => null,
    };

/// A stored document [data] as the app reads it: its [id], and its dates
/// as UTC DateTimes, private fields last.
Map<String, Object?> documentForUse(Map<String, Object?> data, {required String id}) {
  if (data.isEmpty) return data;
  final out = {...data};
  for (final key in const [DocumentFields.createdAt, DocumentFields.updatedAt]) {
    if (out.containsKey(key)) out[key] = cloudDate(out[key]);
  }
  out[DocumentFields.id] = id;
  for (final key in DocumentFields.all) {
    if (out.containsKey(key)) out[key] = out.remove(key);
  }
  return out;
}

/// [data] as it's written: its [id], `createdAt` (kept, or now) and
/// `updatedAt` (now), with the empty key (which databases refuse) removed.
/// An update ([keepCreatedAt]) only writes `createdAt` when given.
Map<String, Object?> documentToSend(
  Map<String, Object?> data, {
  required String? id,
  bool keepCreatedAt = false,
  DateTime Function() now = DateTime.now,
}) {
  if (data.isEmpty) return data;
  final out = {...data};
  final time = now().toUtc();
  if (!keepCreatedAt || out.containsKey(DocumentFields.createdAt)) {
    out[DocumentFields.createdAt] = cloudDateText(out[DocumentFields.createdAt] ?? time);
  }
  out[DocumentFields.updatedAt] = time.toIso8601String();
  if (id != null) out[DocumentFields.id] = id;
  for (final key in DocumentFields.all) {
    if (out.containsKey(key)) out[key] = out.remove(key);
  }
  out.remove('');
  return out;
}
