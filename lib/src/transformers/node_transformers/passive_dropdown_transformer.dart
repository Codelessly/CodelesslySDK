import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveDropdownTransformer extends NodeWidgetTransformer<DropdownNode> {
  PassiveDropdownTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    DropdownNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildDropdownFromNode(context, node, settings);
  }

  Widget buildDropdownFromNode(
    BuildContext context,
    DropdownNode node,
    WidgetBuildSettings settings,
  ) {
    return PassiveDropdownWidget(
      node: node,
      onTap: () => onTap(context, node),
      onChanged: (value) => onChanged(context, node, value),
      settings: settings,
    );
  }

  Widget buildFromProps(
    BuildContext context, {
    required DropdownProperties props,
    required double height,
    required double width,
    bool value = false,
    required WidgetBuildSettings settings,
  }) {
    final node = DropdownNode(
      id: '',
      name: 'Dropdown',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildDropdownFromNode(context, node, settings);
  }

  void onTap(context, DropdownNode node) =>
      FunctionsRepository.triggerAction(context, node: node, TriggerType.click);

  void onChanged(BuildContext context, DropdownNode node, int internalValue) {
    FunctionsRepository.setPropertyValue(context,
        node: node, property: 'value', value: internalValue);

    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.changed, value: internalValue);
  }
}

class PassiveDropdownWidget extends StatelessWidget {
  final DropdownNode node;
  final VoidCallback? onTap;
  final bool useIconFonts;
  final ValueChanged<int>? onChanged;
  final int? initialValue;
  final WidgetBuildSettings settings;

  const PassiveDropdownWidget({
    super.key,
    required this.node,
    this.onTap,
    this.useIconFonts = false,
    this.onChanged,
    this.initialValue,
    required this.settings,
  });

  List<DropdownMenuItem<int>> buildItems(BuildContext context, List items) {
    return [
      for (final (index, value) in items.indexed)
        DropdownMenuItem<int>(
          value: index,
          alignment: node.properties.itemAlignment.flutterAlignmentGeometry ??
              AlignmentDirectional.centerStart,
          child: ChangeNotifierProvider<CodelesslyContext>.value(
            value: context.read<CodelesslyContext>(),
            child: IndexedItemProvider(
              index: index,
              item: value,
              child: Builder(builder: (context) {
                String label = '$value';
                if (node.properties.useDataSource) {
                  String? labelText =
                      PropertyValueDelegate.getPropertyValue<String>(
                          context, node, 'itemLabel');
                  labelText ??= node.properties.itemLabel;
                  label = PropertyValueDelegate.substituteVariables(
                    context,
                    labelText,
                    nullSubstitutionMode: settings.nullSubstitutionMode,
                  );
                }
                return Text(
                  label,
                  style: TextUtils.retrieveTextStyleFromProp(
                    node.properties.itemTextStyle,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ),
          ),
        )
    ];
  }

  List<Widget> selectedItemBuilder(BuildContext context, List items) {
    return [
      for (final (index, value) in items.indexed)
        DropdownMenuItem<int>(
          value: index,
          alignment: node.properties.itemAlignment.flutterAlignmentGeometry ??
              AlignmentDirectional.centerStart,
          child: IndexedItemProvider(
            index: index,
            item: value,
            child: Builder(builder: (context) {
              String label = '$value';
              if (node.properties.useDataSource) {
                String? labelText =
                    PropertyValueDelegate.getPropertyValue<String>(
                        context, node, 'itemLabel');
                labelText ??= node.properties.itemLabel;
                label = PropertyValueDelegate.substituteVariables(
                  context,
                  labelText,
                  nullSubstitutionMode: settings.nullSubstitutionMode,
                );
              }
              return Container(
                constraints: BoxConstraints(
                    maxWidth:
                        node.basicBoxLocal.width - node.properties.iconSize),
                child: Text(
                  label,
                  style: TextUtils.retrieveTextStyleFromProp(
                    node.properties.selectedItemTextStyle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List items = node.properties.useDataSource
        ? PropertyValueDelegate.getPropertyValue<List>(context, node, 'data') ??
            []
        : node.properties.items;

    int? value = PropertyValueDelegate.getPropertyValue<int>(
          context,
          node,
          'value',
        ) ??
        node.value;

    if (value == -1) value = null;

    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    codelesslyContext.conditions;
    return AdaptiveNodeBox(
      node: node,
      child: Theme(
        data: ThemeData(
          hoverColor: node.properties.hoverColor?.toFlutterColor(),
          splashColor: node.properties.splashColor?.toFlutterColor(),
        ),
        child: DropdownButton<int>(
          value: value,
          isDense: node.properties.dense,
          isExpanded: node.properties.expanded,
          autofocus: node.properties.autoFocus,
          enableFeedback: node.properties.enableFeedback,
          alignment:
              node.properties.selectedItemAlignment.flutterAlignmentGeometry ??
                  Alignment.centerLeft,
          hint: node.properties.hint.isNotEmpty
              ? Text(
                  node.properties.hint,
                  style: TextUtils.retrieveTextStyleFromProp(
                    node.properties.hintStyle,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          iconDisabledColor: node.properties.iconDisabledColor.toFlutterColor(),
          iconEnabledColor: node.properties.iconEnabledColor.toFlutterColor(),
          iconSize: node.properties.iconSize,
          icon: retrieveIconWidget(
              node.properties.icon, node.properties.iconSize, useIconFonts),
          dropdownColor: node.properties.dropdownColor.toFlutterColor(),
          focusColor: node.properties.focusColor.toFlutterColor(),
          elevation: node.properties.elevation,
          borderRadius: node.properties.borderRadius.borderRadius,
          onTap: onTap,
          padding: node.padding.flutterEdgeInsets,
          onChanged: node.properties.enabled
              ? (value) => onChanged?.call(value ?? 0)
              : null,
          underline: node.properties.underline ? null : const SizedBox.shrink(),
          items: buildItems(context, items),
          selectedItemBuilder: (context) => selectedItemBuilder(context, items),
        ),
      ),
    );
  }
}
