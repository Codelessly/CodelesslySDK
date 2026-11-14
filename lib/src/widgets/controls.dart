// The controls drawn as render objects (Milestone 3: codelessly_api
// docs/design/11-no-widgets.md), one map per family. The render objects and
// recipes live in lib/src/render/controls, a file per family;
// widgets/registry.dart spreads [controlRecipes] after the island recipes,
// so a family that lands here replaces its islands by being added, without
// editing the island files. A family adds one line here.
import 'package:codelessly_api/core.dart' show ButtonProps, FloatingActionButtonProps, IconButtonProps;

import '../render/controls/app_bar.dart';
import '../render/controls/buttons.dart';
import '../render/controls/navigation_bar.dart';
import '../render/controls/tab_bar.dart';
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

/// Bars: tab bars, navigation bars, the app bar
/// (render/controls/{tab_bar,navigation_bar,app_bar}.dart).
final Map<String, WidgetRecipe> barRecipes = {
  'tabBar': tabBarRecipe,
  'tabs': tabsRecipe,
  'navigationBar': navigationBarRecipe,
  'bottomNavigationBar': navigationBarRecipe,
  'appBar': appBarRecipe,
};

/// The render-object controls, by node type.
final Map<String, WidgetRecipe> controlRecipes = {
  ...buttonRecipes,
  ...barRecipes,
};
