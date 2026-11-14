// The dropdown as a render object: Flutter's `DropdownButton` in SSUI's look
// (soft_saas_ui's `SoftSaaSDropdown`: a `SoftSaaSSelectTrigger` opening a
// `SoftSaaSMenuList` in a popover), with no Material widget in its path.
//
// | Part | SSUI | From the node |
// |---|---|---|
// | field | the field frame (field_frame.dart): 28 high when it hugs, `primaryBackground`, 1 px `primaryBorder`, `secondaryBorder` hovered, 1.5 px `focusBorder` while keyboard-focused or open, radius 7, 50 % disabled | `underline` (false: no border, fill or padding), `focusColor`, `enabled` |
// | value | `inputText`: the scale's size, 400, `primaryText`, optically centered | `selectedItemStyle`, `alignment`, the default text style's font |
// | placeholder | the value's metrics in `tertiaryText` | `hint`, `hintStyle` |
// | chevron | Lucide `chevron-down` at the scale's icon size in `tertiaryText`, turned over while open | `icon` (a glyph instead), `iconSize`, `iconEnabledColor`, `iconDisabledColor` |
// | menu | render/controls/menu.dart: under the field (above when there is no room), its width (120 at least), 240 high at most, rows 28 high, the selected row tinted with a check | `items`, `style`, `itemAlignment`, `dropdownColor`, `borderRadius`, `elevation`, `hoverColor`, `splashColor`, `menuStyle` |
// | image | before the value and each item | `itemImage`, `itemImageSize` |
//
// Keyboard: Enter, Space, Arrow Down and Up open it; while open the arrows,
// Home/End and Page Up/Down move, typing jumps to a row, Enter and Space
// choose, Escape (or a press outside) closes it, the focus staying on the
// field; Tab closes it and moves on. A choice is the node's `changed` with
// the item as its value (written back to the variable `value` is bound to).
import 'dart:async' show scheduleMicrotask;
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show DropdownProps, Json, Node, readDouble;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, immutable, listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, fireTrigger;
import '../recipe.dart';
import 'field_frame.dart';
import 'kit.dart';
import 'kit_dropdown.dart';
import 'menu.dart';
import 'tokens.dart';

/// The recipe of `dropdown` (lib/src/widgets/controls.dart registers it).
void dropdownRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final box = b.obtain<RenderDropdown>('dropdown', RenderDropdown.new)
    ..interactive = interactive
    ..spec = DropdownSpec.of(n, ControlTokens.of(b), inherited: b.slot.textDefault)
    ..onChanged = interactive ? (value) => fireTrigger(b, 'changed', event: {'value': value}) : null
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.enabled = box.spec.enabled && !states.contains(api.WidgetState.disabled);
  box.autofocus = interactive && box.spec.autofocus;
  chain.add(box);
  // A touch lands on it in a 44 × 44 target around a smaller field.
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!box.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

/// What a dropdown shows, resolved from its node and tokens: everything but
/// the value it holds and its states.
@immutable
class DropdownSpec {
  const DropdownSpec({
    required this.tokens,
    required this.scale,
    this.items = const [],
    this.labels = const [],
    this.value,
    this.enabled = true,
    this.autofocus = false,
    this.feedback = true,
    this.hint = '',
    this.hintStyle,
    this.valueStyle = const TextStyle(),
    this.alignX = -1,
    this.underline = true,
    this.focusColor,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.iconDisabledColor,
    this.image = '',
    this.imageSize = 28,
    required this.menu,
  });

  final ControlTokens tokens;

  /// The step of the control scale the field is drawn at (its fixed height's,
  /// else the default).
  final ControlScale scale;

  /// The items (their values) and what each shows.
  final List<Object?> items;
  final List<String> labels;

  /// The node's `value`.
  final Object? value;
  final bool enabled, autofocus;

  /// A click sound when it opens on Android (`enableFeedback`).
  final bool feedback;
  final String hint;
  final TextStyle? hintStyle;

  /// The value's style, resolved.
  final TextStyle valueStyle;

  /// The value's place in the field: -1 start, 0 center, 1 end.
  final double alignX;

  /// The field's box (false: no border, fill or padding).
  final bool underline;
  final Color? focusColor;

  /// The node's own arrow glyph (null: SSUI's chevron).
  final FieldAffix? icon;
  final double? iconSize;
  final Color? iconColor, iconDisabledColor;

  /// An image before the value and each item ('' none; a URL with `${`
  /// still unresolved shows its empty square).
  final String image;
  final double imageSize;

