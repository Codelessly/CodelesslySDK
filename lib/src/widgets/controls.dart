// The controls drawn as render objects (Milestone 3: codelessly_api
// docs/design/11-no-widgets.md), one map per family. The render objects and
// recipes live in lib/src/render/controls, a file per family;
// widgets/registry.dart spreads [controlRecipes] after the island recipes,
// so a family that lands here replaces its islands by being added, without
// editing the island files. A family adds one line here.
import 'package:codelessly_api/core.dart'
    show ButtonProps, DatePickerProps, DateTimeInputProps, FloatingActionButtonProps, IconButtonProps, TimePickerProps;

import '../render/controls/buttons.dart';
import '../render/controls/pickers.dart';
import '../render/recipe.dart';
import 'picker_locale.dart';

/// Buttons (render/controls/buttons.dart).
final Map<String, WidgetRecipe> buttonRecipes = {
  ButtonProps.filled.type: buttonRecipe,
  ButtonProps.elevated.type: buttonRecipe,
  ButtonProps.outlined.type: buttonRecipe,
  ButtonProps.text.type: buttonRecipe,
  IconButtonProps.spec.type: buttonRecipe,
  FloatingActionButtonProps.spec.type: buttonRecipe,
};

/// Date and time pickers (render/controls/pickers.dart), in the platform
/// locale's names with the runtime's clock (picker_locale.dart).
final Map<String, WidgetRecipe> pickerRecipes = {
  for (final type in [DatePickerProps.spec.type, TimePickerProps.spec.type, DateTimeInputProps.spec.type])
    type: (b, n, chain) => pickerRecipe(b, n, chain, locale: pickerLocale()),
};

/// The render-object controls, by node type.
final Map<String, WidgetRecipe> controlRecipes = {
  ...buttonRecipes,
  ...pickerRecipes,
};
