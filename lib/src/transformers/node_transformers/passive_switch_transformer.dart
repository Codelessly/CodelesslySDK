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
      return PreviewSwitchWidget(node: node, settings: settings);
    } else {
      return PassiveSwitchWidget(node: node, settings: settings);
    }
  }
}

class PreviewSwitchWidget extends StatefulWidget {
  const PreviewSwitchWidget({
    super.key,
    required this.node,
    required this.settings,
  });

  final SwitchNode node;
  final WidgetBuildSettings settings;

  @override
  State<PreviewSwitchWidget> createState() => _PreviewSwitchWidgetState();
}

class _PreviewSwitchWidgetState extends State<PreviewSwitchWidget> {
  /// The value the switch was toggled to in this preview, or null to show
  /// the node's own value (its `value` binding, else [SwitchNode.value]).
  bool? toggledValue;

  @override
  void didUpdateWidget(covariant PreviewSwitchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new value given to the node (e.g. inserted on) shows again.
    if (oldWidget.node.value != widget.node.value) toggledValue = null;
  }

  @override
  Widget build(BuildContext context) {
    final bool value =
        toggledValue ??
        PropertyValueDelegate.getPropertyValue<bool>(
          widget.node,
          'value',
          scopedValues: ScopedValues.of(context),
        ) ??
        widget.node.value;
    return TransformerSwitch(
      node: widget.node,
      settings: widget.settings,
      onChanged: (context, value) => setState(() {
        toggledValue = value;
      }),
      value: value,
    );
  }
}

class PassiveSwitchWidget extends StatelessWidget {
  final SwitchNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// The values the switch's bindings read; by default the ones in scope
  /// where it builds. A design canvas passes its variable defaults.
  final ScopedValues? scopedValues;

  const PassiveSwitchWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.scopedValues,
  });

  void onChanged(BuildContext context, bool internalValue) {
    NodeStateProvider.setState(context, internalValue);

    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'value',
      value: internalValue,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: internalValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues =
        this.scopedValues ??
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final bool value =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'value',
          scopedValues: scopedValues,
        ) ??
        node.value;

    return TransformerSwitch(
      node: node,
      settings: settings,
      variablesOverrides: variablesOverrides,
      scopedValues: scopedValues,
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

  /// The values the switch's color bindings read; by default the ones in
  /// scope where it builds.
  final ScopedValues? scopedValues;

  const TransformerSwitch({
    super.key,
    required this.node,
    required this.settings,
    required this.onChanged,
    required this.value,
    this.variablesOverrides = const [],
    this.scopedValues,
  });

  /// [node]'s switch properties with the colors their bindings give them
  /// (`activeTrackColor`, `inactiveTrackColor`, `activeThumbColor`,
  /// `inactiveThumbColor`, `activeTrackBorderColor` and
  /// `inactiveTrackBorderColor` in [SwitchNode.variables], e.g.
  /// `${pal.ink}` or `${= on ? '#1F2B2E' : '#D9D2C3'}`), evaluated with
  /// [scopedValues]; a plain hex colour there is used as it is. A binding
  /// that is missing or isn't a color keeps the node's own color.
  static SwitchProperties resolvedProperties(
    SwitchNode node,
    ScopedValues scopedValues,
  ) {
    ColorRGBA? color(String property) => switch (node.variables[property]) {
      null => null,
      // A plain colour ("#C9A227") given where a binding goes.
      final String raw when !raw.contains(r'${') => ColorRGBA.fromHex(raw),
      _ => PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        node,
        property,
        scopedValues: scopedValues,
      ),
    };
    return node.properties.copyWith(
      activeTrackColor: color('activeTrackColor'),
      inactiveTrackColor: color('inactiveTrackColor'),
      activeThumbColor: color('activeThumbColor'),
      inactiveThumbColor: color('inactiveThumbColor'),
      activeTrackBorderColor: color('activeTrackBorderColor'),
      inactiveTrackBorderColor: color('inactiveTrackBorderColor'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = node.basicBoxLocal.width / kSwitchDefaultWidth;
    final SwitchProperties properties = resolvedProperties(
      node,
      scopedValues ??
          ScopedValues.of(context, variablesOverrides: variablesOverrides),
    );

    return AdaptiveNodeBox(
      node: node,
      child: Transform.scale(
        scale: scale,
        child: Theme(
          data: Theme.of(context).copyWith(),
          child: Switch(
            // Its toggle animates the thumb and the track colours; where
            // tickers are off (the design canvas, its captures) it could
            // never move, so a new switch shows the current value.
            key: TickerMode.valuesOf(context).enabled
                ? null
                : ValueKey<bool>(value),
            value: value,
            onChanged: (value) => onChanged?.call(context, value),
            autofocus: properties.autofocus,
            activeTrackColor: properties.activeTrackColor.toFlutterColor(),
            inactiveTrackColor: properties.inactiveTrackColor
                .toFlutterColor(),
            activeThumbColor: properties.activeThumbColor.toFlutterColor(),
            inactiveThumbColor: properties.inactiveThumbColor
                .toFlutterColor(),
            hoverColor: properties.hoverColor.toFlutterColor(),
            focusColor: properties.focusColor.toFlutterColor(),
            splashRadius: properties.splashRadius,
            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return properties.activeTrackBorderColor?.toFlutterColor();
              }
              return properties.inactiveTrackBorderColor?.toFlutterColor();
            }),
            trackOutlineWidth: WidgetStateProperty.all(
              properties.trackOutlineWidth,
            ),
          ),
        ),
      ),
    );
  }
}
