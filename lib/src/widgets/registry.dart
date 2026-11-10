// Every widget recipe beyond the core layout types (node_tree.dart builds
// canvas, stack, box, row, column, text, icon, spacer and variance itself).
import '../render/recipe.dart';
import 'collections.dart';
import 'indicators.dart';
import 'inputs.dart';
import 'material.dart';
import 'media.dart';

final Map<String, WidgetRecipe> widgetRecipes = {
  ...collectionsRecipes,
  ...inputsRecipes,
  ...materialRecipes,
  ...indicatorsRecipes,
  ...mediaRecipes,
};
