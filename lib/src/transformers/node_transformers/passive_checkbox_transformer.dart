import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';
import '../utils/node_state_provider.dart';

class PassiveCheckboxTransformer extends NodeWidgetTransformer<CheckboxNode> {
  PassiveCheckboxTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    CheckboxNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(context, node, settings: settings);
  }

  Widget buildFromProps(
    BuildContext context, {
    required CheckboxProperties props,
    required double height,
    required double width,
    bool? value,
    required WidgetBuildSettings settings,
  }) {
    final node = CheckboxNode(
      id: '',
      name: 'Checkbox',
      basicBoxLocal: NodeBox(0, 0, width, height),
      alignment: AlignmentModel.none,
      properties: props,
    )..value = value;
    return buildFromNode(context, node, settings: settings);
  }

  Widget buildPreview({
    CheckboxProperties? properties,
    CheckboxNode? node,
    double? height,
    double? width,
    bool? value,
    ValueChanged<bool?>? onChanged,
    WidgetBuildSettings settings =
        const WidgetBuildSettings(debugLabel: 'buildPreview'),
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
      onChanged: (context, value) => onChanged?.call(value),
      settings: settings,
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
      onChanged: (context, value) => onChanged(context, node, value),
    );
  }

  void onChanged(BuildContext context, CheckboxNode node, bool? internalValue) {
    NodeStateProvider.setState(context, internalValue);
    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'value', value: internalValue);

    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.changed, value: internalValue);
  }
}

class PassiveCheckboxWidget extends StatelessWidget {
  final CheckboxNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final void Function(BuildContext context, bool? value)? onChanged;

  const PassiveCheckboxWidget({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    this.variables = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scale = node.basicBoxLocal.width / (node.properties.compact ? Checkbox.width : kCheckboxDefaultSize);

    final bool? value = PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'value',
          scopedValues: ScopedValues.of(context, variablesOverrides: variables),
        ) ??
        node.value;

    return SizedBox.fromSize(
      size: node.basicBoxLocal.size.flutterSize,
      child: Transform.scale(
        scale: scale,
        child: Checkbox(
          key: ValueKey(
              '${node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}'),
          value: node.properties.tristate ? value : (value ?? false),
          tristate: node.properties.tristate,
          autofocus: node.properties.autofocus,
          checkColor: node.properties.checkColor.toFlutterColor(),
          activeColor: node.properties.activeColor.toFlutterColor(),
          hoverColor: node.properties.hoverColor.toFlutterColor(),
          focusColor: node.properties.focusColor.toFlutterColor(),
          onChanged: (value) => onChanged?.call(context, value),
          visualDensity: VisualDensity.standard,
          splashRadius: node.properties.splashRadius,
          shape: RoundedRectangleBorder(
            borderRadius: node.properties.cornerRadius.borderRadius,
          ),
          side: BorderSide(
            color: node.properties.borderColor.toFlutterColor(),
            width: node.properties.borderWidth,
          ),
        ),
      ),
    );
  }
}
