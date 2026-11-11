// Cloud collection queries with their values resolved, and how one runs
// between the database (which needs a composite index for some queries) and
// the app (which can finish any query the way the database would). Pure Dart:
// values are JSON values plus DateTime and Uint8List.
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' show WhereOperator;

/// The field name that stands for a document's id in a [CloudQuery].
const String cloudDocumentIdField = '__name__';

/// One where filter of a [CloudQuery], its field and value resolved.
class CloudWhereFilter {
  const CloudWhereFilter(this.field, this.operator, this.value);

  /// The dotted field path, or [cloudDocumentIdField].
  final String field;
  final WhereOperator operator;

  /// The value compared against; a list for [WhereOperator.takesList].
  final Object? value;

  /// `==`, `in`, `array-contains`, `array-contains-any`: served by single
  /// field indexes in any number.
  bool get isEqualityLike => operator.isEquality;

  /// `<`, `<=`, `>`, `>=`, `!=`, `not-in`.
  bool get isInequality => operator.isInequality;

  /// Whether document [data] with id [id] passes, by Firestore's rules: a
  /// missing field never matches, range filters only match values of the
  /// same type, and `!=`/`not-in` skip nulls.
  bool matches(Map<String, Object?> data, String id) {
    final (exists, actual) = readCloudField(data, id, field);
    if (!exists) return false;
    final target = value;
    final targets = target is List ? target : const <Object?>[];
    return switch (operator) {
      WhereOperator.equal => cloudValuesEqual(actual, target),
      WhereOperator.notEqual => actual != null && !cloudValuesEqual(actual, target),
      WhereOperator.lessThan => _inRange(actual, (c) => c < 0),
      WhereOperator.lessThanOrEqual => _inRange(actual, (c) => c <= 0),
      WhereOperator.greaterThan => _inRange(actual, (c) => c > 0),
      WhereOperator.greaterThanOrEqual => _inRange(actual, (c) => c >= 0),
      WhereOperator.arrayContains => actual is List && actual.any((item) => cloudValuesEqual(item, target)),
      WhereOperator.arrayContainsAny =>
        actual is List && targets.any((wanted) => actual.any((item) => cloudValuesEqual(item, wanted))),
      WhereOperator.inArray => targets.any((wanted) => cloudValuesEqual(actual, wanted)),
      WhereOperator.notInArray => actual != null && !targets.any((wanted) => cloudValuesEqual(actual, wanted)),
    };
  }

  bool _inRange(Object? actual, bool Function(int comparison) test) =>
      actual != null &&
      value != null &&
      cloudTypeOrder(actual) == cloudTypeOrder(value) &&
      test(compareCloudValues(actual, value));

  @override
  bool operator ==(Object other) =>
      other is CloudWhereFilter &&
      other.field == field &&
      other.operator == operator &&
      cloudValuesEqual(other.value, value);

  @override
  int get hashCode => Object.hash(field, operator);

  @override
  String toString() => '$field ${operator.symbol} $value';
}

/// One sort of a [CloudQuery].
class CloudOrderBy {
  const CloudOrderBy(this.field, {this.descending = false});

  /// The dotted field path, or [cloudDocumentIdField].
  final String field;
  final bool descending;

  @override
  bool operator ==(Object other) => other is CloudOrderBy && other.field == field && other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);

  @override
  String toString() => '$field ${descending ? 'desc' : 'asc'}';
}

/// A collection query with its values resolved.
///
/// Firestore answers a query from an index: one per field on its own, merged
/// for any mix of equality filters; a query that also sorts or range-filters
/// on a second field needs a composite index. [plan] gives such queries to
/// the database with only their `==` filters and finishes the rest in the
/// app, with the result the database would give.
class CloudQuery {
  const CloudQuery({this.filters = const [], this.orderBy = const [], this.limit, this.startAfter});

  final List<CloudWhereFilter> filters;
  final List<CloudOrderBy> orderBy;

  /// The most documents to return, or null for all.
  final int? limit;

  /// The id of the last document of the previous page: results start after
  /// it (paging).
  final String? startAfter;

