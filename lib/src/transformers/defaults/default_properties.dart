import 'package:codelessly_api/codelessly_api.dart';

import '../../../codelessly_sdk.dart';

// TODO: InkWells.

ListTileProperties get defaultListTileProperties => ListTileProperties(
      isThreeLine: ListTileDefaults.isThreeLine,
      dense: ListTileDefaults.dense,
      visualDensity: ListTileDefaults.visualDensity,
      shape: ListTileDefaults.shape,
      selectedColor: ListTileDefaults.selectedColor.toColorRGBA(),
      iconColor: ListTileDefaults.iconColor.toColorRGBA(),
      textColor: ListTileDefaults.textColor.toColorRGBA(),
      contentPadding: ListTileDefaults.contentPadding,
      enabled: ListTileDefaults.enabled,
      selected: ListTileDefaults.selected,
      focusColor: ListTileDefaults.focusColor.toColorRGBA(),
      hoverColor: ListTileDefaults.hoverColor.toColorRGBA(),
      autofocus: ListTileDefaults.autofocus,
      cornerRadius: ListTileDefaults.cornerRadius,
      tileColor: ListTileDefaults.tileColor.toColorRGBA(),
      selectedTileColor: ListTileDefaults.selectedTileColor.toColorRGBA(),
      enableFeedback: ListTileDefaults.enableFeedback,
      horizontalTitleGap: ListTileDefaults.horizontalTitleGap,
      minVerticalPadding: ListTileDefaults.minVerticalPadding,
      minLeadingWidth: ListTileDefaults.minLeadingWidth,
    );

TextFieldProperties get defaultTextFieldProperties => TextFieldProperties(
      autoCorrect: TextFieldDefaults.autoCorrect,
      autoFocus: TextFieldDefaults.autoFocus,
      enableInteractiveSelection: TextFieldDefaults.enableInteractiveSelection,
      enabled: TextFieldDefaults.enabled,
      obscureText: TextFieldDefaults.obscureText,
      readOnly: TextFieldDefaults.readOnly,
      showCursor: TextFieldDefaults.showCursor,
      keyboardType: TextFieldDefaults.keyboardType,
      selectionHeightStyle: TextFieldDefaults.selectionHeightStyle,
      selectionWidthStyle: TextFieldDefaults.selectionWidthStyle,
      textAlign: TextFieldDefaults.textAlign,
      textAlignVertical: TextFieldDefaults.textAlignVertical,
      cursorColor: TextFieldDefaults.cursorColor.toColorRGB(),
      cursorHeight: TextFieldDefaults.cursorHeight,
      cursorWidth: TextFieldDefaults.cursorWidth,
      cursorRadius: TextFieldDefaults.cursorRadius,
      maxLines: TextFieldDefaults.maxLines,
      obscuringCharacter: TextFieldDefaults.obscuringCharacter,
      inputStyle: TextFieldDefaults.style,
      decoration: TextFieldDefaults.decoration,
      expands: false,
    );

ButtonProperties get defaultButtonProperties => ButtonProperties(
      buttonType: ButtonTypeEnum.elevated,
      buttonColor: ButtonDefaults.buttonColor.toColorRGBA(),
      shadowColor: ButtonDefaults.shadowColor.toColorRGBA(),
      label: ButtonDefaults.label,
      elevation: ButtonDefaults.elevation,
      cornerRadius: ButtonDefaults.cornerRadius,
      enabled: ButtonDefaults.enabled,
      labelAlignment: ButtonDefaults.labelAlignment,
      placement: ButtonDefaults.placement,
      gap: ButtonDefaults.gap,
      labelStyle: ButtonDefaults.labelStyle,
      icon: ButtonDefaults.icon,
    );

