// The controls drawn as render objects (Milestone 3: codelessly_api
// docs/design/11-no-widgets.md), one map per family. The render objects and
// recipes live in lib/src/render/controls, a file per family;
// widgets/registry.dart spreads [controlRecipes] after the island recipes,
// so a family that lands here replaces its islands by being added, without
// editing the island files. A family adds one line here.
import 'package:codelessly_api/core.dart' show ButtonProps, FloatingActionButtonProps, IconButtonProps, TextFieldProps;

import '../render/controls/buttons.dart';
import '../render/controls/text_field.dart';
import '../render/recipe.dart';
import '../runtime/actions/text_fields.dart' show textFieldServices;

/// Buttons (render/controls/buttons.dart).
final Map<String, WidgetRecipe> buttonRecipes = {
  ButtonProps.filled.type: buttonRecipe,
  ButtonProps.elevated.type: buttonRecipe,
  ButtonProps.outlined.type: buttonRecipe,
  ButtonProps.text.type: buttonRecipe,
  IconButtonProps.spec.type: buttonRecipe,
  FloatingActionButtonProps.spec.type: buttonRecipe,
};

/// Text fields (render/controls/text_field.dart), with the runtime's
/// services (the focus and edit text actions, forms).
final Map<String, WidgetRecipe> textFieldRecipes = {
  TextFieldProps.spec.type: (b, n, chain) => textFieldRecipe(b, n, chain, services: textFieldServices),
};

/// The render-object controls, by node type.
final Map<String, WidgetRecipe> controlRecipes = {
  ...buttonRecipes,
  ...textFieldRecipes,
};
