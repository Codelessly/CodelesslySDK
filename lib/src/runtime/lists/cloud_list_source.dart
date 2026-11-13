// A cloud-bound list's collection, as the list widgets see it: its pages,
// and the writes a list makes (a reordered item's order, a swiped-away
// item). The widgets ask this interface; the data feature implements it
// over the app's cloud database (features/data/cloud_list_source.dart) and
// the services give it by type.
import 'package:codelessly_api/core.dart' show Json, readString;

import '../contracts.dart';
import 'pagination.dart';

/// The collection path of [query] (a list's `query`, the data library's
/// cloud query JSON), its `${...}` read in [scope].
String cloudCollectionPath(Json query, ExpressionEngine expressions, ValueScope scope) =>
    expressions.interpolate(readString(query['collectionPath']) ?? '', scope).trim();

/// The app's cloud database, for a list bound to one of its collections.
abstract interface class CloudListSource {
  /// The cloud list source of [services]; null when they have none.
  static CloudListSource? of(CodelesslyServices? services) => services?.lookup<CloudListSource>();

  /// The pages of [query] (a list's `query` JSON, resolved in [scope]) at
  /// [path]: what tells this query from another of the same list ([key]),
  /// and what reads its pages.
  ({Object key, PageFetcher Function() fetcher}) pages(
    String path,
    Json query,
    ExpressionEngine expressions,
    ValueScope scope,
  );

  /// Sets [fields] of document [id] at [path].
  Future<void> updateDocument(String path, String id, Json fields);

  /// Removes document [id] at [path]; whether there was one.
  Future<bool> removeDocument(String path, String id);
}
