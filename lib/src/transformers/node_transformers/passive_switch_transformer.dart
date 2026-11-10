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

    // Material's switch can't cast a thumb shadow or take a thumb of
    // another size: a switch that asks for either is a plain toggle.
    if (properties.drawsPlainToggle) {
      return AdaptiveNodeBox(
        node: node,
        child: PlainToggle(
          value: value,
          onChanged: onChanged == null
              ? null
              : (bool value) => onChanged!(context, value),
          properties: properties,
        ),
      );
    }

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

/// A switch drawn as a plain toggle: a pill track filling its box with a
/// round thumb that slides between [SwitchProperties.thumbInset] gaps from
/// its edges, casting [SwitchProperties.thumbShadows]. Used for a switch
/// whose track fills its node ([SwitchProperties.drawsPlainToggle]), the
/// way an app's own `AnimatedContainer` toggle draws, which Material's
/// [Switch] can't (it has no thumb shadow, and scaling it to the node makes
/// its thumb smaller and oval).
///
/// The thumb is the box's height less twice the inset (Material 3's
/// proportions, 4/32 of the height, without one). Off, a Material 3 thumb
/// without [SwitchProperties.uniformThumb] is two thirds of that, as
/// Material's is. Colors ease between off and on as the thumb slides;
/// where tickers are off (the design canvas) it shows the value at once.
class PlainToggle extends StatefulWidget {
  /// Whether the toggle is on.
  final bool value;

  /// Called with the new value when tapped (or activated with the
  /// keyboard); null disables it.
  final ValueChanged<bool>? onChanged;

  /// The switch's colors, inset and thumb shadows.
  final SwitchProperties properties;

  /// How long the thumb takes to slide.
  final Duration duration;

  /// Creates a [PlainToggle].
  const PlainToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.properties,
    this.duration = const Duration(milliseconds: 220),
  });

  /// The thumb's diameter in a box [height] tall, on and off.
  static ({double on, double off}) thumbDiameters(
    SwitchProperties properties,
    double height,
  ) {
    final double inset = properties.thumbInset ?? height * 4 / 32;
    final double on = (height - 2 * inset).clamp(0, double.infinity);
    final bool shrinks = properties.useMaterial3 && !properties.uniformThumb;
    return (on: on, off: shrinks ? on * 16 / 24 : on);
  }

  /// [effects] as the box shadows a thumb casts: the visible drop shadows,
  /// each effect's radius its blur radius.
  static List<BoxShadow> boxShadowsOf(List<Effect> effects) => [
    for (final Effect effect in effects)
      if (effect.type == EffectType.dropShadow && effect.visible)
        BoxShadow(
          color: (effect.color ?? ColorRGBA.black).toFlutterColor(),
          offset: Offset(
            effect.offset?.x.toDouble() ?? 0,
            effect.offset?.y.toDouble() ?? 0,
          ),
          blurRadius: effect.radius,
          spreadRadius: effect.spread ?? 0,
        ),
  ];

  @override
  State<PlainToggle> createState() => _PlainToggleState();
}

class _PlainToggleState extends State<PlainToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.value ? 1 : 0,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _position,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic.flipped,
  );
  bool _hovered = false;
  bool _focused = false;

  @override
  void didUpdateWidget(PlainToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _position.duration = widget.duration;
    if (oldWidget.value == widget.value) return;
    final double target = widget.value ? 1 : 0;
    if (TickerMode.valuesOf(context).enabled) {
      _position.animateTo(target);
    } else {
      _position.value = target;
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _position.dispose();
    super.dispose();
  }

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onChanged != null;
    final SwitchProperties p = widget.properties;
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: p.autofocus,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        onShowHoverHighlight: (bool value) =>
            setState(() => _hovered = value),
        onShowFocusHighlight: (bool value) =>
            setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: CustomPaint(
            painter: PlainTogglePainter(
              position: _curved,
              properties: p,
              textDirection: Directionality.maybeOf(context) ??
                  TextDirection.ltr,
              highlight: _focused
                  ? p.focusColor.toFlutterColor()
                  : _hovered
                  ? p.hoverColor.toFlutterColor()
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Paints a [PlainToggle] at [position] (0 off, 1 on).
class PlainTogglePainter extends CustomPainter {
  /// Where the thumb is, 0 off to 1 on.
  final Animation<double> position;

  /// The switch's colors, inset and thumb shadows.
  final SwitchProperties properties;

  /// Right to left, on is at the left.
  final TextDirection textDirection;

  /// The hover or focus color drawn around the thumb, if any.
  final Color? highlight;

  /// Creates a [PlainTogglePainter].
  PlainTogglePainter({
    required this.position,
    required this.properties,
    required this.textDirection,
    this.highlight,
  }) : super(repaint: position);

  /// The thumb's center and radius in a box of [size] at [t] (0 off, 1 on).
  ({Offset center, double radius}) thumbAt(Size size, double t) {
    final double inset = properties.thumbInset ?? size.height * 4 / 32;
    final ({double on, double off}) d = PlainToggle.thumbDiameters(
      properties,
      size.height,
    );
    final double start = inset + d.on / 2;
    final double end = size.width - inset - d.on / 2;
    double x = start + (end - start) * t;
    if (textDirection == TextDirection.rtl) x = size.width - x;
    return (
      center: Offset(x, size.height / 2),
      radius: (d.off + (d.on - d.off) * t) / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = position.value.clamp(0.0, 1.0);
    final SwitchProperties p = properties;
    final RRect track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide / 2),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = Color.lerp(
          p.inactiveTrackColor.toFlutterColor(),
          p.activeTrackColor.toFlutterColor(),
          t,
        )!,
    );
    final Color border = Color.lerp(
      p.inactiveTrackBorderColor?.toFlutterColor() ?? const Color(0x00000000),
      p.activeTrackBorderColor?.toFlutterColor() ?? const Color(0x00000000),
      t,
    )!;
    if (p.trackOutlineWidth > 0 && border.a > 0) {
      canvas.drawRRect(
        track.deflate(p.trackOutlineWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.trackOutlineWidth
          ..color = border,
      );
    }

    final (:Offset center, :double radius) = thumbAt(size, t);
    if (highlight case final Color color?) {
      canvas.drawCircle(
        center,
        radius + (properties.thumbInset ?? size.height * 4 / 32) * 2,
        Paint()..color = color,
      );
    }
    for (final BoxShadow shadow in PlainToggle.boxShadowsOf(p.thumbShadows)) {
      canvas.drawCircle(
        center + shadow.offset,
        radius + shadow.spreadRadius,
        shadow.toPaint(),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Color.lerp(
          p.inactiveThumbColor.toFlutterColor(),
          p.activeThumbColor.toFlutterColor(),
          t,
        )!,
    );
  }

  @override
  bool shouldRepaint(PlainTogglePainter oldDelegate) =>
      oldDelegate.properties != properties ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.highlight != highlight ||
      oldDelegate.position != position;
}
