// The controls drawn as render objects (Milestone 3: codelessly_api
// docs/design/11-no-widgets.md), one map per family. The render objects and
// recipes live in lib/src/render/controls, a file per family;
// widgets/registry.dart spreads [controlRecipes] after the island recipes,
// so a family that lands here replaces its islands by being added, without
// editing the island files. A family adds one line here.
import 'package:codelessly_api/core.dart' show BadgeProps, ButtonProps, ChipProps, FloatingActionButtonProps, IconButtonProps;

import '../render/controls/buttons.dart';
import '../render/controls/chips.dart';
import '../render/recipe.dart';

/// Buttons (render/controls/buttons.dart).
final Map<String, WidgetRecipe> buttonRecipes = {
  ButtonProps.filled.type: buttonRecipe,
  ButtonProps.elevated.type: buttonRecipe,
  ButtonProps.outlined.type: buttonRecipe,
  ButtonProps.text.type: buttonRecipe,
  IconButtonProps.spec.type: buttonRecipe,
  FloatingActionButtonProps.spec.type: buttonRecipe,
};

/// Chips and badges (render/controls/chips.dart).
final Map<String, WidgetRecipe> chipRecipes = {
  ChipProps.chip.type: chipRecipe,
  ChipProps.action.type: chipRecipe,
  ChipProps.choice.type: chipRecipe,
  ChipProps.filter.type: chipRecipe,
  ChipProps.input.type: chipRecipe,
  BadgeProps.spec.type: badgeRecipe,
};

/// The render-object controls, by node type.
final Map<String, WidgetRecipe> controlRecipes = {
  ...buttonRecipes,
  ...chipRecipes,
};
