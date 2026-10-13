import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

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
      return PreviewSegmentedButtonWidget(node: node, settings: settings);
    }
    return PassiveSegmentedButtonWidget(node: node, settings: settings);
  }
}

/// A segmented button whose selection is local state, for previews without
/// a [CodelesslyContext].
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
  late Set<String> selected = widget.node.properties.selected.toSet();

  @override
  Widget build(BuildContext context) {
    return TransformerSegmentedButton(
      node: widget.node,
      settings: widget.settings,
      selected: selected,
      onSelectionChanged: (context, selection) =>
          setState(() => selected = selection),
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

  void onSelectionChanged(BuildContext context, Set<String> selection) {
    final List<String> values = selection.toList();
    NodeStateProvider.setState(context, values);
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'selected',
      value: values,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: values,
    );
  }

  /// Reads a selection from a node value (a list) or a variable (a list or
  /// its string form, such as `["a","b"]` or `[a, b]`).
  static Set<String>? parseSelection(Object? value) {
    switch (value) {
      case null:
        return null;
      case Iterable():
        return {for (final item in value) '$item'};
      case String():
        final String text = value.trim();
        if (text.isEmpty) return {};
        if (text.startsWith('[')) {
          try {
            final Object? decoded = jsonDecode(text);
            if (decoded is List) return {for (final item in decoded) '$item'};
          } on FormatException {
            // Dart's List.toString form, which is not JSON.
          }
          final String inner = text.substring(
            1,
            text.endsWith(']') ? text.length - 1 : text.length,
          );
          return {
            for (final item in inner.split(','))
              if (item.trim().isNotEmpty) item.trim(),
          };
        }
        return {text};
      default:
        return {'$value'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> selected =
        parseSelection(
          PropertyValueDelegate.getPropertyValue<Object>(
            node,
            'selected',
            scopedValues: ScopedValues.of(
              context,
              variablesOverrides: variablesOverrides,
            ),
          ),
        ) ??
        node.properties.selected.toSet();

    return TransformerSegmentedButton(
      node: node,
      settings: settings,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      variablesOverrides: variablesOverrides,
    );
  }
}

class TransformerSegmentedButton extends StatelessWidget {
  final SegmentedButtonNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final void Function(BuildContext context, Set<String> selection)?
  onSelectionChanged;
  final Set<String> selected;

  const TransformerSegmentedButton({
    super.key,
    required this.node,
    required this.settings,
    required this.onSelectionChanged,
    required this.selected,
    this.variablesOverrides = const [],
  });

  @override
  Widget build(BuildContext context) {
    final SegmentedButtonProperties properties = node.properties;
    // SegmentedButton needs at least one segment.
    if (properties.segments.isEmpty) return AdaptiveNodeBox(node: node);

    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );

    final List<ButtonSegment<String>> segments = [
      for (final segment in properties.segments)
        _buildSegment(segment, scopedValues),
    ];

    // Keep the selection within what SegmentedButton accepts, so stale or
    // bound values cannot trip its assertions.
    final Set<String> values = {for (final s in segments) s.value};
    Set<String> selection = selected.where(values.contains).toSet();
    if (!properties.multiSelectionEnabled && selection.length > 1) {
      selection = {selection.first};
    }

    final BorderSide? side =
        properties.borderColor != null || properties.borderWidth != 1
        ? BorderSide(
            color:
                properties.borderColor?.toFlutterColor() ??
                Theme.of(context).colorScheme.outline,
            width: properties.borderWidth,
          )
        : null;

    return AdaptiveNodeBox(
      node: node,
      child: SegmentedButton<String>(
        key: ValueKey(
          '${node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}',
        ),
        segments: segments,
        selected: selection,
        onSelectionChanged: node.enabled && onSelectionChanged != null
            ? (selection) => onSelectionChanged!(context, selection)
            : null,
        multiSelectionEnabled: properties.multiSelectionEnabled,
        // A layout without a selection still renders when one is required.
        emptySelectionAllowed:
            properties.emptySelectionAllowed || selection.isEmpty,
        showSelectedIcon: properties.showSelectedIcon,
        selectedIcon: properties.selectedIcon != null
            ? retrieveIconWidget(properties.selectedIcon!)
            : null,
        direction: properties.direction.flutterAxis,
        style: SegmentedButton.styleFrom(
          backgroundColor: properties.backgroundColor?.toFlutterColor(),
          selectedBackgroundColor: properties.selectedBackgroundColor
              ?.toFlutterColor(),
          foregroundColor: properties.foregroundColor?.toFlutterColor(),
          selectedForegroundColor: properties.selectedForegroundColor
              ?.toFlutterColor(),
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: properties.cornerRadius.borderRadius,
          ),
        ),
      ),
    );
  }

  ButtonSegment<String> _buildSegment(
    ButtonSegmentModel segment,
    ScopedValues scopedValues,
  ) {
    final Widget? icon = segment.icon != null
        ? retrieveIconWidget(segment.icon!)
        : null;
    final String label = PropertyValueDelegate.substituteVariables(
      segment.label,
      scopedValues: scopedValues,
      nullSubstitutionMode: settings.nullSubstitutionMode,
    );
    return ButtonSegment<String>(
      value: segment.value,
      icon: icon,
      // A segment needs a label or an icon.
      label: label.isNotEmpty || icon == null
          ? Text(label.isNotEmpty ? label : segment.value)
          : null,
      tooltip: segment.tooltip?.isNotEmpty == true ? segment.tooltip : null,
      enabled: segment.enabled,
    );
  }
}
