// Schema-2 JSON as the current schema reads it: through the migrations
// (migrate2to3, then migrate3to4).
// The SDK's tests are written in schema 2; those that decode a node or a
// behavior directly (not a whole document, which LayoutDocument.fromJson
// migrates) go through these.
import 'package:codelessly_api/codelessly_api.dart';

/// [Node.fromJson] of schema-2 node JSON (migrated first; a node already in
/// the current schema is unchanged by it).
Node? migratedNode(Object? json, {String? id, Catalog? catalog}) =>
    Node.fromJson(json is Map ? migrateNode(readMap(json)!, id: id ?? '') : json, id: id, catalog: catalog);

/// [Behaviors.fromJson] of schema-2 node JSON.
Behaviors migratedBehaviors(Json m) => Behaviors.fromJson(migrateNode(m));

/// A schema-2 `effectAnimations[index]` entry, as the animation it became.
NodeAnimation? legacyEffect(Json effect, int index) => migratedBehaviors({
      'type': 'box',
      'effectAnimations': [...List<Object?>.filled(index, null), effect],
    }).animations.lastOrNull;

/// A schema-2 action.
ActionDef legacyAction(Json a, {Catalog? catalog}) => migratedNode({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': [a]},
      ],
    }, id: 'n', catalog: catalog)!
        .actions
        .single
        .actions
        .single;
