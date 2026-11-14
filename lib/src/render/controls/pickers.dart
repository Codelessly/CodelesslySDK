// Date and time pickers as render objects: `datePicker`, `timePicker` and
// `dateTimeInput`, with no Material widget in their path (no
// `showDatePicker`, no `showTimePicker`, no dialog route).
//
// The face is SSUI's select trigger (its date and time pickers' closed
// state): a field on the control scale (28 high when it hugs), a calendar
// or clock icon before the value, a chevron after it, the 1 px hairline
// that darkens under the pointer and turns into the 1.5 px focus border
// while focused or open, the error color in error, 50 % when disabled.
// The field is drawn here until workstream A's field frame
// (render/controls/field_frame.dart) lands, which it should then use.
//
// A tap, Enter, Space, Up or Down opens the picker as an entry of the
// root's overlay layer (render/controls/kit_pickers.dart): a popover under
// the field on a wide view, a bottom sheet on a narrow one; a tap outside
// or Escape closes it. Dates are picked in SSUI's calendar
// (render/controls/calendar.dart), times in hour and minute columns
// (render/controls/time_dial.dart; SSUI has no dial). A pick writes the
// value back as the node's `changed` (`yyyy-MM-dd`, `HH:mm`, or a UTC
// date-time for a date and time).
import 'dart:async' show scheduleMicrotask;
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show DatePickerProps, DateTimeInputMode, DateTimeInputPicker, DateTimeInputProps, Json, Node, PickerFieldProps, TimePickerProps, readInt, readString;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, fireTrigger;
import '../paint/icon_glyph.dart';
import '../paint/icon_names.dart';
import '../recipe.dart';
import 'calendar.dart';
import 'kit.dart';
import 'kit_pickers.dart';
import 'root.dart';
import 'time_dial.dart';
import 'tokens.dart';

/// What a picker picks.
enum PickerKind { date, time, dateTime }

/// The recipe of `datePicker`, `timePicker` and `dateTimeInput`
/// (lib/src/widgets/controls.dart registers it with intl's [locale]).
void pickerRecipe(NodeBuilder b, Node n, List<RenderBox> chain, {PickerLocale locale = PickerLocale.english}) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final spec = PickerSpec.of(n, ControlTokens.of(b), locale, inherited: b.slot.textDefault);
  final box = b.obtain<RenderPickerField>('picker', RenderPickerField.new)
    ..interactive = interactive
    ..spec = spec
    ..onChanged = interactive ? (value) => fireTrigger(b, 'changed', event: {'value': value}) : null
    // With the design's own picker (`picker: none`) a tap is the node's
    // click (its reactions take it); Enter is too.
    ..onClick = interactive ? () => fireTrigger(b, 'click') : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.enabled = spec.enabled && !states.contains(api.WidgetState.disabled);
  chain.add(box);
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!box.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

/// What a picker shows and picks, resolved from its node: everything but
/// its states and what the user picked since.
@immutable
class PickerSpec {
  const PickerSpec({
    required this.kind,
    required this.tokens,
    required this.colors,
    required this.locale,
    this.value = '',
    this.first,
    this.last,
    this.enabled = true,
    this.opens = true,
    this.use24h = false,
    this.pattern,
    this.readable = false,
    this.style = const TextStyle(),
    this.ownColor,
    this.hint,
    this.hintStyle,
    this.placeholder = 'Select date',
    this.decoration = api.InputDecoration.empty,
    this.helpText = '',
    this.displayText = '',
    this.bare = false,
    this.icon,
    this.padding,
  });

  final PickerKind kind;
  final ControlTokens tokens;
  final PickerColors colors;
  final PickerLocale locale;

  /// The bound value (ISO).
  final String value;

  /// The days that may be picked.
  final DateTime? first, last;
  final bool enabled;

  /// Whether a tap opens the picker (`dateTimeInput`'s `picker: none`
  /// leaves the tap to the node's reactions).
  final bool opens;

  /// 24-hour time in the picker and the default text.
  final bool use24h;

  /// The value's intl pattern (null or empty: the default text).
  final String? pattern;

  /// The default text reads as words (`Thu, Nov 12`, `9:05 AM`: a
  /// `dateTimeInput`) rather than ISO (`2026-11-12`, `09:05`).
  final bool readable;

  /// The node's value style (its own fields over the default text style it
  /// is under), and its own color.
  final TextStyle style;
  final Color? ownColor;

  /// Shown while empty, in [hintStyle] (else SSUI's placeholder color).
  final String? hint;
  final TextStyle? hintStyle;

