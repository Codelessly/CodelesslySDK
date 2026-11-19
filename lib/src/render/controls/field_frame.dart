// The frame of a field, as a render object: what Flutter's `InputDecorator`
// draws around a `TextField` or a `DropdownButtonFormField`, in SSUI's look
// (design_systems/ssui: TextInput, Field). A control whose content is a line
// of text (the text field's editable text, the dropdown's value) extends
// [RenderFieldFrame] and supplies its content; the frame lays out and paints
// everything else:
//
// | Part | SSUI | From the decoration |
// |---|---|---|
// | label | above the box, never floating: `fieldLabel` 11.5/600 in `secondaryText`, 6 px above | `labelText`, `labelStyle` |
// | box | 28 high when it hugs (the control scale), 240 wide unless its content is wider; `primaryBackground` fill, radius 7 | `filled`, `fillColor`, `constraints` |
// | border | 1 px `primaryBorder`, `secondaryBorder` hovered, 1.5 px `focusBorder` focused, `error` in error | `border`, `enabledBorder`, `focusedBorder`, `errorBorder`, `focusedErrorBorder`, `disabledBorder` |
// | content | its line centered in the box, `paddingX` (8) at the sides | `contentPadding` |
// | hint | the content's metrics in `tertiaryText` | `hintText`, `hintStyle` |
// | prefix, suffix | an icon at the scale's icon size in `secondaryText`, and/or a text | `prefixIcon`, `prefixText`, `suffixIcon`, `suffixText` |
// | helper, error | `caption` 11 in `secondaryText` / `error`, 4 px below; the error replaces the helper | `helperText`, `errorText` |
// | disabled | the whole field at 50 % | `enabled` |
//
// The label stays where it is in every state (error included), the box never
// changes size between states, and every color is a token: no Material
// default reaches it.
import 'dart:math' as math;
import 'dart:ui' as ui show BoxHeightStyle;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, readInt, readString;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import '../layout/control_line.dart';
import '../paint/icon_glyph.dart';
import '../paint/icon_names.dart';
import 'kit.dart';
import 'tokens.dart';

/// The width a hugging field takes when its content is narrower (SSUI's
/// TextInput preview).
const double kFieldHugWidth = 240;

/// Between the label and the box (SSUI's Field).
const double kFieldLabelGap = 6;

/// Between the box and its helper or error line.
const double kFieldBelowGap = 4;

/// What draws a field's border in one state.
enum FieldBorderKind { none, outline, underline }

/// A field's border in one state: its kind, side and corners (null: the
/// control radius of the field's step).
@immutable
class FieldBorder {
  const FieldBorder(this.kind, this.side, [this.radius]);

  final FieldBorderKind kind;
  final BorderSide side;
  final BorderRadius? radius;

  static const none = FieldBorder(FieldBorderKind.none, BorderSide.none);

  /// [b] as the frame draws it (null: unset).
  static FieldBorder? of(api.InputBorder? b) {
    if (b == null) return null;
    final s = b.borderSide;
    final side = s.style == api.BorderStyle.none || s.width <= 0
        ? BorderSide.none
        : BorderSide(color: s.color?.flutter ?? const Color(0xFF000000), width: s.width);
    return switch (b.type) {
      // No line, its corners kept: they round the field's fill.
      api.InputBorderType.none =>
        b.fields.has(api.InputBorderFields.borderRadius) ? FieldBorder(FieldBorderKind.none, BorderSide.none, b.borderRadius.flutter) : none,
      api.InputBorderType.outline => FieldBorder(
        FieldBorderKind.outline,
        side,
        b.fields.has(api.InputBorderFields.borderRadius) ? b.borderRadius.flutter : null,
      ),
      api.InputBorderType.underline => FieldBorder(
        FieldBorderKind.underline,
        side,
        b.fields.has(api.InputBorderFields.borderRadius) ? b.borderRadius.flutter : null,
      ),
    };
  }

  FieldBorder withSide(BorderSide s) => FieldBorder(kind, s, radius);

  @override
  bool operator ==(Object other) =>
      other is FieldBorder && other.kind == kind && other.side == side && other.radius == radius;

  @override
  int get hashCode => Object.hash(kind, side, radius);
}

/// A prefix or a suffix: an icon, a text, or both (the text nearer the
/// content).
@immutable
class FieldAffix {
  const FieldAffix({
    this.icon = const {},
    this.iconSize,
    this.iconColor,
    this.text = '',
    this.textStyle,
    this.padding,
    this.minWidth = 0,
    this.tappable = false,
    this.alwaysVisible = true,
    this.button = false,
  });

  /// A number field's minus or plus button ([FieldDecoration.steppers]):
  /// a square slot as wide as the box is high, ruled off from the value.
  factory FieldAffix.stepper({required bool plus}) =>
      FieldAffix(icon: _glyph({'name': plus ? 'add' : 'remove'}), tappable: true, button: true);

  /// The glyph (an icon prop, as an `icon` node's).
  final Json icon;

  /// Its size (null: the scale's icon size).
  final double? iconSize;

  /// Its color (null: `secondaryText`).
  final Color? iconColor;
  final String text;

  /// The text's own style fields, over the content's style in
  /// `secondaryText`.
  final TextStyle? textStyle;

  /// Around the icon (null: the scale's side padding outside it).
  final EdgeInsets? padding;

  /// The slot's least width (`prefixIconConstraints.minWidth`).
  final double minWidth;

  /// Whether a tap on the icon is the affix's (it has reactions).
  final bool tappable;

  /// Whether the text shows while the field is empty and unfocused
  /// (Flutter's `prefixText` doesn't; an icon always shows).
  final bool alwaysVisible;

  /// A button in the box (a stepper's): its whole slot takes the press, it
  /// is ruled off from the content and tinted under the pointer.
  final bool button;

  bool get hasIcon => icon.isNotEmpty && icon['show'] != false;
  bool get hasText => text.isNotEmpty;
  bool get isEmpty => !hasIcon && !hasText;

