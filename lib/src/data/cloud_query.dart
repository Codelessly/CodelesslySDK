import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';

/// The field name that stands for a document's id in a [CloudQuery].
/// Firestore reserves it, so no user field can collide with it.
const String cloudDocumentIdField = '__name__';

/// One where filter of a [CloudQuery], with its field and value already
/// resolved from variables.
class CloudWhereFilter {
  /// The dotted field path, or [cloudDocumentIdField].
  final String field;

  /// How [value] is compared.
  final WhereQueryOperator operator;

  /// The value compared against. A list for [WhereQueryOperator.inArray],
  /// [WhereQueryOperator.notInArray] and
  /// [WhereQueryOperator.arrayContainsAny].
  final Object? value;

  /// Creates a [CloudWhereFilter].
  const CloudWhereFilter(this.field, this.operator, this.value);

  /// Whether this matches documents by equality: `==`, `in`,
  /// `array-contains` and `array-contains-any`. Firestore serves any number
  /// of these from its automatic single-field indexes.
  bool get isEqualityLike => operator.isEqualityOperator;

  /// Whether this is a range or exclusion filter: `<`, `<=`, `>`, `>=`, `!=`
  /// and `not-in`.
  bool get isInequality => operator.isInequalityOperator;

  /// Whether the document [data] with id [id] passes this filter, following
  /// Firestore's rules: a missing field never matches, range filters only
  /// match values of the same type, and `!=`/`not-in` skip nulls.
  bool matches(Map<String, dynamic> data, String id) {
    final (bool exists, Object? actual) = readCloudField(data, id, field);
    if (!exists) return false;
    final Object? target = value;
    final List<Object?> targets = target is List ? target : const [];
    return switch (operator) {
      WhereQueryOperator.equal => cloudValuesEqual(actual, target),
      WhereQueryOperator.notEqual =>
        actual != null && !cloudValuesEqual(actual, target),
      WhereQueryOperator.lessThan => _inRange(actual, (c) => c < 0),
      WhereQueryOperator.lessThanOrEqual => _inRange(actual, (c) => c <= 0),
      WhereQueryOperator.greaterThan => _inRange(actual, (c) => c > 0),
      WhereQueryOperator.greaterThanOrEqual => _inRange(actual, (c) => c >= 0),
      WhereQueryOperator.arrayContains =>
        actual is List && actual.any((item) => cloudValuesEqual(item, target)),
      WhereQueryOperator.arrayContainsAny =>
        actual is List &&
            targets.any(
              (wanted) => actual.any((item) => cloudValuesEqual(item, wanted)),
            ),
      WhereQueryOperator.inArray => targets.any(
        (wanted) => cloudValuesEqual(actual, wanted),
      ),
      WhereQueryOperator.notInArray =>
        actual != null &&
            !targets.any((wanted) => cloudValuesEqual(actual, wanted)),
    };
  }

  bool _inRange(Object? actual, bool Function(int comparison) test) =>
      actual != null &&
      value != null &&
      cloudTypeOrder(actual) == cloudTypeOrder(value) &&
      test(compareCloudValues(actual, value));

  @override
  String toString() => '$field ${operator.operator} $value';
}

/// One sort of a [CloudQuery].
class CloudOrderBy {
  /// The dotted field path, or [cloudDocumentIdField].
  final String field;

  /// Whether larger values come first.
  final bool descending;

  /// Creates a [CloudOrderBy].
  const CloudOrderBy(this.field, {this.descending = false});

  @override
  String toString() => '$field ${descending ? 'desc' : 'asc'}';
}

/// A collection query with its variables resolved: what the app asked for,
/// before deciding which part Firestore runs.
///
/// Firestore answers a query from an index. It builds one for every single
/// field on its own, and merges them for any mix of equality filters, but a
/// query that also sorts or range-filters on a second field needs a
/// composite index somebody created in the Firebase console. App builders
/// can't create those, so [plan] gives such queries to Firestore with only
/// their `==` filters and finishes the rest in the app, where every operator
/// gives the same result Firestore would.
class CloudQuery {
  /// Filters every document must pass.
  final List<CloudWhereFilter> filters;

  /// The sort, first entry first.
  final List<CloudOrderBy> orderBy;

