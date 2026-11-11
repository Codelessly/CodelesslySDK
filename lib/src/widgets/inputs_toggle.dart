// A switch drawn as a plain toggle: a pill track
// filling its box with a round thumb that slides between inset gaps from
// its edges, casting the switch's thumb shadows. Material's Switch has no
// thumb shadow, and scaling it to the node makes its thumb smaller and oval.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Node, SwitchProps;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../render/convert.dart';

/// An API easing curve as a Flutter [Curve].
class _ApiCurve extends Curve {
  const _ApiCurve(this.curve);
  final api.AnimationCurve curve;

  /// Flutter's own constant where there is one.
  static Curve of(api.AnimationCurve c) => switch (c) {
        api.AnimationCurve.linear => Curves.linear,
        api.AnimationCurve.easeIn => Curves.easeIn,
        api.AnimationCurve.easeOut => Curves.easeOut,
        api.AnimationCurve.easeInOut => Curves.easeInOut,
        api.AnimationCurve.easeOutBack => Curves.easeOutBack,
        api.AnimationCurve.easeOutCubic => Curves.easeOutCubic,
        api.AnimationCurve.easeInOutCubic => Curves.easeInOutCubic,
        api.AnimationCurve.easeInOutSine => Curves.easeInOutSine,
        api.AnimationCurve.fastOutSlowIn => Curves.fastOutSlowIn,
        api.AnimationCurve.decelerate => Curves.decelerate,
        api.AnimationCurve.elasticOut => Curves.elasticOut,
        api.AnimationCurve.bounceOut => Curves.bounceOut,
        _ => _ApiCurve(c),
      };

  @override
  double transformInternal(double t) => curve.transform(t);
}

/// Whether [n] is drawn as a [PlainToggle]: its track fills the node and it
/// has thumb shadows, a thumb inset or a thumb border.
bool drawsPlainToggle(Node n) =>
    n.prop(SwitchProps.fillTrack) &&
    (n.prop(SwitchProps.thumbShadows).isNotEmpty ||
        n.prop(SwitchProps.thumbInset) != null ||
        n.prop(SwitchProps.activeThumbBorderColor) != null ||
        n.prop(SwitchProps.inactiveThumbBorderColor) != null);

/// The plain toggle of switch [node]. Off, a Material 3 thumb without
/// `uniformThumb` is two thirds of its on size, as Material's is. Colors ease
/// between off and on as the thumb slides (for `toggleDurationMs`, along
/// `toggleCurve`); where tickers are off (a design canvas) it shows the
/// value at once.
class PlainToggle extends StatefulWidget {
  const PlainToggle({
    super.key,
    required this.node,
    required this.value,
    required this.onChanged,
    this.duration,
  });

  final Node node;
  final bool value;

  /// Null disables it.
  final ValueChanged<bool>? onChanged;

  /// The slide's duration; null is the node's `toggleDurationMs`.
  final Duration? duration;

  Duration get _duration => duration ?? Duration(milliseconds: node.prop(SwitchProps.toggleDurationMs));

  /// The thumb's diameter in a box [height] tall, on and off.
  static ({double on, double off}) thumbDiameters(Node n, double height, {required bool material3}) {
    final inset = n.prop(SwitchProps.thumbInset) ?? height * 4 / 32;
    final on = (height - 2 * inset).clamp(0.0, double.infinity);
    final shrinks = material3 && !n.prop(SwitchProps.uniformThumb);
    return (on: on, off: shrinks ? on * 16 / 24 : on);
  }

  @override
  State<PlainToggle> createState() => _PlainToggleState();
}

class _PlainToggleState extends State<PlainToggle> with SingleTickerProviderStateMixin {
  late final AnimationController _position =
      AnimationController(vsync: this, duration: widget._duration, value: widget.value ? 1 : 0);
  late final CurvedAnimation _curved = _initCurve();
  bool _hovered = false, _focused = false;

  CurvedAnimation _initCurve() {
    final a = CurvedAnimation(parent: _position, curve: Curves.linear);
    _setCurve(a);
    return a;
  }

