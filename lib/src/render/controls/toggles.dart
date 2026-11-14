// The toggles as render objects: `checkbox`, `switch` and `radio` (with the
// `radioGroup` behavior around radios), with no Material widget in their
// path. Unstyled, each is SSUI's control (design_systems/ssui:
// SoftSaaSCheckbox, SoftSaaSSwitch, SoftSaaSRadio):
//
// | Type | Hugging size | Off | On |
// |---|---|---|---|
// | checkbox | 16 × 16, radius 4 | primaryBackground, 1 px secondaryBorder (tertiaryText hovered) | primary, white check |
// | radio | 16 × 16 | primaryBackground, 1 px secondaryBorder (tertiaryText hovered) | primary, white dot (8) |
// | switch | 36 × 20, pill | secondaryBorder track (tertiaryText hovered) | primary track; white thumb, 2 px inset |
//
// A node with a size of its own keeps the proportions the Material islands
// drew at: a checkbox's box is 18/40 of its node (all of it when
// `compact`), a radio's ring 18/32 (all of it when `compact`), a switch's
// track 52/59 of its width (all of the node with `fillTrack`). Changes ease
// over SSUI's `durations.control` on the tree's ticker (a switch's
// `toggleDurationMs` and `toggleCurve` when it sets them); disabled is 50 %
// opacity; keyboard focus is SSUI's ring. Every colour, side, radius and
// thumb prop of the old islands still applies over these.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show CheckboxProps, Node, RadioProps, SwitchProps;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, fireTrigger;
import '../recipe.dart';
import 'kit.dart';
import 'kit_toggles.dart';
import 'tokens.dart';

/// The kinds of toggle.
enum ToggleKind { checkbox, switchToggle, radio }

/// The recipe of `checkbox` (lib/src/widgets/controls.dart registers it).
void checkboxRecipe(NodeBuilder b, Node n, List<RenderBox> chain) => _toggleRecipe(b, n, chain, ToggleKind.checkbox);

/// The recipe of `switch`.
void switchRecipe(NodeBuilder b, Node n, List<RenderBox> chain) => _toggleRecipe(b, n, chain, ToggleKind.switchToggle);

/// The recipe of `radio`.
void radioRecipe(NodeBuilder b, Node n, List<RenderBox> chain) => _toggleRecipe(b, n, chain, ToggleKind.radio);

void _toggleRecipe(NodeBuilder b, Node n, List<RenderBox> chain, ToggleKind kind) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final group = kind == ToggleKind.radio ? _radioGroupOf(b) : null;
  final box = b.obtain<RenderToggle>('toggle', RenderToggle.new)
    ..interactive = interactive
    ..configure(kind, n, ControlTokens.of(b), Size(l.width.value, l.height.value))
    ..group = group?.key
    ..onChanged = interactive
        ? (value) {
            fireTrigger(b, 'changed', event: {'value': value});
            // Flutter's RadioGroup.onChanged: the group node's reactions.
            if (group?.box case final NodeBuilder g) fireTrigger(g, 'changed', event: {'value': value});
          }
        : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  final enabled = kind != ToggleKind.switchToggle || n.prop(SwitchProps.enabled);
  box.enabled = enabled && !states.contains(api.WidgetState.disabled);
  box.autofocus = interactive &&
      switch (kind) {
        ToggleKind.checkbox => n.prop(CheckboxProps.autofocus),
        ToggleKind.switchToggle => n.prop(SwitchProps.autofocus),
        ToggleKind.radio => n.prop(RadioProps.autofocus),
      };
  chain.add(box);
  // A touch lands on it in a 44 × 44 target around it (hit testing only).
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!box.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

/// The `radioGroup` node a radio is in: who shares its arrow keys, and the
/// box whose `changed` reactions a choice runs.
({Object key, NodeBuilder? box})? _radioGroupOf(NodeBuilder b) {
  for (var id = b.source.parentOf(b.id); id != null; id = b.source.parentOf(id)) {
    if (b.source.node(id)?.behaviors.radioGroup == null) continue;
    final box = b.tree.boxOf(id, instance: b.instance) ?? b.tree.boxesOf(id).firstOrNull;
    return (key: (b.tree, id, b.instance), box: box);
  }
  return null;
}

/// A checkbox, a switch or a radio: its value, its look in its states, the
/// keyboard and screen readers.
class RenderToggle extends RenderControl {
  RenderToggle() {
    onPressed = _toggle;
    focusNode.onKey = _key;
  }