CheckboxProperties get defaultCheckboxProperties => CheckboxProperties(
      checkColor: CheckBoxDefaults.checkColor.toColorRGBA(),
      activeColor: CheckBoxDefaults.activeColor.toColorRGBA(),
      hoverColor: CheckBoxDefaults.hoverColor.toColorRGBA(),
      focusColor: CheckBoxDefaults.focusColor.toColorRGBA(),
      tristate: CheckBoxDefaults.tristate,
      borderColor: CheckBoxDefaults.borderColor.toColorRGBA(),
      borderWidth: CheckBoxDefaults.borderWidth,
      cornerRadius: CheckBoxDefaults.cornerRadius,
      splashRadius: CheckBoxDefaults.splashRadius,
      autofocus: CheckBoxDefaults.autofocus,
    );

SwitchProperties get defaultSwitchProperties => SwitchProperties(
      activeTrackColor: SwitchDefaults.activeTrackColor.toColorRGBA(),
      inactiveTrackColor: SwitchDefaults.inactiveTrackColor.toColorRGBA(),
      activeThumbColor: SwitchDefaults.activeThumbColor.toColorRGBA(),
      inactiveThumbColor: SwitchDefaults.inactiveThumbColor.toColorRGBA(),
      hoverColor: SwitchDefaults.hoverColor.toColorRGBA(),
      focusColor: SwitchDefaults.focusColor.toColorRGBA(),
      splashRadius: SwitchDefaults.splashRadius,
      autofocus: SwitchDefaults.autofocus,
    );

RadioProperties get defaultRadioProperties => RadioProperties(
      activeColor: RadioDefaults.activeColor.toColorRGBA(),
      inactiveColor: RadioDefaults.inactiveColor.toColorRGBA(),
      hoverColor: RadioDefaults.hoverColor.toColorRGBA(),
      focusColor: RadioDefaults.focusColor.toColorRGBA(),
      splashRadius: RadioDefaults.splashRadius,
      autofocus: RadioDefaults.autofocus,
      toggleable: RadioDefaults.toggleable,
    );

M2NavigationBarProperties get defaultM2FixedNavigationBarProperties =>
    M2NavigationBarProperties(
      backgroundColor: M2NavigationBarDefaults.backgroundColor.toColorRGBA(),
      elevation: M2NavigationBarDefaults.elevation,
      navigationBarType: M2NavigationBarDefaults.navigationBarType,
      landscapeLayout: M2NavigationBarDefaults.landscapeLayout,
      selectedLabelStyle: TextProp.general(
          fontSize: M2NavigationBarDefaults.labelFontSize,
          fills: [M2NavigationBarDefaults.selectedLabelColorDark.toPaint()]),
      unselectedLabelStyle: TextProp.general(
          fontSize: M2NavigationBarDefaults.labelFontSize,
          fills: [M2NavigationBarDefaults.unselectedLabelColorDark.toPaint()]),
      selectedIconColor:
          M2NavigationBarDefaults.selectedIconColor.toColorRGBA(),
      unselectedIconColor:
          M2NavigationBarDefaults.unselectedIconColor.toColorRGBA(),
      unselectedIconSize: M2NavigationBarDefaults.unselectedIconSize,
      selectedIconSize: M2NavigationBarDefaults.selectedIconSize,
      labelBehavior: M2NavigationBarDefaults.labelBehavior,
      items: [],
    );

M2NavigationBarProperties get defaultM2ShiftingNavigationBarProperties =>
    M2NavigationBarProperties(
      backgroundColor: M2NavigationBarDefaults.backgroundColor.toColorRGBA(),
      elevation: M2NavigationBarDefaults.elevation,
      navigationBarType: M2NavigationBarDefaults.navigationBarType,
      landscapeLayout: M2NavigationBarDefaults.landscapeLayout,
      selectedLabelStyle: TextProp.general(
          fontSize: M2NavigationBarDefaults.labelFontSize,
          fills: [M2NavigationBarDefaults.selectedLabelColorLight.toPaint()]),
      unselectedLabelStyle: TextProp.general(
          fontSize: M2NavigationBarDefaults.labelFontSize,
          fills: [M2NavigationBarDefaults.unselectedLabelColorLight.toPaint()]),
      selectedIconColor:
          M2NavigationBarDefaults.selectedIconColor.toColorRGBA(),
      unselectedIconColor:
          M2NavigationBarDefaults.unselectedIconColor.toColorRGBA(),
      unselectedIconSize: M2NavigationBarDefaults.unselectedIconSize,
      selectedIconSize: M2NavigationBarDefaults.selectedIconSize,
      labelBehavior: M2NavigationBarDefaults.labelBehavior,
      items: [],
    );