  /// The most documents to return, or null for all of them.
  final int? limit;

  /// Creates a [CloudQuery].
  const CloudQuery({
    this.filters = const [],
    this.orderBy = const [],
    this.limit,
  });

  /// Whether Firestore can run this query as is, with no composite index:
  /// only equality-like filters, or filters and sorts that all name one
  /// field. Sorting by document id ascending is free, since every index ends
  /// with it. Combinations Firestore refuses outright (two array filters,
  /// `not-in` with `!=`, `in` or another `not-in`) count as not runnable too,
  /// since the app can still answer them.
  bool get runsOnServer {
    int count(WhereQueryOperator operator) =>
        filters.where((filter) => filter.operator == operator).length;
    final int arrayFilters =
        count(WhereQueryOperator.arrayContains) +
        count(WhereQueryOperator.arrayContainsAny);
    final int notIn = count(WhereQueryOperator.notInArray);
    if (arrayFilters > 1) return false;
    if (notIn > 1) return false;
    if (notIn > 0 &&
        count(WhereQueryOperator.notEqual) +
                count(WhereQueryOperator.inArray) +
                count(WhereQueryOperator.arrayContainsAny) >
            0) {
      return false;
    }

    final List<CloudOrderBy> sorts = [
      for (final CloudOrderBy order in orderBy)
        if (order.field != cloudDocumentIdField || order.descending) order,
    ];
    final bool hasInequality = filters.any((filter) => filter.isInequality);
    if (!hasInequality && sorts.isEmpty) return true;

    final Set<String> fields = {
      for (final CloudWhereFilter filter in filters) filter.field,
      for (final CloudOrderBy order in sorts) order.field,
    };
    return fields.length <= 1;
  }

  /// The order Firestore returns documents in: the explicit [orderBy], then
  /// any inequality fields it doesn't name (sorted by name), then the
  /// document id, each extra key following the direction of the last
  /// explicit sort.
  List<CloudOrderBy> get effectiveOrderBy {
    final bool descending = orderBy.isNotEmpty && orderBy.last.descending;
    final Set<String> named = {for (final order in orderBy) order.field};
    final List<String> inequalityFields = {
      for (final CloudWhereFilter filter in filters)
        if (filter.isInequality && !named.contains(filter.field)) filter.field,
    }.toList()..sort(compareCloudStrings);
    return [
      ...orderBy,
      for (final String field in inequalityFields)
        CloudOrderBy(field, descending: descending),
      if (!named.contains(cloudDocumentIdField))
        CloudOrderBy(cloudDocumentIdField, descending: descending),
    ];
  }

  /// The composite index Firestore needs to run this query, or null when it
  /// [runsOnServer] without one: its `==` and array filter fields first (by
  /// name), then its sorts in order, then inequality fields it doesn't sort
  /// by. The publish step creates these for the app's queries; see
  /// [CloudIndex].
  CloudIndex? get requiredIndex {
    if (runsOnServer) return null;
    final List<CloudIndexField> fields = [];
    void add(CloudIndexField field) {
      if (fields.every((f) => f.field != field.field)) fields.add(field);
    }

    final List<CloudWhereFilter> equalities = [
      for (final filter in filters)
        if (filter.isEqualityLike) filter,
    ]..sort((a, b) => compareCloudStrings(a.field, b.field));
    for (final CloudWhereFilter filter in equalities) {
      add(
        CloudIndexField(
          filter.field,
          arrayContains:
              filter.operator == WhereQueryOperator.arrayContains ||
              filter.operator == WhereQueryOperator.arrayContainsAny,
        ),
      );
    }
    for (final CloudOrderBy order in orderBy) {
      if (order.field == cloudDocumentIdField) continue;
      add(CloudIndexField(order.field, descending: order.descending));
    }
    final List<String> inequalities = {
      for (final filter in filters)
        if (filter.isInequality) filter.field,
    }.toList()..sort(compareCloudStrings);
    for (final String field in inequalities) {
      add(CloudIndexField(field));
    }
    if (fields.length < 2) return null;
    return CloudIndex(fields);
  }

