import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

class PassiveChipTransformer extends NodeWidgetTransformer<ChipNode> {
  PassiveChipTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ChipNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    if (settings.isPreview) {
      return PreviewChipWidget(node: node, settings: settings);
    }
    return PassiveChipWidget(node: node, settings: settings);
  }
}

/// A chip whose selection is local state, for previews without a
/// [CodelesslyContext].
class PreviewChipWidget extends StatefulWidget {
  const PreviewChipWidget({
    super.key,
    required this.node,
    required this.settings,
  });

  final ChipNode node;
  final WidgetBuildSettings settings;

  @override
  State<PreviewChipWidget> createState() => _PreviewChipWidgetState();
}

class _PreviewChipWidgetState extends State<PreviewChipWidget> {
  late bool selected = widget.node.properties.selected;

  @override
  Widget build(BuildContext context) {
    return TransformerChip(
      node: widget.node,
      settings: widget.settings,
      selected: selected,
      onPressed: (_) {},
      onSelected: (_, value) => setState(() => selected = value),
      onDeleted: (_) {},
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

  void onPressed(BuildContext context) {
    FunctionsRepository.triggerAction(context, node: node, TriggerType.click);
  }

  void onSelected(BuildContext context, bool selected) {
    NodeStateProvider.setState(context, selected);
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'selected',
      value: selected,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: selected,
    );
    // Selecting is also the chip's press.
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.click,
      value: selected,
    );
  }

  void onDeleted(BuildContext context) {
    FunctionsRepository.triggerAction(context, node: node, TriggerType.click);
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );
    final bool selected =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'selected',
          scopedValues: scopedValues,
        ) ??
        node.properties.selected;

    return TransformerChip(
      node: node,
      settings: settings,
      variablesOverrides: variablesOverrides,
      selected: selected,
      onPressed: onPressed,
      onSelected: onSelected,
      onDeleted: onDeleted,
    );
  }
}

/// Builds the Flutter chip that matches [ChipNode.properties]' chip type.
class TransformerChip extends StatelessWidget {
  final ChipNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final bool selected;
  final void Function(BuildContext context)? onPressed;
  final void Function(BuildContext context, bool selected)? onSelected;
  final void Function(BuildContext context)? onDeleted;

  const TransformerChip({
    super.key,
    required this.node,
    required this.settings,
    required this.selected,
    this.onPressed,
    this.onSelected,
    this.onDeleted,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ChipProperties properties = node.properties;
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );

    final String label =
        PropertyValueDelegate.getPropertyValue<String>(
          node,
          'label',
          scopedValues: scopedValues,
        ) ??
        PropertyValueDelegate.substituteVariables(
          properties.label,
          scopedValues: scopedValues,
          nullSubstitutionMode: settings.nullSubstitutionMode,
        );
    final TextStyle labelStyle = TextUtils.retrieveTextStyleFromProp(
      properties.labelStyle,
    );

    final String? avatarUrl = properties.avatar;
    final Widget? avatar = avatarUrl != null && avatarUrl.isNotEmpty
        ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
        : properties.icon != null
        ? retrieveIconWidget(properties.icon!, properties.icon!.size ?? 18)
        : null;
    final Widget? deleteIcon = properties.deleteIcon != null
        ? retrieveIconWidget(
            properties.deleteIcon!,
            properties.deleteIcon!.size ?? 18,
          )
        : null;

    // Without a border color or width, the chip keeps the Material 3 border,
    // which also changes with the selected state.
    final BorderSide? side =
        properties.borderColor != null || properties.borderWidth != 1
        ? BorderSide(
            color:
                properties.borderColor?.toFlutterColor() ??
                Theme.of(context).colorScheme.outlineVariant,
            width: properties.borderWidth,
          )
        : null;
    final OutlinedBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(properties.cornerRadius),
    );

    final Color? backgroundColor = properties.backgroundColor?.toFlutterColor();
    final Color? selectedColor = properties.selectedColor?.toFlutterColor();
    final Color? shadowColor = properties.shadowColor?.toFlutterColor();
    final EdgeInsets padding = properties.padding.flutterEdgeInsets;
    final EdgeInsets labelPadding = properties.labelPadding.flutterEdgeInsets;
    final String? tooltip = properties.tooltip?.isNotEmpty == true
        ? properties.tooltip
        : null;
    final bool enabled = node.enabled;
    final Key key = ValueKey(
      '${node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}',
    );
    final Widget labelWidget = Text(label);

    final Widget chip = switch (properties.chipType) {
      ChipType.basic => Chip(
        key: key,
        label: labelWidget,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        backgroundColor: backgroundColor,
        side: side,
        shape: shape,
        elevation: properties.elevation,
        shadowColor: shadowColor,
        padding: padding,
        autofocus: properties.autofocus,
      ),
      ChipType.action => ActionChip(
        key: key,
        label: labelWidget,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        backgroundColor: backgroundColor,
        side: side,
        shape: shape,
        elevation: properties.elevation,
        shadowColor: shadowColor,
        padding: padding,
        tooltip: tooltip,
        autofocus: properties.autofocus,
        onPressed: enabled && onPressed != null
            ? () => onPressed!(context)
            : null,
      ),
      ChipType.choice => ChoiceChip(
        key: key,
        label: labelWidget,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        selected: selected,
        backgroundColor: backgroundColor,
        selectedColor: selectedColor,
        showCheckmark: properties.showCheckmark,
        checkmarkColor: properties.checkmarkColor?.toFlutterColor(),
        side: side,
        shape: shape,
        elevation: properties.elevation,
        shadowColor: shadowColor,
        padding: padding,
        tooltip: tooltip,
        autofocus: properties.autofocus,
        onSelected: enabled && onSelected != null
            ? (value) => onSelected!(context, value)
            : null,
      ),
      ChipType.filter => FilterChip(
        key: key,
        label: labelWidget,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        selected: selected,
        backgroundColor: backgroundColor,
        selectedColor: selectedColor,
        showCheckmark: properties.showCheckmark,
        checkmarkColor: properties.checkmarkColor?.toFlutterColor(),
        side: side,
        shape: shape,
        elevation: properties.elevation,
        shadowColor: shadowColor,
        padding: padding,
        tooltip: tooltip,
        autofocus: properties.autofocus,
        onSelected: enabled && onSelected != null
            ? (value) => onSelected!(context, value)
            : null,
      ),
      ChipType.input => InputChip(
        key: key,
        label: labelWidget,
        avatar: avatar,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        deleteIcon: deleteIcon,
        deleteIconColor: properties.deleteIconColor?.toFlutterColor(),
        backgroundColor: backgroundColor,
        side: side,
        shape: shape,
        elevation: properties.elevation,
        shadowColor: shadowColor,
        padding: padding,
        tooltip: tooltip,
        autofocus: properties.autofocus,
        isEnabled: enabled,
        onPressed: enabled && onPressed != null
            ? () => onPressed!(context)
            : null,
        onDeleted: enabled && onDeleted != null
            ? () => onDeleted!(context)
            : null,
      ),
    };

    // Chips draw ink and need a Material ancestor, which a layout may not
    // provide (e.g. when measured offscreen).
    return AdaptiveNodeBox(
      node: node,
      child: Material(type: MaterialType.transparency, child: chip),
    );
  }
}