  /// [icon] of an input's decoration ([tokens] for nothing yet), with
  /// [text] in [textStyle].
  static FieldAffix? of(
    api.InputIcon? icon,
    String? text,
    api.TextStyle textStyle, {
    api.EdgeInsets? padding,
    api.BoxConstraints? constraints,
    bool alwaysVisible = false,
  }) {
    final glyph = icon == null ? const <String, Object?>{} : _glyph(icon.icon);
    final t = text ?? '';
    if (glyph.isEmpty && t.isEmpty) return null;
    return FieldAffix(
      icon: glyph,
      iconSize: icon != null && icon.fields.has(api.InputIconFields.size) ? icon.size : null,
      iconColor: icon?.color?.flutter,
      text: t,
      textStyle: textStyle.isEmpty ? null : ownStyle(textStyle),
      padding: padding?.flutter,
      minWidth: constraints?.minWidth ?? 0,
      tappable: icon != null && icon.actions.isNotEmpty,
      alwaysVisible: alwaysVisible,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FieldAffix &&
      _sameJson(other.icon, icon) &&
      other.iconSize == iconSize &&
      other.iconColor == iconColor &&
      other.text == text &&
      other.textStyle == textStyle &&
      other.padding == padding &&
      other.minWidth == minWidth &&
      other.tappable == tappable &&
      other.alwaysVisible == alwaysVisible &&
      other.button == button;

  @override
  int get hashCode => Object.hash(text, iconSize, iconColor, padding, minWidth, tappable);
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

/// The fields [s] sets, as a Flutter style that only overrides them (merged
/// over a base with [TextStyle.merge]).
TextStyle ownStyle(api.TextStyle s) {
  final w = s.fontWeight;
  if (s.fontFamily case final String family) {
    FontDemand.need(family, ((w ?? 400) ~/ 100 * 100).clamp(100, 900), s.fontStyle == api.FontStyle.italic);
  }
  return TextStyle(
    fontFamily: s.fontFamily,
    fontFamilyFallback: FontDemand.fallbackOf(s.fontFamily, s.fontFamilyFallback),
    fontSize: s.fontSize,
    fontWeight: w == null ? null : FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)],
    fontStyle: s.fontStyle == null ? null : FontStyle.values.byName(s.fontStyle!.name),
    letterSpacing: s.letterSpacing,
    height: s.height,
    color: s.foreground == null ? s.color?.flutter : null,
    backgroundColor: s.backgroundColor?.flutter,
    decoration: switch (s.decoration) {
      null => null,
      api.TextDecoration.none => TextDecoration.none,
      api.TextDecoration.underline => TextDecoration.underline,
      api.TextDecoration.overline => TextDecoration.overline,
      api.TextDecoration.lineThrough => TextDecoration.lineThrough,
    },
    decorationColor: s.decorationColor?.flutter,
    fontFeatures: s.fontFeatures.isEmpty && s.tabularFigures == null ? null : fontFeatures(s),
  );
}

/// What a field's frame shows, resolved from its decoration and tokens:
/// everything but its states.
@immutable
class FieldDecoration {
  const FieldDecoration({
    required this.tokens,
    this.label = '',
    this.labelStyle,
    this.hint = '',
    this.hintStyle,
    this.hintMaxLines,
    this.helper = '',
    this.helperStyle,
    this.helperMaxLines,
    this.error,
    this.errorStyle,
    this.errorMaxLines,
    this.counter = '',
    this.counterStyle,
    this.prefix,
    this.suffix,
    this.contentPadding,
    this.filled,
    this.fillColor,
    this.hoverColor,
    this.focusColor,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.errorBorder,
    this.focusedErrorBorder,
    this.disabledBorder,
    this.collapsed = false,
    this.constraints,
    this.enabled = true,
    this.focusRingWidth = 0,
    this.focusRingColor,
    this.valueStyle = const TextStyle(),
  });

  final ControlTokens tokens;

  /// Drawn above the box ('' none), its own style fields over SSUI's
  /// `fieldLabel`.
  final String label;
  final TextStyle? labelStyle;

  /// Shown while the content is empty, in the content's metrics.
  final String hint;
  final TextStyle? hintStyle;
  final int? hintMaxLines;
  final String helper;
  final TextStyle? helperStyle;
  final int? helperMaxLines;

  /// The error: null none, '' (or [api.kErrorWithoutMessage]) the error
  /// border with no message.
  final String? error;
  final TextStyle? errorStyle;
  final int? errorMaxLines;

  /// Shown at the end of the helper line ('' none).
  final String counter;
  final TextStyle? counterStyle;
  final FieldAffix? prefix, suffix;

  /// The decoration's own (null: SSUI's: the scale's side padding, the
  /// line centered).
  final EdgeInsets? contentPadding;

  /// The decoration's `filled` (null: SSUI's field is filled) and fill.
  final bool? filled;
  final Color? fillColor;
  final Color? hoverColor, focusColor;
  final FieldBorder? border, enabledBorder, focusedBorder, errorBorder, focusedErrorBorder, disabledBorder;

  /// No box: no border, fill or padding (`isCollapsed`).
  final bool collapsed;
  final BoxConstraints? constraints;
  final bool enabled;

  /// A ring of this width around the box while focused (0: none, SSUI's
  /// focus border only).
  final double focusRingWidth;
  final Color? focusRingColor;

  /// The content's text style (resolved): the hint and affix texts take its
  /// metrics.
  final TextStyle valueStyle;

  /// Whether the field is in error (with or without a message).
  bool get hasError => error != null;

  /// The error's message ('' none).
  String get errorMessage => error == null || error == api.kErrorWithoutMessage ? '' : error!.trim();