  /// Shown while empty when there is no [hint].
  final String placeholder;
  final api.InputDecoration decoration;
  final String helpText;

  /// Shown instead of the value (a `dateTimeInput`'s bound display text).
  final String displayText;

  /// Only the value and its icon (a `dateTimeInput`'s `bare`): the node
  /// draws the box.
  final bool bare;

  /// The icon after the value (a `dateTimeInput`'s `icon`).
  final api.InputIcon? icon;

  /// The node's own padding (null: the scale's).
  final EdgeInsets? padding;

  bool get decorated => decoration != api.InputDecoration.empty;

  /// [n]'s picker in [tokens], reading names and now from [locale].
  factory PickerSpec.of(Node n, ControlTokens tokens, PickerLocale locale, {api.TextStyle? inherited}) {
    final padding = n.layout.padding == api.EdgeInsets.zero ? null : n.layout.padding.flutter;
    switch (n.type) {
      case 'dateTimeInput':
        final mode = n.prop(DateTimeInputProps.mode);
        var first = parseDay(n.prop(DateTimeInputProps.firstDate));
        var last = parseDay(n.prop(DateTimeInputProps.lastDate));
        if (mode != DateTimeInputMode.time) {
          final lower = parseDay(n.prop(DateTimeInputProps.min)), upper = parseDay(n.prop(DateTimeInputProps.max));
          if (lower != null && (first == null || lower.isAfter(first))) first = lower;
          if (upper != null && (last == null || upper.isBefore(last))) last = upper;
        }
        final d = n.prop(DateTimeInputProps.decoration);
        final own = n.prop(DateTimeInputProps.style);
        final hintStyle = n.prop(DateTimeInputProps.hintStyle);
        final label = n.prop(DateTimeInputProps.labelText);
        final kind = switch (mode) {
          DateTimeInputMode.date => PickerKind.date,
          DateTimeInputMode.time => PickerKind.time,
          DateTimeInputMode.dateTime => PickerKind.dateTime,
        };
        return PickerSpec(
          kind: kind,
          tokens: tokens,
          colors: PickerColors.of(tokens, null),
          locale: locale,
          value: n.prop(DateTimeInputProps.value),
          first: first,
          last: last,
          enabled: n.prop(DateTimeInputProps.enabled),
          opens: n.prop(DateTimeInputProps.picker) == DateTimeInputPicker.dialog,
          pattern: n.prop(DateTimeInputProps.format),
          readable: true,
          style: _style(own, inherited),
          ownColor: own.color?.flutter,
          hint: d.hintText ?? n.prop(DateTimeInputProps.hint) ?? (label != null && label.isNotEmpty ? label : null),
          hintStyle: hintStyle.isEmpty ? null : _style(hintStyle, inherited).copyWith(color: hintStyle.color?.flutter),
          placeholder: _placeholder(kind),
          decoration: d,
          displayText: n.prop(DateTimeInputProps.displayText),
          bare: n.prop(DateTimeInputProps.bare),
          icon: d.suffixIcon ?? n.prop(DateTimeInputProps.icon),
          padding: padding,
        );
      default:
        final time = n.type == TimePickerProps.spec.type;
        final d = n.prop(PickerFieldProps.decoration);
        final own = n.prop(PickerFieldProps.style);
        final hs = d.hintStyle;
        final kind = time ? PickerKind.time : PickerKind.date;
        return PickerSpec(
          kind: kind,
          tokens: tokens,
          colors: PickerColors.of(tokens, n.prop(PickerFieldProps.pickerTheme)),
          locale: locale,
          value: n.prop(time ? TimePickerProps.value : DatePickerProps.value),
          first: time ? null : parseDay(n.prop(DatePickerProps.firstDate)),
          last: time ? null : parseDay(n.prop(DatePickerProps.lastDate)),
          enabled: n.prop(time ? TimePickerProps.enabled : DatePickerProps.enabled),
          use24h: time && n.prop(TimePickerProps.alwaysUse24HourFormat),
          pattern: n.prop(PickerFieldProps.format),
          style: _style(own, inherited),
          ownColor: own.color?.flutter,
          hint: d.hintText,
          hintStyle: hs.isEmpty ? null : _style(hs, inherited).copyWith(color: hs.color?.flutter),
          placeholder: _placeholder(kind),
          decoration: d,
          helpText: n.prop(PickerFieldProps.helpText),
          icon: d.suffixIcon,
          padding: padding,
        );
    }
  }