  late final ControlEase _on = ControlEase(this);

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app); a design canvas
  /// draws it at rest.
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
    markNeedsPaint();
  }

  ToggleKind _kind = ToggleKind.checkbox;
  ToggleKind get kind => _kind;

  Node? _node;
  late ControlTokens _tokens;
  Size _design = Size.zero;
  bool _configured = false;

  /// The node it draws, the tokens it draws with and its design size.
  void configure(ToggleKind kind, Node n, ControlTokens tokens, Size design) {
    final changed = kind != _kind || n != _node || design != _design || !_sameTokens(tokens);
    _kind = kind;
    _node = n;
    _tokens = tokens;
    _design = design;
    _on
      ..duration = Duration(
          milliseconds: kind == ToggleKind.switchToggle && n.props.has(SwitchProps.toggleDurationMs)
              ? n.prop(SwitchProps.toggleDurationMs)
              : tokens.controlMs)
      ..curve = kind == ToggleKind.switchToggle && n.props.has(SwitchProps.toggleCurve)
          ? n.prop(SwitchProps.toggleCurve)
          : api.AnimationCurve.easeOut;
    _follow(_boundValue(n));
    if (changed) {
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    }
  }

  bool _sameTokens(ControlTokens t) =>
      _configured && t.theme == _tokens.theme && t.dark == _tokens.dark && t.backdrop == _tokens.backdrop;

  Node get node => _node!;
  ControlTokens get tokens => _tokens;

  /// The value the node gives (a radio: its group's value).
  Object? _boundValue(Node n) => switch (_kind) {
        ToggleKind.checkbox => n.prop(CheckboxProps.value),
        ToggleKind.switchToggle => n.prop(SwitchProps.value),
        ToggleKind.radio => n.prop(RadioProps.groupValue),
      };

  Object? _bound;
  Object? _value;

  /// What it shows: a checkbox's `bool?`, a switch's `bool`, a radio's
  /// group value.
  Object? get value => _value;

  /// A new bound value shows (as a widget's `didUpdateWidget` adopts it); an
  /// unchanged one keeps what the user chose since.
  void _follow(Object? bound) {
    final controlled = _kind == ToggleKind.switchToggle && node.prop(SwitchProps.controlled);
    if (_configured && bound == _bound && !controlled) return;
    final first = !_configured;
    _configured = true;
    _bound = bound;
    if (bound == _value && !first) return;
    _value = bound;
    _on.animateTo(_progress, animate: !first && _interactive);
    markNeedsSemanticsUpdate();
  }

  /// Checked (a checkbox's `true` or mixed, a switch on, a radio chosen).
  bool get checked => switch (_kind) {
        ToggleKind.checkbox => _value != false,
        ToggleKind.switchToggle => _value == true,
        ToggleKind.radio => _value == node.prop(RadioProps.value),
      };

  /// A tristate checkbox in its mixed state.
  bool get mixed => _kind == ToggleKind.checkbox && node.prop(CheckboxProps.tristate) && _value == null;

  double get _progress => checked ? 1 : 0;

  /// How far it is from off (0) to on (1) now.
  double get position => _on.value;

  /// Reports a new value (the node's `changed`); null when not interactive.
  void Function(Object? value)? onChanged;

  /// A tap, Enter or Space.
  void _toggle() {
    if (!_interactive) return;
    switch (_kind) {
      case ToggleKind.checkbox:
        final tristate = node.prop(CheckboxProps.tristate);
        // Flutter's order: false, true, then (tristate) null.
        final next = switch (_value) {
          false => true,
          true => tristate ? null : false,
          _ => false,
        };
        _set(next);
      case ToggleKind.switchToggle:
        final next = _value != true;
        // A controlled switch shows only its value: its reactions set it.
        if (node.prop(SwitchProps.controlled)) {
          onChanged?.call(next);
          return;
        }
        _set(next);
      case ToggleKind.radio:
        _choose();
    }
  }

  void _set(Object? v) {
    _value = v;
    _on.animateTo(_progress, animate: true);
    markNeedsSemanticsUpdate();
    onChanged?.call(v);
  }

  /// Chooses this radio (a toggleable one already chosen lets go).
  void _choose() {
    final own = node.prop(RadioProps.value);
    if (_value == own) {
      if (node.prop(RadioProps.toggleable)) _set(null);
      return;
    }
    _set(own);
  }

  // --- radio groups -------------------------------------------------------------

  /// The radio group it is in (radios of one group share arrow keys).
  Object? group;

  static final Set<RenderToggle> _radios = {};

  /// Flutter's RadioGroup keys: right and down choose the next radio of the
  /// group in reading order, left and up the previous, wrapping; the focus
  /// moves with the choice.
  bool _key(KeyEvent event) {
    if (_kind != ToggleKind.radio || group == null) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    final forward = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown
        ? true
        : key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp
            ? false
            : null;
    if (forward == null) return false;
    Offset at(RenderToggle r) => r.localToGlobal(Offset.zero);
    final peers = [
      for (final r in _radios)
        if (r.attached && r.hasSize && r.enabled && r.group == group) r,
    ]..sort((a, b) {
        final p = at(a), q = at(b);
        return (p.dy - q.dy).abs() > 0.5 ? p.dy.compareTo(q.dy) : p.dx.compareTo(q.dx);
      });
    if (peers.length < 2 || !peers.contains(this)) return false;
    final next = peers[(peers.indexOf(this) + (forward ? 1 : -1)) % peers.length];
    next._choose();
    next.focusNode.requestFocus();
    return true;
  }

  // --- pointer ---------------------------------------------------------------------

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (_interactive) super.handleEvent(event, entry);
  }

  @override
  MouseCursor get cursor => _interactive ? super.cursor : MouseCursor.defer;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (!_interactive) focusNode.leave();
    _radios.add(this);
  }

  @override
  void detach() {
    _radios.remove(this);
    _on.detach();
    super.detach();
  }

  // --- geometry -----------------------------------------------------------------

  /// Its size when it hugs: its design size, else SSUI's.
  Size get _natural {
    final ssui = switch (_kind) {
      ToggleKind.switchToggle => const Size(36, 20),
      _ => const Size(16, 16),
    };
    return Size(_design.width > 0 ? _design.width : ssui.width, _design.height > 0 ? _design.height : ssui.height);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _natural.width;
  @override
  double computeMaxIntrinsicWidth(double height) => _natural.width;
  @override
  double computeMinIntrinsicHeight(double width) => _natural.height;
  @override
  double computeMaxIntrinsicHeight(double width) => _natural.height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(_natural);

  @override
  void performLayout() => size = constraints.constrain(_natural);

  /// Where the mark is: a checkbox's box, a radio's ring, a switch's track.
  Rect get markRect {
    final box = Offset.zero & size;
    final n = node;
    switch (_kind) {
      case ToggleKind.checkbox:
        final hug = _design.width <= 0 || _design.height <= 0;
        final side = hug || n.prop(CheckboxProps.compact) ? size.shortestSide : size.shortestSide * 18 / 40;
        return Rect.fromCenter(center: box.center, width: side, height: side);
      case ToggleKind.radio:
        final hug = _design.width <= 0 || _design.height <= 0;
        final side = hug || n.prop(RadioProps.compact) ? size.shortestSide : size.shortestSide * 18 / 32;
        return Rect.fromCenter(center: box.center, width: side, height: side);
      case ToggleKind.switchToggle:
        if (n.prop(SwitchProps.fillTrack) || _design.width <= 0 || _design.height <= 0) return box;
        // SSUI's 36 × 20 track at Material's share of the node's width.
        var w = size.width * 52 / 59, h = w * 20 / 36;
        if (h > size.height) {
          h = size.height;
          w = h * 36 / 20;
        }
        return Rect.fromCenter(center: box.center, width: w, height: h);
    }
  }

  // --- look -----------------------------------------------------------------------

  Color? _c(api.Color? c) => c?.flutter;

  /// A switch's track colour now (off to on as its thumb slides).
  Color get trackColor {
    final n = node, t = _tokens;
    final off = _c(n.prop(SwitchProps.inactiveTrackColor)) ?? (hovered ? t.tertiaryText : t.secondaryBorder);
    final on = _c(n.prop(SwitchProps.activeTrackColor)) ?? t.primary;
    return lerpColor(off, on, position);
  }

  /// A switch's thumb: its centre and radius in the box.
  ({Offset centre, double radius}) get thumb {
    final track = markRect;
    final inset = node.prop(SwitchProps.thumbInset) ?? track.height / 10;
    final d = math.max(0.0, track.height - 2 * inset);
    final start = track.left + inset + d / 2, end = track.right - inset - d / 2;
    return (centre: Offset(start + (end - start) * position, track.center.dy), radius: d / 2);
  }

  /// A checkbox's or radio's fill now.
  Color get markFill {
    final n = node, t = _tokens;
    if (_kind == ToggleKind.checkbox) {
      return lerpColor(_c(n.prop(CheckboxProps.fillColor)) ?? t.primaryBackground,
          _c(n.prop(CheckboxProps.activeColor)) ?? t.primary, position);
    }
    return lerpColor(_c(n.prop(RadioProps.backgroundColor)) ?? t.primaryBackground,
        _c(n.prop(RadioProps.activeColor)) ?? t.primary, position);
  }

  /// A checkbox's or radio's outline now (null: none).
  BorderSide? get markSide {
    final n = node, t = _tokens;
    final rest = BorderSide(color: hovered ? t.tertiaryText : t.secondaryBorder);
    if (_kind == ToggleKind.checkbox) {
      final off = switch (n.prop(CheckboxProps.side)) { final s? => borderSideOf(s), null => rest };
      final on = switch (n.prop(CheckboxProps.activeSide)) { final s? => borderSideOf(s), null => null };
      if (position >= 1) return on;
      if (on != null && position > 0) return BorderSide.lerp(off, on, position);
      return position <= 0 ? off : off.copyWith(color: off.color.withValues(alpha: off.color.a * (1 - position)));
    }
    final side = n.prop(RadioProps.side);
    final inactive = _c(n.prop(RadioProps.inactiveColor));
    final off = side != null
        ? borderSideOf(side)
        : inactive != null
            ? rest.copyWith(color: inactive)
            : rest;
    return position >= 1 ? null : off.copyWith(color: off.color.withValues(alpha: off.color.a * (1 - position)));
  }

  /// The checkbox's corner radius.
  double get _boxRadius {
    final r = node.prop(CheckboxProps.borderRadius);
    if (r != null) return r.topLeft;
    return markRect.width / 4;
  }

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// The alpha it was last painted at (255; disabled 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      _opacity.layer = context.pushOpacity(offset, 128, _paintToggle, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintToggle(context, offset);
  }

  void _paintToggle(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    switch (_kind) {
      case ToggleKind.checkbox:
        _paintCheckbox(canvas);
      case ToggleKind.radio:
        _paintRadio(canvas);
      case ToggleKind.switchToggle:
        _paintSwitch(canvas);
    }
    canvas.restore();
  }

  /// A hover or focus colour of the node's own: a halo behind the mark
  /// (Material's reaction circle), [radius] across.
  void _halo(Canvas canvas, Offset centre, double radius, api.Color? hover, api.Color? focus) {
    final c = focusHighlight && focus != null
        ? focus.flutter
        : hovered && hover != null
            ? hover.flutter
            : null;
    if (c != null && c.a > 0) canvas.drawCircle(centre, radius, Paint()..color = c);
  }

  void _paintCheckbox(Canvas canvas) {
    final n = node;
    final rect = markRect;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(math.min(_boxRadius, rect.width / 2)));
    final splash = n.prop(CheckboxProps.splashRadius) ?? 20;
    _halo(canvas, rect.center, splash * rect.width / 18, n.prop(CheckboxProps.hoverColor), n.prop(CheckboxProps.focusColor));
    canvas.drawRRect(shape, Paint()..color = markFill);
    if (markSide case final BorderSide side when side.width > 0 && side.color.a > 0 && side.style != BorderStyle.none) {
      canvas.drawRRect(
          shape.deflate(side.width / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = side.width
            ..color = side.color);
    }
    if (position > 0) {
      final ink = _c(n.prop(CheckboxProps.checkColor)) ?? _tokens.onAccent;
      // SSUI: an 11 px check in a 16 px box.
      paintCheckMark(canvas, rect.center, rect.width * 11 / 16, ink.withValues(alpha: ink.a * position),
          indeterminate: mixed);
    }
    if (focusHighlight && n.prop(CheckboxProps.focusColor) == null) paintFocusRingAround(canvas, shape, _tokens.focusBorder);
  }

  void _paintRadio(Canvas canvas) {
    final n = node;
    final rect = markRect;
    final r = rect.width / 2;
    final splash = n.prop(RadioProps.splashRadius) ?? 20;
    _halo(canvas, rect.center, splash * rect.width / 18, n.prop(RadioProps.hoverColor), n.prop(RadioProps.focusColor));
    canvas.drawCircle(rect.center, r, Paint()..color = markFill);
    if (markSide case final BorderSide side when side.width > 0 && side.color.a > 0 && side.style != BorderStyle.none) {
      canvas.drawCircle(
          rect.center,
          r - side.width / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = side.width
            ..color = side.color);
    }
    if (position > 0) {
      // SSUI: a white dot 8 px less than the ring; Flutter's innerRadius
      // (of an 18 px ring) when the node sets one.
      final inner = n.prop(RadioProps.innerRadius);
      final dot = inner != null ? inner * rect.width / 18 : math.max(0.0, r - 4 * rect.width / 16);
      canvas.drawCircle(rect.center, dot * position, Paint()..color = _tokens.onAccent);
    }
    if (focusHighlight && n.prop(RadioProps.focusColor) == null) {
      paintFocusRingAround(canvas, RRect.fromRectAndRadius(rect, Radius.circular(r)), _tokens.focusBorder);
    }
  }

  void _paintSwitch(Canvas canvas) {
    final n = node;
    final track = markRect;
    final t = position;
    final trackRadius = (n.prop(SwitchProps.trackRadius) ?? track.shortestSide / 2).clamp(0.0, track.shortestSide / 2);
    final shape = RRect.fromRectAndRadius(track, Radius.circular(trackRadius));
    canvas.drawRRect(shape, Paint()..color = trackColor);
    final outline =
        lerpColor(_c(n.prop(SwitchProps.inactiveTrackOutlineColor)), _c(n.prop(SwitchProps.activeTrackOutlineColor)), t);
    final outlineWidth = n.prop(SwitchProps.trackOutlineWidth) ?? 2;
    if (outlineWidth > 0 && outline.a > 0) {
      canvas.drawRRect(
          shape.deflate(outlineWidth / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = outlineWidth
            ..color = outline);
    }
    final (:centre, :radius) = thumb;
    final inset = n.prop(SwitchProps.thumbInset) ?? track.height / 10;
    // A thumb radius makes it a rounded square; none keeps it round.
    final corner = n.prop(SwitchProps.thumbRadius);
    void drawThumb(Offset c, double r, Paint paint) => corner == null
        ? canvas.drawCircle(c, r, paint)
        : canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r), Radius.circular(corner.clamp(0, r))), paint);
    final hover = n.prop(SwitchProps.hoverColor), focus = n.prop(SwitchProps.focusColor);
    final halo = focusHighlight && focus != null
        ? focus.flutter
        : hovered && hover != null
            ? hover.flutter
            : null;
    if (halo != null && halo.a > 0) drawThumb(centre, radius + inset * 2, Paint()..color = halo);
    // Shadows only when the node casts them: SSUI's thumb has none.
    for (final e in n.prop(SwitchProps.thumbShadows)) {
      if (e.type != api.EffectType.dropShadow || !e.visible) continue;
      final shadow = boxShadow(e);
      drawThumb(centre + shadow.offset, radius + shadow.spreadRadius, shadow.toPaint());
    }
    final thumbColor = lerpColor(_c(n.prop(SwitchProps.inactiveThumbColor)) ?? _tokens.onAccent,
        _c(n.prop(SwitchProps.activeThumbColor)) ?? _tokens.onAccent, t);
    drawThumb(centre, radius, Paint()..color = thumbColor);
    final ring =
        lerpColor(_c(n.prop(SwitchProps.inactiveThumbBorderColor)), _c(n.prop(SwitchProps.activeThumbBorderColor)), t);
    final ringWidth = math.min(n.prop(SwitchProps.thumbBorderWidth) ?? 1, radius);
    if (ringWidth > 0 && ring.a > 0) {
      drawThumb(
          centre,
          radius - ringWidth / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringWidth
            ..color = ring);
    }
    if (focusHighlight && focus == null) paintFocusRingAround(canvas, shape, _tokens.focusBorder);
  }

  // --- semantics -----------------------------------------------------------------

  @override
  String get semanticsName => '';

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    switch (_kind) {
      case ToggleKind.checkbox:
        if (mixed) {
          config
            ..isChecked = false
            ..isCheckStateMixed = true;
        } else {
          config.isChecked = _value == true;
        }
      case ToggleKind.switchToggle:
        config.isToggled = _value == true;
      case ToggleKind.radio:
        config
          ..isChecked = checked
          ..isInMutuallyExclusiveGroup = true;
    }
  }

  @override
  void dispose() {
    _on.dispose();
    _opacity.layer = null;
    super.dispose();
  }
}