  /// Splits this query between Firestore and the app. Queries that
  /// [runsOnServer], or whose [requiredIndex] is among [readyIndexes] (keys
  /// of the indexes the project has), go to Firestore whole. Others, or all
  /// of them when [forceClient] is set (after Firestore reported a missing
  /// index anyway), send Firestore their `==` filters only, or their first
  /// filter alone when there is no `==` filter, and leave the rest to
  /// [CloudQueryPlan.finish].
  CloudQueryPlan plan({
    bool forceClient = false,
    Set<String> readyIndexes = const {},
  }) {
    if (!forceClient &&
        (runsOnServer || readyIndexes.contains(requiredIndex?.key))) {
      return CloudQueryPlan._(server: this);
    }

    final List<CloudWhereFilter> server = [
      for (final filter in filters)
        if (filter.operator == WhereQueryOperator.equal) filter,
    ];
    if (server.isEmpty && filters.isNotEmpty) server.add(filters.first);

    return CloudQueryPlan._(
      server: CloudQuery(filters: server),
      clientFilters: [
        for (final filter in filters)
          if (!server.contains(filter)) filter,
      ],
      clientOrderBy: effectiveOrderBy,
      clientLimit: limit,
      runsOnClient: true,
    );
  }

  /// [ref] narrowed by this query's filters, sorts and limit.
  Query<Map<String, dynamic>> applyTo(Query<Map<String, dynamic>> ref) {
    Query<Map<String, dynamic>> query = ref;
    for (final CloudWhereFilter filter in filters) {
      final Object field = _firestoreField(filter.field);
      final Object? value = filter.value;
      final List<Object?>? values = value is List ? value : null;
      query = switch (filter.operator) {
        WhereQueryOperator.equal => query.where(field, isEqualTo: value),
        WhereQueryOperator.notEqual => query.where(field, isNotEqualTo: value),
        WhereQueryOperator.lessThan => query.where(field, isLessThan: value),
        WhereQueryOperator.lessThanOrEqual => query.where(
          field,
          isLessThanOrEqualTo: value,
        ),
        WhereQueryOperator.greaterThan => query.where(
          field,
          isGreaterThan: value,
        ),
        WhereQueryOperator.greaterThanOrEqual => query.where(
          field,
          isGreaterThanOrEqualTo: value,
        ),
        WhereQueryOperator.arrayContains => query.where(
          field,
          arrayContains: value,
        ),
        WhereQueryOperator.arrayContainsAny => query.where(
          field,
          arrayContainsAny: values,
        ),
        WhereQueryOperator.inArray => query.where(field, whereIn: values),
        WhereQueryOperator.notInArray => query.where(field, whereNotIn: values),
      };
    }
    for (final CloudOrderBy order in orderBy) {
      query = query.orderBy(
        _firestoreField(order.field),
        descending: order.descending,
      );
    }
    if (limit case final int limit) query = query.limit(limit);
    return query;
  }

  static Object _firestoreField(String field) =>
      field == cloudDocumentIdField ? FieldPath.documentId : field;

  @override
  bool operator ==(Object other) =>
      other is CloudQuery && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() =>
      'CloudQuery(where: $filters, orderBy: $orderBy, limit: $limit)';
}

/// How a [CloudQuery] runs: the part Firestore runs ([server]) and the
/// filters, sort and limit the app applies to what comes back ([finish]).
class CloudQueryPlan {
  /// What Firestore runs. Needs no composite index.
  final CloudQuery server;

  /// Whether the app finishes the query.
  final bool runsOnClient;

  /// Filters the app applies.
  final List<CloudWhereFilter> clientFilters;

  /// The sort the app applies, including Firestore's implicit keys.
  final List<CloudOrderBy> clientOrderBy;

  /// The limit the app applies.
  final int? clientLimit;

  const CloudQueryPlan._({
    required this.server,
    this.runsOnClient = false,
    this.clientFilters = const [],
    this.clientOrderBy = const [],
    this.clientLimit,
  });

  /// [ref] narrowed by the [server] part.
  Query<Map<String, dynamic>> applyTo(Query<Map<String, dynamic>> ref) =>
      server.applyTo(ref);

