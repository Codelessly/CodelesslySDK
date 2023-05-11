import 'package:codelessly_api/codelessly_api.dart' hide kRadialReactionRadius;
import 'package:flutter/material.dart';

const Color kDefaultPrimaryColor = Color(0xFF5C69E5);
const Color kDefaultFocusColor = Color(0x1f000000);
const Color kDefaultHoverColor = Color(0x0a000000);
const Color kDefaultSplashColor = Color(0x66c8c8c8);
const Color kDefaultOverlayColor = Color(0x1a5c69e5);
const Color kDefaultTextColor = Colors.black;
const Color kDefaultIconColor = Colors.black;
const Color kDefaultPrimaryTextColor = Colors.white;
const double kDefaultIconSize = 24;
const double kDefaultButtonElevation = 2;

class ThemeDefaults {
  const ThemeDefaults._();

  // ListTile
  static const ListTileDefaults listTile = ListTileDefaults._();
  static const IconDefaults icon = IconDefaults._();
  static const ButtonDefaults button = ButtonDefaults._();
  static const TextFieldDefaults textField = TextFieldDefaults._();
}

class ListTileDefaults {
  static const Color tileColor = Colors.transparent;
  static const Color textColor = kDefaultTextColor;
  static const Color iconColor = kDefaultIconColor;
  static const Color selectedColor = kDefaultPrimaryColor;
  static const Color selectedTileColor = Colors.transparent;
  static const Color focusColor = kDefaultFocusColor;
  static const Color hoverColor = kDefaultHoverColor;
  static const CornerRadius cornerRadius = CornerRadius.zero;
  static const VisualDensityModel visualDensity = VisualDensityModel.compact;
  static const CShapeBorder shape = CShapeBorder.roundedRectangle;
  static const EdgeInsetsModel contentPadding = kDefaultListTileContentPadding;
  static const double horizontalTitleGap = kDefaultListTileHorizontalTitleGap;
  static const double minVerticalPadding = kDefaultListTileMinVerticalPadding;
  static const double minLeadingWidth = kDefaultListTileMinLeadingWidth;
  static const bool dense = false;
  static const bool enableFeedback = true;
  static const bool isThreeLine = false;
  static const bool enabled = true;
  static const bool selected = false;
  static const bool autofocus = false;

  const ListTileDefaults._();
}

class IconDefaults {
  static const Color color = kDefaultIconColor;
  static const double size = 24;

  const IconDefaults._();
}

class ButtonDefaults {
  static const Color buttonColor = kDefaultPrimaryColor;
  static const Color shadowColor = Color(0xFFA5A5A5);
  static const String label = 'Button';
  static const double elevation = 0;
  static const CornerRadius cornerRadius =
      CornerRadius.all(RadiusModel.circular(4));
  static const bool enabled = true;
  static const TextAlignHorizontalEnum labelAlignment =
      TextAlignHorizontalEnum.center;
  static const IconPlacementEnum placement = IconPlacementEnum.start;
  static const double gap = 8;

  static StartEndProp get labelStyle => StartEndProp.general(fontSize: 13);
  static const MultiSourceIconModel icon = MultiSourceIconModel(size: 20);

  const ButtonDefaults._();
}

class TextFieldDefaults {
  static const bool autoCorrect = false;
  static const bool autoFocus = false;
  static const bool enableInteractiveSelection = true;
  static const bool enabled = true;
  static const bool obscureText = false;
  static const bool readOnly = false;
  static const bool showCursor = true;
  static const TextInputTypeEnum keyboardType = TextInputTypeEnum.text;
  static const BoxHeightStyleEnum selectionHeightStyle =
      BoxHeightStyleEnum.tight;
  static const BoxWidthStyleEnum selectionWidthStyle = BoxWidthStyleEnum.tight;
  static const TextAlignHorizontalEnum textAlign = TextAlignHorizontalEnum.left;
  static const TextAlignVerticalEnum textAlignVertical =
      TextAlignVerticalEnum.center;
  static const Color cursorColor = kDefaultPrimaryColor;
  static const double cursorHeight = 14;
  static const double cursorWidth = 2;
  static const double cursorRadius = 2;
  static const int maxLines = 1;
  static const String obscuringCharacter = '•';

