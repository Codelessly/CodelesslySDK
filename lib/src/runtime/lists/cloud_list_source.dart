// A cloud-bound list's collection, as the list widgets see it: its pages,
// and the writes a list makes (a reordered item's order, a swiped-away
// item). The widgets ask this; what the app's cloud database is stays with
// the services.
import 'package:codelessly_api/codelessly_api.dart' show CloudQueryDef, Json;

import '../../services/cloud/database.dart';
import '../../services/cloud/resolve.dart';
import '../../services/services.dart' show Services;
import '../contracts.dart';
import 'page_fetchers.dart';
import 'pagination.dart';

/// The collection path of [def], its `${...}` read in [scope].
String cloudCollectionPath(CloudQueryDef def, ExpressionEngine expressions, ValueScope scope) =>
    resolveCollectionPath(def, expressions, scope);

/// The app's cloud database, for a list bound to one of its collections.
final class CloudListSource {
  CloudListSource._(this._database);

  /// The cloud database of [services]; null when they have none.
  static CloudListSource? of(CodelesslyServices? services) => switch (services) {
        final Services s => CloudListSource._(s.cloud),
        _ => null,
      };

  final CloudDatabase _database;

  /// The pages of [def] (resolved in [scope]) at [path]: what tells this
  /// query from another of the same list ([key]), and what reads its pages.
  ({Object key, PageFetcher Function() fetcher}) pages(
    String path,
    CloudQueryDef def,
    ExpressionEngine expressions,
    ValueScope scope,
  ) {
    final query = resolveCloudQuery(def, expressions, scope);
    return (
      key: ('cloud', path, query.filters.toString(), query.orderBy.toString()),
      fetcher: () => cloudPageFetcher(_database, path, query),
    );
  }

  /// Sets [fields] of document [id] at [path].
  Future<void> updateDocument(String path, String id, Json fields) => _database.updateDocument(path, id, fields);

  /// Removes document [id] at [path]; whether there was one.
  Future<bool> removeDocument(String path, String id) => _database.removeDocument(path, id);
}
