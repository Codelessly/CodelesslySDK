import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import '../data/cloud_database.dart';

/// Referenced documents by field, then by id.
typedef RelatedDocumentMap = Map<String, Map<String, Map<String, dynamic>>>;

/// [doc] with each of its reference fields that [related] has loaded
/// replaced by the referenced document (with its `id`). A reference not
/// loaded yet stays its id.
Map<String, dynamic> withRelated(
  Map<String, dynamic> doc,
  RelatedDocumentMap related,
) {
  if (related.isEmpty) return doc;
  return {
    for (final MapEntry<String, dynamic> entry in doc.entries)
      entry.key: switch (entry.value) {
        final String id when related[entry.key]?[id] != null =>
          related[entry.key]![id],
        final value => value,
      },
  };
}

/// Loads the documents the [fields] (reference fields of the list's
/// collection, [collectionPath]) of [docs] point to, once each, and builds
/// [builder] with what has loaded so far; it rebuilds as more arrive.
class RelatedDocumentsLoader extends StatefulWidget {
  /// The reference fields to load.
  final List<String> fields;

  /// The list's collection, whose schema names each field's collection.
  final String collectionPath;

  /// The database to read from.
  final FirestoreCloudDatabase? database;

  /// The results whose references load.
  final List<Map<String, dynamic>> docs;

  /// Builds the list with the related documents loaded so far.
  final Widget Function(BuildContext context, RelatedDocumentMap related)
  builder;

  const RelatedDocumentsLoader({
    super.key,
    required this.fields,
    required this.collectionPath,
    required this.database,
    required this.docs,
    required this.builder,
  });

  @override
  State<RelatedDocumentsLoader> createState() => _RelatedDocumentsLoaderState();
}

class _RelatedDocumentsLoaderState extends State<RelatedDocumentsLoader> {
  final RelatedDocumentMap related = {};
  final Set<String> requested = {};

  @override
  void initState() {
    super.initState();
    // The schema naming each field's collection may arrive after the list.
    widget.database?.addListener(_onRules);
  }

  @override
  void didUpdateWidget(RelatedDocumentsLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      oldWidget.database?.removeListener(_onRules);
      widget.database?.addListener(_onRules);
    }
  }

  @override
  void dispose() {
    widget.database?.removeListener(_onRules);
    super.dispose();
  }

  void _onRules() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _load();
    return widget.builder(context, related);
  }

  void _load() {
    final FirestoreCloudDatabase? database = widget.database;
    if (database == null || widget.fields.isEmpty) return;
    final CollectionSchema? schema = database.rules.schemaFor(
      widget.collectionPath,
    );
    for (final String field in widget.fields) {
      final String? target = schema?.field(field)?.referenceCollection;
      if (target == null || target.isEmpty) continue;
      for (final Map<String, dynamic> doc in widget.docs) {
        final Object? id = doc[field];
        if (id is! String || id.isEmpty) continue;
        if (!requested.add('$field/$id')) continue;
        database.getCollectionPath(target).doc(id).get().then((
          DocumentSnapshot<Map<String, dynamic>> snapshot,
        ) {
          final Map<String, dynamic>? data = snapshot.data();
          if (data == null || !mounted) return;
          setState(
            () => (related[field] ??= {})[id] = sanitizeCloudDataForUse(
              data,
              docId: id,
            ),
          );
        }, onError: (Object _) {});
      }
    }
  }
}