  /// The menu's look.
  final MenuLook menu;

  /// The size of the chevron (or the node's arrow).
  double get chevronSize => iconSize ?? scale.iconSize;

  /// [n]'s dropdown drawn with [tokens]; [inherited] is the default text
  /// style it is under (its font).
  factory DropdownSpec.of(Node n, ControlTokens tokens, {api.TextStyle? inherited}) {
    Color? c(api.Color? v) => v?.flutter;
    final h = n.layout.height;
    final scale = h.fit == api.SizeFit.hug ? tokens.scaleFor(tokens.defaultHeight) : tokens.scaleFor(h.value);
    final dataSource = n.prop(DropdownProps.useDataSource);
    // Items from a data source are bound at runtime (as before: none here).
    final List<Object?> items = dataSource ? const [] : n.prop(DropdownProps.items);
    String labelOf(Object? v) => dataSource ? n.prop(DropdownProps.itemLabel) : '$v';
    final family = TextStyle(fontFamily: inherited?.fontFamily);
    TextStyle? own(api.TextStyle s) => s.isEmpty ? null : ownStyle(s);
    final valueStyle = FieldDecoration.valueStyleFor(tokens, scale, inherited: family, own: own(n.prop(DropdownProps.selectedItemStyle)));
    final iconProp = n.prop(DropdownProps.icon);
    final iconSize = n.props.has(DropdownProps.iconSize) ? n.prop(DropdownProps.iconSize) : null;
    FieldAffix? icon;
    if (iconProp != null) {
      final a = FieldAffix.of(iconProp, null, api.TextStyle.empty);
      if (a != null && a.hasIcon) {
        icon = FieldAffix(
          icon: a.icon,
          iconSize: iconSize ?? a.iconSize ?? scale.iconSize,
          iconColor: a.iconColor ?? c(n.prop(DropdownProps.iconEnabledColor)) ?? tokens.tertiaryText,
        );
      }
    }
    return DropdownSpec(
      tokens: tokens,
      scale: scale,
      items: items,
      labels: [for (final i in items) labelOf(i)],
      value: n.prop(DropdownProps.value),
      enabled: n.prop(DropdownProps.enabled),
      autofocus: n.prop(DropdownProps.autofocus),
      feedback: n.prop(DropdownProps.enableFeedback) ?? true,
      hint: n.prop(DropdownProps.hint) ?? '',
      hintStyle: own(n.prop(DropdownProps.hintStyle)),
      valueStyle: valueStyle,
      alignX: n.prop(DropdownProps.alignment).x,
      underline: n.prop(DropdownProps.underline),
      focusColor: c(n.prop(DropdownProps.focusColor)),
      icon: icon,
      iconSize: iconSize,
      iconColor: c(n.prop(DropdownProps.iconEnabledColor)),
      iconDisabledColor: c(n.prop(DropdownProps.iconDisabledColor)),
      image: n.prop(DropdownProps.itemImage).trim(),
      imageSize: n.prop(DropdownProps.itemImageSize),
      menu: _menuLook(n, tokens, scale, family),
    );
  }

  /// The image prop of [image] (empty: none, or a template not yet
  /// resolved).
  Json get imageGlyph => image.isEmpty || image.contains(r'${') ? const {} : {'source': 'image', 'image': image};