  /// [d] of a field drawn with [tokens], its content in [valueStyle]; an
  /// [errorOverride] (a validator's message) replaces the decoration's error.
  factory FieldDecoration.of(
    api.InputDecoration d,
    ControlTokens tokens, {
    required TextStyle valueStyle,
    String? errorOverride,
    String? counterFallback,
    double focusRingWidth = 0,
    Color? focusRingColor,
    String Function(String? text)? text,
    bool steppers = false,
    bool collapsed = false,
  }) {
    final t = text ?? (s) => s ?? '';
    String? error;
    final own = errorOverride ?? d.errorText;
    if (own == api.kErrorWithoutMessage) {
      error = '';
    } else if (own != null && own.trim().isNotEmpty) {
      final shown = t(own).trim();
      error = shown.isEmpty ? null : shown;
    }
    TextStyle? style(api.TextStyle s) => s.isEmpty ? null : ownStyle(s);
    final always = d.affixesAlwaysVisible;
    return FieldDecoration(
      tokens: tokens,
      label: t(d.labelText).trim(),
      labelStyle: style(d.labelStyle.isEmpty ? d.floatingLabelStyle : d.labelStyle),
      hint: t(d.hintText),
      hintStyle: style(d.hintStyle),
      hintMaxLines: d.hintMaxLines,
      helper: t(d.helperText).trim(),
      helperStyle: style(d.helperStyle),
      helperMaxLines: d.helperMaxLines,
      error: error,
      errorStyle: style(d.errorStyle),
      errorMaxLines: d.errorMaxLines,
      // A design's own counter text (written empty: no counter, as in Flutter), else the
      // field's count against its limit.
      counter: d.counterText == null ? (counterFallback ?? '') : t(d.counterText),
      counterStyle: style(d.counterStyle),
      prefix: steppers ? FieldAffix.stepper(plus: false) : FieldAffix.of(
        d.prefixIcon,
        t(d.prefixText),
        d.prefixStyle,
        padding: d.prefixIconPadding,
        constraints: d.prefixIconConstraints,
        alwaysVisible: always,
      ),
      suffix: steppers ? FieldAffix.stepper(plus: true) : FieldAffix.of(
        d.suffixIcon,
        t(d.suffixText),
        d.suffixStyle,
        padding: d.suffixIconPadding,
        constraints: d.suffixIconConstraints,
        alwaysVisible: always,
      ),
      contentPadding: d.contentPadding?.flutter,
      filled: d.filled,
      fillColor: d.fillColor?.flutter,
      hoverColor: d.hoverColor?.flutter,
      focusColor: d.focusColor?.flutter,
      border: FieldBorder.of(d.border),
      enabledBorder: FieldBorder.of(d.enabledBorder),
      focusedBorder: FieldBorder.of(d.focusedBorder),
      errorBorder: FieldBorder.of(d.errorBorder),
      focusedErrorBorder: FieldBorder.of(d.focusedErrorBorder),
      disabledBorder: FieldBorder.of(d.disabledBorder),
      collapsed: collapsed || d.isCollapsed,
      constraints: d.constraints.isEmpty ? null : d.constraints.flutter,
      enabled: d.enabled,
      focusRingWidth: focusRingWidth,
      focusRingColor: focusRingColor,
      valueStyle: valueStyle,
    );
  }

  /// SSUI's field text at [scale] in [tokens] ([inherited] and [own] style
  /// fields over it): `inputText` weight and line, the scale's size,
  /// `primaryText`, the theme's font.
  static TextStyle valueStyleFor(ControlTokens tokens, ControlScale scale, {TextStyle? inherited, TextStyle? own}) {
    var s = TextStyle(
      fontFamily: tokens.fontFamily,
      fontSize: scale.fontSize,
      fontWeight: FontWeight.w400,
      height: 1.25,
      letterSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
      color: tokens.onSurface,
    );
    if (inherited != null) s = s.merge(inherited);
    if (own != null) s = s.merge(own);
    return s;
  }

  // --- colors ---------------------------------------------------------------------

  Color _token(String name, Color fallback) => tokens.theme.color(name)?.flutter ?? fallback;

  /// The field's fill (null: none).
  Color? get fill {
    if (collapsed || filled == false) return null;
    return fillColor ?? _token('primaryBackground', tokens.surface);
  }

  Color get labelColor => tokens.secondaryText;
  Color get hintColor => _token('tertiaryText', tokens.onSurface.withValues(alpha: .4));
  Color get helperColor => tokens.secondaryText;
  Color get errorColor => tokens.error;

  /// The border drawn in a state: the decoration's own for the state, else
  /// its `border` in the state's color, else SSUI's outline.
  FieldBorder borderFor({required bool focused, required bool hovered, required bool enabled}) {
    if (collapsed) return FieldBorder.none;
    final t = tokens;
    final error = hasError;
    final own = !enabled
        ? disabledBorder
        : error
        ? (focused ? focusedErrorBorder ?? errorBorder : errorBorder)
        : focused
        ? focusedBorder
        : enabledBorder;
    if (own != null) return own;
    final shape = border ?? const FieldBorder(FieldBorderKind.outline, BorderSide());
    if (shape.kind == FieldBorderKind.none) return FieldBorder.none;
    final width = !enabled ? 1.0 : (focused ? 1.5 : 1.0);
    final color = !enabled
        ? t.primaryBorder
        : error
        ? t.error
        : focused
        ? t.focusBorder
        : hovered
        ? t.secondaryBorder
        : border != null && border!.side != const BorderSide() && border!.side != BorderSide.none
        ? border!.side.color
        : t.primaryBorder;
    return shape.withSide(BorderSide(color: color, width: width));
  }

  @override
  bool operator ==(Object other) =>
      other is FieldDecoration &&
      other.tokens.theme == tokens.theme &&
      other.tokens.dark == tokens.dark &&
      other.tokens.backdrop == tokens.backdrop &&
      other.label == label &&
      other.labelStyle == labelStyle &&
      other.hint == hint &&
      other.hintStyle == hintStyle &&
      other.hintMaxLines == hintMaxLines &&
      other.helper == helper &&
      other.helperStyle == helperStyle &&
      other.helperMaxLines == helperMaxLines &&
      other.error == error &&
      other.errorStyle == errorStyle &&
      other.errorMaxLines == errorMaxLines &&
      other.counter == counter &&
      other.counterStyle == counterStyle &&
      other.prefix == prefix &&
      other.suffix == suffix &&
      other.contentPadding == contentPadding &&
      other.filled == filled &&
      other.fillColor == fillColor &&
      other.hoverColor == hoverColor &&
      other.focusColor == focusColor &&
      other.border == border &&
      other.enabledBorder == enabledBorder &&
      other.focusedBorder == focusedBorder &&
      other.errorBorder == errorBorder &&
      other.focusedErrorBorder == focusedErrorBorder &&
      other.disabledBorder == disabledBorder &&
      other.collapsed == collapsed &&
      other.constraints == constraints &&
      other.enabled == enabled &&
      other.focusRingWidth == focusRingWidth &&
      other.focusRingColor == focusRingColor &&
      other.valueStyle == valueStyle;

  @override
  int get hashCode => Object.hash(label, hint, helper, error, prefix, suffix, contentPadding, valueStyle, enabled);
}

/// Where a pointer is on a field's frame.
enum FieldFramePart { label, box, prefixIcon, suffixIcon, below, none }

/// A field: [decoration]'s frame (label above, box, hint, affixes, helper
/// or error below) around content its subclass lays out and paints
/// ([layoutContent], [paintContent]). The content is one line centered in the
/// box, or several from its top ([contentMultiline]).
abstract class RenderFieldFrame extends RenderControl implements LabeledControl, ControlLineField {
  RenderFieldFrame();

