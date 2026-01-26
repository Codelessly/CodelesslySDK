import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/src/api/nodes/segmented_button_node.dart'
    as api_segmented;
import 'package:flutter/material.dart' hide ButtonSegment;
import 'package:flutter/material.dart' as material;

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

class PassiveSegmentedButtonTransformer
    extends NodeWidgetTransformer<SegmentedButtonNode> {
  PassiveSegmentedButtonTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SegmentedButtonNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    if (settings.isPreview) {
      return PreviewSegmentedButtonWidget(
        node: node,
        settings: settings,
      );
    } else {
      return PassiveSegmentedButtonWidget(
        node: node,
        settings: settings,
      );
    }
  }
}

class PreviewSegmentedButtonWidget extends StatefulWidget {
  const PreviewSegmentedButtonWidget({
    super.key,
    required this.node,
    required this.settings,
  });

  final SegmentedButtonNode node;
  final WidgetBuildSettings settings;

  @override
  State<PreviewSegmentedButtonWidget> createState() =>
      _PreviewSegmentedButtonWidgetState();
}

class _PreviewSegmentedButtonWidgetState
    extends State<PreviewSegmentedButtonWidget> {
  late Set<String> selectedSegments;

  @override
  void initState() {
    super.initState();
    selectedSegments = widget.node.properties.selectedSegments.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return TransformerSegmentedButton(
      node: widget.node,
      settings: widget.settings,
      selectedSegments: selectedSegments,
      onSelectionChanged: (context, newSelection) {
        setState(() {
          selectedSegments = newSelection;
        });
      },
    );
  }
}

class PassiveSegmentedButtonWidget extends StatelessWidget {
  final SegmentedButtonNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  const PassiveSegmentedButtonWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
  });

  void onSelectionChanged(BuildContext context, Set<String> newSelection) {
    final List<String> selectionList = newSelection.toList();
    NodeStateProvider.setState(context, selectionList);

    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'selectedSegments',
      value: selectionList,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: selectionList,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
          node,
          'selected',
          scopedValues: ScopedValues.of(
            context,
            variablesOverrides: variablesOverrides,
          ),
        ) ??
        node.properties.selectedSegments;

    final Set<String> selectedSegments = value is List
        ? value.cast<String>().toSet()
        : (value is Set ? value.cast<String>() : <String>{});

    return TransformerSegmentedButton(
      node: node,
      settings: settings,
      selectedSegments: selectedSegments,
      onSelectionChanged: onSelectionChanged,
      variables: variablesOverrides,
    );
  }
}

class TransformerSegmentedButton extends StatelessWidget {
  final SegmentedButtonNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variables;
  final void Function(BuildContext context, Set<String> selection)?
      onSelectionChanged;
  final Set<String> selectedSegments;

  const TransformerSegmentedButton({
    super.key,
    required this.node,
    required this.settings,
    required this.onSelectionChanged,
    required this.selectedSegments,
    this.variables = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variables,
    );

    final List<material.ButtonSegment<String>> segments =
        node.properties.segments.map((segment) {
      return material.ButtonSegment<String>(
        value: segment.value,
        label: segment.label.isNotEmpty
            ? Text(
                PropertyValueDelegate.substituteVariables(
                  segment.label,
                  scopedValues: scopedValues,
                  nullSubstitutionMode: settings.nullSubstitutionMode,
                ),
              )
            : null,
        icon: segment.icon != null && (segment.icon?.show ?? false)
            ? retrieveIconWidget(
                segment.icon!,
                segment.icon!.size ?? 24,
              )
            : null,
        tooltip: segment.tooltip,
        enabled: segment.enabled,
      );
    }).toList();

    return AdaptiveNodeBox(
      node: node,
      child: SegmentedButton<String>(
        key: ValueKey(
          '${node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}',
        ),
        segments: segments,
        selected: selectedSegments,
        onSelectionChanged: onSelectionChanged != null
            ? (Set<String> newSelection) {
                onSelectionChanged?.call(context, newSelection);
              }
            : null,
        multiSelectionEnabled: node.properties.multiSelectionEnabled,
        emptySelectionAllowed: node.properties.emptySelectionAllowed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return node.properties.selectedColor?.toFlutterColor();
            }
            return node.properties.unselectedColor?.toFlutterColor();
          }),
          side: WidgetStateProperty.all(
            BorderSide(
              color: node.properties.borderColor?.toFlutterColor() ??
                  Theme.of(context).colorScheme.outline,
              width: node.properties.borderWidth,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: node.properties.cornerRadius.borderRadius,
            ),
          ),
        ),
      ),
    );
  }
}
