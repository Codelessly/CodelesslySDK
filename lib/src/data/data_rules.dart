import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';

import 'cloud_query.dart';

/// Who can read and write a cloud database collection. Set per collection in
/// the editor's Data panel, stored in `data_rules/{projectId}`, and enforced
/// by Firestore security rules; the SDK stamps and filters by
/// [DataRules.ownerField] so its writes and queries pass them.
enum DataRule {
  /// Anyone using the app. The default.
  app,

  /// Only signed-in users can read and write.
  signedIn,

  /// Each signed-in user reads and writes only their own documents.
  owner,

  /// Anyone using the app reads; signed-in users write only their own
  /// documents.
  publicReadOwnerWrite;

  /// Whether writes record the signed-in user as the document's owner.
  bool get stampsOwner => this == owner || this == publicReadOwnerWrite;

  /// Whether reads only return the signed-in user's own documents.
  bool get readsOwnOnly => this == owner;

  /// Whether writing needs a signed-in user.
  bool get writeNeedsSignIn => this != app;
}

/// The [DataRule] of each collection of a project.
class DataRules {
  /// The Firestore collection holding each project's rules document.
  static const String rulesCollection = 'data_rules';

  /// The field holding the uid of the user who owns a document.
  static const String ownerField = 'ownerId';

  /// Collection name -> rule. Collections not listed use [DataRule.app].
  final Map<String, DataRule> collections;

  /// Collection name -> its typed fields, defined in the editor's Data panel.
  final Map<String, CollectionSchema> schemas;

  /// Collection name -> the keys ([CloudIndex.key]) of the composite indexes
  /// it has, which publishing creates for the app's queries. Queries with a
  /// ready index run (and page) in Firestore instead of in the app.
  final Map<String, Set<String>> indexes;

  /// Creates [DataRules].
  const DataRules([
    this.collections = const {},
    this.schemas = const {},
    this.indexes = const {},
  ]);

  /// Reads `{collections: {name: rule}, schemas: {name: schema}}`, ignoring
  /// unknown rules and unreadable schemas.
  factory DataRules.fromJson(Map? json) {
    final Map? collections = json?['collections'] as Map?;
    final Map? schemas = json?['schemas'] as Map?;
    final Map? indexes = json?['indexes'] as Map?;
    return DataRules(
      {
        for (final MapEntry entry in (collections ?? {}).entries)
          if (DataRule.values.asNameMap()[entry.value] case final DataRule rule)
            entry.key.toString(): rule,
      },
      {
        for (final MapEntry entry in (schemas ?? {}).entries)
          if (entry.value is Map)
            entry.key.toString(): CollectionSchema.fromJson({
              'name': entry.key.toString(),
              ...entry.value as Map,
            }),
      },
      {
        for (final MapEntry entry in (indexes ?? {}).entries)
          if (entry.value is List)
            entry.key.toString(): {
              for (final Object? key in entry.value as List) '$key',
            },
      },
    );
  }

  /// The JSON stored in the rules document.
  Map<String, dynamic> toJson() => {
    'collections': {
      for (final MapEntry<String, DataRule> entry in collections.entries)
        entry.key: entry.value.name,
    },
    if (indexes.isNotEmpty)
      'indexes': {
        for (final MapEntry<String, Set<String>> entry in indexes.entries)
          entry.key: entry.value.toList(),
      },
    if (schemas.isNotEmpty)
      'schemas': {
        for (final MapEntry<String, CollectionSchema> entry in schemas.entries)
          entry.key: entry.value.toJson(),
      },
  };

  /// The name of the collection [path] names: its last collection (`tasks`
  /// for `users/u1/tasks`).
  static String? collectionName(String path) {
    // `${...}` data (as in the editor) stands for one segment.
    final String plain = path.trim().replaceAll(RegExp(r'\$\{[^}]*\}'), '_');
    final List<String> parts = [
      for (final String part in plain.split(pathSeparatorRegex))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    return parts.isEmpty
        ? null
        : parts[(parts.length - 1) - (parts.length - 1) % 2];
  }

  /// The schema of the collection [path] names, if it has one: the schema of
  /// its last collection (`tasks` for `users/u1/tasks`), else of its top one.
  CollectionSchema? schemaFor(String path) =>
      schemas[collectionName(path)] ?? schemas[topCollection(path)];

  /// The keys of the composite indexes ready for the collection [path]
  /// names.
  Set<String> readyIndexesFor(String path) =>
      indexes[collectionName(path)] ?? const {};

  /// The top-level collection of [path], which is what rules are set on.
  static String topCollection(String path) {
    final String first = path.trim().split(pathSeparatorRegex).first.trim();
    return first.isEmpty ? 'default' : first;
  }

  /// The rule for documents under [path].
  DataRule ruleFor(String path) =>
      collections[topCollection(path)] ?? DataRule.app;

  /// [value] ready to write under [path] by user [uid]: owned collections
  /// record [uid] as the owner. Throws a [StateError] with a readable
  /// message when the collection needs a signed-in user and there is none.
  Map<String, dynamic> prepareWrite(
    String path,
    Map<String, dynamic> value,
    String? uid,
  ) {
    final DataRule rule = ruleFor(path);
    if (rule.writeNeedsSignIn && (uid == null || uid.isEmpty)) {
      throw StateError('Sign in to save this.');
    }
    if (!rule.stampsOwner) return value;
    return {...value, ownerField: uid};
  }

  /// The filters that limit reads of [path] to what [uid] may read: none for
  /// shared collections, the owner filter for owner-only ones. Null when the
  /// user can't read any of it because they aren't signed in.
  List<CloudWhereFilter>? readFilters(String path, String? uid) {
    final DataRule rule = ruleFor(path);
    if (!rule.readsOwnOnly && rule != DataRule.signedIn) return const [];
    if (uid == null || uid.isEmpty) return null;
    if (!rule.readsOwnOnly) return const [];
    return [CloudWhereFilter(ownerField, WhereQueryOperator.equal, uid)];
  }

  /// [query] on [path] limited to what [uid] may read: only their own
  /// documents in owner-only collections. Null when the user can't read any
  /// of it because they aren't signed in.
  Query<Map<String, dynamic>>? filterQuery(
    Query<Map<String, dynamic>> query,
    String path,
    String? uid,
  ) {
    final List<CloudWhereFilter>? filters = readFilters(path, uid);
    if (filters == null) return null;
    return CloudQuery(filters: filters).applyTo(query);
  }
}
