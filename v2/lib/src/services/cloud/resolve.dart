// A stored query (CloudQueryDef) resolved against the runtime's values.
import 'dart:convert';

import 'package:codelessly_api_v2/codelessly_api.dart' show CloudQueryDef, WhereFilter;

import '../../runtime/contracts.dart';
import 'query.dart';

final _single = RegExp(r'^\$\{[^{}]*\}$');

/// [text] as a value: a lone `${...}` keeps its value's type; other text is
/// interpolated, then read as a literal ([parseLiteral]).
Object? resolveValue(String text, ExpressionEngine expressions, ValueScope scope) {
  final trimmed = text.trim();
  if (_single.hasMatch(trimmed)) return expressions.evaluate(trimmed, scope);
  return parseLiteral(expressions.interpolate(text, scope));
}

/// [text] read as a literal: `true`, `false`, `null`, numbers, and JSON
/// lists and objects; anything else stays text.
Object? parseLiteral(String text) {
  final t = text.trim();
  switch (t) {
    case 'true':
      return true;
    case 'false':
      return false;
    case 'null':
      return null;
  }
  if (num.tryParse(t) case final num n) return n;
  if ((t.startsWith('[') && t.endsWith(']')) || (t.startsWith('{') && t.endsWith('}'))) {
    try {
      return jsonDecode(t);
    } on FormatException {
      return text;
    }
  }
  return text;
}

/// The collection path of [def], its `${...}` interpolated.
String resolveCollectionPath(CloudQueryDef def, ExpressionEngine expressions, ValueScope scope) =>
    expressions.interpolate(def.collectionPath, scope).trim();

/// [def] as a [CloudQuery]: each filter's value resolved ([resolveValue];
/// a list for `in`, `not-in` and `array-contains-any`), `${documentId}`
/// fields as the document id, [limit] (paging) over the stored limit.
CloudQuery resolveCloudQuery(
  CloudQueryDef def,
  ExpressionEngine expressions,
  ValueScope scope, {
  int? limit,
  String? startAfter,
}) {
  String field(String f) => f.trim() == r'${documentId}' ? cloudDocumentIdField : expressions.interpolate(f, scope);

  CloudWhereFilter filter(WhereFilter w) {
    final value = resolveValue(w.value, expressions, scope) ?? '';
    return CloudWhereFilter(
      field(w.field),
      w.operator,
      w.operator.takesList ? (value is List ? value : [value]) : value,
    );
  }

  return CloudQuery(
    filters: [for (final w in def.where) filter(w)],
    orderBy: [for (final o in def.orderBy) CloudOrderBy(field(o.field), descending: o.descending)],
    limit: limit ?? def.limit,
    startAfter: startAfter,
  );
}
