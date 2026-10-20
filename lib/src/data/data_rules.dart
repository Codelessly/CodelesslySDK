import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';

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

  /// Creates [DataRules].
  const DataRules([this.collections = const {}]);

  /// Reads `{collections: {name: rule}}`, ignoring unknown rules.
  factory DataRules.fromJson(Map? json) {
    final Map? collections = json?['collections'] as Map?;
    return DataRules({
      for (final MapEntry entry in (collections ?? {}).entries)
        if (DataRule.values.asNameMap()[entry.value] case final DataRule rule)
          entry.key.toString(): rule,
    });
  }

  /// The JSON stored in the rules document.
  Map<String, dynamic> toJson() => {
    'collections': {
      for (final MapEntry<String, DataRule> entry in collections.entries)
        entry.key: entry.value.name,
    },
  };

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

  /// [query] on [path] limited to what [uid] may read: only their own
  /// documents in owner-only collections. Null when the user can't read any
  /// of it because they aren't signed in.
  Query<Map<String, dynamic>>? filterQuery(
    Query<Map<String, dynamic>> query,
    String path,
    String? uid,
  ) {
    final DataRule rule = ruleFor(path);
    if (!rule.readsOwnOnly && rule != DataRule.signedIn) return query;
    if (uid == null || uid.isEmpty) return null;
    if (!rule.readsOwnOnly) return query;
    return query.where(ownerField, isEqualTo: uid);
  }
}
