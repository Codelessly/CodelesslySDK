import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveButtonTransformer extends NodeWidgetTransformer<ButtonNode> {
  PassiveButtonTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    ButtonNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildButtonFromNode(
      context,
      node,
      settings: settings,
    );
  }

  Widget buildButtonWidgetFromProps(
    BuildContext context, {
    required ButtonProperties props,
    required double height,
    required double width,
    EdgeInsetsModel? padding,
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  }) {
    final node = ButtonNode(
      id: '',
      name: 'Button',
      basicBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      edgePins: EdgePinsModel.standard,
      padding: padding ?? EdgeInsetsModel.zero,
    );
    return buildButtonFromNode(context, node, settings: settings);
  }

  Widget buildButtonFromNode(
    BuildContext context,
    ButtonNode node, {
    required WidgetBuildSettings settings,
  }) {
    return PassiveButtonWidget(
      node: node,
      settings: settings,
      onPressed: () => onPressed(context, node.reactions),
      onLongPress: () => onLongPress(context, node.reactions),
    );
  }

  void onPressed(BuildContext context, List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .forEach((reaction) =>
          FunctionsRepository.performAction(context, reaction.action));

  void onLongPress(BuildContext context, List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.longPress)
      .forEach((reaction) =>
          FunctionsRepository.performAction(context, reaction.action));
}

class PassiveButtonWidget extends StatelessWidget {
  final ButtonNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double? elevation;
  final bool useIconFonts;

  PassiveButtonWidget({
    super.key,
    required this.node,
    required this.settings,
    List<VariableData>? variables,
    this.onPressed,
    this.onLongPress,
    this.elevation,
    this.useIconFonts = false,
  }) : variables = variables ?? [];

  @override
  Widget build(BuildContext context) {
    /// Check if this is a part of a list item.
    final IndexedItemProvider? indexProvider = IndexedItemProvider.of(context);
    if (indexProvider != null) {
      variables.add(
        VariableData(
          id: 'index',
          name: 'index',
          value: indexProvider.index.toString(),
        ),
      );
    }

    final String? layoutID = context.read<CodelesslyContext>().layoutID;
    if (layoutID != null) {
      final Map<String, VariableData> variablesMap = context
              .read<Codelessly>()
              .dataManager
              .publishModel!
              .variables[layoutID]
              ?.variables ??
          {};

      variables.addAll(variablesMap.values);
      print('variables: ${variablesMap.values.map((e) => e.name)}');
    }

    String text = transformText(node.properties.label, variables, context);

    // final CodelesslyContext codelesslyContext =
    //     context.read<CodelesslyContext>();

    // codelesslyContext.data
    //     .forEach((key, value) => text = text.replaceAll(key, value));

    final ButtonStyle buttonStyle =
        createMasterButtonStyle(node, elevation: elevation);
    final textAlign = node.properties.labelAlignment.toFlutter();
    final double effectiveIconSize =
        min(node.properties.icon.size ?? 24, node.basicBoxLocal.height);
    Widget iconWidget = retrieveIconWidget(
        node.properties.icon, effectiveIconSize, useIconFonts);

    final bool enabled =
        context.getNodeValue(node.id, 'enabled') ?? node.properties.enabled;

    Widget buttonWidget;
    switch (node.properties.buttonType) {
      case ButtonTypeEnum.elevated:
        buttonWidget = ElevatedButton(
          onPressed: enabled ? () => onPressed?.call() : null,
          onLongPress: enabled ? () => onLongPress?.call() : null,
          style: buttonStyle,
          child: !node.properties.icon.isEmpty
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
                    Flexible(child: Text(text, textAlign: textAlign)),
                    if (node.properties.placement == IconPlacementEnum.end) ...{
                      if (node.properties.icon.show)
                        SizedBox(width: node.properties.gap),
                      iconWidget,
                    }
                  ],
                )
              : Text(text, textAlign: textAlign),
        );
        break;
      case ButtonTypeEnum.text:
        buttonWidget = TextButton(
          onPressed: () => onPressed?.call(),
          onLongPress: () => onLongPress?.call(),
          style: buttonStyle,
          child: !node.properties.icon.isEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  verticalDirection: VerticalDirection.down,
                  children: [
                    if (node.properties.placement ==
                        IconPlacementEnum.start) ...{
                      iconWidget,
                      SizedBox(width: node.properties.gap),
                    },
                    Flexible(child: Text(text, textAlign: textAlign)),
                    if (node.properties.placement == IconPlacementEnum.end) ...{
                      SizedBox(width: node.properties.gap),
                      iconWidget,
                    }
                  ],
                )
              : Text(text, textAlign: textAlign),
        );
        break;
      case ButtonTypeEnum.outlined:
        buttonWidget = OutlinedButton(
          onPressed: enabled ? () => onPressed?.call() : null,
          onLongPress: enabled ? () => onLongPress?.call() : null,
          style: buttonStyle,
          child: !node.properties.icon.isEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  verticalDirection: VerticalDirection.down,
                  children: [
                    if (node.properties.placement ==
                        IconPlacementEnum.start) ...{
                      iconWidget,
                      SizedBox(width: node.properties.gap),
                    },
                    Flexible(child: Text(text, textAlign: textAlign)),
                    if (node.properties.placement == IconPlacementEnum.end) ...{
                      SizedBox(width: node.properties.gap),
                      iconWidget,
                    }
                  ],
                )
              : Text(text, textAlign: textAlign),
        );
        break;
      case ButtonTypeEnum.icon:
        buttonWidget = ElevatedButton(
          style: buttonStyle.copyWith(
            textStyle: MaterialStateProperty.all(TextStyle()),
          ),
          onPressed: enabled ? () => onPressed?.call() : null,
          child: iconWidget,
        );
    }

    return AdaptiveNodeBox(node: node, child: buttonWidget);
  }
}
