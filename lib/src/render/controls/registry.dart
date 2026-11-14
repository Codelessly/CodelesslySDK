// The controls drawn as render objects (Milestone 3: codelessly_api
// docs/design/11-no-widgets.md), one map per family, each in its family's
// own file. lib/src/widgets/registry.dart spreads [controlRecipes] after the
// island recipes, so a family that lands here replaces its islands by being
// added, without editing the island files.
import '../recipe.dart';
import 'buttons.dart';

/// The render-object controls, by node type.
final Map<String, WidgetRecipe> controlRecipes = {
  ...buttonRecipes,
};
