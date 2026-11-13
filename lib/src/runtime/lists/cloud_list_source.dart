// A cloud-bound list's collection, as the list widgets see it: its pages,
// and the writes a list makes (a reordered item's order, a swiped-away
// item). The widgets ask this interface; the data feature implements it
// over the app's cloud database (features/data/cloud_list_source.dart) and
// the services give it by type.
import 'package:codelessly_api/codelessly_api.dart' show CloudQueryDef, Json;

import '../contracts.dart';
import 'pagination.dart';

/// The collection path of [def], its `${...}` read in [scope].
String cloudCollectionPath(CloudQueryDef def, ExpressionEngine expressions, ValueScope scope) =>
    expressions.interpolate(def.collectionPath, scope).trim();

/// The app's cloud database, for a list bound to one of its collections.
abstract interface class CloudListSource {
  /// The cloud list source of [services]; null when they have none.
  static CloudListSource? of(CodelesslyServices? services) => services?.lookup<CloudListSource>();

  /// The pages of [def] (resolved in [scope]) at [path]: what tells this
  /// query from another of the same list ([key]), and what reads its pages.
  ({Object key, PageFetcher Function() fetcher}) pages(
    String path,
    CloudQueryDef def,
    ExpressionEngine expressions,
    ValueScope scope,
  );

  /// Sets [fields] of document [id] at [path].
  Future<void> updateDocument(String path, String id, Json fields);

  /// Removes document [id] at [path]; whether there was one.
  Future<bool> removeDocument(String path, String id);
}