  /// The frame's decoration, [selected] when an item is chosen (its image
  /// shows before it).
  FieldDecoration decorationFor({required bool selected}) {
    final s = scale;
    final padRight = underline ? fieldSidePadding(s) : 0.0;
    final suffix = icon ??
        // SSUI's chevron is drawn by the dropdown itself: the slot only
        // reserves its room (the side padding, the glyph, the gap).
        FieldAffix(minWidth: padRight + chevronSize + s.gap);
    FieldAffix? prefix;
    if (image.isNotEmpty && selected) {
      final glyph = imageGlyph;
      prefix = FieldAffix(
        icon: glyph.isEmpty ? const {'show': true, 'source': 'image', 'image': ''} : glyph,
        iconSize: imageSize,
        padding: EdgeInsets.only(left: underline ? fieldSidePadding(s) : 0, right: math.max(0, 10 - s.gap)),
      );
    }
    return FieldDecoration(
      tokens: tokens,
      hint: hint,
      hintStyle: hintStyle,
      prefix: prefix,
      suffix: suffix,
      contentPadding: underline ? null : EdgeInsets.zero,
      filled: underline ? null : false,
      border: underline ? null : FieldBorder.none,
      focusColor: focusColor,
      enabled: enabled,
      valueStyle: valueStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DropdownSpec &&
      other.tokens.theme == tokens.theme &&
      other.tokens.dark == tokens.dark &&
      other.tokens.backdrop == tokens.backdrop &&
      other.scale.name == scale.name &&
      api.jsonEquality.equals(other.items, items) &&
      listEquals(other.labels, labels) &&
      api.jsonEquality.equals(other.value, value) &&
      other.enabled == enabled &&
      other.autofocus == autofocus &&
      other.feedback == feedback &&
      other.hint == hint &&
      other.hintStyle == hintStyle &&
      other.valueStyle == valueStyle &&
      other.alignX == alignX &&
      other.underline == underline &&
      other.focusColor == focusColor &&
      other.icon == icon &&
      other.iconSize == iconSize &&
      other.iconColor == iconColor &&
      other.iconDisabledColor == iconDisabledColor &&
      other.image == image &&
      other.imageSize == imageSize &&
      other.menu == menu;

  @override
  int get hashCode => Object.hash(scale.name, labels.length, hint, enabled, underline, image);
}

/// SSUI's menu (rows of the field's step, `primaryBackground`, hairline,
/// `level3`), the node's props over it, its `menuStyle` over those.
MenuLook _menuLook(Node n, ControlTokens t, ControlScale scale, TextStyle family) {
  Color? c(api.Color? v) => v?.flutter;
  final ms = n.prop(DropdownProps.menuStyle);
  double? num(String k) => ms == null ? null : readDouble(ms[k]);
  Color? hex(String k) => ms == null ? null : api.Color.fromJson(ms[k])?.flutter;
  EdgeInsets? insets(String k) => ms == null || ms[k] == null ? null : api.EdgeInsets.fromJson(ms[k]).flutter;
  // Rows: SSUI's `inputText` of the step, the node's `style` over it.
  var text = TextStyle(
    fontFamily: family.fontFamily ?? t.fontFamily,
    fontSize: scale.fontSize,
    fontWeight: FontWeight.w400,
    height: 1.25,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
    color: t.onSurface,
  );
  final style = n.prop(DropdownProps.style);
  if (!style.isEmpty) text = text.merge(ownStyle(style));
  // SSUI's selected row: primary ink at 500 on `activeTint`, with a check.
  // A menu with its own style (`menuStyle`) keeps its own selected look.
  TextStyle selected;
  Color? selectedFill;
  var showCheck = true;
  if (ms == null) {
    selected = text.copyWith(color: t.primary, fontWeight: FontWeight.w500);
    selectedFill = t.activeTint;
  } else {
    final own = api.TextStyle.fromJson(ms['selectedTextStyle']);
    selected = own.isEmpty ? text : text.merge(ownStyle(own));
    selectedFill = hex('selectedItemColor');
    showCheck = ms['showCheck'] == true;
  }
  // Shadows: SSUI's floating `level3`; a node's own elevation or shadows
  // instead.
  var shadows = t.shadows('level3');
  if (n.props.has(DropdownProps.elevation)) {
    final e = n.prop(DropdownProps.elevation);
    shadows = e <= 0 ? const [] : t.shadows(e <= 1 ? 'level1' : e <= 3 ? 'level2' : e <= 8 ? 'level3' : 'level4');
  }
  if (ms != null && ms['shadows'] != null) {
    shadows = [for (final e in api.Effect.listFromJson(ms['shadows'])) if (e.visible && e.type == api.EffectType.dropShadow) boxShadow(e)];
  }
  BorderSide? border = BorderSide(color: t.primaryBorder);
  if (ms != null && ms['border'] != null) {
    final b = api.BorderSide.fromJson(ms['border']);
    border = b == null || b.width <= 0 ? null : BorderSide(color: b.color?.flutter ?? t.primaryBorder, width: b.width);
  }
  return MenuLook(
    fill: hex('color') ?? c(n.prop(DropdownProps.dropdownColor)) ?? t.primaryBackground,
    radius: num('radius') ?? n.prop(DropdownProps.borderRadius)?.topLeft ?? t.radius('control', 7),
    border: border,
    shadows: shadows,
    padding: insets('padding') ?? (ms == null ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(vertical: 6)),
    maxHeight: num('maxHeight') ?? (ms == null ? 240 : 320),
    minWidth: num('minWidth') ?? 0,
    gap: num('offset') ?? (ms == null ? 4 : 6),
    itemHeight: num('itemHeight') ?? (ms == null ? menuRowHeight(scale) : 40),
    itemPadding: insets('itemPadding') ?? (ms == null ? const EdgeInsets.symmetric(horizontal: 8) : const EdgeInsets.symmetric(horizontal: 14)),
    rowRadius: ms == null ? t.radius('inner', 5) : 0,
    hoverFill: hex('hoverItemColor') ?? c(n.prop(DropdownProps.hoverColor)) ?? t.hoverOverlay,
    pressedFill: c(n.prop(DropdownProps.splashColor)) ?? t.pressedOverlay,
    selectedFill: selectedFill,
    textStyle: text,
    selectedTextStyle: selected,
    showCheck: showCheck,
    checkLeading: ms?['checkPosition'] == 'leading',
    checkSize: num('checkSize') ?? (ms == null ? 14 : 18),
    checkColor: hex('checkColor') ?? (ms == null ? t.primary : null),
    alignX: n.prop(DropdownProps.itemAlignment).x,
  );
}

/// A dropdown: the field frame showing the chosen item (or the hint) and
/// SSUI's chevron, opening a [RenderMenu] of the items in a [ControlPopup]
/// anchored to the frame's box.
class RenderDropdown extends RenderFieldFrame {
  RenderDropdown() {
    hugWidth = 0;
    onPressed = toggle;
    focusNode.onKey = _onKey;
    _menu = RenderMenu()..onSelected = _choose;
    _popup = ControlPopup(content: _menu, onDismiss: _dismissed);
  }

  late final RenderMenu _menu;
  late final ControlPopup _popup;

  /// The menu (shown while [isOpen]).
  RenderMenu get menu => _menu;

  /// Its popup in the root's overlay layer.
  ControlPopup get popup => _popup;

  bool get isOpen => _popup.isOpen;

  bool _interactive = false;

  /// Whether it takes pointers, keys and opens (a running app); a design
  /// canvas draws it at rest.
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) {
      _popup.close();
      focusNode.leave();
    }
    markNeedsPaint();
  }