  /// The documents Firestore returned for [server], filtered, sorted and
  /// limited as the whole query asked. [data] and [id] read a document.
  List<T> finish<T>(
    Iterable<T> docs, {
    required Map<String, dynamic> Function(T doc) data,
    required String Function(T doc) id,
  }) {
    if (!runsOnClient) return docs.toList();

    final List<({T doc, Map<String, dynamic> data, String id})> rows = [
      for (final T doc in docs) (doc: doc, data: data(doc), id: id(doc)),
    ];
    final List<String> sortFields = [
      for (final CloudOrderBy order in clientOrderBy)
        if (order.field != cloudDocumentIdField) order.field,
    ];
    // Firestore leaves out documents missing a field the query sorts by.
    rows.retainWhere(
      (row) =>
          clientFilters.every((filter) => filter.matches(row.data, row.id)) &&
          sortFields.every(
            (field) => readCloudField(row.data, row.id, field).$1,
          ),
    );

    rows.sort((a, b) {
      for (final CloudOrderBy order in clientOrderBy) {
        final int comparison = compareCloudValues(
          readCloudField(a.data, a.id, order.field).$2,
          readCloudField(b.data, b.id, order.field).$2,
        );
        if (comparison != 0) return order.descending ? -comparison : comparison;
      }
      return 0;
    });

    final Iterable<T> result = rows.map((row) => row.doc);
    final int? limit = clientLimit;
    return (limit == null ? result : result.take(limit)).toList();
  }

  @override
  String toString() => runsOnClient
      ? 'CloudQueryPlan(server: $server, client where: $clientFilters, '
            'client orderBy: $clientOrderBy, client limit: $clientLimit)'
      : 'CloudQueryPlan(server: $server)';
}

/// Whether [error] is Firestore saying a query needs an index that doesn't
/// exist.
bool isMissingIndexError(Object? error) =>
    error is FirebaseException && error.code == 'failed-precondition';

/// A readable message for a cloud [error], with Firestore's own text and
/// code, so it can be shown in variables and logs.
String describeCloudError(Object? error) => switch (error) {
  FirebaseException(:final String code, :final String? message) =>
    message == null || message.isEmpty ? code : '$message ($code)',
  null => 'Unknown error',
  _ => error.toString(),
};

/// Reads [field] (a dotted path, or [cloudDocumentIdField]) of the document
/// [data] with id [id]: whether it exists, and its value.
(bool, Object?) readCloudField(
  Map<String, dynamic> data,
  String id,
  String field,
) {
  if (field == cloudDocumentIdField) return (true, id);
  if (data.containsKey(field)) return (true, data[field]);
  Object? current = data;
  for (final String part in field.split('.')) {
    if (current is! Map || !current.containsKey(part)) return (false, null);
    current = current[part];
  }
  return (true, current);
}

/// Firestore's order of value types: null, booleans, numbers, dates,
/// strings, bytes, references, geo points, arrays, maps.
int cloudTypeOrder(Object? value) => switch (value) {
  null => 0,
  bool() => 1,
  num() => 2,
  Timestamp() || DateTime() => 3,
  String() => 5,
  Blob() || Uint8List() => 6,
  DocumentReference() => 7,
  GeoPoint() => 8,
  List() => 9,
  Map() => 10,
  _ => 11,
};

/// Whether Firestore treats [a] and [b] as equal: numbers by value (so `1`
/// equals `1.0`, and NaN equals NaN), lists and maps by their contents.
bool cloudValuesEqual(Object? a, Object? b) => compareCloudValues(a, b) == 0;

