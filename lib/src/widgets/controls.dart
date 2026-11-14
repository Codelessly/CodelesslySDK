// The controls drawn as render objects (Milestone 3: codelessly_api
// docs/design/11-no-widgets.md), one map per family. The render objects and
// recipes live in lib/src/render/controls, a file per family;
// widgets/registry.dart spreads [controlRecipes] after the island recipes,
// so a family that lands here replaces its islands by being added, without
// editing the island files. A family adds one line here.
import 'package:codelessly_api/core.dart'
    show AccordionProps, ButtonProps, ExpansionTileProps, FloatingActionButtonProps, IconButtonProps, ListTileProps;

import '../render/controls/buttons.dart';
import '../render/controls/expansion.dart';
import '../render/controls/tile.dart';
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

/// List tiles, accordions and expansion tiles (render/controls/{tile,expansion}.dart).
final Map<String, WidgetRecipe> tileRecipes = {
  ListTileProps.spec.type: listTileRecipe,
  AccordionProps.spec.type: accordionRecipe,
  ExpansionTileProps.spec.type: expansionTileRecipe,
};

/// The render-object controls, by node type.
final Map<String, WidgetRecipe> controlRecipes = {
  ...buttonRecipes,
  ...tileRecipes,
};
