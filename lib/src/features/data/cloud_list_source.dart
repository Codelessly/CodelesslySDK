// Cloud-bound lists over the app's cloud database: the data feature's
// implementation of the runtime's CloudListSource, and the page fetcher
// that reads a query's pages.
import 'package:codelessly_api/codelessly_api.dart' show CloudQueryDef, Json;

import '../../runtime/contracts.dart';
import '../../runtime/lists/cloud_list_source.dart';
import '../../runtime/lists/pagination.dart';
import '../../services/cloud/backend.dart' show CloudAggregate;
import '../../services/cloud/database.dart';
import '../../services/cloud/query.dart';
import '../../services/cloud/resolve.dart';

/// [CloudListSource] over a [CloudDatabase].
final class DatabaseListSource implements CloudListSource {
  DatabaseListSource(this._database);

  final CloudDatabase _database;

  @override
  ({Object key, PageFetcher Function() fetcher}) pages(
    String path,
    Json json,
    ExpressionEngine expressions,
    ValueScope scope,
  ) {
    final query = resolveCloudQuery(CloudQueryDef.fromJson(json), expressions, scope);
    return (
      key: ('cloud', path, query.filters.toString(), query.orderBy.toString()),
      fetcher: () => cloudPageFetcher(_database, path, query),
    );
  }

  @override
  Future<void> updateDocument(String path, String id, Json fields) => _database.updateDocument(path, id, fields);

  @override
  Future<bool> removeDocument(String path, String id) => _database.removeDocument(path, id);
}

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