  static StartEndProp get style => StartEndProp.general(
        fontSize: 14,
        fills: [PaintModel.blackPaint],
      );

  static InputDecorationModel get decoration => InputDecorationModel();
  static const Color fillColor = Color(0xffeeeeee);

  const TextFieldDefaults._();
}

class CheckBoxDefaults {
  static const Color checkColor = Colors.white;
  static const Color activeColor = kDefaultPrimaryColor;
  static const Color borderColor = Colors.grey;
  static const Color hoverColor = kDefaultHoverColor;
  static const Color focusColor = kDefaultFocusColor;
  static const double splashRadius = kRadialReactionRadius;
  static const bool autofocus = false;
  static const bool tristate = false;
  static const double borderWidth = 1.5;
  static const CornerRadius cornerRadius =
      CornerRadius.all(RadiusModel.circular(3));

  CheckBoxDefaults._();
}

class SwitchDefaults {
  static const Color activeTrackColor = kDefaultPrimaryColor;
  static const Color inactiveTrackColor = Colors.grey;
  static const Color activeThumbColor = Colors.white;
  static const Color inactiveThumbColor = Colors.white;
  static const Color hoverColor = kDefaultHoverColor;
  static const Color focusColor = kDefaultFocusColor;
  static const double splashRadius = kRadialReactionRadius;
  static const bool autofocus = false;

  SwitchDefaults._();
}

class RadioDefaults {
  static const Color activeColor = kDefaultPrimaryColor;
  static const Color inactiveColor = Colors.grey;
  static const Color hoverColor = kDefaultHoverColor;
  static const Color focusColor = kDefaultFocusColor;
  static const double splashRadius = kRadialReactionRadius;
  static const bool autofocus = false;
  static const bool toggleable = false;

  RadioDefaults._();
}

class AppBarDefaults {
  static const bool centerTitle = false;
  static const double elevation = 0;
  static const MultiSourceIconModel leading =
      MultiSourceIconModel.icon(color: null);
  static const bool automaticallyImplyLeading = false;

  static StartEndProp get titleStyle => StartEndProp.general(fontSize: 18);
  static const Color backgroundColor = kDefaultPrimaryColor;
  static const String title = 'App Bar';
  static const double titleSpacing = 16;

  static const Color shadowColor = Colors.black;

  AppBarDefaults._();
}

class M2NavigationBarDefaults {
  static const Color backgroundColor = Colors.white;
  static const double elevation = 0;
  static const M2NavigationBarType navigationBarType =
      M2NavigationBarType.fixed;
  static const M2NavigationBarLandscapeLayout landscapeLayout =
      M2NavigationBarLandscapeLayout.spread;
  static const Color selectedLabelColorDark = kDefaultPrimaryColor;
  static const Color selectedLabelColorLight = Colors.white;
  static const Color unselectedLabelColorDark = Colors.grey;
  static const Color unselectedLabelColorLight = Colors.white54;
  static const double labelFontSize = 13;
  static const Color selectedIconColor = kDefaultPrimaryColor;
  static const Color unselectedIconColor = Colors.grey;
  static const double unselectedIconSize = 24;
  static const double selectedIconSize = 24;
  static const MaterialNavigationBarLabelBehavior labelBehavior =
      MaterialNavigationBarLabelBehavior.alwaysShow;

  M2NavigationBarDefaults._();
}

class M3NavigationBarDefaults {
  static const Color backgroundColor = Color(0xfFEEEEEE);
  static const double elevation = 0;

  static TextProp get selectedLabelStyle => TextProp(
        fontSize: 13,
        fontName: FontName(
          family: 'Roboto',
          style: 'Normal',
          weight: FontWeightNumeric.w600,
        ),
      );

  static TextProp get unselectedLabelStyle => TextProp(fontSize: 13);
  static const Color unselectedIconColor = Colors.black;
  static const Color selectedIconColor = kDefaultPrimaryColor;
  static const Color indicatorColor = Color(0x12000000);
  static const double unselectedIconSize = 24;
  static const double selectedIconSize = 24;
  static const MaterialNavigationBarLabelBehavior labelBehavior =
      MaterialNavigationBarLabelBehavior.alwaysShow;