  FieldDecoration? _decoration;
  FieldDecoration get decoration => _decoration!;
  set decoration(FieldDecoration v) {
    if (v == _decoration) return;
    _decoration = v;
    _syncGlyphs();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  double _hugWidth = kFieldHugWidth;

  /// The width it takes when it hugs and its content is narrower (a node's
  /// design width, else [kFieldHugWidth]).
  set hugWidth(double v) {
    if (v == _hugWidth) return;
    _hugWidth = v;
    markNeedsLayout();
  }

  TextAlignVertical? _alignVertical;

  /// Where one line sits in a box taller than it (null: centered).
  set alignVertical(TextAlignVertical? v) {
    if (v == _alignVertical) return;
    _alignVertical = v;
    markNeedsLayout();
  }

  TextAlign _hintAlign = TextAlign.start;
  set hintAlign(TextAlign v) {
    if (v == _hintAlign) return;
    _hintAlign = v;
    markNeedsLayout();
  }

  /// A tap on an affix icon that has reactions ([FieldAffix.tappable]):
  /// true for the prefix.
  void Function(bool prefix)? onAffixTap;

  // --- what the subclass supplies ---------------------------------------------------

  /// The content's width on one line, uncut (what a hugging field fits).
  double contentNaturalWidth();

  /// The content's height laid out [width] wide (one line: its line's).
  double contentHeightFor(double width);

  /// The height of one line of the content.
  double get contentLineHeight;

  /// Whether the content grows by lines (the box grows with it when it
  /// hugs; its first line sits at the top).
  bool get contentMultiline => false;

  /// Whether it shows nothing (the hint shows).
  bool get contentEmpty;

  /// Lays the content out in [rect] (local coordinates).
  void layoutContent(Rect rect);

  /// Paints the content, [offset] being the frame's origin.
  void paintContent(PaintingContext context, Offset offset);

  /// Whether the affix texts show (Flutter shows them while focused or
  /// not empty).
  bool get affixTextsShown => focusNode.hasFocus || !contentEmpty;

  // --- children: the affix glyphs --------------------------------------------------

  RenderIconGlyph? _prefixGlyph, _suffixGlyph;

  /// Its own render children besides the glyphs (the editable text);
  /// the subclass adopts and drops them.
  List<RenderBox> get contentChildren => const [];

  void _syncGlyphs() {
    final d = decoration;
    _prefixGlyph = _syncGlyph(_prefixGlyph, d.prefix);
    _suffixGlyph = _syncGlyph(_suffixGlyph, d.suffix);
  }

  RenderIconGlyph? _syncGlyph(RenderIconGlyph? g, FieldAffix? a) {
    if (a == null || !a.hasIcon) {
      if (g != null) dropChild(g);
      return null;
    }
    if (g == null) {
      g = RenderIconGlyph();
      adoptChild(g);
    }
    g
      ..icon = a.icon
      ..color = a.iconColor ?? decoration.tokens.secondaryText;
    return g;
  }

  Iterable<RenderBox> get _frameChildren => [?_prefixGlyph, ?_suffixGlyph];

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    _frameChildren.forEach(visitor);
    contentChildren.forEach(visitor);
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    _frameChildren.forEach(redepthChild);
    contentChildren.forEach(redepthChild);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    ControlLine.fieldAttached();
    for (final c in [..._frameChildren, ...contentChildren]) {
      c.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    ControlLine.fieldDetached();
    for (final c in [..._frameChildren, ...contentChildren]) {
      c.detach();
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final o = (child.parentData as BoxParentData?)?.offset ?? Offset.zero;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  // --- texts --------------------------------------------------------------------------

  /// The direction the field lays out in (its node's): under right to left
  /// its text and hint start at the right, the prefix is on the right and
  /// the suffix on the left, the label and helper sit at the right and the
  /// counter at the left, as Flutter's InputDecorator.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection = TextDirection.ltr;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    for (final p in [_label, _hint, _below, _counter, _prefixText, _suffixText]) {
      p.textDirection = v;
    }
    markNeedsLayout();
  }

  bool get _rtl => _textDirection == TextDirection.rtl;

  /// [x] (with [width]) mirrored across the box under right to left.
  double _across(double x, double width) => _rtl ? boxRect.left + boxRect.right - x - width : x;

  final TextPainter _label = TextPainter(textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');
  final TextPainter _hint = TextPainter(textDirection: TextDirection.ltr, ellipsis: '…');
  final TextPainter _below = TextPainter(textDirection: TextDirection.ltr, ellipsis: '…');
  final TextPainter _counter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
  final TextPainter _prefixText = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
  final TextPainter _suffixText = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);

  /// The label's style now (its own fields over the theme's `fieldLabel`).
  TextStyle get labelStyle => _labelStyle;

  TextStyle get _labelStyle {
    final d = decoration;
    // The theme's `fieldLabel` (a design system's: Desk's 12.5/500), so a
    // field's own label is drawn as the labels a form writes beside it (a
    // Field's) are; else SSUI's 11.5/600.
    final theme = d.tokens.theme.textStyles['fieldLabel'];
    final own = theme == null ? null : textStyle(theme);
    final base = TextStyle(
      fontFamily: own?.fontFamily ?? d.tokens.fontFamily,
      fontSize: own?.fontSize ?? 11.5,
      fontWeight: own?.fontWeight ?? FontWeight.w600,
      height: own?.height ?? 1.3,
      letterSpacing: own?.letterSpacing ?? 0,
      leadingDistribution: TextLeadingDistribution.even,
      color: d.labelColor,
    );
    return d.labelStyle == null ? base : base.merge(d.labelStyle);
  }

  TextStyle _captionStyle(Color color, TextStyle? own) {
    final base = TextStyle(
      fontFamily: decoration.tokens.fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
    );
    return own == null ? base : base.merge(own);
  }

  /// How far below the content's top the hint is painted: its baseline on
  /// the content's (Flutter's InputDecorator lays the hint and the input
  /// out on one baseline), 0 when they share a style.
  double get hintBaselineShift {
    final d = decoration;
    if (d.hintStyle == null) return 0;
    final key = (d.valueStyle, hintStyle);
    if (_hintShiftKey == key) return _hintShift;
    final value = TextPainter(text: TextSpan(text: ' ', style: d.valueStyle), textDirection: TextDirection.ltr)..layout();
    final hint = TextPainter(text: TextSpan(text: ' ', style: hintStyle), textDirection: TextDirection.ltr)..layout();
    _hintShift = value.computeDistanceToActualBaseline(TextBaseline.alphabetic) -
        hint.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    value.dispose();
    hint.dispose();
    _hintShiftKey = key;
    return _hintShift;
  }

  Object? _hintShiftKey;
  double _hintShift = 0;

  /// The hint's style: the content's, in `tertiaryText`, the decoration's
  /// hint style over it (so the hint and the typed text share a line).
  TextStyle get hintStyle {
    final d = decoration;
    final s = d.valueStyle.copyWith(color: d.hintColor);
    return d.hintStyle == null ? s : s.merge(d.hintStyle);
  }

  TextStyle _affixStyle(FieldAffix a) {
    final s = decoration.valueStyle.copyWith(color: decoration.tokens.secondaryText);
    return a.textStyle == null ? s : s.merge(a.textStyle);
  }

  /// The line under the box: the error's message, else the helper.
  String get belowText {
    final d = decoration;
    return d.hasError ? d.errorMessage : d.helper;
  }

  // --- geometry -----------------------------------------------------------------------

  /// The step of the control scale the box is at.
  ControlScale scale = ControlScale.compact;

  /// The box (border, fill), the content, the affix slots and the line
  /// below, in local coordinates (after layout).
  Rect boxRect = Rect.zero, contentRect = Rect.zero;
  Rect _prefixIconRect = Rect.zero, _suffixIconRect = Rect.zero;
  Offset _prefixTextAt = Offset.zero, _suffixTextAt = Offset.zero;
  double _labelTop = 0, _belowTop = 0;

  double get _labelExtent {
    if (decoration.label.isEmpty) return 0;
    _layoutLabel(double.infinity);
    return _label.height + kFieldLabelGap;
  }

  void _layoutLabel(double width) {
    _label
      ..text = TextSpan(text: decoration.label, style: _labelStyle)
      ..layout(maxWidth: width.isFinite ? math.max(0, width) : double.infinity);
  }

  void _layoutBelow(double width) {
    final d = decoration;
    final error = d.hasError && d.errorMessage.isNotEmpty;
    _below
      ..text = TextSpan(
        text: belowText,
        style: error ? _captionStyle(d.errorColor, d.errorStyle) : _captionStyle(d.helperColor, d.helperStyle),
      )
      ..maxLines = (error ? d.errorMaxLines : d.helperMaxLines) ?? (error ? 2 : 1)
      ..layout(maxWidth: width.isFinite ? math.max(0, width) : double.infinity);
    _counter
      ..text = TextSpan(text: d.counter, style: _captionStyle(d.helperColor, d.counterStyle))
      ..layout();
  }

  /// The height of the line(s) below the box at [width] (0: none).
  double _belowExtent(double width) {
    final d = decoration;
    if (belowText.isEmpty && d.counter.isEmpty) return 0;
    _layoutBelow(width);
    final h = math.max(belowText.isEmpty ? 0.0 : _below.height, d.counter.isEmpty ? 0.0 : _counter.height);
    return kFieldBelowGap + h;
  }

  /// The reserved part of a fixed height for the line below: the helper's
  /// (an error that comes where no helper was is drawn below the box,
  /// which keeps its height).
  double _reservedBelow(double width) {
    final d = decoration;
    if (d.helper.isEmpty && d.counter.isEmpty) return 0;
    return _belowExtent(width);
  }

  EdgeInsets _padding(ControlScale s) {
    final d = decoration;
    if (d.collapsed) return EdgeInsets.zero;
    return d.contentPadding ?? EdgeInsets.symmetric(horizontal: _sidePadding(s));
  }

  /// SSUI's field padding at a step (its `paddingX`: 6/8/10/10/12).
  static double _sidePadding(ControlScale s) => switch (s.name) {
    'xs' => 6,
    'compact' => 8,
    'small' || 'medium' => 10,
    _ => 12,
  };

  double _iconSize(FieldAffix a, ControlScale s) => a.iconSize ?? s.iconSize;

  /// The width an affix slot takes, its outer padding included: [prefix]
  /// on the leading side.
  double _affixWidth(FieldAffix? a, ControlScale s, {required bool prefix}) {
    if (a == null) return 0;
    if (a.button) return s.height;
    final pad = _padding(s);
    final outer = prefix ? pad.left : pad.right;
    var w = 0.0;
    if (a.hasIcon) {
      final p = a.padding;
      w += _iconSize(a, s) + (p == null ? outer : p.horizontal);
    } else {
      w += outer;
    }
    final text = prefix ? _prefixText : _suffixText;
    if (a.hasText && (a.alwaysVisible || affixTextsShown)) {
      text
        ..text = TextSpan(text: a.text, style: _affixStyle(a))
        ..layout();
      w += text.width + (a.hasIcon ? 4 : 0);
    }
    w += s.gap;
    return math.max(w, a.minWidth);
  }

  /// The hint's width on one line.
  double get _hintNaturalWidth {
    final d = decoration;
    if (d.hint.isEmpty) return 0;
    final p = TextPainter(
      text: TextSpan(text: d.hint, style: hintStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  double get _defaultBoxHeight => decoration.tokens.defaultHeight;

  /// The box's sides beyond the content, at [s].
  double _sides(ControlScale s) {
    final d = decoration;
    final pad = _padding(s);
    final p = d.prefix == null ? pad.left : _affixWidth(d.prefix, s, prefix: true);
    final q = d.suffix == null ? pad.right : _affixWidth(d.suffix, s, prefix: false);
    return p + q;
  }

  /// The width it takes when it hugs. [height] is the height it is held to,
  /// when it is: its sides (padding, a chevron's or an icon's slot) are
  /// those of the step it is drawn at there. Measured at the default step, a
  /// field 40 high was narrower than its own value, which was cut.
  double _naturalWidth([double? height]) {
    final d = decoration;
    final box = height == null || !height.isFinite ? null : height - _labelExtent;
    final s = box != null && box >= 20 ? d.tokens.scaleFor(box) : ControlScale.compact;
    final content = math.max(contentNaturalWidth(), _hintNaturalWidth);
    var w = math.max(_hugWidth, content + _sides(s) + (d.collapsed ? 0 : 2));
    if (d.label.isNotEmpty) {
      _layoutLabel(double.infinity);
      w = math.max(w, _label.width);
    }
    final c = d.constraints;
    if (c != null) w = c.constrainWidth(w);
    return w;
  }

  /// The box's height when it hugs, [width] wide.
  double _hugBoxHeight(double width) {
    final d = decoration;
    final s = d.tokens.scaleFor(_defaultBoxHeight);
    final line = contentLineHeight;
    final pad = _padding(s);
    final contentWidth = math.max(0.0, width - _sides(s));
    double h;
    if (d.collapsed) {
      h = contentMultiline ? contentHeightFor(contentWidth) : line;
    } else if (contentMultiline) {
      final padV = d.contentPadding != null ? pad.vertical : math.max(0.0, _defaultBoxHeight - line);
      h = math.max(_defaultBoxHeight, contentHeightFor(contentWidth) + padV);
    } else {
      h = d.contentPadding != null ? math.max(_defaultBoxHeight, line + pad.vertical) : _defaultBoxHeight;
    }
    final c = d.constraints;
    if (c != null) h = c.constrainHeight(h);
    return h;
  }

  Size _sizeFor(BoxConstraints c) {
    final width = c.hasTightWidth ? c.maxWidth : c.constrainWidth(_naturalWidth(c.hasTightHeight ? c.maxHeight : null));
    final label = _labelExtent;
    final double height;
    if (c.hasTightHeight) {
      height = c.maxHeight;
    } else {
      height = c.constrainHeight(label + _hugBoxHeight(width) + _belowExtent(width));
    }
    return Size(width, height);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) {
    final w = width.isFinite ? width : _naturalWidth();
    return _labelExtent + _hugBoxHeight(w) + _belowExtent(w);
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _sizeFor(constraints);

  // --- the control line ------------------------------------------------------------
  //
  // The box is the control a row lines up (layout/control_line.dart): the
  // label hangs above it, the helper, error or counter below it.

  @override
  ControlInsets get controlInsets => hasSize
      ? ControlInsets(math.max(0, boxRect.top), math.max(0, size.height - boxRect.bottom))
      : ControlInsets.zero;

  @override
  ControlInsets dryControlInsets(BoxConstraints constraints) {
    final d = decoration;
    final size = getDryLayout(constraints);
    // Measured on painters of their own: the frame's are laid out for paint.
    var above = 0.0;
    if (d.label.isNotEmpty) {
      final p = TextPainter(text: TextSpan(text: d.label, style: _labelStyle), textDirection: _textDirection, maxLines: 1)
        ..layout();
      above = p.height + kFieldLabelGap;
      p.dispose();
    }
    final reserved = d.helper.isNotEmpty || d.counter.isNotEmpty;
    var below = 0.0;
    if ((constraints.hasTightHeight ? reserved : (belowText.isNotEmpty || d.counter.isNotEmpty))) {
      final error = d.hasError && d.errorMessage.isNotEmpty;
      final line = TextPainter(
        text: TextSpan(
          text: belowText,
          style: error ? _captionStyle(d.errorColor, d.errorStyle) : _captionStyle(d.helperColor, d.helperStyle),
        ),
        textDirection: _textDirection,
        ellipsis: '…',
        maxLines: (error ? d.errorMaxLines : d.helperMaxLines) ?? (error ? 2 : 1),
      )..layout(maxWidth: size.width);
      final counter = TextPainter(
          text: TextSpan(text: d.counter, style: _captionStyle(d.helperColor, d.counterStyle)), textDirection: _textDirection, maxLines: 1)
        ..layout();
      below = kFieldBelowGap + math.max(belowText.isEmpty ? 0.0 : line.height, d.counter.isEmpty ? 0.0 : counter.height);
      line.dispose();
      counter.dispose();
    }
    final box = math.max(0.0, size.height - above - below);
    return ControlInsets(math.min(above, size.height), math.max(0, size.height - above - box));
  }

  int _fontEpoch = -1;

  @override
  void performLayout() {
    // Fonts loaded since the last layout (a theme's family asked for late):
    // its texts are measured again, as a paragraph's are.
    final epoch = ControlLabel.fontEpoch;
    if (epoch != _fontEpoch) {
      _fontEpoch = epoch;
      for (final p in [_label, _hint, _below, _counter, _prefixText, _suffixText]) {
        p.markNeedsLayout();
      }
    }
    final d = decoration;
    size = _sizeFor(constraints);
    final width = size.width;
    final labelExtent = _labelExtent;
    if (d.label.isNotEmpty) _layoutLabel(width);
    _labelTop = 0;
    final boxTop = labelExtent;
    final double boxHeight;
    if (constraints.hasTightHeight) {
      boxHeight = math.max(0.0, size.height - labelExtent - _reservedBelow(width));
    } else {
      boxHeight = math.max(0.0, size.height - labelExtent - _belowExtent(width));
    }
    boxRect = Rect.fromLTWH(0, boxTop, width, boxHeight);
    scale = d.tokens.scaleFor(boxHeight >= 20 ? boxHeight : _defaultBoxHeight);
    final s = scale;
    final pad = _padding(s);
    // The slots.
    var left = boxRect.left + (d.prefix == null ? pad.left : 0);
    var right = boxRect.right - (d.suffix == null ? pad.right : 0);
    if (d.prefix case final FieldAffix a) {
      final slot = _affixWidth(a, s, prefix: true);
      var x = boxRect.left;
      if (a.button) {
        final size = _iconSize(a, s);
        _prefixIconRect = Rect.fromLTWH(x + (slot - size) / 2, boxRect.center.dy - size / 2, size, size);
      } else if (a.hasIcon) {
        final size = _iconSize(a, s);
        final p = a.padding;
        x += p == null ? pad.left : p.left;
        _prefixIconRect = Rect.fromLTWH(x, boxRect.center.dy - size / 2, size, size);
        x += size + (p == null ? 0 : p.right) + (a.hasText ? 4 : 0);
      } else {
        _prefixIconRect = Rect.zero;
        x += pad.left;
      }
      _prefixTextAt = Offset(x, 0);
      left = boxRect.left + slot;
    }
    if (d.suffix case final FieldAffix a) {
      final slot = _affixWidth(a, s, prefix: false);
      var x = boxRect.right;
      if (a.button) {
        final size = _iconSize(a, s);
        _suffixIconRect = Rect.fromLTWH(x - (slot + size) / 2, boxRect.center.dy - size / 2, size, size);
      } else if (a.hasIcon) {
        final size = _iconSize(a, s);
        final p = a.padding;
        x -= p == null ? pad.right : p.right;
        _suffixIconRect = Rect.fromLTWH(x - size, boxRect.center.dy - size / 2, size, size);
        x -= size + (p == null ? 0 : p.left) + (a.hasText ? 4 : 0);
      } else {
        _suffixIconRect = Rect.zero;
        x -= pad.right;
      }
      final shown = a.hasText && (a.alwaysVisible || affixTextsShown);
      _suffixTextAt = Offset(x - (shown ? _suffixText.width : 0), 0);
      right = boxRect.right - slot;
    }
    final contentWidth = math.max(0.0, right - left);
    // The content: one line centered (or as aligned), or lines from the
    // padding's top.
    final line = contentLineHeight;
    double top, height;
    if (contentMultiline) {
      final padTop = d.collapsed ? 0.0 : (d.contentPadding?.top ?? math.max(0.0, (_defaultBoxHeight - line) / 2));
      final padBottom = d.collapsed ? 0.0 : (d.contentPadding?.bottom ?? padTop);
      top = boxRect.top + padTop;
      height = math.max(line, boxRect.height - padTop - padBottom);
    } else {
      final free = boxRect.height - line;
      final y = _alignVertical?.y ?? 0;
      // Flutter's InputDecorator aligns a field with no outline border to the
      // top (textAlignVertical null): a padding given puts the line its top
      // below the box's top.
      final outlined = [d.border, d.enabledBorder, d.focusedBorder].any((b) => b?.kind == FieldBorderKind.outline);
      // A hugging box is never lower than the kit's default height
      // ([_hugBoxHeight]). Where that floor, not the padding, set the height,
      // the room it added is shared above and below the line: a borderless
      // field with no padding in a row (a search row) is level with the icon
      // beside it, not 4 px above it.
      final padded = d.contentPadding;
      final floorRoom =
          padded == null || d.collapsed || constraints.hasTightHeight ? 0.0 : math.max(0.0, free - padded.vertical);
      if (d.contentPadding != null && _alignVertical == null && !outlined) {
        top = boxRect.top + d.contentPadding!.top + floorRoom / 2;
      } else if (d.contentPadding != null && !d.collapsed && _alignVertical != null && _alignVertical!.y < 0) {
        top = boxRect.top + d.contentPadding!.top;
      } else {
        top = boxRect.top + free / 2 * (1 + y);
      }
      height = line;
    }
    contentRect = Rect.fromLTWH(_across(left, contentWidth), top, contentWidth, height);
    // An affix's text width, when its text shows (only then is its painter
    // laid out).
    bool shows(FieldAffix? a) => a != null && a.hasText && (a.alwaysVisible || affixTextsShown);
    final prefixTextWidth = shows(d.prefix) ? _prefixText.width : 0.0;
    final suffixTextWidth = shows(d.suffix) ? _suffixText.width : 0.0;
    _prefixTextAt = Offset(_across(_prefixTextAt.dx, prefixTextWidth), contentRect.top);
    _suffixTextAt = Offset(_across(_suffixTextAt.dx, suffixTextWidth), contentRect.top);
    if (_rtl) {
      _prefixIconRect = _prefixIconRect.isEmpty
          ? _prefixIconRect
          : Rect.fromLTWH(_across(_prefixIconRect.left, _prefixIconRect.width), _prefixIconRect.top, _prefixIconRect.width,
              _prefixIconRect.height);
      _suffixIconRect = _suffixIconRect.isEmpty
          ? _suffixIconRect
          : Rect.fromLTWH(_across(_suffixIconRect.left, _suffixIconRect.width), _suffixIconRect.top, _suffixIconRect.width,
              _suffixIconRect.height);
    }
    // The hint, in the content's place.
    _hint
      ..text = TextSpan(text: d.hint, style: hintStyle)
      ..textAlign = _hintAlign
      ..maxLines = contentMultiline ? d.hintMaxLines : 1
      ..layout(minWidth: contentWidth, maxWidth: contentWidth);
    // The line below.
    _belowTop = boxRect.bottom + kFieldBelowGap;
    if (belowText.isNotEmpty || d.counter.isNotEmpty) {
      _layoutBelow(width);
      if (d.counter.isNotEmpty) _layoutBelow(math.max(0, width - _counter.width - 8));
    }
    for (final (g, r) in [(_prefixGlyph, _prefixIconRect), (_suffixGlyph, _suffixIconRect)]) {
      if (g == null) continue;
      g.layout(BoxConstraints.tight(r.size));
      (g.parentData! as BoxParentData).offset = r.topLeft;
    }
    layoutContent(contentRect);
  }

  /// Which part of the frame [local] is on.
  FieldFramePart partAt(Offset local) {
    final d = decoration;
    if (d.prefix?.button ?? false) {
      if (buttonSlot(prefix: true).contains(local)) return FieldFramePart.prefixIcon;
    } else if (d.prefix?.tappable ?? false) {
      if (_prefixIconRect.inflate(6).contains(local)) return FieldFramePart.prefixIcon;
    }
    if (d.suffix?.button ?? false) {
      if (buttonSlot(prefix: false).contains(local)) return FieldFramePart.suffixIcon;
    } else if (d.suffix?.tappable ?? false) {
      if (_suffixIconRect.inflate(6).contains(local)) return FieldFramePart.suffixIcon;
    }
    if (boxRect.contains(local)) return FieldFramePart.box;
    if (local.dy < boxRect.top) return FieldFramePart.label;
    if (local.dy > boxRect.bottom) return FieldFramePart.below;
    return FieldFramePart.none;
  }

  /// The slot of a button affix (its whole height of the box, as wide as
  /// the box is high), at the start for the prefix (the end in RTL).
  Rect buttonSlot({required bool prefix}) {
    final w = math.min(boxRect.height, boxRect.width / 3);
    final atStart = prefix != _rtl;
    return atStart ? Rect.fromLTWH(boxRect.left, boxRect.top, w, boxRect.height) : Rect.fromLTWH(boxRect.right - w, boxRect.top, w, boxRect.height);
  }

  /// Whether a button affix can't be pressed now (a stepper at its bound).
  bool affixDisabled({required bool prefix}) => false;

  FieldFramePart? _hoverPart;

  /// The part of the frame under the pointer (a button affix is tinted).
  set hoverPart(FieldFramePart? v) {
    if (v == _hoverPart) return;
    _hoverPart = v;
    markNeedsPaint();
  }

  FieldFramePart? get hoverPart => hovered ? _hoverPart : null;

  // --- paint ----------------------------------------------------------------------------

  /// The border drawn now (its states included).
  FieldBorder get currentBorder =>
      decoration.borderFor(focused: focusNode.hasFocus, hovered: hovered, enabled: enabled && decoration.enabled);

  /// The box's outline now.
  RRect get boxShape {
    final b = currentBorder;
    final r = b.radius ?? decoration.border?.radius ?? BorderRadius.circular(decoration.tokens.radiusFor(scale));
    return r.toRRect(boxRect);
  }

  /// The fill now (null: none), its hover or focus color over it.
  Color? get fillNow {
    final d = decoration;
    var fill = d.fill;
    if (fill == null) return null;
    if (hovered && d.hoverColor != null) fill = Color.alphaBlend(d.hoverColor!, fill);
    if (focusNode.hasFocus && d.focusColor != null) fill = Color.alphaBlend(d.focusColor!, fill);
    return fill;
  }

  /// The label's color, the line below's (the error's red in error).
  Color get labelColor => _labelStyle.color ?? decoration.labelColor;
  Color get belowColor => (decoration.hasError && decoration.errorMessage.isNotEmpty)
      ? (decoration.errorStyle?.color ?? decoration.errorColor)
      : (decoration.helperStyle?.color ?? decoration.helperColor);

  /// Whether the hint shows now.
  bool get hintShown => contentEmpty && decoration.hint.isNotEmpty;

  /// Where the label's glyphs are (local).
  Rect get labelRect => decoration.label.isEmpty ? Rect.zero : Offset(_rtl ? size.width - _label.width : 0, _labelTop) & _label.size;

  /// Where the line below is (local; empty when none).
  Rect get belowRect => belowText.isEmpty ? Rect.zero : Offset(0, _belowTop) & _below.size;

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  /// The alpha it was last painted at (a disabled field 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled || !decoration.enabled) {
      _opacity.layer = context.pushOpacity(offset, 128, _paintFrame, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintFrame(context, offset);
  }

  void _paintFrame(PaintingContext context, Offset offset) {
    final d = decoration;
    final canvas = context.canvas;
    if (d.label.isNotEmpty) _label.paint(canvas, offset + Offset(_rtl ? size.width - _label.width : 0, _labelTop));
    final shape = boxShape.shift(offset);
    if (fillNow case final Color fill when fill.a > 0) canvas.drawRRect(shape, Paint()..color = fill);
    // The affixes.
    for (final (a, prefix) in [(d.prefix, true), (d.suffix, false)]) {
      if (a == null || !a.hasText || !(a.alwaysVisible || affixTextsShown)) continue;
      final p = prefix ? _prefixText : _suffixText;
      final at = prefix ? _prefixTextAt : _suffixTextAt;
      p.paint(canvas, offset + Offset(at.dx, contentRect.top + (contentLineHeight - p.height) / 2));
    }
    // A button affix (a stepper's minus and plus): tinted under the pointer,
    // ruled off from the value by a hairline of the border's color.
    for (final (a, prefix) in [(d.prefix, true), (d.suffix, false)]) {
      if (a == null || !a.button) continue;
      final slot = buttonSlot(prefix: prefix).shift(offset);
      final part = prefix ? FieldFramePart.prefixIcon : FieldFramePart.suffixIcon;
      if (hoverPart == part && enabled && !affixDisabled(prefix: prefix)) {
        canvas
          ..save()
          ..clipRRect(shape)
          ..drawRect(slot, Paint()..color = d.tokens.hoverOverlay)
          ..restore();
      }
      final rule = decoration.borderFor(focused: false, hovered: false, enabled: enabled && d.enabled);
      final x = (prefix != _rtl) ? slot.right - .5 : slot.left + .5;
      canvas.drawLine(Offset(x, slot.top), Offset(x, slot.bottom),
          Paint()
            ..color = rule.side.color.a > 0 ? rule.side.color : d.tokens.primaryBorder
            ..strokeWidth = 1);
    }
    for (final g in _frameChildren) {
      final dim = (identical(g, _prefixGlyph) && (d.prefix?.button ?? false) && affixDisabled(prefix: true)) ||
          (identical(g, _suffixGlyph) && (d.suffix?.button ?? false) && affixDisabled(prefix: false));
      final at = offset + (g.parentData! as BoxParentData).offset;
      if (dim) {
        context.pushOpacity(at, 90, (context, offset) => context.paintChild(g, offset));
      } else {
        context.paintChild(g, at);
      }
    }
    // The hint and the content, inside the box.
    final clip = d.collapsed ? (Offset.zero & size) : boxRect;
    _clip.layer = context.pushClipRect(needsCompositing, offset, clip, (context, offset) {
      if (hintShown) _hint.paint(context.canvas, offset + contentRect.topLeft + Offset(0, hintBaselineShift));
      paintContent(context, offset);
    }, oldLayer: _clip.layer);
    // The clip may have pushed a layer: draw on the canvas after it.
    final over = context.canvas;
    // The border over the content (it never moves it).
    final b = currentBorder;
    if (b.kind != FieldBorderKind.none && b.side.width > 0 && b.side.color.a > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b.side.width
        ..color = b.side.color;
      if (b.kind == FieldBorderKind.outline) {
        over.drawRRect(shape.deflate(b.side.width / 2), paint);
      } else {
        final y = shape.bottom - b.side.width / 2;
        over.drawLine(Offset(shape.left, y), Offset(shape.right, y), paint);
      }
    }
    if (d.focusRingWidth > 0 && focusNode.hasFocus && d.focusRingColor != null) {
      paintFocusRing(over, shape, d.focusRingColor!, width: d.focusRingWidth);
    }
    final below = belowText;
    if (below.isNotEmpty) _below.paint(over, offset + Offset(_rtl ? size.width - _below.width : 0, _belowTop));
    if (d.counter.isNotEmpty) {
      _counter.paint(over, offset + Offset(_rtl ? 0 : size.width - _counter.width, _belowTop));
    }
  }

  // --- what tools and the guard read --------------------------------------------------------

  /// The texts the frame draws itself: its label, hint (while shown) and
  /// the line below, with their glyph boxes.
  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels {
    if (!hasSize) return const [];
    final d = decoration;
    List<Rect> glyphs(TextPainter p, Offset at) {
      final text = p.plainText;
      if (text.isEmpty) return const [];
      return [
        for (final b in p.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
          boxHeightStyle: ui.BoxHeightStyle.tight,
        ))
          b.toRect().shift(at),
      ];
    }

    return [
      if (d.label.isNotEmpty)
        (text: d.label, fontFamily: _labelStyle.fontFamily, glyphs: glyphs(_label, Offset(0, _labelTop))),
      if (hintShown) (text: d.hint, fontFamily: hintStyle.fontFamily, glyphs: glyphs(_hint, contentRect.topLeft)),
      if (belowText.isNotEmpty)
        (text: belowText, fontFamily: _below.text?.style?.fontFamily, glyphs: glyphs(_below, Offset(0, _belowTop))),
    ];
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final d = decoration;
    if (d.hint.isNotEmpty) config.hint = d.hint;
    final below = belowText;
    if (below.isNotEmpty) config.hint = d.hint.isEmpty ? below : '${d.hint}\n$below';
  }

  @override
  String get semanticsName => decoration.label;

  @override
  void dispose() {
    for (final p in [_label, _hint, _below, _counter, _prefixText, _suffixText]) {
      p.dispose();
    }
    _opacity.layer = null;
    _clip.layer = null;
    super.dispose();
  }
}