/// Compares [a] and [b] the way Firestore orders them: by [cloudTypeOrder]
/// first, then by value within a type.
int compareCloudValues(Object? a, Object? b) {
  final int typeComparison = cloudTypeOrder(a).compareTo(cloudTypeOrder(b));
  if (typeComparison != 0) return typeComparison;
  switch ((a, b)) {
    case (null, null):
      return 0;
    case (final bool a, final bool b):
      return a == b ? 0 : (a ? 1 : -1);
    case (final num a, final num b):
      if (a.isNaN || b.isNaN) return a.isNaN ? (b.isNaN ? 0 : -1) : 1;
      return a < b ? -1 : (a > b ? 1 : 0);
    case (final Object a, final Object b) when cloudTypeOrder(a) == 3:
      return _microseconds(a).compareTo(_microseconds(b));
    case (final String a, final String b):
      return compareCloudStrings(a, b);
    case (final Object a, final Object b) when cloudTypeOrder(a) == 6:
      return _compareLists(_bytes(a), _bytes(b));
    case (final DocumentReference a, final DocumentReference b):
      return _compareLists(a.path.split('/'), b.path.split('/'));
    case (final GeoPoint a, final GeoPoint b):
      final int latitude = compareCloudValues(a.latitude, b.latitude);
      return latitude != 0
          ? latitude
          : compareCloudValues(a.longitude, b.longitude);
    case (final List a, final List b):
      return _compareLists(a, b);
    case (final Map a, final Map b):
      final List<String> aKeys = a.keys.map((key) => '$key').toList()
        ..sort(compareCloudStrings);
      final List<String> bKeys = b.keys.map((key) => '$key').toList()
        ..sort(compareCloudStrings);
      for (int i = 0; i < aKeys.length && i < bKeys.length; i++) {
        final int key = compareCloudStrings(aKeys[i], bKeys[i]);
        if (key != 0) return key;
        final int value = compareCloudValues(a[aKeys[i]], b[bKeys[i]]);
        if (value != 0) return value;
      }
      return aKeys.length.compareTo(bKeys.length);
  }
  return '$a'.compareTo('$b');
}

/// Compares strings by code point, which is the UTF-8 byte order Firestore
/// uses (Dart's own [String.compareTo] goes by UTF-16 code unit).
int compareCloudStrings(String a, String b) {
  final Iterator<int> aRunes = a.runes.iterator;
  final Iterator<int> bRunes = b.runes.iterator;
  while (true) {
    final bool aNext = aRunes.moveNext();
    final bool bNext = bRunes.moveNext();
    if (!aNext || !bNext) return aNext ? 1 : (bNext ? -1 : 0);
    final int comparison = aRunes.current.compareTo(bRunes.current);
    if (comparison != 0) return comparison;
  }
}

int _compareLists(List a, List b) {
  for (int i = 0; i < a.length && i < b.length; i++) {
    final int comparison = compareCloudValues(a[i], b[i]);
    if (comparison != 0) return comparison;
  }
  return a.length.compareTo(b.length);
}

int _microseconds(Object value) => switch (value) {
  Timestamp(:final int seconds, :final int nanoseconds) =>
    seconds * 1000000 + nanoseconds ~/ 1000,
  DateTime() => value.microsecondsSinceEpoch,
  _ => 0,
};

List<int> _bytes(Object value) => switch (value) {
  Blob(:final Uint8List bytes) => bytes,
  Uint8List() => value,
  _ => const [],
};

/// A field of a [CloudIndex].
class CloudIndexField {
  /// The field.
  final String field;

  /// Whether the index sorts it descending.
  final bool descending;

  /// Whether the index answers array-contains filters on it.
  final bool arrayContains;

  /// Creates a [CloudIndexField].
  const CloudIndexField(
    this.field, {
    this.descending = false,
    this.arrayContains = false,
  });

  /// `field:asc`, `field:desc` or `field:contains`.
  String get key =>
      '$field:${arrayContains
          ? 'contains'
          : descending
          ? 'desc'
          : 'asc'}';

  /// The field as the index requests store it.
  Map<String, dynamic> toJson() => {
    'fieldPath': field,
    if (arrayContains)
      'arrayConfig': 'CONTAINS'
    else
      'order': descending ? 'DESCENDING' : 'ASCENDING',
  };

  @override
  bool operator ==(Object other) =>
      other is CloudIndexField && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A composite index on a collection's documents, which lets Firestore run
/// (and page) a query that filters and sorts on several fields.
class CloudIndex {
  /// The indexed fields, in order.
  final List<CloudIndexField> fields;

  /// Creates a [CloudIndex].
  const CloudIndex(this.fields);

  /// Identifies the index: its fields' keys joined by commas.
  String get key => fields.map((field) => field.key).join(',');

  /// The index as the index requests store it.
  Map<String, dynamic> toJson() => {
    'key': key,
    'fields': [for (final field in fields) field.toJson()],
  };

  @override
  bool operator ==(Object other) => other is CloudIndex && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'CloudIndex($key)';
}