  void _setCurve(CurvedAnimation a) {
    final curve = _ApiCurve.of(widget.node.prop(SwitchProps.toggleCurve));
    a
      ..curve = curve
      ..reverseCurve = curve.flipped;
  }

  @override
  void didUpdateWidget(PlainToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _position.duration = widget._duration;
    _setCurve(_curved);
    if (oldWidget.value == widget.value) return;
    final target = widget.value ? 1.0 : 0.0;
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
    final enabled = widget.onChanged != null;
    final n = widget.node;
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: n.prop(SwitchProps.autofocus),
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _toggle();
            return null;
          }),
        },
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: CustomPaint(
            painter: PlainTogglePainter(
              position: _curved,
              node: n,
              material3: Theme.of(context).useMaterial3,
              textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
              highlight: _focused
                  ? n.prop(SwitchProps.focusColor)?.flutter
                  : _hovered
                      ? n.prop(SwitchProps.hoverColor)?.flutter
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
  PlainTogglePainter({
    required this.position,
    required this.node,
    required this.material3,
    required this.textDirection,
    this.highlight,
  }) : super(repaint: position);

  final Animation<double> position;
  final Node node;
  final bool material3;

  /// Right to left, on is at the left.
  final TextDirection textDirection;

  /// The hover or focus color drawn around the thumb.
  final Color? highlight;

  static const _clear = Color(0x00000000);

  double _inset(Size size) => node.prop(SwitchProps.thumbInset) ?? size.height * 4 / 32;

  /// The thumb's center and radius in a box of [size] at [t] (0 off, 1 on).
  ({Offset center, double radius}) thumbAt(Size size, double t) {
    final inset = _inset(size);
    final d = PlainToggle.thumbDiameters(node, size.height, material3: material3);
    final start = inset + d.on / 2, end = size.width - inset - d.on / 2;
    var x = start + (end - start) * t;
    if (textDirection == TextDirection.rtl) x = size.width - x;
    return (center: Offset(x, size.height / 2), radius: (d.off + (d.on - d.off) * t) / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = position.value.clamp(0.0, 1.0);
    final n = node;
    Color lerp(api.Color? off, api.Color? on) => Color.lerp(off?.flutter ?? _clear, on?.flutter ?? _clear, t)!;
    final track = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide / 2));
    canvas.drawRRect(
        track, Paint()..color = lerp(n.prop(SwitchProps.inactiveTrackColor), n.prop(SwitchProps.activeTrackColor)));
    final border = lerp(n.prop(SwitchProps.inactiveTrackOutlineColor), n.prop(SwitchProps.activeTrackOutlineColor));
    final outline = n.prop(SwitchProps.trackOutlineWidth) ?? 2;
    if (outline > 0 && border.a > 0) {
      canvas.drawRRect(
          track.deflate(outline / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = outline
            ..color = border);
    }
    final (:center, :radius) = thumbAt(size, t);
    if (highlight case final Color color) {
      canvas.drawCircle(center, radius + _inset(size) * 2, Paint()..color = color);
    }
    for (final e in n.prop(SwitchProps.thumbShadows)) {
      if (e.type != api.EffectType.dropShadow || !e.visible) continue;
      final shadow = boxShadow(e);
      canvas.drawCircle(center + shadow.offset, radius + shadow.spreadRadius, shadow.toPaint());
    }
    canvas.drawCircle(
        center, radius, Paint()..color = lerp(n.prop(SwitchProps.inactiveThumbColor), n.prop(SwitchProps.activeThumbColor)));
    // The border inside the thumb's edge, as a BoxDecoration's.
    final ring = lerp(n.prop(SwitchProps.inactiveThumbBorderColor), n.prop(SwitchProps.activeThumbBorderColor));
    final ringWidth = math.min(n.prop(SwitchProps.thumbBorderWidth) ?? 1, radius);
    if (ringWidth > 0 && ring.a > 0) {
      canvas.drawCircle(
          center,
          radius - ringWidth / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringWidth
            ..color = ring);
    }
  }

  @override
  bool shouldRepaint(PlainTogglePainter oldDelegate) =>
      oldDelegate.node != node ||
      oldDelegate.material3 != material3 ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.highlight != highlight ||
      oldDelegate.position != position;
}