  /// Told with the chosen item (its value).
  ValueChanged<Object?>? onChanged;

  DropdownSpec? _spec;
  DropdownSpec get spec => _spec!;
  set spec(DropdownSpec v) {
    final old = _spec;
    if (v == old) return;
    _spec = v;
    // The node's value replaces the one chosen here when it changes (a
    // bound variable written back, or set elsewhere).
    if (old == null || !api.jsonEquality.equals(old.value, v.value)) _value = v.value;
    _sync();
  }

  Object? _value;

  /// The value it holds now (the node's, or the item chosen since).
  Object? get value => _value;

  /// The item the value is (by content; null: none or ambiguous).
  int? get selectedIndex {
    final items = spec.items;
    int? found;
    for (var i = 0; i < items.length; i++) {
      if (api.jsonEquality.equals(items[i], _value)) {
        if (found != null) return null;
        found = i;
      }
    }
    return found;
  }

  /// What the field shows (null: the hint).
  String? get selectedLabel {
    final i = selectedIndex;
    return i == null ? null : spec.labels[i];
  }

  void _sync() {
    final s = spec;
    final i = selectedIndex;
    decoration = s.decorationFor(selected: i != null);
    _menu
      ..look = s.menu
      ..items = [
        for (var k = 0; k < s.items.length; k++)
          MenuItem(label: s.labels[k], selected: k == i, image: s.imageGlyph, imageSize: s.image.isEmpty ? 0 : s.imageSize),
      ];
    _popup.position = AnchoredPlacement(gap: s.menu.gap, minWidth: math.max(120, s.menu.minWidth), maxHeight: s.menu.maxHeight);
    _popup.layer?.position = _popup.position;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  // --- opening and choosing -----------------------------------------------------

  /// Opens the menu (closes it when open).
  void toggle() => isOpen ? close() : open();

  /// Opens the menu under (or over) the field, the chosen item active and
  /// in view; the field keeps the focus and takes the menu's keys.
  void open() {
    if (!_interactive || !enabled || isOpen || spec.items.isEmpty || !attached) return;
    focusNode.requestFocus();
    final i = selectedIndex;
    _menu.active = i;
    if (i != null) _menu.reveal(i, center: true);
    if (!_popup.open(this, area: () => boxRect)) return;
    if (spec.feedback && defaultTargetPlatform == TargetPlatform.android) SystemSound.play(SystemSoundType.click);
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// Closes the menu (the focus stays on the field).
  void close() {
    if (!isOpen) return;
    _popup.close();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _dismissed() {
    focusNode.requestFocus();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _choose(int i) {
    close();
    focusNode.requestFocus();
    final item = spec.items[i];
    _value = item;
    _sync();
    // Flutter's `onChanged` runs on every choice, the same item included.
    onChanged?.call(item);
  }

  bool _onKey(KeyEvent event) {
    if (!_interactive || event is KeyUpEvent) return false;
    final key = event.logicalKey;
    if (isOpen) {
      if (_popup.handleKey(event)) return true;
      if (key == LogicalKeyboardKey.tab) {
        close();
        return false;
      }
      _menu.handleKey(event);
      return true;
    }
    if (enabled && (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp)) {
      open();
      return true;
    }
    return false;
  }

  // --- pointer -------------------------------------------------------------------------

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

  @override
  void detach() {
    // The root may be detaching too (a tree going away): its overlay is
    // left alone until that is over.
    if (isOpen) scheduleMicrotask(() => attached ? null : close());
    super.detach();
  }

  // --- the content: the value and the chevron ------------------------------------

  final ControlLabel _label = ControlLabel();
  final TextPainter _probe = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
  TextStyle? _probed;
  double _lineHeight = 0;

  TextStyle get _valueStyle => spec.valueStyle;

  @override
  double contentNaturalWidth() {
    var w = 0.0;
    final p = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
    for (final l in spec.labels) {
      p
        ..text = TextSpan(text: l, style: _valueStyle)
        ..layout();
      w = math.max(w, p.width);
    }
    p.dispose();
    // The image the chosen item shows, when none is chosen yet.
    if (spec.image.isNotEmpty && selectedIndex == null && spec.labels.isNotEmpty) w += spec.imageSize + 10;
    return w;
  }

  @override
  double get contentLineHeight {
    final s = _valueStyle;
    if (_probed != s) {
      _probed = s;
      _probe
        ..text = TextSpan(text: 'Xg', style: s)
        ..layout();
      _lineHeight = _probe.height;
    }
    return _lineHeight;
  }

  @override
  double contentHeightFor(double width) => contentLineHeight;

  @override
  bool get contentEmpty => selectedLabel == null;

  Rect _content = Rect.zero, _chevron = Rect.zero;
  double _labelLeft = 0;

  @override
  void layoutContent(Rect rect) {
    _content = rect;
    final text = selectedLabel ?? '';
    _label
      ..update(text, _valueStyle, align: TextAlign.left)
      ..layout(rect.width);
    final free = math.max(0.0, rect.width - _label.size.width);
    _labelLeft = rect.left + free * (spec.alignX.clamp(-1.0, 1.0) + 1) / 2;
    final size = spec.chevronSize;
    final padRight = decoration.contentPadding?.right ?? fieldSidePadding(scale);
    _chevron = spec.icon != null ? Rect.zero : Rect.fromLTWH(boxRect.right - padRight - size, boxRect.center.dy - size / 2, size, size);
  }

  /// The chevron's color now.
  Color get chevronColor {
    final s = spec;
    final on = enabled && s.enabled;
    return (on ? s.iconColor : s.iconDisabledColor ?? s.iconColor) ?? s.tokens.tertiaryText;
  }

  /// Where SSUI's chevron is (local; empty with the node's own arrow).
  Rect get chevronRect => _chevron;

  @override
  void paintContent(PaintingContext context, Offset offset) {
    if (selectedLabel != null) _label.paint(context.canvas, offset.dx + _labelLeft, offset.dy + _content.center.dy);
    if (_chevron != Rect.zero) {
      StrokeGlyph.chevronDown.paint(context.canvas, _chevron.shift(offset), chevronColor, turns: isOpen ? .5 : 0);
    }
  }

  // --- states, semantics, the guard ---------------------------------------------------

  /// SSUI's select: the focus border while keyboard-focused or open (a
  /// field picked with the pointer and closed again shows its rest border).
  @override
  FieldBorder get currentBorder => decoration.borderFor(
        focused: focusHighlight || isOpen,
        hovered: hovered && !isOpen,
        enabled: enabled && decoration.enabled,
      );

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels {
    final own = super.labels;
    final text = selectedLabel;
    if (text == null || text.isEmpty || !hasSize) return own;
    return [
      ...own,
      (text: text, fontFamily: _valueStyle.fontFamily, glyphs: _label.glyphBoxes(_labelLeft, _content.center.dy)),
    ];
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isButton = true
      ..isExpanded = isOpen;
    final v = selectedLabel;
    if (v != null) config.value = v;
  }

  @override
  void dispose() {
    _popup.close();
    _label.dispose();
    _probe.dispose();
    _menu.dispose();
    super.dispose();
  }
}
