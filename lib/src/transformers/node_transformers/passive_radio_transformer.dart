import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';
import '../utils/node_state_provider.dart';

class PassiveRadioTransformer extends NodeWidgetTransformer<RadioNode> {
  PassiveRadioTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    RadioNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(context, node);
  }

  Widget buildFromProps(
    BuildContext context, {
    required RadioProperties props,
    required double height,
    required double width,
    String value = '',
    String? groupValue,
  }) {
    final node = RadioNode(
      id: '',
      name: 'Radio',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      value: value,
      groupValue: groupValue,
    );
    return buildFromNode(context, node);
  }

  Widget buildPreview({
    RadioProperties? properties,
    RadioNode? node,
    double? height,
    double? width,
    String value = '',
    String? groupValue,
    ValueChanged<String?>? onChanged,
  }) {
    final previewNode = RadioNode(
      properties: properties ?? node?.properties ?? RadioProperties(),
      id: '',
      name: 'Radio',
      basicBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
      retainedOuterBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
    );
    previewNode.value = value;
    previewNode.groupValue = groupValue;
    return PassiveRadioWidget(
      node: previewNode,
      onChanged: (context, value) => onChanged?.call(value),
    );
  }

  Widget buildFromNode(BuildContext context, RadioNode node) {
    return PassiveRadioWidget(
      node: node,
      onChanged: (context, value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, RadioNode node, String? value) {
    NodeStateProvider.setState(context, value);
    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'groupValue', value: value);

    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.click, value: value);
  }

  void onAction(Reaction reaction) {
    switch (reaction.action.type) {
      case ActionType.link:
        launchUrl(Uri.dataFromString((reaction.action as LinkAction).url));
      default:
        break;
    }
  }
}

class PassiveRadioWidget extends StatelessWidget {
  final RadioNode node;
  final List<VariableData> variablesOverrides;
  final void Function(BuildContext context, String? value)? onChanged;

  const PassiveRadioWidget({
    super.key,
    required this.node,
    required this.onChanged,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );
    final value = PropertyValueDelegate.getPropertyValue<String>(
          node,
          'value',
          scopedValues: scopedValues,
        ) ??
        node.value;
    final groupValue = PropertyValueDelegate.getPropertyValue<String>(
          node,
          'groupValue',
          scopedValues: scopedValues,
        ) ??
        node.groupValue ??
        '';
    final scale = node.basicBoxLocal.width / kRadioDefaultSize;

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: Transform.scale(
        scale: scale,
        child: Radio<String>(
          value: value,
          groupValue: groupValue,
          autofocus: node.properties.autofocus,
          activeColor: node.properties.activeColor.toFlutterColor(),
          hoverColor: node.properties.hoverColor.toFlutterColor(),
          focusColor: node.properties.focusColor.toFlutterColor(),
          onChanged: (value) => onChanged?.call(context, value),
          toggleable: node.properties.toggleable,
          splashRadius: node.properties.splashRadius,
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return node.properties.activeColor.toFlutterColor();
            }
            return node.properties.inactiveColor.toFlutterColor();
          }),
        ),
      ),
    );
  }
}