  M3NavigationBarDefaults._();
}

class SliderDefaults {
  static const Color activeTrackColor = kDefaultPrimaryColor;
  static const Color inactiveTrackColor = Color(0X3D5C69E5);
  static const Color overlayColor = kDefaultHoverColor;
  static const Color thumbColor = kDefaultPrimaryColor;
  static const bool autofocus = false;
  static const double min = 0;
  static const double max = 100;
  static const double trackHeight = kSliderDefaultTrackHeight;
  static const String label = kSliderDefaultLabel;
  static const bool isDiscrete = false;
  static const bool showLabel = false;
  static const Color activeTickMarkColor = Colors.grey;
  static const Color inactiveTickMarkColor = Colors.grey;
  static const Color valueIndicatorColor = Colors.black;
  static const Color valueIndicatorTextColor = Colors.white;
  static const double valueIndicatorFontSize = 14;
  static const bool allowFractionalPoints = false;
  static const double thumbRadius = kSliderDefaultThumbRadius;
  static const bool showThumb = true;
  static const SliderTrackShapeEnum trackShape =
      SliderTrackShapeEnum.roundedRectangle;
  static const double tickMarkRadius = kSliderDefaultTickMarkRadius;
  static const SliderValueIndicatorShape valueIndicatorShape =
      SliderValueIndicatorShape.rectangle;
  static const double overlayRadius = kSliderDefaultOverlayRadius;
  static const bool deriveOverlayColorFromThumb = true;

  SliderDefaults._();
}

class ExpansionTileDefaults {
  static const Color backgroundColor = Colors.transparent;
  static const Color collapsedBackgroundColor = Colors.transparent;
  static const bool initiallyExpanded = false;
  static const bool maintainState = false;
  static const EdgeInsetsModel tilePadding = kDefaultListTileContentPadding;
  static const AlignmentModel expandedAlignment = AlignmentModel.center;
  static const CrossAxisAlignmentC expandedCrossAxisAlignment =
      CrossAxisAlignmentC.center;
  static const EdgeInsetsModel childrenPadding = EdgeInsetsModel.zero;
  static const Color iconColor = Colors.black;
  static const Color collapsedIconColor = Colors.black;
  static const Color textColor = Colors.black;
  static const Color collapsedTextColor = Colors.black;
  static const ListTileControlAffinityC controlAffinity =
      ListTileControlAffinityC.trailing;
  static const VisualDensityModel visualDensity = VisualDensityModel.standard;

  ExpansionTileDefaults._();
}

class FloatingActionButtonDefaults {
  static const Color backgroundColor = kDefaultPrimaryColor;
  static const Color foregroundColor = kDefaultPrimaryTextColor;
  static const double elevation = 6;
  static const double focusElevation = 6;
  static const double highlightElevation = 12;
  static const double hoverElevation = 8;
  static const FloatingActionButtonType type = FloatingActionButtonType.regular;
  static const MultiSourceIconModel icon =
      MultiSourceIconModel.icon(size: 24, color: null);
  static const String label = 'Button';

  static TextProp get labelStyle =>
      TextProp.general(fontSize: 16, fills: List.empty(growable: true));
  static const Color focusColor = kDefaultFocusColor;
  static const Color hoverColor = kDefaultHoverColor;
  static const Color splashColor = kDefaultSplashColor;
  static const double extendedIconLabelSpacing = 8;
}

class DividerDefaults {
  static const Color color = Colors.black;
  static const double thickness = 1;
  static const double indent = 0;
  static const double endIndent = 0;
}

class MaterialLoadingIndicatorDefaults {
  static const Color color = kDefaultPrimaryColor;
  static const double strokeWidth = 4;
}

class CupertinoLoadingIndicatorDefaults {
  static const Color color = kDefaultPrimaryColor;
  static const double radius = 10;
}

class ProgressBarDefaults {
  static const Color backgroundColor = kDefaultSplashColor;
  static const Color progressColor = kDefaultPrimaryColor;
  static const double maxValue = 100;
  static const bool animate = true;
  static const int animationDurationInMillis = 300;
  static const CornerRadius cornerRadius =
      CornerRadius.all(RadiusModel.circular(8));
}
