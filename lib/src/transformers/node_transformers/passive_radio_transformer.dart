import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../codelessly_sdk.dart';

class PassiveRadioTransformer extends NodeWidgetTransformer<RadioNode> {
  PassiveRadioTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    RadioNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
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
      onChanged: onChanged,
    );
  }

  Widget buildFromNode(BuildContext context, RadioNode node) {
    return PassiveRadioWidget(
      node: node,
      onChanged: (value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, RadioNode node, String? value) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();

    if (node.variables.containsKey('groupValue')) {
      // a variable is linked to this node.
      final ValueNotifier<VariableData>? variable =
          payload.variables[node.variables['groupValue'] ?? ''];
      if (variable != null) {
        variable.value = variable.value.copyWith(value: value);
      }
    }

    node.reactions
        .where((reaction) => reaction.trigger.type == TriggerType.click)
        .forEach(onAction);
  }

  void onAction(Reaction reaction) {
    switch (reaction.action.type) {
      case ActionType.link:
        launchUrl(Uri.dataFromString((reaction.action as LinkAction).url));
        break;
      default:
        break;
    }
  }
}

class PassiveRadioWidget extends StatelessWidget with PropertyValueGetterMixin {
  final RadioNode node;
  final List<VariableData> variables;
  final ValueChanged<String?>? onChanged;

  const PassiveRadioWidget({
    super.key,
    required this.node,
    required this.onChanged,
    this.variables = const [],
  });

  @override
  Widget build(BuildContext context) {
    final value = variables.getStringById(node.variables['value'] ?? '',
        defaultValue: node.value);
    final groupValue = getPropertyValue<String>(context, node, 'groupValue') ??
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
          onChanged: onChanged,
          toggleable: node.properties.toggleable,
          splashRadius: node.properties.splashRadius,
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return node.properties.activeColor.toFlutterColor();
            }
            return node.properties.inactiveColor.toFlutterColor();
          }),
        ),
      ),
    );
  }
}
