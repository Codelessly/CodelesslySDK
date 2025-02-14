import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveButtonTransformer extends NodeWidgetTransformer<ButtonNode> {
  PassiveButtonTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ButtonNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildButtonFromNode(
      node,
      settings: settings,
    );
  }

  Widget buildFromProps(
    BuildContext context, {
    required ButtonProperties props,
    required double height,
    required double width,
    EdgeInsetsModel? padding,
    required WidgetBuildSettings settings,
  }) {
    final node = ButtonNode(
      id: '',
      name: 'Button',
      basicBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      edgePins: EdgePinsModel.standard,
      padding: padding ?? EdgeInsetsModel.zero,
    );
    return buildButtonFromNode(node, settings: settings);
  }

  Widget buildButtonFromNode(
    ButtonNode node, {
    required WidgetBuildSettings settings,
  }) {
    return PassiveButtonWidget(
      node: node,
      settings: settings,
      onPressed: (context) => onPressed(context, node.reactions),
      onLongPress: (context) => onLongPress(context, node.reactions),
    );
  }

  void onPressed(BuildContext context, List<Reaction> reactions) =>
      FunctionsRepository.triggerAction(
        context,
        reactions: reactions,
        TriggerType.click,
      );

  void onLongPress(BuildContext context, List<Reaction> reactions) =>
      FunctionsRepository.triggerAction(
        context,
        reactions: reactions,
        TriggerType.longPress,
      );
}

class PassiveButtonWidget extends StatelessWidget {
  final ButtonNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final void Function(BuildContext context)? onPressed;
  final void Function(BuildContext context)? onLongPress;
  final double? elevation;

  PassiveButtonWidget({
    super.key,
    required this.node,
    required this.settings,
    List<VariableData>? variables,
    this.onPressed,
    this.onLongPress,
    this.elevation,
  }) : variablesOverrides = variables ?? [];

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues =
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final ButtonStyle buttonStyle = createMasterButtonStyle(
      node,
      elevation: elevation,
      scopedValues: scopedValues,
    );
    final double effectiveIconSize =
        min(node.properties.icon.size ?? 24, node.basicBoxLocal.height);
    Widget? iconWidget =
        retrieveIconWidget(node.properties.icon, effectiveIconSize);

    final bool enabled = PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'enabled',
          scopedValues: scopedValues,
        ) ??
        node.properties.enabled;

    final Text label;

    // TODO: refactor into TextUtils where it can be built without a style.
    // TODO: @Birju @Saad Use FX symbol if conditions are applied.
    if (settings.replaceVariablesWithSymbols) {
      final List<TextSpan> spans = node.properties.label
          .splitMap(
            variablePathRegex,
            onMatch: (match) => VariableSpan(
              variable: match[0]!,
              style: const TextStyle(),
            ),
            onNonMatch: (text) => TextSpan(text: text),
          )
          .toList();
      label = Text.rich(
        TextSpan(children: spans),
        textAlign: node.properties.labelAlignment.flutterTextAlignment,
      );
    } else {
      final String value = PropertyValueDelegate.getPropertyValue<String>(
            node,
            'label',
            scopedValues: scopedValues,
          ) ??
          PropertyValueDelegate.substituteVariables(
            node.properties.label,
            scopedValues: scopedValues,
            nullSubstitutionMode: settings.nullSubstitutionMode,
          );
      label = Text(
        value,
        textAlign: node.properties.labelAlignment.flutterTextAlignment,
      );
    }

    Widget buttonWidget;
    switch (node.properties.buttonType) {
      case ButtonTypeEnum.elevated:
        buttonWidget = ElevatedButton(
          onPressed: enabled ? () => onPressed?.call(context) : null,
          onLongPress: enabled ? () => onLongPress?.call(context) : null,
          style: buttonStyle,
          child: iconWidget != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  verticalDirection: VerticalDirection.down,
                  children: [
                    if (node.properties.placement ==
                        IconPlacementEnum.start) ...{
                      iconWidget,
                      if (node.properties.icon.show)
                        SizedBox(width: node.properties.gap),
                    },
                    Flexible(child: label),
                    if (node.properties.placement == IconPlacementEnum.end) ...{
                      if (node.properties.icon.show)
                        SizedBox(width: node.properties.gap),
                      iconWidget,
                    }
                  ],
                )
              : label,
        );
      case ButtonTypeEnum.text:
        buttonWidget = TextButton(
          onPressed: enabled ? () => onPressed?.call(context) : null,
          onLongPress: enabled ? () => onLongPress?.call(context) : null,
          style: buttonStyle,
          child: iconWidget != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  verticalDirection: VerticalDirection.down,
                  children: [
                    if (node.properties.placement ==
                        IconPlacementEnum.start) ...{
                      iconWidget,
                      SizedBox(width: node.properties.gap),
                    },
                    Flexible(child: label),
                    if (node.properties.placement == IconPlacementEnum.end) ...{
                      SizedBox(width: node.properties.gap),
                      iconWidget,
                    }
                  ],
                )
              : label,
        );
      case ButtonTypeEnum.outlined:
        buttonWidget = OutlinedButton(
          onPressed: enabled ? () => onPressed?.call(context) : null,
          onLongPress: enabled ? () => onLongPress?.call(context) : null,
          style: buttonStyle,
          child: iconWidget != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  verticalDirection: VerticalDirection.down,
                  children: [
                    if (node.properties.placement ==
                        IconPlacementEnum.start) ...{
                      iconWidget,
                      SizedBox(width: node.properties.gap),
                    },
                    Flexible(child: label),
                    if (node.properties.placement == IconPlacementEnum.end) ...{
                      SizedBox(width: node.properties.gap),
                      iconWidget,
                    }
                  ],
                )
              : label,
        );
      case ButtonTypeEnum.icon:
        buttonWidget = ElevatedButton(
          style: buttonStyle.copyWith(
            textStyle: WidgetStateProperty.all(const TextStyle()),
          ),
          onPressed: enabled ? () => onPressed?.call(context) : null,
          onLongPress: enabled ? () => onLongPress?.call(context) : null,
          child: iconWidget,
        );
    }

    return AdaptiveNodeBox(node: node, child: buttonWidget);
  }
}