  CloudQuery copyWith({int? limit, String? startAfter, List<CloudWhereFilter>? filters}) => CloudQuery(
        filters: filters ?? this.filters,
        orderBy: orderBy,
        limit: limit ?? this.limit,
        startAfter: startAfter ?? this.startAfter,
      );

  /// Whether the database runs this query as is, without a composite
  /// index: only equality-like filters, or filters and sorts that all name
  /// one field (sorting by id ascending is free). Combinations Firestore
  /// refuses (two array filters, `not-in` with `!=`, `in` or another
  /// `not-in`) count as not runnable, since the app can answer them.
  bool get runsOnServer {
    int count(WhereOperator operator) => filters.where((f) => f.operator == operator).length;
    final arrayFilters = count(WhereOperator.arrayContains) + count(WhereOperator.arrayContainsAny);
    final notIn = count(WhereOperator.notInArray);
    if (arrayFilters > 1 || notIn > 1) return false;
    if (notIn > 0 &&
        count(WhereOperator.notEqual) + count(WhereOperator.inArray) + count(WhereOperator.arrayContainsAny) > 0) {
      return false;
    }
    final sorts = [
      for (final order in orderBy)
        if (order.field != cloudDocumentIdField || order.descending) order,
    ];
    final hasInequality = filters.any((f) => f.isInequality);
    if (!hasInequality && sorts.isEmpty) return true;
    final fields = {for (final f in filters) f.field, for (final o in sorts) o.field};
    return fields.length <= 1;
  }

  /// The order the database returns documents in: [orderBy], then any
  /// inequality fields it doesn't name (by name), then the document id, the
  /// extra keys following the last explicit sort's direction.
  List<CloudOrderBy> get effectiveOrderBy {
    final descending = orderBy.isNotEmpty && orderBy.last.descending;
    final named = {for (final o in orderBy) o.field};
    final inequalityFields = {
      for (final f in filters)
        if (f.isInequality && !named.contains(f.field)) f.field,
    }.toList()
      ..sort(compareCloudStrings);
    return [
      ...orderBy,
      for (final field in inequalityFields) CloudOrderBy(field, descending: descending),
      if (!named.contains(cloudDocumentIdField)) CloudOrderBy(cloudDocumentIdField, descending: descending),
    ];
  }

  /// The composite index the database needs for this query, or null when it
  /// [runsOnServer]: its equality and array fields (by name), its sorts in
  /// order, then inequality fields it doesn't sort by.
  CloudIndex? get requiredIndex {
    if (runsOnServer) return null;
    final fields = <CloudIndexField>[];
    void add(CloudIndexField field) {
      if (fields.every((f) => f.field != field.field)) fields.add(field);
    }

    final equalities = [
      for (final f in filters)
        if (f.isEqualityLike) f,
    ]..sort((a, b) => compareCloudStrings(a.field, b.field));
    for (final f in equalities) {
      add(CloudIndexField(f.field,
          arrayContains: f.operator == WhereOperator.arrayContains || f.operator == WhereOperator.arrayContainsAny));
    }
    for (final o in orderBy) {
      if (o.field == cloudDocumentIdField) continue;
      add(CloudIndexField(o.field, descending: o.descending));
    }
    final inequalities = {
      for (final f in filters)
        if (f.isInequality) f.field,
    }.toList()
      ..sort(compareCloudStrings);
    for (final field in inequalities) {
      add(CloudIndexField(field));
    }
    return fields.length < 2 ? null : CloudIndex(fields);
  }

