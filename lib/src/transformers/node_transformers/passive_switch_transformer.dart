import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';
import '../utils/node_state_provider.dart';

class PassiveSwitchTransformer extends NodeWidgetTransformer<SwitchNode> {
  PassiveSwitchTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SwitchNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(context, node, settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required SwitchProperties props,
    required double height,
    required double width,
    bool value = false,
    required WidgetBuildSettings settings,
  }) {
    final node = SwitchNode(
      id: '',
      name: 'Switch',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      value: value,
    );
    return buildFromNode(context, node, settings);
  }

  Widget buildPreview({
    SwitchProperties? properties,
    SwitchNode? node,
    double? height,
    double? width,
    bool value = false,
    ValueChanged<bool>? onChanged,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
  }) {
    final previewNode = SwitchNode(
      properties: properties ?? node?.properties ?? SwitchProperties(),
      id: '',
      name: 'Switch',
      basicBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
      retainedOuterBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
    );
    previewNode.value = value;
    return PassiveSwitchWidget(
      node: previewNode,
      onChanged: (context, value) => onChanged?.call(value),
      settings: settings,
    );
  }

  Widget buildFromNode(
    BuildContext context,
    SwitchNode node,
    WidgetBuildSettings settings,
  ) {
    return PassiveSwitchWidget(
      node: node,
      settings: settings,
      onChanged: (context, value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, SwitchNode node, bool internalValue) {
    NodeStateProvider.setState(context, internalValue);
    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'value', value: internalValue);

    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.changed, value: internalValue);
  }
}

class PassiveSwitchWidget extends StatelessWidget {
  final SwitchNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final void Function(BuildContext context, bool value)? onChanged;

  const PassiveSwitchWidget({
    super.key,
    required this.node,
    required this.settings,
    this.onChanged,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );
    final bool value = PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'value',
          scopedValues: scopedValues,
        ) ??
        node.value;
    // final bool value = variables.getBooleanById(node.variables['value'] ?? '',
    //     defaultValue: node.value);
    final scale = node.basicBoxLocal.width / kSwitchDefaultWidth;
    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: Transform.scale(
        scale: scale,
        child: Theme(
          data: Theme.of(context).copyWith(),
          child: Switch(
            value: value,
            onChanged: (value) => onChanged?.call(context, value),
            autofocus: node.properties.autofocus,
            activeTrackColor: node.properties.activeTrackColor.toFlutterColor(),
            inactiveTrackColor:
                node.properties.inactiveTrackColor.toFlutterColor(),
            activeColor: node.properties.activeThumbColor.toFlutterColor(),
            inactiveThumbColor:
                node.properties.inactiveThumbColor.toFlutterColor(),
            hoverColor: node.properties.hoverColor.toFlutterColor(),
            focusColor: node.properties.focusColor.toFlutterColor(),
            splashRadius: node.properties.splashRadius,
            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return node.properties.activeTrackBorderColor?.toFlutterColor();
              }
              return node.properties.inactiveTrackBorderColor?.toFlutterColor();
            }),
            trackOutlineWidth:
                WidgetStateProperty.all(node.properties.trackOutlineWidth),
          ),
        ),
      ),
    );
  }
}