  static String _placeholder(PickerKind k) => switch (k) {
        PickerKind.date => 'Select date',
        PickerKind.time => 'Select time',
        PickerKind.dateTime => 'Select date and time',
      };

  // --- the value ------------------------------------------------------------------

  /// [raw]'s day, when it has one.
  DateTime? dayOf(String raw) => kind == PickerKind.time ? null : parseDay(raw);

  /// [raw]'s time of day (minutes since midnight), when it has one.
  int? clockOf(String raw) => switch (kind) {
        PickerKind.date => null,
        PickerKind.time => parseClock(raw),
        PickerKind.dateTime => switch (DateTime.tryParse(raw)) {
            null => null,
            final d => d.hour * 60 + d.minute,
          },
      };

  /// Whether [raw] is a value (else the field shows its hint).
  bool hasValue(String raw) => switch (kind) {
        PickerKind.date => dayOf(raw) != null,
        PickerKind.time => clockOf(raw) != null,
        PickerKind.dateTime => dayOf(raw) != null && clockOf(raw) != null,
      };

  /// The text the field shows for [raw]: the display text, else the value
  /// in its pattern, else the default, else '' (empty).
  String textOf(String raw) {
    if (displayText.isNotEmpty) return displayText;
    if (!hasValue(raw)) return '';
    final day = dayOf(raw), clock = clockOf(raw);
    final at = DateTime(day?.year ?? 2000, day?.month ?? 1, day?.day ?? 1, (clock ?? 0) ~/ 60, (clock ?? 0) % 60);
    final p = pattern;
    if (p != null && p.trim().isNotEmpty) {
      if (locale.format(p, at) case final String s) return s;
    }
    return switch (kind) {
      PickerKind.date => readable ? mediumDay(day!, locale) : isoDay(day!),
      PickerKind.time => readable ? readableClock(clock!, locale, use24h: use24h) : isoClock(clock!),
      PickerKind.dateTime => '${mediumDay(day!, locale)} · ${readableClock(clock!, locale, use24h: use24h)}',
    };
  }

  /// The value written back for [day] and [clock].
  String write(DateTime? day, int? clock) => switch (kind) {
        PickerKind.date => isoDay(day!),
        PickerKind.time => isoClock(clock!),
        PickerKind.dateTime => DateTime.utc(day!.year, day.month, day.day, clock! ~/ 60, clock % 60).toIso8601String(),
      };

  /// Whether a day can be picked at all.
  bool get pickable => kind == PickerKind.time || first == null || last == null || !first!.isAfter(last!);

  @override
  bool operator ==(Object other) =>
      other is PickerSpec &&
      other.kind == kind &&
      other.tokens.theme == tokens.theme &&
      other.tokens.dark == tokens.dark &&
      other.tokens.backdrop == tokens.backdrop &&
      other.colors == colors &&
      identical(other.locale, locale) &&
      other.value == value &&
      other.first == first &&
      other.last == last &&
      other.enabled == enabled &&
      other.opens == opens &&
      other.use24h == use24h &&
      other.pattern == pattern &&
      other.readable == readable &&
      other.style == style &&
      other.ownColor == ownColor &&
      other.hint == hint &&
      other.hintStyle == hintStyle &&
      other.placeholder == placeholder &&
      other.decoration == decoration &&
      other.helpText == helpText &&
      other.displayText == displayText &&
      other.bare == bare &&
      other.icon == icon &&
      other.padding == padding;

  @override
  int get hashCode => Object.hash(kind, value, enabled, pattern, displayText, hint, decoration);
}

/// The node's own text fields over the default text style it is under (its
/// color is the node's own only: [PickerSpec.ownColor]).
TextStyle _style(api.TextStyle own, api.TextStyle? inherited) {
  final s = inherited == null ? own : inherited.merge(own);
  final w = s.fontWeight;
  return TextStyle(
    fontFamily: s.fontFamily,
    fontSize: s.fontSize,
    fontWeight: w == null ? null : FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)],
    fontStyle: s.fontStyle == null ? null : FontStyle.values.byName(s.fontStyle!.name),
    letterSpacing: s.letterSpacing,
    height: s.height,
  );
}

/// An input icon's glyph as the icon render object draws it.
Json _glyph(Json glyph) {
  if (glyph.isEmpty || glyph['show'] == false) return const {};
  final codepoint = readInt(glyph['codepoint']);
  if ((codepoint == null || codepoint <= 0) && readString(glyph['image']) == null) {
    if (readString(glyph['name']) case final String name when name.isNotEmpty) return iconWithName(glyph, name);
  }
  return glyph;
}