  /// Splits this query between the database and the app. Queries that
  /// [runsOnServer], or whose [requiredIndex] is in [readyIndexes], go to
  /// the database whole. Others (or all, with [forceClient], after the
  /// database reported a missing index anyway) send it their `==` filters,
  /// or their first filter when none is `==`, and leave the rest (and the
  /// paging) to [CloudQueryPlan.finish]. When [keepOnServer] is given (the
  /// filters the database's rules need to see, such as an expiry bound),
  /// those are what the database runs instead.
  CloudQueryPlan plan({
    bool forceClient = false,
    Set<String> readyIndexes = const {},
    List<CloudWhereFilter> keepOnServer = const [],
  }) {
    if (!forceClient && (runsOnServer || readyIndexes.contains(requiredIndex?.key))) {
      return CloudQueryPlan._(server: this);
    }
    final server = keepOnServer.isNotEmpty
        ? [...keepOnServer]
        : [
            for (final f in filters)
              if (f.operator == WhereOperator.equal) f,
          ];
    if (server.isEmpty && filters.isNotEmpty) server.add(filters.first);
    return CloudQueryPlan._(
      server: CloudQuery(filters: server),
      clientFilters: [
        for (final f in filters)
          if (!server.contains(f)) f,
      ],
      clientOrderBy: effectiveOrderBy,
      clientLimit: limit,
      clientStartAfter: startAfter,
      runsOnClient: true,
    );
  }

  @override
  bool operator ==(Object other) => other is CloudQuery && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() =>
      'CloudQuery(where: $filters, orderBy: $orderBy, limit: $limit${startAfter == null ? '' : ', after: $startAfter'})';
}

/// How a [CloudQuery] runs: what the database runs ([server]) and what the
/// app applies to its results ([finish]).
class CloudQueryPlan {
  const CloudQueryPlan._({
    required this.server,
    this.runsOnClient = false,
    this.clientFilters = const [],
    this.clientOrderBy = const [],
    this.clientLimit,
    this.clientStartAfter,
  });

  /// What the database runs; needs no composite index.
  final CloudQuery server;

  /// Whether the app finishes the query.
  final bool runsOnClient;
  final List<CloudWhereFilter> clientFilters;

  /// The sort the app applies, including the database's implicit keys.
  final List<CloudOrderBy> clientOrderBy;
  final int? clientLimit;
  final String? clientStartAfter;

  /// The documents the database returned for [server], filtered, sorted,
  /// paged and limited as the whole query asked. [data] and [id] read one.
  List<T> finish<T>(Iterable<T> docs, {required Map<String, Object?> Function(T doc) data, required String Function(T doc) id}) {
    if (!runsOnClient) return docs.toList();
    final rows = [for (final doc in docs) (doc: doc, data: data(doc), id: id(doc))];
    final sortFields = [
      for (final o in clientOrderBy)
        if (o.field != cloudDocumentIdField) o.field,
    ];
    // The database leaves out documents missing a field the query sorts by.
    rows.retainWhere((row) =>
        clientFilters.every((f) => f.matches(row.data, row.id)) &&
        sortFields.every((field) => readCloudField(row.data, row.id, field).$1));
    rows.sort((a, b) {
      for (final o in clientOrderBy) {
        final c = compareCloudValues(readCloudField(a.data, a.id, o.field).$2, readCloudField(b.data, b.id, o.field).$2);
        if (c != 0) return o.descending ? -c : c;
      }
      return 0;
    });
    var result = rows.map((row) => row.doc);
    if (clientStartAfter case final String after) {
      final index = rows.indexWhere((row) => row.id == after);
      if (index >= 0) result = result.skip(index + 1);
    }
    final limit = clientLimit;
    return (limit == null ? result : result.take(limit)).toList();
  }

  @override
  String toString() => runsOnClient
      ? 'CloudQueryPlan(server: $server, client where: $clientFilters, client orderBy: $clientOrderBy, '
          'client limit: $clientLimit)'
      : 'CloudQueryPlan(server: $server)';
}

/// Reads [field] (a dotted path, or [cloudDocumentIdField]) of document
/// [data] with id [id]: whether it exists, and its value.
(bool, Object?) readCloudField(Map<String, Object?> data, String id, String field) {
  if (field == cloudDocumentIdField) return (true, id);
  if (data.containsKey(field)) return (true, data[field]);
  Object? current = data;
  for (final part in field.split('.')) {
    if (current is! Map || !current.containsKey(part)) return (false, null);
    current = current[part];
  }
  return (true, current);
}

