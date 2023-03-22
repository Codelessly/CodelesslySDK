import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveCheckboxTransformer extends NodeWidgetTransformer<CheckboxNode> {
  PassiveCheckboxTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    CheckboxNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(context, node, settings: settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required CheckboxProperties props,
    required double height,
    required double width,
    bool? value,
  }) {
    final node = CheckboxNode(
      id: '',
      name: 'Checkbox',
      basicBoxLocal: NodeBox(0, 0, width, height),
      alignment: AlignmentModel.none,
      properties: props,
    )..value = value;
    return buildFromNode(context, node, settings: WidgetBuildSettings());
  }

  Widget buildPreview({
    CheckboxProperties? properties,
    CheckboxNode? node,
    double? height,
    double? width,
    bool? value,
    ValueChanged<bool?>? onChanged,
  }) {
    final previewNode = CheckboxNode(
      properties: properties ?? node?.properties ?? CheckboxProperties(),
      id: '',
      name: 'Checkbox',
      basicBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
      retainedOuterBoxLocal: NodeBox(0, 0, width ?? 32, height ?? 32),
    );
    previewNode.value = value;
    return PassiveCheckboxWidget(
      node: previewNode,
      onChanged: onChanged,
      settings: WidgetBuildSettings(),
    );
  }

  Widget buildFromNode(
    BuildContext context,
    CheckboxNode node, {
    required WidgetBuildSettings settings,
  }) {
    return PassiveCheckboxWidget(
      node: node,
      settings: settings,
      onChanged: (value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, CheckboxNode node, bool? internalValue) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Change local state of checkbox.
    if (payload.nodeValues.containsKey(node.id)) {
      final List<ValueModel> values = payload.nodeValues[node.id]!.value;
      final ValueModel value = values.firstWhere((val) => val.name == 'value');
      final List<ValueModel> updatedValues = [...values]
        ..remove(value)
        ..add(value.copyWith(value: internalValue));
      // DataUtils.nodeValues[node.id]!.value = updatedValues;
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

class PassiveCheckboxWidget extends StatelessWidget {
  final CheckboxNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final ValueChanged<bool?>? onChanged;

  const PassiveCheckboxWidget({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    this.variables = const [],
  });

  @override
  Widget build(BuildContext context) {
    // bool? value = node.value;
    // if (node.variables['value'] != null) {
    //   value = variables.getBooleanByIdOrNull(node.variables['value']!);
    // }
    final scale = node.basicBoxLocal.width / kCheckboxDefaultSize;

    final bool? value = context.getNodeValue(node.id, 'value') ?? node.value;

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: Transform.scale(
          scale: scale,
          child: Checkbox(
            value: node.properties.tristate ? value : (value ?? false),
            tristate: node.properties.tristate,
            autofocus: node.properties.autofocus,
            checkColor: node.properties.checkColor.toFlutterColor(),
            activeColor: node.properties.activeColor.toFlutterColor(),
            hoverColor: node.properties.hoverColor.toFlutterColor(),
            focusColor: node.properties.focusColor.toFlutterColor(),
            onChanged: onChanged,
            splashRadius: node.properties.splashRadius,
            shape: RoundedRectangleBorder(
              borderRadius: node.properties.cornerRadius.borderRadius,
            ),
            side: BorderSide(
              color: node.properties.borderColor.toFlutterColor(),
              width: node.properties.borderWidth,
            ),
          )),
    );
  }
}
