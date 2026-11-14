// Buttons as render objects: `filledButton`, `elevatedButton`,
// `outlinedButton`, `textButton`, `iconButton` and `floatingActionButton`,
// with no Material widget in their path. Unstyled, each is SSUI's button
// (docs/design/11-no-widgets.md §10 in codelessly_api):
//
// | Type | SSUI variant | Fill / ink | Border |
// |---|---|---|---|
// | filledButton | primary | primary / onPrimary | — |
// | filledButton tonal | tertiary | tertiaryBackground / onSurface | — |
// | elevatedButton | elevated | raisedBackground / onSurface | primaryBorder |
// | outlinedButton | outline | — / onSurface | primaryBorder |
// | textButton | ghost | — / onSurface | — |
// | iconButton | IconButton ghost | — / secondaryText | — |
// | floatingActionButton | primary, floating (level3 shadow) | primary / onPrimary | — |
//
// The geometry is the control scale's (render/controls/tokens.dart): a
// hugging button is 28 high; a sized one takes its box and the padding,
// font and icon sizes of the nearest step. Every `ButtonStyle` field and
// the node's `states` patches apply over this.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show ButtonProps, FloatingActionButtonProps, IconButtonProps, Json, Node, SizeFit, readInt, readString;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, fireTrigger;
import '../paint/icon_glyph.dart';
import '../paint/icon_names.dart';
import '../recipe.dart';
import 'kit.dart';
import 'tokens.dart';

/// The kinds of button, as SSUI draws them.
enum ButtonKind { filled, tonal, elevated, outlined, text, icon, fab }

