// The controls drawn as render objects (Milestone 3: codelessly_api
// docs/design/11-no-widgets.md), one map per family. The render objects and
// recipes live in lib/src/render/controls, a file per family;
// widgets/registry.dart spreads [controlRecipes] after the island recipes,
// so a family that lands here replaces its islands by being added, without
// editing the island files. A family adds one line here.
import 'package:codelessly_api/core.dart'
    show
        BadgeProps,
        AccordionProps,
        ButtonProps,
        ChipProps,
        DatePickerProps,
        DateTimeInputProps,
        DropdownProps,
        ExpansionTileProps,
        FloatingActionButtonProps,
        IconButtonProps,
        ListTileProps,
        TextFieldProps,
        TimePickerProps;

import '../render/controls/app_bar.dart';
import '../render/controls/buttons.dart';
import '../render/controls/chips.dart';
import '../render/controls/dropdown.dart';
import '../render/controls/expansion.dart';
import '../render/controls/navigation_bar.dart';
import '../render/controls/pickers.dart';
import '../render/controls/segmented.dart';
import '../render/controls/slider.dart';
import '../render/controls/tab_bar.dart';
import '../render/controls/text_field.dart';
import '../render/controls/tile.dart';
import '../render/controls/toggles.dart';
import '../render/recipe.dart';
import '../runtime/actions/text_fields.dart' show textFieldServices;
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

/// Bars: tab bars, navigation bars, the app bar
/// (render/controls/{tab_bar,navigation_bar,app_bar}.dart).
final Map<String, WidgetRecipe> barRecipes = {
  'tabBar': tabBarRecipe,
  'tabs': tabsRecipe,
  'navigationBar': navigationBarRecipe,
  'bottomNavigationBar': navigationBarRecipe,
  'appBar': appBarRecipe,
};

/// Date and time pickers (render/controls/pickers.dart), in the platform
/// locale's names with the runtime's clock (picker_locale.dart).
final Map<String, WidgetRecipe> pickerRecipes = {
  for (final type in [DatePickerProps.spec.type, TimePickerProps.spec.type, DateTimeInputProps.spec.type])
    type: (b, n, chain) => pickerRecipe(b, n, chain, locale: pickerLocale()),
};
/// The dropdown (render/controls/dropdown.dart; its menu in menu.dart).
final Map<String, WidgetRecipe> dropdownRecipes = {DropdownProps.spec.type: dropdownRecipe};

/// Text fields (render/controls/text_field.dart), with the runtime's
/// services (the focus and edit text actions, forms).
final Map<String, WidgetRecipe> textFieldRecipes = {
  TextFieldProps.spec.type: (b, n, chain) => textFieldRecipe(b, n, chain, services: textFieldServices),
};

/// List tiles, accordions and expansion tiles (render/controls/{tile,expansion}.dart).
final Map<String, WidgetRecipe> tileRecipes = {
  ListTileProps.spec.type: listTileRecipe,
  AccordionProps.spec.type: accordionRecipe,
  ExpansionTileProps.spec.type: expansionTileRecipe,
};

/// Toggles, slider and segmented button (render/controls/{toggles,slider,
/// segmented}.dart).
final Map<String, WidgetRecipe> toggleRecipes = {
  'checkbox': checkboxRecipe,
  'switch': switchRecipe,
  'radio': radioRecipe,
  'slider': sliderRecipe,
  'segmentedButton': segmentedRecipe,
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
  ...barRecipes,
  ...pickerRecipes,
  ...dropdownRecipes,
  ...textFieldRecipes,
  ...tileRecipes,
  ...toggleRecipes,
};
