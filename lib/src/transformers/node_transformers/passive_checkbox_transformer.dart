import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

class PassiveCheckboxTransformer extends NodeWidgetTransformer<CheckboxNode> {
  PassiveCheckboxTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    CheckboxNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    if (settings.isPreview) {
      bool? effectiveValue = node.value;
      return StatefulBuilder(
        builder: (context, setState) => TransformerCheckbox(
          node: node,
          settings: settings,
          onChanged: (context, value) => setState(() {
            effectiveValue = value;
          }),
          value: effectiveValue,
        ),
      );
    } else {
      return PassiveCheckboxWidget(
        node: node,
        settings: settings,
      );
    }
  }
}

class PassiveCheckboxWidget extends StatelessWidget {
  final CheckboxNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;

  const PassiveCheckboxWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variables = const [],
  });

  void onChanged(BuildContext context, bool? internalValue) {
    NodeStateProvider.setState(context, internalValue);

    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'value', value: internalValue);
    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.changed, value: internalValue);
  }

  @override
  Widget build(BuildContext context) {
    final bool? value = PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'value',
          scopedValues: ScopedValues.of(context, variablesOverrides: variables),
        ) ??
        node.value;

    return TransformerCheckbox(
      node: node,
      settings: settings,
      value: value,
      onChanged: onChanged,
      variables: variables,
    );
  }
}

class TransformerCheckbox extends StatefulWidget {
  final CheckboxNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final void Function(BuildContext context, bool? value)? onChanged;
  final bool? value;

  const TransformerCheckbox({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    required this.value,
    this.variables = const [],
  });

  @override
  State<TransformerCheckbox> createState() => _TransformerCheckboxState();
}

class _TransformerCheckboxState extends State<TransformerCheckbox> {
  @override
  Widget build(BuildContext context) {
    final double scale = widget.node.basicBoxLocal.width /
        (widget.node.properties.compact
            ? Checkbox.width
            : kCheckboxDefaultSize);

    return SizedBox.fromSize(
      size: widget.node.basicBoxLocal.size.flutterSize,
      child: Transform.scale(
        scale: scale,
        child: Checkbox(
          key: ValueKey(
              '${widget.node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}'),
          value: widget.node.properties.tristate
              ? widget.value
              : (widget.value ?? false),
          tristate: widget.node.properties.tristate,
          autofocus: widget.node.properties.autofocus,
          checkColor: widget.node.properties.checkColor.toFlutterColor(),
          activeColor: widget.node.properties.activeColor.toFlutterColor(),
          hoverColor: widget.node.properties.hoverColor.toFlutterColor(),
          focusColor: widget.node.properties.focusColor.toFlutterColor(),
          onChanged: (value) => widget.onChanged?.call(context, value),
          visualDensity: VisualDensity.standard,
          splashRadius: widget.node.properties.splashRadius,
          shape: RoundedRectangleBorder(
            borderRadius: widget.node.properties.cornerRadius.borderRadius,
          ),
          side: BorderSide(
            color: widget.node.properties.borderColor.toFlutterColor(),
            width: widget.node.properties.borderWidth,
          ),
        ),
      ),
    );
  }
}
