import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveChipTransformer extends NodeWidgetTransformer<ChipNode> {
  PassiveChipTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ChipNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveChipWidget(
      node: node,
      settings: settings,
    );
  }
}

class PassiveChipWidget extends StatelessWidget {
  final ChipNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  const PassiveChipWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
  });

  void onTapChip(BuildContext context) {
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.click,
    );
  }

  void onSelectChip(BuildContext context, bool selected) {
    // Update the selected state
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'selected',
      value: selected,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.click,
      value: selected,
    );
  }

  void onDeleteChip(BuildContext context) {
    // Trigger delete action
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.click,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );

    final String label = PropertyValueDelegate.substituteVariables(
      node.properties.label,
      scopedValues: scopedValues,
      nullSubstitutionMode: settings.nullSubstitutionMode,
    );

    // Build label widget
    final Widget labelWidget = Text(
      label,
      style: TextUtils.retrieveTextStyleFromProp(
        node.properties.labelStyle,
        effects: const [],
      ),
    );

    // Build icon if present
    final Widget? iconWidget = node.properties.icon != null &&
            (node.properties.icon?.show ?? false)
        ? retrieveIconWidget(
            node.properties.icon!,
            node.properties.icon!.size ?? 18,
          )
        : null;

    // Build avatar if present (CircleAvatar)
    final Widget? avatarWidget = node.properties.avatar != null &&
            node.properties.avatar!.isNotEmpty
        ? CircleAvatar(
            backgroundImage: NetworkImage(node.properties.avatar!),
          )
        : null;

    // Build delete icon if present (for input chips)
    final Widget? deleteIconWidget = node.properties.deleteIcon != null &&
            (node.properties.deleteIcon?.show ?? false)
        ? retrieveIconWidget(
            node.properties.deleteIcon!,
            node.properties.deleteIcon!.size ?? 18,
          )
        : null;

    // Background colors
    final Color? backgroundColor =
        node.properties.backgroundColor?.toFlutterColor();
    final Color? selectedColor = node.properties.selectedColor?.toFlutterColor();

    // Border
    final BorderSide? borderSide = node.properties.borderColor != null
        ? BorderSide(
            color: node.properties.borderColor!.toFlutterColor(),
            width: node.properties.borderWidth,
          )
        : null;

    // Shape
    final OutlinedBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(node.properties.cornerRadius),
      side: borderSide ?? BorderSide.none,
    );

    // Common properties
    final EdgeInsets padding = node.properties.padding.flutterEdgeInsets;
    final EdgeInsets labelPadding =
        node.properties.labelPadding.flutterEdgeInsets;
    final double elevation = node.properties.elevation;
    final Color? shadowColor = node.properties.shadowColor?.toFlutterColor();

    // Get selected state from variables if available
    final bool selected = PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'selected',
          scopedValues: scopedValues,
        ) ??
        node.properties.selected;

    // Build appropriate chip based on type
    return AdaptiveNodeBox(
      node: node,
      child: _buildChipByType(
        context: context,
        label: labelWidget,
        icon: iconWidget,
        avatar: avatarWidget,
        deleteIcon: deleteIconWidget,
        backgroundColor: backgroundColor,
        selectedColor: selectedColor,
        shape: shape,
        padding: padding,
        labelPadding: labelPadding,
        elevation: elevation,
        shadowColor: shadowColor,
        selected: selected,
      ),
    );
  }

  Widget _buildChipByType({
    required BuildContext context,
    required Widget label,
    Widget? icon,
    Widget? avatar,
    Widget? deleteIcon,
    Color? backgroundColor,
    Color? selectedColor,
    required OutlinedBorder shape,
    required EdgeInsets padding,
    required EdgeInsets labelPadding,
    required double elevation,
    Color? shadowColor,
    required bool selected,
  }) {
    switch (node.properties.chipType) {
      case ChipType.basic:
        return Chip(
          label: label,
          avatar: avatar,
          labelStyle: TextUtils.retrieveTextStyleFromProp(
            node.properties.labelStyle,
            effects: const [],
          ),
          labelPadding: labelPadding,
          backgroundColor: backgroundColor,
          shape: shape,
          elevation: elevation,
          shadowColor: shadowColor,
          padding: padding,
          autofocus: node.properties.autofocus,
        );

      case ChipType.action:
        return ActionChip(
          label: label,
          avatar: avatar,
          labelStyle: TextUtils.retrieveTextStyleFromProp(
            node.properties.labelStyle,
            effects: const [],
          ),
          labelPadding: labelPadding,
          backgroundColor: backgroundColor,
          shape: shape,
          elevation: elevation,
          shadowColor: shadowColor,
          padding: padding,
          autofocus: node.properties.autofocus,
          onPressed: node.enabled ? () => onTapChip(context) : null,
        );

      case ChipType.choice:
        return ChoiceChip(
          label: label,
          avatar: avatar,
          labelStyle: TextUtils.retrieveTextStyleFromProp(
            node.properties.labelStyle,
            effects: const [],
          ),
          labelPadding: labelPadding,
          selected: selected,
          backgroundColor: backgroundColor,
          selectedColor: selectedColor,
          shape: shape,
          elevation: elevation,
          shadowColor: shadowColor,
          padding: padding,
          autofocus: node.properties.autofocus,
          onSelected: node.enabled ? (bool selected) => onSelectChip(context, selected) : null,
        );

      case ChipType.filter:
        return FilterChip(
          label: label,
          avatar: avatar,
          labelStyle: TextUtils.retrieveTextStyleFromProp(
            node.properties.labelStyle,
            effects: const [],
          ),
          labelPadding: labelPadding,
          selected: selected,
          backgroundColor: backgroundColor,
          selectedColor: selectedColor,
          shape: shape,
          elevation: elevation,
          shadowColor: shadowColor,
          padding: padding,
          autofocus: node.properties.autofocus,
          onSelected: node.enabled ? (bool selected) => onSelectChip(context, selected) : null,
        );

      case ChipType.input:
        return InputChip(
          label: label,
          avatar: avatar,
          labelStyle: TextUtils.retrieveTextStyleFromProp(
            node.properties.labelStyle,
            effects: const [],
          ),
          labelPadding: labelPadding,
          deleteIcon: deleteIcon,
          backgroundColor: backgroundColor,
          shape: shape,
          elevation: elevation,
          shadowColor: shadowColor,
          padding: padding,
          autofocus: node.properties.autofocus,
          onPressed: node.enabled ? () => onTapChip(context) : null,
          onDeleted: node.enabled ? () => onDeleteChip(context) : null,
        );
    }
  }
}
