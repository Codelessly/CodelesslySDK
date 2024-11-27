import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

class PassiveSwitchTransformer extends NodeWidgetTransformer<SwitchNode> {
  PassiveSwitchTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SwitchNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    if (settings.isPreview) {
      bool effectiveValue = node.value;
      return StatefulBuilder(
        builder: (context, setState) => TransformerSwitch(
          node: node,
          settings: settings,
          onChanged: (context, value) => setState(() {
            effectiveValue = value;
          }),
          value: effectiveValue,
        ),
      );
    } else {
      return PassiveSwitchWidget(
        node: node,
        settings: settings,
      );
    }
  }
}

class PassiveSwitchWidget extends StatelessWidget {
  final SwitchNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  const PassiveSwitchWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
  });

  void onChanged(BuildContext context, bool internalValue) {
    NodeStateProvider.setState(context, internalValue);

    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'value', value: internalValue);
    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.changed, value: internalValue);
  }

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

    return TransformerSwitch(
      node: node,
      settings: settings,
      variablesOverrides: variablesOverrides,
      value: value,
      onChanged: onChanged,
    );
  }
}

class TransformerSwitch extends StatelessWidget {
  final SwitchNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final void Function(BuildContext context, bool value)? onChanged;
  final bool value;

  const TransformerSwitch({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    required this.value,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scale = node.basicBoxLocal.width / kSwitchDefaultWidth;

    return AdaptiveNodeBox(
      node: node,
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