M3NavigationBarProperties get defaultM3NavigationBarProperties =>
    M3NavigationBarProperties(
      backgroundColor: M3NavigationBarDefaults.backgroundColor.toColorRGBA(),
      elevation: M3NavigationBarDefaults.elevation,
      selectedLabelStyle: M3NavigationBarDefaults.selectedLabelStyle,
      unselectedLabelStyle: M3NavigationBarDefaults.unselectedLabelStyle,
      unselectedIconColor:
          M3NavigationBarDefaults.unselectedIconColor.toColorRGBA(),
      selectedIconColor:
          M3NavigationBarDefaults.selectedIconColor.toColorRGBA(),
      unselectedIconSize: M3NavigationBarDefaults.unselectedIconSize,
      selectedIconSize: M3NavigationBarDefaults.selectedIconSize,
      labelBehavior: M3NavigationBarDefaults.labelBehavior,
      indicatorColor: M3NavigationBarDefaults.indicatorColor.toColorRGBA(),
      items: [],
    );

SliderProperties get defaultSliderProperties => SliderProperties(
      activeTrackColor: SliderDefaults.activeTrackColor.toColorRGBA(),
      inactiveTrackColor: SliderDefaults.inactiveTrackColor.toColorRGBA(),
      overlayColor: SliderDefaults.overlayColor.toColorRGBA(),
      thumbColor: SliderDefaults.thumbColor.toColorRGBA(),
      autofocus: SliderDefaults.autofocus,
      min: SliderDefaults.min,
      max: SliderDefaults.max,
      trackHeight: SliderDefaults.trackHeight,
      label: SliderDefaults.label,
      isDiscrete: SliderDefaults.isDiscrete,
      showLabel: SliderDefaults.showLabel,
      activeTickMarkColor: SliderDefaults.activeTickMarkColor.toColorRGBA(),
      inactiveTickMarkColor: SliderDefaults.inactiveTickMarkColor.toColorRGBA(),
      valueIndicatorColor: SliderDefaults.valueIndicatorColor.toColorRGBA(),
      valueIndicatorTextColor:
          SliderDefaults.valueIndicatorTextColor.toColorRGBA(),
      valueIndicatorFontSize: SliderDefaults.valueIndicatorFontSize,
      allowFractionalPoints: SliderDefaults.allowFractionalPoints,
      thumbRadius: SliderDefaults.thumbRadius,
      showThumb: SliderDefaults.showThumb,
      trackShape: SliderDefaults.trackShape,
      tickMarkRadius: SliderDefaults.tickMarkRadius,
      valueIndicatorShape: SliderDefaults.valueIndicatorShape,
      overlayRadius: SliderDefaults.overlayRadius,
      deriveOverlayColorFromThumb: SliderDefaults.deriveOverlayColorFromThumb,
    );

ExpansionTileProperties get defaultExpansionTileProperties =>
    ExpansionTileProperties(
      backgroundColor: ExpansionTileDefaults.backgroundColor.toColorRGBA(),
      collapsedBackgroundColor:
          ExpansionTileDefaults.collapsedBackgroundColor.toColorRGBA(),
      initiallyExpanded: ExpansionTileDefaults.initiallyExpanded,
      maintainState: ExpansionTileDefaults.maintainState,
      tilePadding: ExpansionTileDefaults.tilePadding,
      expandedAlignment: ExpansionTileDefaults.expandedAlignment,
      expandedCrossAxisAlignment:
          ExpansionTileDefaults.expandedCrossAxisAlignment,
      childrenPadding: ExpansionTileDefaults.childrenPadding,
      iconColor: ExpansionTileDefaults.iconColor.toColorRGBA(),
      collapsedIconColor:
          ExpansionTileDefaults.collapsedIconColor.toColorRGBA(),
      textColor: ExpansionTileDefaults.textColor.toColorRGBA(),
      collapsedTextColor:
          ExpansionTileDefaults.collapsedTextColor.toColorRGBA(),
      controlAffinity: ExpansionTileDefaults.controlAffinity,
      visualDensity: ExpansionTileDefaults.visualDensity,
    );