/// The recipe of every button type (`filledButton`, `elevatedButton`,
/// `outlinedButton`, `textButton`, `iconButton`, `floatingActionButton`):
/// lib/src/widgets/controls.dart registers it.
void buttonRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final fab = n.type == FloatingActionButtonProps.spec.type;
  final l = n.layout;
  chain.add(b.fitBox('fit', fab ? SizeFit.fixed : l.width.fit, fab ? SizeFit.fixed : l.height.fit,
      Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final box = b.obtain<RenderButton>('button', RenderButton.new)
    ..interactive = interactive
    ..spec = ButtonSpec.of(n, ControlTokens.of(b), inherited: b.slot.textDefault)
    ..selected = states.contains(api.WidgetState.selected)
    ..onPressed = interactive ? () => fireTrigger(b, 'click') : null
    // The node's own `states` patches follow what the button tracks.
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.enabled = box.spec.enabled && !states.contains(api.WidgetState.disabled);
  box.autofocus = interactive && box.spec.autofocus;
  chain.add(box);
  // A touch lands on it in a 44 × 44 target around a smaller button
  // (hit testing only: its box keeps its size).
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!box.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

/// What a button shows, resolved from its node and tokens: everything but
/// its states.
@immutable
class ButtonSpec {
  const ButtonSpec({
    required this.kind,
    required this.tokens,
    this.label = '',
    this.align = TextAlign.center,
    this.icon = const {},
    this.iconAtEnd = false,
    this.spacing,
    this.enabled = true,
    this.autofocus = false,
    this.background,
    this.foreground,
    this.iconColor,
    this.iconSize,
    this.labelStyle = const TextStyle(),
    this.side,
    this.shape,
    this.elevation,
    this.padding,
    this.fabType = api.FloatingActionButtonType.regular,
    this.hoverColor,
    this.focusColor,
    this.splashColor,
  });

  final ButtonKind kind;
  final ControlTokens tokens;
  final String label;
  final TextAlign align;
  final Json icon;
  final bool iconAtEnd;

  /// Between the icon and the label (null: the scale's).
  final double? spacing;
  final bool enabled;
  final bool autofocus;

  /// The node's own colours (`style`), over the variant's.
  final Color? background, foreground, iconColor;
  final double? iconSize;

  /// The node's label style fields over the scale's (size, weight, family).
  final TextStyle labelStyle;
  final BorderSide? side;
  final OutlinedBorder? shape;
  final double? elevation;

  /// The node's padding (null: the scale's).
  final EdgeInsets? padding;
  final api.FloatingActionButtonType fabType;
  final Color? hoverColor, focusColor, splashColor;

  bool get hasIcon => icon.isNotEmpty && icon['show'] != false;

  /// [n]'s button, drawn with [tokens]; [inherited] is the default text
  /// style it is under.
  factory ButtonSpec.of(Node n, ControlTokens tokens, {api.TextStyle? inherited}) {
    Color? c(api.Color? v) => v?.flutter;
    if (n.type == FloatingActionButtonProps.spec.type) {
      final type = n.prop(FloatingActionButtonProps.type);
      final shape = n.prop(FloatingActionButtonProps.shape);
      return ButtonSpec(
        kind: ButtonKind.fab,
        tokens: tokens,
        fabType: type,
        label: type == api.FloatingActionButtonType.extended ? n.prop(FloatingActionButtonProps.label) : '',
        icon: _glyph(n.prop(FloatingActionButtonProps.icon)),
        autofocus: n.prop(FloatingActionButtonProps.autofocus),
        background: c(n.prop(FloatingActionButtonProps.backgroundColor)),
        foreground: c(n.prop(FloatingActionButtonProps.foregroundColor)),
        labelStyle: _labelStyle(n.prop(FloatingActionButtonProps.extendedTextStyle), inherited),
        spacing: n.prop(FloatingActionButtonProps.extendedIconLabelSpacing),
        padding: n.prop(FloatingActionButtonProps.extendedPadding)?.flutter,
        elevation: n.prop(FloatingActionButtonProps.elevation),
        shape: shape == null ? null : outlinedBorder(shape),
        hoverColor: c(n.prop(FloatingActionButtonProps.hoverColor)),
        focusColor: c(n.prop(FloatingActionButtonProps.focusColor)),
        splashColor: c(n.prop(FloatingActionButtonProps.splashColor)),
      );
    }
    final icon = n.type == IconButtonProps.spec.type;
    final s = n.prop(ButtonProps.style);
    final kind = switch (n.type) {
      'filledButton' => n.prop(ButtonProps.tonal) ? ButtonKind.tonal : ButtonKind.filled,
      'elevatedButton' => ButtonKind.elevated,
      'outlinedButton' => ButtonKind.outlined,
      'iconButton' => ButtonKind.icon,
      _ => ButtonKind.text,
    };
    final padding = n.layout.padding;
    return ButtonSpec(
      kind: kind,
      tokens: tokens,
      label: icon ? '' : n.prop(ButtonProps.label),
      align: icon ? TextAlign.center : textAlign(n.prop(ButtonProps.textAlign)),
      icon: _glyph(n.prop(icon ? IconButtonProps.icon : ButtonProps.icon)),
      iconAtEnd: !icon && n.prop(ButtonProps.iconAlignment) == api.IconAlignment.end,
      spacing: !icon && n.props.has(ButtonProps.spacing) ? n.prop(ButtonProps.spacing) : null,
      enabled: n.prop(ButtonProps.enabled),
      autofocus: n.prop(ButtonProps.autofocus),
      background: c(s.backgroundColor),
      foreground: c(s.foregroundColor) ?? s.textStyle.color?.flutter,
      iconColor: c(s.iconColor),
      iconSize: s.iconSize,
      labelStyle: _labelStyle(s.textStyle, inherited),
      side: s.side == null
          ? null
          : BorderSide(color: s.side!.color?.flutter ?? const Color(0xFF000000), width: s.side!.width),
      shape: s.shape == null ? null : outlinedBorder(s.shape!),
      elevation: s.elevation,
      padding: padding == api.EdgeInsets.zero ? null : padding.flutter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ButtonSpec &&
      other.kind == kind &&
      other.tokens.theme == tokens.theme &&
      other.tokens.dark == tokens.dark &&
      other.tokens.backdrop == tokens.backdrop &&
      other.label == label &&
      other.align == align &&
      _sameJson(other.icon, icon) &&
      other.iconAtEnd == iconAtEnd &&
      other.spacing == spacing &&
      other.enabled == enabled &&
      other.autofocus == autofocus &&
      other.background == background &&
      other.foreground == foreground &&
      other.iconColor == iconColor &&
      other.iconSize == iconSize &&
      other.labelStyle == labelStyle &&
      other.side == side &&
      other.shape == shape &&
      other.elevation == elevation &&
      other.padding == padding &&
      other.fabType == fabType &&
      other.hoverColor == hoverColor &&
      other.focusColor == focusColor &&
      other.splashColor == splashColor;

  @override
  int get hashCode => Object.hash(kind, label, background, foreground, enabled, padding, fabType);
}

bool _sameJson(Json a, Json b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// A glyph prop as the icon render object draws it: a Material icon given
/// by name alone is looked up by name.
Json _glyph(Json glyph) {
  if (glyph.isEmpty || glyph['show'] == false) return const {};
  final codepoint = readInt(glyph['codepoint']);
  if ((codepoint == null || codepoint <= 0) && readString(glyph['image']) == null) {
    if (readString(glyph['name']) case final String name when name.isNotEmpty) return iconWithName(glyph, name);
  }
  return glyph;
}

/// The label fields a node sets, over the default text style it is under.
TextStyle _labelStyle(api.TextStyle own, api.TextStyle? inherited) {
  final s = inherited == null ? own : inherited.merge(own);
  final w = s.fontWeight;
  return TextStyle(
    fontFamily: s.fontFamily,
    fontSize: s.fontSize,
    fontWeight: w == null ? null : FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)],
    fontStyle: s.fontStyle == null ? null : FontStyle.values.byName(s.fontStyle!.name),
    letterSpacing: s.letterSpacing,
    height: s.height,
    decoration: switch (s.decoration) {
      api.TextDecoration.underline => TextDecoration.underline,
      api.TextDecoration.lineThrough => TextDecoration.lineThrough,
      api.TextDecoration.overline => TextDecoration.overline,
      _ => null,
    },
  );
}

/// [s] as Flutter's border.
OutlinedBorder outlinedBorder(api.ShapeBorder s) {
  final side = s.side == null
      ? BorderSide.none
      : BorderSide(color: s.side!.color?.flutter ?? const Color(0xFF000000), width: s.side!.width);
  final radius = s.borderRadius.flutter;
  return switch (s.type) {
    api.ShapeBorderType.roundedRectangle => RoundedRectangleBorder(borderRadius: radius, side: side),
    api.ShapeBorderType.circle => CircleBorder(side: side),
    api.ShapeBorderType.stadium => StadiumBorder(side: side),
    api.ShapeBorderType.continuousRectangle => ContinuousRectangleBorder(borderRadius: radius, side: side),
    api.ShapeBorderType.beveledRectangle => BeveledRectangleBorder(borderRadius: radius, side: side),
    api.ShapeBorderType.roundedSuperellipse => RoundedSuperellipseBorder(borderRadius: radius, side: side),
  };
}

/// The geometry of a button at a height.
class _Metrics {
  _Metrics(this.scale, this.padX, this.fontSize, this.iconSize, this.gap, this.radius);
  final ControlScale scale;
  final double padX, fontSize, iconSize, gap, radius;
}

/// A button: its surface, label and icon, in the states [RenderControl]
/// resolves.
class RenderButton extends RenderControl implements LabelledControl {
  RenderButton();

  final ControlLabel _label = ControlLabel();
  RenderIconGlyph? _glyph;

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app); a design canvas
  /// draws it at rest.
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
    markNeedsPaint();
  }

  ButtonSpec? _spec;
  ButtonSpec get spec => _spec!;
  set spec(ButtonSpec v) {
    if (v == _spec) return;
    _spec = v;
    _syncIcon();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  void _syncIcon() {
    final s = spec;
    if (!s.hasIcon) {
      icon = null;
      _glyph = null;
      return;
    }
    final g = _glyph ??= RenderIconGlyph();
    if (!identical(icon, g)) icon = g;
    g.icon = s.icon;
    g.color = _look().iconInk;
  }

  /// The icon's colour follows the states: set whenever the button is to
  /// be painted again (never while painting).
  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    final g = _glyph;
    if (g != null && _spec != null) g.color = _look().iconInk;
  }

  ButtonKind get kind => spec.kind;
  bool get _iconOnly => kind == ButtonKind.icon || (kind == ButtonKind.fab && spec.label.isEmpty);

  @override
  String get semanticsName => spec.label;

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
  }

  // --- geometry ------------------------------------------------------------------

  /// The height a hugging button takes.
  double get _naturalHeight => switch (kind) {
        ButtonKind.fab => switch (spec.fabType) {
            api.FloatingActionButtonType.small => 40,
            api.FloatingActionButtonType.large => 96,
            _ => 56,
          },
        // A node's own vertical padding around its content, when that is
        // taller than the scale's step.
        _ => spec.padding == null || spec.padding!.vertical == 0
            ? spec.tokens.defaultHeight
            : math.max(spec.tokens.defaultHeight, _contentHeight + spec.padding!.vertical),
      };

  /// The label's line (or the icon, when taller) at the default step.
  double get _contentHeight {
    final m = _metricsAt(spec.tokens.defaultHeight);
    final line = _iconOnly ? 0.0 : m.fontSize * (spec.labelStyle.height ?? 1.2);
    return math.max(line, spec.hasIcon ? m.iconSize : 0);
  }

  _Metrics _metricsAt(double height) {
    final s = spec;
    final t = s.tokens;
    if (kind == ButtonKind.fab) {
      final large = s.fabType == api.FloatingActionButtonType.large;
      final small = s.fabType == api.FloatingActionButtonType.small;
      final radius = small ? t.radius('panel', 8) : t.radius('dialog', 12) * (large ? 1.5 : 1);
      return _Metrics(ControlScale.steps.last, s.padding?.left ?? 16, s.labelStyle.fontSize ?? 14,
          s.iconSize ?? (large ? 36 : 24), s.spacing ?? 8, radius);
    }
    final scale = t.scaleFor(height);
    final iconOnly = kind == ButtonKind.icon;
    return _Metrics(
      scale,
      s.padding?.left ?? scale.paddingX,
      s.labelStyle.fontSize ?? scale.fontSize,
      s.iconSize ?? (iconOnly ? scale.iconOnlySize : scale.iconSize),
      s.spacing ?? scale.gap,
      t.radiusFor(scale),
    );
  }

  double _heightFor(BoxConstraints c) {
    if (c.hasTightHeight) return c.maxHeight;
    return c.constrainHeight(_naturalHeight);
  }

  /// The label's style at [m], in [color].
  TextStyle _textStyle(_Metrics m, Color color) {
    final own = spec.labelStyle;
    return TextStyle(
      fontFamily: own.fontFamily ?? spec.tokens.fontFamily,
      fontSize: m.fontSize,
      fontWeight: own.fontWeight ?? FontWeight.w500,
      fontStyle: own.fontStyle,
      letterSpacing: own.letterSpacing ?? 0,
      height: own.height ?? 1.2,
      decoration: own.decoration,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
    );
  }

  double _contentWidth(_Metrics m) {
    if (_iconOnly) return m.iconSize;
    _label.update(spec.label, _textStyle(m, const Color(0xFF000000)), align: spec.align);
    final text = _label.intrinsicWidth;
    if (!spec.hasIcon) return text;
    return m.iconSize + (spec.label.isEmpty ? 0 : m.gap) + text;
  }

  double _naturalWidth(double height) {
    final m = _metricsAt(height);
    // Icon only: a square of its height, or the icon in the node's padding.
    if (_iconOnly) return kind == ButtonKind.fab || spec.padding == null ? height : math.max(height, m.iconSize + spec.padding!.horizontal);
    final pad = spec.padding;
    return (pad == null ? m.padX * 2 : pad.horizontal) + _contentWidth(m);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth(height.isFinite && height > 0 ? height : _naturalHeight);

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _naturalHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _naturalHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final h = _heightFor(constraints);
    return constraints.constrain(Size(_naturalWidth(h), h));
  }

  late _Metrics _m;
  Rect _iconRect = Rect.zero;
  double _labelLeft = 0;

  @override
  void performLayout() {
    final h = _heightFor(constraints);
    size = constraints.constrain(Size(_naturalWidth(h), h));
    final m = _m = _metricsAt(size.height);
    final pad = spec.padding ?? EdgeInsets.symmetric(horizontal: m.padX);
    final inner = Rect.fromLTRB(pad.left, 0, size.width - pad.right, size.height);
    final g = _glyph;
    if (_iconOnly) {
      _iconRect = Rect.fromCenter(center: size.center(Offset.zero), width: m.iconSize, height: m.iconSize);
    } else {
      _label.update(spec.label, _textStyle(m, const Color(0xFF000000)), align: spec.align);
      final iconW = spec.hasIcon ? m.iconSize + (spec.label.isEmpty ? 0 : m.gap) : 0.0;
      _label.layout(math.max(0, inner.width - iconW));
      final content = iconW + _label.size.width;
      // The label and icon together, centred (or as the label's alignment
      // puts them when the button is wider than they are).
      final free = math.max(0.0, inner.width - content);
      final start = inner.left +
          switch (spec.align) {
            TextAlign.left || TextAlign.start => 0.0,
            TextAlign.right || TextAlign.end => free,
            _ => free / 2,
          };
      if (spec.hasIcon && !spec.iconAtEnd) {
        _iconRect = Rect.fromLTWH(start, (size.height - m.iconSize) / 2, m.iconSize, m.iconSize);
        _labelLeft = start + iconW;
      } else {
        _labelLeft = start;
        _iconRect = Rect.fromLTWH(start + _label.size.width + m.gap, (size.height - m.iconSize) / 2, m.iconSize, m.iconSize);
      }
    }
    // The glyph fills its square (its own size is the box's).
    g?.layout(BoxConstraints.tight(_iconRect.size));
  }

  // --- paint -------------------------------------------------------------------------

  /// The fill, ink and border of the variant, then the node's style, then
  /// the selected look.
  ({Color? fill, Color ink, Color iconInk, BorderSide? side, bool filled}) _look() {
    final s = spec, t = s.tokens;
    Color? fill;
    Color ink;
    BorderSide? side;
    var filled = false;
    switch (kind) {
      case ButtonKind.filled || ButtonKind.fab:
        fill = t.primary;
        ink = t.readableOn(t.primary, t.onPrimary);
        filled = true;
      case ButtonKind.tonal:
        fill = t.tertiaryBackground;
        ink = t.onSurface;
      case ButtonKind.elevated:
        fill = t.raisedBackground;
        ink = t.onSurface;
        side = BorderSide(color: hovered ? t.secondaryBorder : t.primaryBorder);
      case ButtonKind.outlined:
        ink = t.onSurface;
        side = BorderSide(color: hovered ? t.secondaryBorder : t.primaryBorder);
      case ButtonKind.text:
        ink = t.onSurface;
      case ButtonKind.icon:
        ink = hovered || selected ? t.onSurface : t.secondaryText;
    }
    if (s.background case final Color own) {
      fill = own;
      filled = own.a > .9;
      // A fill of its own: a label that reads on it, unless the node says.
      if (s.foreground == null) ink = t.readableOn(own, ink);
    }
    if (s.foreground case final Color own) ink = own;
    if (s.side case final BorderSide own) side = own;
    if (selected && kind != ButtonKind.filled && kind != ButtonKind.fab && s.background == null) {
      fill = Color.alphaBlend(t.activeTint, fill ?? const Color(0x00000000));
      if (s.foreground == null) ink = t.primary;
      if (side != null && s.side == null) side = BorderSide(color: t.primaryTintBorder);
    }
    return (fill: fill, ink: ink, iconInk: s.iconColor ?? ink, side: side, filled: filled);
  }

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => _iconOnly || spec.label.isEmpty || !hasSize
      ? const []
      : [(text: spec.label, fontFamily: _label.fontFamily, glyphs: _label.glyphBoxes(_labelLeft, size.height / 2))];

  /// The label's colour now (its states included).
  Color get labelColor => _look().ink;

  /// The fill now (null: none), before the state layer.
  Color? get fillColor => _look().fill;

  /// The border now (null: none).
  BorderSide? get borderSide => _look().side;

  /// The overlay of its state now (hover, press), if any.
  Color? get stateOverlay => _overlay(_look().filled);

  /// The shadows it casts.
  List<BoxShadow> get shadows => _shadows();

  /// The label's font family (null: the platform's).
  String? get fontFamily => spec.labelStyle.fontFamily ?? spec.tokens.fontFamily;

  /// Its outline.
  OutlinedBorder get shape => _shape;

  Color? _overlay(bool filled) {
    final s = spec, t = spec.tokens;
    if (pressed) return s.splashColor ?? (filled ? t.filledOverlay(pressed: true) : t.pressedOverlay);
    if (hovered) return s.hoverColor ?? (filled ? t.filledOverlay(pressed: false) : t.hoverOverlay);
    if (focusHighlight && s.focusColor != null) return s.focusColor;
    return null;
  }

  List<BoxShadow> _shadows() {
    final e = spec.elevation;
    if (kind == ButtonKind.fab && e == null) return spec.tokens.shadows('level3');
    if (e == null || e <= 0) return const [];
    return spec.tokens.shadows(e <= 1 ? 'level1' : e <= 3 ? 'level2' : e <= 6 ? 'level3' : 'level4');
  }

  OutlinedBorder get _shape => spec.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(_m.radius));

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// The alpha it was last painted at (255: opaque; a disabled button 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      // Disabled: the whole button at SSUI's 50 %.
      _opacity.layer = context.pushOpacity(offset, 128, _paintButton, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintButton(context, offset);
  }

  void _paintButton(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final look = _look();
    final shape = _shape;
    final path = shape.getOuterPath(rect);
    for (final sh in _shadows()) {
      canvas.drawPath(path.shift(sh.offset), sh.toPaint());
    }
    if (look.fill case final Color fill when fill.a > 0) canvas.drawPath(path, Paint()..color = fill);
    final overlay = _overlay(look.filled);
    if (overlay != null && overlay.a > 0) canvas.drawPath(path, Paint()..color = overlay);
    if (look.side case final BorderSide side when side.width > 0 && side.color.a > 0) {
      shape.copyWith(side: side.copyWith(strokeAlign: BorderSide.strokeAlignInside)).paint(canvas, rect);
    }
    if (focusHighlight) {
      shape
          .copyWith(side: BorderSide(color: spec.tokens.focusBorder, width: 1.5, strokeAlign: BorderSide.strokeAlignOutside))
          .paint(canvas, rect);
    }
    if (!_iconOnly) {
      _label.update(spec.label, _textStyle(_m, look.ink), align: spec.align);
      _label.layout(_laidOutLabelWidth);
      _label.paint(canvas, offset.dx + _labelLeft, offset.dy + size.height / 2);
    }
    final g = _glyph;
    if (g != null && identical(icon, g)) context.paintChild(g, offset + _iconRect.topLeft);
  }

  double get _laidOutLabelWidth {
    final pad = spec.padding ?? EdgeInsets.symmetric(horizontal: _m.padX);
    final iconW = spec.hasIcon ? _m.iconSize + (spec.label.isEmpty ? 0 : _m.gap) : 0.0;
    return math.max(0, size.width - pad.horizontal - iconW);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) =>
      transform.translateByDouble(_iconRect.left, _iconRect.top, 0, 1);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isButton = true;
  }

  @override
  void dispose() {
    _label.dispose();
    _opacity.layer = null;
    super.dispose();
  }
}
