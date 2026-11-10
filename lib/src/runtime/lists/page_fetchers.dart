// Page sources of a pagination (SDK 8.x's data/page_fetchers.dart): an API
// call per page, or the list's cloud query a page at a time.
import 'package:codelessly_api/codelessly_api.dart' show Json, Pagination;

import '../../services/cloud/backend.dart' show CloudAggregate;
import '../../services/cloud/database.dart';
import '../../services/cloud/query.dart';
import '../contracts.dart';
import 'pagination.dart';

/// Matches `${page.page}`, `${page.offset}`, `${page.cursor}`,
/// `${page.pageSize}` and `${page.limit}` in an API's parameters.
final RegExp pageTokenRegex = RegExp(r'\$\{\s*page\.(\w+)\s*\}');

/// [text] with [request]'s values in place of its `${page.*}` tokens; a
/// missing cursor is empty.
String substitutePageTokens(String text, PageRequest request) {
  final values = request.toMap();
  return text.replaceAllMapped(pageTokenRegex, (m) => '${values[m.group(1)] ?? ''}');
}

/// The value at [path] (dot separated, list indexes allowed) in a decoded
/// JSON [body]; an empty path is the body.
Object? valueAtPath(Object? body, String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return body;
  return PaginationController.keyOf(body, trimmed);
}

/// Calls an API with [params] (the API's input values) and gives its
/// response value (`{isSuccess, data, statusCode...}`).
typedef ApiCaller = Future<Object?> Function(String apiId, Json params);

/// Reads a page from the API [model] names: calls it with its parameters,
/// where `${page.*}` reads the page asked for (then the rest of `${...}`
/// through [resolve]), and reads the page's items, total and next cursor
/// from the response at the model's paths. A response that isn't a success
/// fails the page.
PageFetcher apiPageFetcher(Pagination model, ApiCaller call, {Object? Function(String text)? resolve}) =>
    (request) async {
      final params = <String, Object?>{
        for (final e in model.parameters.entries)
          e.key: switch (e.value) {
            final String text => (resolve ?? (t) => t)(substitutePageTokens(text, request)),
            final other => other,
          },
      };
      final response = await call(model.apiId ?? '', params);
      Object? body = response;
      if (response case {'isSuccess': final bool ok}) {
        if (!ok) {
          final code = response['statusCode'];
          throw StateError(code == null ? 'The API call failed' : 'The API answered $code');
        }
        body = response['data'];
      }
      final items = valueAtPath(body, model.itemsPath);
      final total = model.totalPath.isEmpty ? null : valueAtPath(body, model.totalPath);
      final cursor = model.cursorPath.isEmpty ? null : valueAtPath(body, model.cursorPath);
      return PageResult(
        items is List ? items.cast<Object?>() : const [],
        totalCount: switch (total) {
          final num v => v.toInt(),
          final String v => int.tryParse(v),
          _ => null,
        },
        nextCursor: cursor == '' ? null : cursor,
      );
    };

/// Reads a page of a cloud query: [PageRequest.pageSize] documents after
/// the cursor (the id of the page before's last document). The documents
/// the query matches are counted once, for page numbers and "of 312".
PageFetcher cloudPageFetcher(CloudDatabase database, String path, CloudQuery query, {bool countTotal = true}) {
  int? total;
  var counted = false;
  return (request) async {
    final cursor = request.cursor;
    final docs = await database.query(
      path,
      query.copyWith(limit: request.pageSize, startAfter: cursor is String ? cursor : null),
    );
    if (countTotal && !counted) {
      counted = true;
      try {
        total = (await database.aggregate(path, CloudQuery(filters: query.filters), CloudAggregate.count))?.toInt();
      } catch (_) {
        // Pages still load; the total stays unknown.
      }
    }
    final last = docs.isEmpty ? null : docs.last['id'];
    return PageResult(
      docs,
      totalCount: total,
      nextCursor: docs.length == request.pageSize && last is String ? last : null,
    );
  };
}

/// Resolves the `${...}` in an API parameter (a lone one keeps its type).
Object? Function(String) resolverIn(ExpressionEngine engine, ValueScope scope) => (text) {
      final t = text.trim();
      if (RegExp(r'^\$\{[^{}]*\}$').hasMatch(t)) return engine.evaluate(t, scope);
      return engine.interpolate(text, scope);
    };
