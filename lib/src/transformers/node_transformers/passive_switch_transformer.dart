import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveSwitchTransformer extends NodeWidgetTransformer<SwitchNode> {
  PassiveSwitchTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SwitchNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(context, node, settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required SwitchProperties props,
    required double height,
    required double width,
    bool value = false,
  }) {
    final node = SwitchNode(
      id: '',
      name: 'Switch',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      value: value,
    );
    return buildFromNode(context, node);
  }

  Widget buildPreview({
    SwitchProperties? properties,
    SwitchNode? node,
    double? height,
    double? width,
    bool value = false,
    ValueChanged<bool>? onChanged,
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
      onChanged: onChanged,
    );
  }

  Widget buildFromNode(
    BuildContext context,
    SwitchNode node, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return PassiveSwitchWidget(
      node: node,
      settings: settings,
      onChanged: (value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, SwitchNode node, bool internalValue) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();

    if (node.variables.containsKey('value')) {
      // a variable is linked to this node.
      final ValueNotifier<VariableData>? variable =
      payload.variables[node.variables['value'] ?? ''];
      if (variable != null) {
        variable.value =
            variable.value.copyWith(value: internalValue.toString());
      }
    }

    // Change local state of switch.
    if (payload.nodeValues.containsKey(node.id)) {
      final List<ValueModel> values = payload.nodeValues[node.id]!.value;
      final ValueModel value = values.firstWhere((val) => val.name == 'value');
      final List<ValueModel> updatedValues = [...values]
        ..remove(value)
        ..add(value.copyWith(value: internalValue));
      payload.nodeValues[node.id]!.value = updatedValues;
    }
    node.reactions
        .where((reaction) => reaction.trigger.type == TriggerType.changed)
        .forEach((reaction) => FunctionsRepository.performAction(
              context,
              reaction.action,
              internalValue: internalValue,
            ));
  }
}

class PassiveSwitchWidget extends StatelessWidget with PropertyValueGetterMixin {
  final SwitchNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final ValueChanged<bool>? onChanged;

  const PassiveSwitchWidget({
    super.key,
    required this.node,
    this.settings = const WidgetBuildSettings(),
    this.onChanged,
    this.variables = const [],
  });

  @override
  Widget build(BuildContext context) {
    final bool value = getPropertyValue<bool>(context, node, 'value') ?? node.value;
    // final bool value = variables.getBooleanById(node.variables['value'] ?? '',
    //     defaultValue: node.value);
    final scale = node.basicBoxLocal.width / kSwitchDefaultWidth;
    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: Transform.scale(
        scale: scale,
        child: Switch(
          value: value,
          onChanged: onChanged,
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
        ),
      ),
    );
  }
}
