// The SDK's node tree: the render core's tree ([RenderTree]) with what the
// layers above it give every tree: the built-in widgets (registry.dart),
// the runtime's gesture layers and its image loader.
import 'package:codelessly_api/core.dart' show Node;
import 'package:flutter/foundation.dart';

import '../render/node_tree.dart';
import '../render/recipe.dart';
import '../render/source.dart';
import '../runtime/gestures/gestures.dart';
import '../runtime/http_image_loader.dart';
import 'inputs.dart' show inputsRecipes;
import 'registry.dart';

/// The SDK's built-in widgets: every recipe beyond the core layout types.
final RecipeCatalog builtInCatalog = RecipeCatalog(recipes: widgetRecipes, inputs: inputsRecipes.keys.toSet());

/// Owns the boxes built from one [NodeSource], building every widget type
/// the SDK has.
///
/// A [RenderTree] with the SDK's own [catalog], [gestures] and [imageLoader]: the render
/// core's tree draws only the core layout types on its own, and takes the
/// rest from the layers above it. The boxes, views and recipes of a tree
/// name it by [RenderTree].
class NodeTree extends RenderTree {
  NodeTree(
    super.source, {
    super.observer,
    super.environment,
    super.binder,
    super.interactions,
    super.recipes,
    RecipeCatalog? catalog,
    super.gestures = const DragGestures(),
    super.imageLoader = const HttpImageLoader(),
    super.components,
  }) : super(catalog: catalog ?? builtInCatalog);

  /// See [RenderTree.withoutBindsUnder].
  @visibleForTesting
  static Node withoutBindsUnder(Node n, Map<String, Object?> patch) =>
      // ignore: invalid_use_of_visible_for_testing_member
      RenderTree.withoutBindsUnder(n, patch);

  /// The key of node [id]'s box in [instance] (null: outside repeats).
  static String keyOf(String id, Object? instance) => RenderTree.keyOf(id, instance);
}
