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

/// A design-time switch: shows its bound value (or its own), and
/// can be toggled locally until that value changes.
class _PreviewSwitchWidgetState extends State<PreviewSwitchWidget> {
  bool? toggled;
  bool? toggledFrom;

  @override
  Widget build(BuildContext context) {
    final bool bound =
        PropertyValueDelegate.getPropertyValue<bool>(
          widget.node,
          'value',
          scopedValues: ScopedValues.of(context),
        ) ??
        widget.node.value;
    if (toggled != null && bound != toggledFrom) toggled = null;
    final bool effectiveValue = toggled ?? bound;
    return TransformerSwitch(
      node: widget.node,
      settings: widget.settings,
      onChanged: (context, value) => setState(() {
        toggled = value;
        toggledFrom = bound;
      }),
      value: effectiveValue,
    );
  }
}

class PassiveSwitchWidget extends StatelessWidget {
  final SwitchNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// The values bindings read instead of the build context's, such as the
  /// variable defaults a design canvas shows.
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

  /// The thumb icon of a switch with [SwitchProperties.uniformThumb]: an
  /// empty icon in every state, which makes a Material 3 thumb as large off
  /// as on (a thumb with an icon always takes the full size), without
  /// drawing anything on it. Null otherwise: the off thumb is smaller.
  static WidgetStateProperty<Icon?>? thumbIconOf(SwitchProperties properties) =>
      properties.uniformThumb
      ? const WidgetStatePropertyAll<Icon?>(Icon(null))
      : null;

  /// The size of the track a [Switch] draws under [theme]: 52×32 in
  /// Material 3, 33×14 in Material 2.
  static Size trackSizeOf(ThemeData theme) =>
      theme.useMaterial3 ? const Size(52, 32) : const Size(33, 14);

  @override
  Widget build(BuildContext context) {
    final SwitchProperties properties = resolvedProperties(
      node,
      scopedValues ??
          ScopedValues.of(context, variablesOverrides: variablesOverrides),
    );
    final bool fillTrack = properties.fillTrack;

    final Widget toggle = Theme(
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
        inactiveTrackColor: properties.inactiveTrackColor.toFlutterColor(),
        activeThumbColor: properties.activeThumbColor.toFlutterColor(),
        inactiveThumbColor: properties.inactiveThumbColor.toFlutterColor(),
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
        thumbIcon: thumbIconOf(properties),
        // A track that fills the node has no margin around it: no padding
        // and no tap target height beyond the switch's own.
        padding: fillTrack ? EdgeInsets.zero : null,
        materialTapTargetSize: fillTrack
            ? MaterialTapTargetSize.shrinkWrap
            : null,
      ),
    );

    if (fillTrack) {
      // The switch, now as wide as its track and centring it vertically in
      // its collapsed height, is cut to the track's box (its thumb, hover
      // and focus rings still paint past it) and that box is stretched to
      // the node's bounds.
      return AdaptiveNodeBox(
        node: node,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox.fromSize(
            size: trackSizeOf(Theme.of(context)),
            child: OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: toggle,
            ),
          ),
        ),
      );
    }

    final scale = node.basicBoxLocal.width / kSwitchDefaultWidth;
    return AdaptiveNodeBox(
      node: node,
      child: Transform.scale(scale: scale, child: toggle),
    );
  }
}