/// The database's order of value types: null, booleans, numbers, dates,
/// strings, bytes, (references, geo points,) lists, maps.
int cloudTypeOrder(Object? value) => switch (value) {
      null => 0,
      bool() => 1,
      num() => 2,
      DateTime() => 3,
      String() => 5,
      Uint8List() => 6,
      List() => 9,
      Map() => 10,
      _ => 11,
    };

/// Whether the database treats [a] and [b] as equal: numbers by value (`1`
/// equals `1.0`, NaN equals NaN), lists and maps by content.
bool cloudValuesEqual(Object? a, Object? b) => compareCloudValues(a, b) == 0;

/// Compares [a] and [b] the way the database orders them.
int compareCloudValues(Object? a, Object? b) {
  final typeComparison = cloudTypeOrder(a).compareTo(cloudTypeOrder(b));
  if (typeComparison != 0) return typeComparison;
  switch ((a, b)) {
    case (null, null):
      return 0;
    case (final bool a, final bool b):
      return a == b ? 0 : (a ? 1 : -1);
    case (final num a, final num b):
      if (a.isNaN || b.isNaN) return a.isNaN ? (b.isNaN ? 0 : -1) : 1;
      return a < b ? -1 : (a > b ? 1 : 0);
    case (final DateTime a, final DateTime b):
      return a.microsecondsSinceEpoch.compareTo(b.microsecondsSinceEpoch);
    case (final String a, final String b):
      return compareCloudStrings(a, b);
    case (final Uint8List a, final Uint8List b):
      return _compareLists(a, b);
    case (final List a, final List b):
      return _compareLists(a, b);
    case (final Map a, final Map b):
      final aKeys = a.keys.map((k) => '$k').toList()..sort(compareCloudStrings);
      final bKeys = b.keys.map((k) => '$k').toList()..sort(compareCloudStrings);
      for (var i = 0; i < aKeys.length && i < bKeys.length; i++) {
        final key = compareCloudStrings(aKeys[i], bKeys[i]);
        if (key != 0) return key;
        final value = compareCloudValues(a[aKeys[i]], b[bKeys[i]]);
        if (value != 0) return value;
      }
      return aKeys.length.compareTo(bKeys.length);
  }
  return '$a'.compareTo('$b');
}

/// Compares strings by code point (UTF-8 byte order, as the database does;
/// Dart's [String.compareTo] goes by UTF-16 code unit).
int compareCloudStrings(String a, String b) {
  final aRunes = a.runes.iterator;
  final bRunes = b.runes.iterator;
  while (true) {
    final aNext = aRunes.moveNext();
    final bNext = bRunes.moveNext();
    if (!aNext || !bNext) return aNext ? 1 : (bNext ? -1 : 0);
    final c = aRunes.current.compareTo(bRunes.current);
    if (c != 0) return c;
  }
}

int _compareLists(List a, List b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final c = compareCloudValues(a[i], b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}

/// A field of a [CloudIndex].
class CloudIndexField {
  const CloudIndexField(this.field, {this.descending = false, this.arrayContains = false});

  final String field;
  final bool descending;

  /// Whether the index answers array-contains filters on it.
  final bool arrayContains;

  /// `field:asc`, `field:desc` or `field:contains`.
  String get key => '$field:${arrayContains ? 'contains' : descending ? 'desc' : 'asc'}';

  Map<String, Object?> toJson() => {
        'fieldPath': field,
        if (arrayContains) 'arrayConfig': 'CONTAINS' else 'order': descending ? 'DESCENDING' : 'ASCENDING',
      };

  @override
  bool operator ==(Object other) => other is CloudIndexField && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A composite index, which lets the database run (and page) a query that
/// filters and sorts on several fields.
class CloudIndex {
  const CloudIndex(this.fields);

  final List<CloudIndexField> fields;

  /// The fields' keys joined by commas.
  String get key => fields.map((f) => f.key).join(',');

  Map<String, Object?> toJson() => {
        'key': key,
        'fields': [for (final f in fields) f.toJson()],
      };

  @override
  bool operator ==(Object other) => other is CloudIndex && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'CloudIndex($key)';
}