// --- the field --------------------------------------------------------------------

/// A picker's face: SSUI's select trigger, which opens the picker.
class RenderPickerField extends RenderControl implements LabeledControl {
  RenderPickerField() {
    focusNode.onKey = _key;
  }

  final ControlLabel _label = ControlLabel();
  RenderIconGlyph? _prefix, _suffix;

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app).
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) {
      focusNode.leave();
      close();
    }
    markNeedsPaint();
  }

  PickerSpec? _spec;
  PickerSpec get spec => _spec!;
  set spec(PickerSpec v) {
    if (v == _spec) return;
    // A new bound value (another field set it, a reset) wins over the last
    // pick.
    if (_spec != null && v.value != _spec!.value) _picked = null;
    _spec = v;
    _syncIcons();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  /// Writes a pick back (the node's `changed`).
  ValueChanged<String>? onChanged;

  /// The node's click (with `picker: none`).
  VoidCallback? onClick;

  String? _picked;

  /// The value shown: the last pick, else the bound value.
  String get value => _picked ?? spec.value;

  /// The text shown ('' while empty: the hint shows).
  String get text => spec.textOf(value);

  bool get _empty => text.isEmpty;

  /// What shows: the value's text or the hint.
  String get shown => _empty ? (spec.hint ?? spec.placeholder) : text;

  @override
  String get semanticsName => spec.helpText.isNotEmpty ? spec.helpText : spec.placeholder.replaceFirst('Select ', 'Pick a ');

  // --- the icons --------------------------------------------------------------------

  void _syncIcons() {
    final s = spec;
    final prefix = s.decoration.prefixIcon;
    _prefix = _setGlyph(_prefix, prefix == null ? null : _glyph(prefix.icon), prefix?.color?.flutter);
    final suffix = s.icon;
    _suffix = _setGlyph(_suffix, suffix == null ? null : _glyph(suffix.icon), suffix?.color?.flutter);
  }

  RenderIconGlyph? _setGlyph(RenderIconGlyph? old, Json? glyph, Color? color) {
    if (glyph == null || glyph.isEmpty) {
      if (old != null) dropChild(old);
      return null;
    }
    final g = old ?? RenderIconGlyph();
    if (old == null) adoptChild(g);
    g
      ..icon = glyph
      ..color = color ?? _iconInk;
    return g;
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_prefix != null) visitor(_prefix!);
    if (_suffix != null) visitor(_suffix!);
  }

  @override
  void redepthChildren() {
    if (_prefix != null) redepthChild(_prefix!);
    if (_suffix != null) redepthChild(_suffix!);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  // --- geometry ---------------------------------------------------------------------

  ControlScale _scaleAt(double h) => spec.tokens.scaleFor(h);

  /// SSUI's field text at [scale] (12.5 at small, as its fields).
  double _fontSize(ControlScale scale) => spec.style.fontSize ?? (scale.name == 'small' ? 12.5 : scale.fontSize);

  /// Its padding: the decoration's, the node's, else SSUI's (the scale's
  /// `paddingX`).
  EdgeInsets _padding(ControlScale scale) =>
      spec.decoration.contentPadding?.flutter ?? spec.padding ?? (spec.bare ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: scale.paddingX - 2));

  double _iconSize(ControlScale scale) => spec.bare ? 16 : scale.iconSize;

  bool get _leadingIcon => !spec.bare && (spec.decorated ? _prefix != null : true);
  bool get _trailingIcon => spec.bare || (spec.decorated ? _suffix != null : true);

  double get _naturalHeight {
    final t = spec.tokens;
    final scale = _scaleAt(t.defaultHeight);
    final line = _fontSize(scale) * (spec.style.height ?? 1.25);
    final pad = _padding(scale);
    if (spec.bare) return math.max(line, _iconSize(scale)) + pad.vertical;
    return pad.vertical == 0 ? t.defaultHeight : math.max(t.defaultHeight, line + pad.vertical);
  }

  double _heightFor(BoxConstraints c) => c.hasTightHeight ? c.maxHeight : c.constrainHeight(_naturalHeight);

  TextStyle _textStyle(ControlScale scale, Color color) {
    final own = spec.style;
    final hint = _empty && spec.hintStyle != null ? spec.hintStyle! : null;
    final base = TextStyle(
      fontFamily: own.fontFamily ?? spec.tokens.fontFamily,
      fontSize: _fontSize(scale),
      fontWeight: own.fontWeight ?? FontWeight.w400,
      fontStyle: own.fontStyle,
      letterSpacing: own.letterSpacing ?? 0,
      height: own.height ?? 1.25,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
    );
    return hint == null ? base : base.merge(hint.copyWith(color: hint.color ?? color));
  }

  double _naturalWidth(double height) {
    final scale = _scaleAt(height);
    final pad = _padding(scale);
    _label.update(shown, _textStyle(scale, const Color(0xFF000000)), align: TextAlign.left);
    var w = pad.horizontal + _label.intrinsicWidth;
    if (_leadingIcon) w += _prefixSize(scale) + scale.gap;
    if (_trailingIcon) w += _suffixSize(scale) + scale.gap;
    return w.ceilToDouble();
  }

  double _prefixSize(ControlScale scale) => _prefix != null ? (spec.decoration.prefixIcon?.size ?? 24).clamp(8, 48).toDouble() : _iconSize(scale);
  double _suffixSize(ControlScale scale) => _suffix != null ? (spec.icon?.size ?? 24).clamp(8, 48).toDouble() : _iconSize(scale);

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

  late ControlScale _scale;
  Rect _prefixRect = Rect.zero, _suffixRect = Rect.zero;
  double _labelLeft = 0, _labelWidth = 0;

  @override
  void performLayout() {
    final h = _heightFor(constraints);
    size = constraints.constrain(Size(_naturalWidth(h), h));
    final scale = _scale = _scaleAt(size.height);
    final pad = _padding(scale);
    var left = pad.left, right = size.width - pad.right;
    final cy = pad.top + (size.height - pad.vertical) / 2;
    if (_leadingIcon) {
      final s = _prefixSize(scale);
      _prefixRect = Rect.fromCenter(center: Offset(left + s / 2, cy), width: s, height: s);
      left += s + scale.gap;
    }
    if (_trailingIcon) {
      final s = _suffixSize(scale);
      _suffixRect = Rect.fromCenter(center: Offset(right - s / 2, cy), width: s, height: s);
      right -= s + scale.gap;
    }
    _labelLeft = left;
    _labelWidth = math.max(0, right - left);
    _label.update(shown, _textStyle(scale, const Color(0xFF000000)), align: TextAlign.left);
    _label.layout(_labelWidth);
    _prefix?.layout(BoxConstraints.tight(_prefixRect.size));
    _suffix?.layout(BoxConstraints.tight(_suffixRect.size));
    (_prefix?.parentData as BoxParentData?)?.offset = _prefixRect.topLeft;
    (_suffix?.parentData as BoxParentData?)?.offset = _suffixRect.topLeft;
  }

  double get _centerY {
    final pad = _padding(_scale);
    return pad.top + (size.height - pad.vertical) / 2;
  }

  // --- the look ---------------------------------------------------------------------

  bool get open => _popup != null;

  bool get _error {
    final e = spec.decoration.errorText;
    return e != null && e.isNotEmpty;
  }

  Color get _primaryText => spec.tokens.onSurface;
  Color get _tertiaryText => spec.tokens.theme.color('tertiaryText')?.flutter ?? _primaryText.withValues(alpha: .45);
  Color get _iconInk => spec.bare ? (spec.ownColor ?? _primaryText) : _tertiaryText;

  /// The value's color now (the hint's while empty).
  Color get labelColor => _empty ? (spec.hintStyle?.color ?? _tertiaryText) : (spec.ownColor ?? _primaryText);

  /// The fill now (null: none).
  Color? get fillColor {
    if (spec.bare) return null;
    final d = spec.decoration;
    if (spec.decorated) return d.filled == true ? (d.fillColor?.flutter ?? spec.tokens.surface) : null;
    return spec.tokens.surface;
  }

  /// Whether it draws focused (keyboard focus, or its picker open).
  bool get _focusedLook => open || focusHighlight;

  /// The border now: its kind, side and corners (null: none).
  ({api.InputBorderType type, BorderSide side, BorderRadius radius})? get border {
    if (spec.bare) return null;
    final t = spec.tokens;
    final d = spec.decoration;
    final radius = BorderRadius.circular(t.radiusFor(_scaleAt(hasSize ? size.height : t.defaultHeight)));
    // SSUI's: the hairline, darker hovered, the focus border, the error.
    final ssuiColor = _error ? t.error : _focusedLook ? t.focusBorder : hovered ? t.secondaryBorder : t.primaryBorder;
    final ssuiWidth = _focusedLook ? 1.5 : 1.0;
    if (!spec.decorated) return (type: api.InputBorderType.outline, side: BorderSide(color: ssuiColor, width: ssuiWidth), radius: radius);
    final own = (_error ? (_focusedLook ? d.focusedErrorBorder ?? d.errorBorder : d.errorBorder) : null) ??
        (!enabled ? d.disabledBorder : null) ??
        (_focusedLook ? d.focusedBorder : null) ??
        d.enabledBorder ??
        d.border;
    if (own == null) return (type: api.InputBorderType.outline, side: BorderSide(color: ssuiColor, width: ssuiWidth), radius: radius);
    final s = own.borderSide;
    // A border of the node's own color keeps it; one without takes SSUI's
    // state color.
    final color = s.color?.flutter ?? ssuiColor;
    return (type: own.type, side: BorderSide(color: color, width: _focusedLook && s.color == null ? 1.5 : s.width), radius: own.borderRadius.flutter);
  }

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => !hasSize || shown.isEmpty
      ? const []
      : [(text: shown, fontFamily: _label.fontFamily, glyphs: _label.glyphBoxes(_labelLeft, _centerY))];

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// The alpha it was last painted at (a disabled field 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    if (_spec == null) return;
    // The icons' color follows the states (set outside paint).
    if (spec.decoration.prefixIcon?.color == null) _prefix?.color = _iconInk;
    if (spec.icon?.color == null) _suffix?.color = _iconInk;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled) {
      _opacity.layer = context.pushOpacity(offset, 128, _paintField, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintField(context, offset);
  }

  void _paintField(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final b = border;
    final rrect = b == null ? RRect.fromRectAndRadius(rect, Radius.zero) : b.radius.toRRect(rect);
    if (fillColor case final Color fill when fill.a > 0) {
      canvas.drawRRect(b?.type == api.InputBorderType.outline ? rrect : RRect.fromRectAndRadius(rect, Radius.zero), Paint()..color = fill);
    }
    if (spec.decorated && hovered) {
      if (spec.decoration.hoverColor?.flutter case final Color h) canvas.drawRRect(rrect, Paint()..color = h);
    }
    if (b != null && b.side.width > 0 && b.side.color.a > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b.side.width
        ..color = b.side.color;
      switch (b.type) {
        case api.InputBorderType.outline:
          canvas.drawRRect(rrect.deflate(b.side.width / 2), paint);
        case api.InputBorderType.underline:
          canvas.drawLine(rect.bottomLeft - Offset(0, b.side.width / 2), rect.bottomRight - Offset(0, b.side.width / 2), paint);
        case api.InputBorderType.none:
          break;
      }
    }
    final scale = _scale;
    if (_leadingIcon) {
      if (_prefix case final RenderIconGlyph g) {
        context.paintChild(g, offset + _prefixRect.topLeft);
      } else {
        final s = _prefixRect.size.width;
        paintPickerGlyph(canvas, spec.kind == PickerKind.time ? PickerGlyph.clock : PickerGlyph.calendar,
            Rect.fromCenter(center: offset + _prefixRect.center, width: s, height: s), _iconInk);
      }
    }
    if (_trailingIcon) {
      if (_suffix case final RenderIconGlyph g) {
        context.paintChild(g, offset + _suffixRect.topLeft);
      } else {
        final r = (offset + _suffixRect.topLeft) & _suffixRect.size;
        if (spec.bare) {
          paintPickerGlyph(canvas, spec.kind == PickerKind.time ? PickerGlyph.clock : PickerGlyph.calendar, r, _iconInk);
        } else {
          // SSUI's chevron turns up while the picker is open.
          if (open) {
            canvas.save();
            canvas.translate(r.center.dx, r.center.dy);
            canvas.rotate(math.pi);
            canvas.translate(-r.center.dx, -r.center.dy);
          }
          paintPickerGlyph(canvas, PickerGlyph.chevronDown, r, _iconInk);
          if (open) canvas.restore();
        }
      }
    }
    _label.update(shown, _textStyle(scale, labelColor), align: TextAlign.left);
    _label.layout(_labelWidth);
    _label.paint(canvas, offset.dx + _labelLeft, offset.dy + _centerY);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final o = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  // --- pointer and keys ---------------------------------------------------------

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    // With the design's own picker the node's reactions take the tap.
    if (_interactive && spec.opens) super.handleEvent(event, entry);
  }

  @override
  MouseCursor get cursor => _interactive && spec.opens ? super.cursor : MouseCursor.defer;

  @override
  void activate() {
    if (!enabled || !_interactive) return;
    if (!spec.opens) {
      onClick?.call();
      return;
    }
    open ? close() : openPicker();
  }

  bool _key(KeyEvent event) {
    final popup = _panel;
    if (popup != null) {
      if (event is KeyUpEvent) return false;
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape) {
        close();
        return true;
      }
      if (key == LogicalKeyboardKey.tab) {
        close();
        return false;
      }
      return popup.handleKey(event);
    }
    if (event is KeyDownEvent &&
        spec.opens &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      openPicker(byKeyboard: true);
      return true;
    }
    return false;
  }

  // --- the picker ---------------------------------------------------------------------

  RenderPickerPopup? _popup;
  RenderPickerPanel? _panel;
  RenderControlRoot? _root;

  /// The popup showing (null: closed).
  RenderPickerPopup? get popup => _popup;

  /// Its panel, while open.
  RenderPickerPanel? get panel => _panel;

  /// Opens the picker in the root's overlay layer; [byKeyboard] shows the
  /// keyboard's cursor in it from the start.
  void openPicker({bool byKeyboard = false}) {
    if (_popup != null || !spec.opens || !spec.pickable || !enabled || !_interactive || !attached || !hasSize) return;
    final root = RenderControlRoot.of(this);
    if (root == null || !root.hasSize) return;
    final anchor = MatrixUtils.transformRect(getTransformTo(root), Offset.zero & size);
    // Narrow is the screen's width (a small embedded root on a wide screen
    // still opens a popover).
    RenderObject top = root;
    while (top.parent != null) {
      top = top.parent!;
    }
    final screen = top is RenderView ? top.size.width : root.size.width;
    final sheet = screen < kPickerSheetBreakpoint;
    final panel = RenderPickerPanel(
      spec: spec,
      value: value,
      sheet: sheet,
      keyboard: byKeyboard,
      onCommit: _commit,
      onCancel: close,
    );
    final popup = RenderPickerPopup(
      panel: panel,
      anchorRect: anchor,
      sheet: sheet,
      scrim: spec.colors.scrim,
      onDismiss: close,
      semanticsLabel: spec.helpText.isNotEmpty ? spec.helpText : spec.placeholder,
    );
    _root = root..showOverlay(popup);
    _popup = popup;
    _panel = panel;
    focusNode.requestFocus();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// Closes the picker (nothing picked).
  void close() {
    final p = _popup;
    if (p == null) return;
    _popup = null;
    _panel = null;
    _root?.hideOverlay(p);
    _root = null;
    p.dispose();
    if (attached) {
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  void _commit(String value) {
    _picked = value;
    close();
    markNeedsLayout();
    onChanged?.call(value);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _prefix?.attach(owner);
    _suffix?.attach(owner);
    if (!_interactive) focusNode.leave();
  }

  @override
  void detach() {
    // The whole root going away (it detaches its entries after its
    // content): the popup goes once it has.
    if (_root case final RenderControlRoot root when !root.attached) {
      scheduleMicrotask(() {
        // Back on screen (a root moved): take the popup away; else the root
        // went with it.
        if (root.attached) {
          close();
        } else {
          _popup = _panel = null;
          _root = null;
        }
      });
    } else {
      close();
    }
    super.detach();
    _prefix?.detach();
    _suffix?.detach();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isButton = true
      ..value = _empty ? '' : text
      ..hint = _empty ? shown : '';
    if (spec.opens) config.isExpanded = open;
  }

  @override
  void dispose() {
    close();
    _label.dispose();
    _opacity.layer = null;
    super.dispose();
  }
}

// --- the panel ----------------------------------------------------------------------

/// What opens from a picker: its surface (SSUI's popover: the surface, a
/// hairline, `shadows.level3`, the control radius; or a sheet with its top
/// corners rounded at the dialog radius), the help text, then the calendar
/// or the time columns (a date and time: the calendar, then the time).
class RenderPickerPanel extends RenderBox {
  RenderPickerPanel({
    required PickerSpec spec,
    required String value,
    required this.sheet,
    required bool keyboard,
    required this.onCommit,
    required this.onCancel,
  }) : _spec = spec {
    final day = spec.dayOf(value);
    final clock = spec.clockOf(value);
    final now = spec.locale.now();
    if (spec.kind != PickerKind.time) {
      calendar = RenderCalendar(
        colors: spec.colors,
        symbols: spec.locale,
        today: now,
        value: day,
        first: spec.first,
        last: spec.last,
        onPicked: _pickedDay,
      )..keyboardCursor = keyboard;
      adoptChild(calendar!);
    }
    if (spec.kind != PickerKind.date) {
      time = RenderTimeColumns(
        colors: spec.colors,
        symbols: spec.locale,
        minutes: clock ?? now.hour * 60 + now.minute,
        use24h: spec.use24h,
        onDone: _pickedTime,
        onCancel: onCancel,
      )..keyboardCursor = keyboard;
      adoptChild(time!);
    }
    _onTime = spec.kind == PickerKind.time;
    _day = day;
  }

  final PickerSpec _spec;
  final bool sheet;

  /// Sets the value (ISO, as written back).
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  RenderCalendar? calendar;
  RenderTimeColumns? time;
  bool _onTime = false;
  DateTime? _day;

  /// What shows: the time columns (else the calendar).
  bool get showingTime => _onTime;

  RenderBox get active => _onTime ? time! : calendar!;

  void _pickedDay(DateTime d) {
    if (_spec.kind == PickerKind.date) {
      onCommit(_spec.write(d, null));
      return;
    }
    // A date and time: the time next, under the day picked.
    _day = d;
    _onTime = true;
    time!.title = mediumDay(d, _spec.locale);
    time!.keyboardCursor = calendar!.keyboardCursor;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  void _pickedTime(int minutes) => onCommit(_spec.write(_day, minutes));

  /// A key while open; true when used.
  bool handleKey(KeyEvent event) => _onTime ? time!.handleKey(event) : calendar!.handleKey(event);

  // --- geometry -----------------------------------------------------------------

  static const _pad = 8.0;
  EdgeInsets get _padding => sheet ? const EdgeInsets.fromLTRB(16, 20, 16, 24) : const EdgeInsets.all(_pad);

  double get _helpHeight => _spec.helpText.isEmpty ? 0 : 24;

  TextPainter _help() =>
      pickerText(_spec.helpText, _spec.colors.style(11.5, weight: FontWeight.w600, color: _spec.colors.muted), align: TextAlign.left);

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (calendar != null) visitor(calendar!);
    if (time != null) visitor(time!);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => visitor(active);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    calendar?.attach(owner);
    time?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    calendar?.detach();
    time?.detach();
  }

  @override
  void redepthChildren() {
    if (calendar != null) redepthChild(calendar!);
    if (time != null) redepthChild(time!);
  }

  @override
  void performLayout() {
    final pad = _padding;
    final width = sheet ? constraints.maxWidth : RenderCalendar.gridWidth + pad.horizontal;
    final inner = sheet ? math.min(width - pad.horizontal, 360.0) : RenderCalendar.gridWidth;
    for (final c in [calendar, time]) {
      c?.layout(BoxConstraints.tightFor(width: inner), parentUsesSize: true);
    }
    final a = active;
    (a.parentData! as BoxParentData).offset = Offset((width - inner) / 2, pad.top + _helpHeight);
    size = constraints.constrain(Size(width, pad.vertical + _helpHeight + a.size.height));
  }

  /// Its outline.
  RRect get outline {
    final c = _spec.colors;
    final r = Offset.zero & size;
    if (!sheet) return RRect.fromRectAndRadius(r, Radius.circular(c.radius));
    final top = Radius.circular(_spec.tokens.radius('dialog', 12));
    return RRect.fromRectAndCorners(r, topLeft: top, topRight: top);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final c = _spec.colors;
    paintPickerSurface(canvas, outline.shift(offset), c);
    if (sheet) {
      // The sheet's handle.
      final h = Rect.fromCenter(center: offset + Offset(size.width / 2, 8), width: 36, height: 4);
      canvas.drawRRect(RRect.fromRectAndRadius(h, const Radius.circular(2)), Paint()..color = c.divider);
    }
    if (_spec.helpText.isNotEmpty) {
      final p = _help();
      final a = (active.parentData! as BoxParentData).offset;
      p.paint(canvas, offset + Offset(a.dx + 2, _padding.top + (_helpHeight - p.height) / 2 - 2));
      p.dispose();
    }
    final a = active;
    context.paintChild(a, offset + (a.parentData! as BoxParentData).offset);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final a = active;
    return result.addWithPaintOffset(
        offset: (a.parentData! as BoxParentData).offset, position: position, hitTest: (r, p) => a.hitTest(r, position: p));
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final o = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.explicitChildNodes = true;
    if (_spec.helpText.isNotEmpty) {
      config
        ..label = _spec.helpText
        ..textDirection = TextDirection.ltr;
    }
  }
}