FloatingActionButtonProperties get defaultFloatingActionButtonProperties =>
    FloatingActionButtonProperties(
      backgroundColor:
          FloatingActionButtonDefaults.backgroundColor.toColorRGBA(),
      foregroundColor:
          FloatingActionButtonDefaults.foregroundColor.toColorRGBA(),
      label: FloatingActionButtonDefaults.label,
      type: FloatingActionButtonDefaults.type,
      elevation: FloatingActionButtonDefaults.elevation,
      icon: FloatingActionButtonDefaults.icon,
      labelStyle: FloatingActionButtonDefaults.labelStyle,
      hoverColor: FloatingActionButtonDefaults.hoverColor.toColorRGBA(),
      focusColor: FloatingActionButtonDefaults.focusColor.toColorRGBA(),
      splashColor: FloatingActionButtonDefaults.splashColor.toColorRGBA(),
      focusElevation: FloatingActionButtonDefaults.focusElevation,
      hoverElevation: FloatingActionButtonDefaults.hoverElevation,
      highlightElevation: FloatingActionButtonDefaults.highlightElevation,
      extendedIconLabelSpacing:
          FloatingActionButtonDefaults.extendedIconLabelSpacing,
    );

DividerProperties get defaultDividerProperties => DividerProperties(
      color: DividerDefaults.color.toColorRGBA(),
      thickness: DividerDefaults.thickness,
      indent: DividerDefaults.indent,
      endIndent: DividerDefaults.endIndent,
    );

CupertinoLoadingIndicatorProperties
    get defaultCupertinoLoadingIndicatorProperties =>
        CupertinoLoadingIndicatorProperties(
          color: CupertinoLoadingIndicatorDefaults.color.toColorRGBA(),
          radius: CupertinoLoadingIndicatorDefaults.radius,
        );

MaterialLoadingIndicatorProperties
    get defaultMaterialLoadingIndicatorProperties =>
        MaterialLoadingIndicatorProperties(
          color: MaterialLoadingIndicatorDefaults.color.toColorRGBA(),
          strokeWidth: MaterialLoadingIndicatorDefaults.strokeWidth,
        );

ProgressBarProperties get defaultProgressBarProperties => ProgressBarProperties(
      maxValue: ProgressBarDefaults.maxValue,
      backgroundColor: ProgressBarDefaults.backgroundColor.toColorRGBA(),
      progressColor: ProgressBarDefaults.progressColor.toColorRGBA(),
      animate: ProgressBarDefaults.animate,
      animationDurationInMillis: ProgressBarDefaults.animationDurationInMillis,
      cornerRadius: ProgressBarDefaults.cornerRadius,
    );

TabBarProperties get defaultTabBarProperties => TabBarProperties(
      dividerColor: TabBarDefaults.dividerColor.toColorRGBA(),
      indicatorColor: TabBarDefaults.indicatorColor.toColorRGBA(),
      indicatorWeight: TabBarDefaults.indicatorWeight,
      labelColor: TabBarDefaults.labelColor.toColorRGBA(),
      labelPadding: TabBarDefaults.labelPadding,
      labelStyle: TabBarDefaults.labelStyle,
      unselectedLabelColor: TabBarDefaults.unselectedLabelColor.toColorRGBA(),
      unselectedLabelStyle: TabBarDefaults.unselectedLabelStyle,
      indicatorSize: TabBarDefaults.indicatorSize,
      indicatorPadding: TabBarDefaults.indicatorPadding,
      tabItemDirection: TabBarDefaults.tabItemDirection,
      gap: TabBarDefaults.gap,
    );
