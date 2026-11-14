// Chips and badges as render objects: `chip`, `actionChip`, `choiceChip`,
// `filterChip`, `inputChip` and `badge`, with no Material widget in their
// path. Unstyled, a chip is SSUI's (soft_saas_ui's `SoftSaaSChip`, with the
// selected look of the design system's Chip):
//
// | Part | SSUI |
// |---|---|
// | surface | a pill 24 high (20 at a height of 20 or less), `tertiaryBackground`, 1 px `primaryBorder` |
// | label | 12/500 (11 at 20), line height 1.2, `onSurface`, centred |
// | avatar, check mark | 12, 6 before the label |
// | delete icon (inputChip) | an x, 12, 6 after the label |
// | selected | `activeTint`, `primaryTintBorder`, `primary` ink |
// | hover, press, focus, disabled | the kit's overlays, ring and 50 % |
//
// A selectable chip always keeps the check mark's room, so selecting never
// resizes it; unselected, its label is centred in that width. A badge over a
// child is Flutter's (a dot or a count at its alignment, in `error`); with no
// child it is SSUI's Badge: a tinted label 20 high, a pill for a count.
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show BadgeProps, ChipProps, ChipVariant, Json, Node;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, Slot, SlotKind, fireTrigger, runTrigger;
import '../paint/icon_glyph.dart';
import '../paint/icon_names.dart';
import '../recipe.dart';
import 'buttons.dart' show outlinedBorder;
import 'kit.dart';
import 'tokens.dart';

/// The kinds of chip.
enum ChipKind { chip, action, choice, filter, input }

ChipKind _kindOf(String type) => switch (type) {
      'actionChip' => ChipKind.action,
      'choiceChip' => ChipKind.choice,
      'filterChip' => ChipKind.filter,
      'inputChip' => ChipKind.input,
      _ => ChipKind.chip,
    };

/// The recipe of every chip type: lib/src/widgets/controls.dart registers
/// it.
void chipRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final spec = ChipSpec.of(n, ControlTokens.of(b), inherited: b.slot.textDefault);
  final states = b.tree.statesOf(b.id, instance: b.instance);
  final patched = n.behaviors.states.patches.keys.toSet();
  final controlled = n.bind.containsKey('props.selected');
  // A plain chip takes a tap only when the node has a click reaction (its
  // reactions layer leaves the tap to it).
  final clickable = n.actions.any((r) => r.trigger.type == api.TriggerType.click);
  final box = b.obtain<RenderChip>('chip', RenderChip.new)
    ..interactive = interactive
    ..spec = spec
    ..pressable = spec.kind != ChipKind.chip || clickable
    ..onStateChanged = interactive && patched.isNotEmpty
        ? (s, on) {
            if (patched.contains(s)) b.tree.setState(b.id, s, on, instance: b.instance);
          }
        : null;
  box.syncSelected(spec.selected, controlled: controlled, bound: states.contains(api.WidgetState.selected));
  box.onPressed = !interactive
      ? null
      : () async {
          if (spec.selectable) {
            final value = !box.selected;
            if (!controlled) box.localSelected = value;
            // Its binding and `changed` see the new value before `click`.
            await runTrigger(b, 'changed', event: {'value': value});
            if (box.attached) await runTrigger(b, 'click', event: {'value': value});
          } else {
            fireTrigger(b, 'click');
          }
        };
  box.onDeleted = interactive ? () => fireTrigger(b, 'deleted') : null;
  box.enabled = spec.enabled && !states.contains(api.WidgetState.disabled);
  box.autofocus = interactive && spec.autofocus;
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

/// What a chip shows, resolved from its node and tokens.
@immutable
class ChipSpec {
  const ChipSpec({
    required this.kind,
    required this.tokens,
    this.label = '',
    this.labelStyle = const TextStyle(),
    this.avatar = const {},
    this.avatarSize,
    this.avatarColor,
    this.deleteIcon = const {},
    this.deleteIconSize,
    this.deleteIconColor,
    this.selected = false,
    this.showCheckmark = true,
    this.checkmarkColor,
    this.background,
    this.selectedColor,
    this.side,
    this.shape,
    this.elevation,
    this.shadowColor,
    this.padding,
    this.labelPadding,
    this.tooltip,
    this.autofocus = false,
    this.enabled = true,
    this.plain = false,
    this.spacing = 4,
  });

  final ChipKind kind;
  final ControlTokens tokens;
  final String label;

  /// The node's label fields (size, weight, family, colour).
  final TextStyle labelStyle;
  final Json avatar;
  final double? avatarSize;
  final Color? avatarColor;
  final Json deleteIcon;
  final double? deleteIconSize;
  final Color? deleteIconColor;
  final bool selected;
  final bool showCheckmark;
  final Color? checkmarkColor;
  final Color? background, selectedColor;
  final BorderSide? side;
  final OutlinedBorder? shape;
  final double? elevation;
  final Color? shadowColor;
  final EdgeInsets? padding, labelPadding;
  final String? tooltip;
  final bool autofocus;
  final bool enabled;

  /// [ChipVariant.plain]: exactly its padding (10 × 4), radius 8, a
  /// [spacing] gap.
  final bool plain;
  final double spacing;

  /// Toggled by a tap (a choice or filter chip).
  bool get selectable => kind == ChipKind.choice || kind == ChipKind.filter;

  /// Shows a selected look when its `selected` says (an input chip too).
  bool get showsSelection => selectable || kind == ChipKind.input;

  bool get hasAvatar => avatar.isNotEmpty && avatar['show'] != false;

  /// A check mark may show: its room is always kept.
  bool get hasCheck => showsSelection && showCheckmark;

  /// An input chip's delete icon (an x unless it says otherwise).
  bool get hasDelete => kind == ChipKind.input && deleteIcon['show'] != false;

  factory ChipSpec.of(Node n, ControlTokens tokens, {api.TextStyle? inherited}) {
    Color? c(api.Color? v) => v?.flutter;
    final kind = _kindOf(n.type);
    final selectable = kind != ChipKind.chip && kind != ChipKind.action;
    final sideModel = n.prop(ChipProps.side);
    final shape = n.prop(ChipProps.shape);
    final nodePadding = n.layout.padding;
    return ChipSpec(
      kind: kind,
      tokens: tokens,
      label: n.prop(ChipProps.label),
      labelStyle: _labelStyle(n.prop(ChipProps.labelStyle), inherited),
      avatar: _glyph(n.prop(ChipProps.avatar)),
      avatarSize: n.prop(ChipProps.avatarSize),
      avatarColor: c(n.prop(ChipProps.avatarColor)),
      deleteIcon: kind == ChipKind.input ? _glyph(n.prop(ChipProps.deleteIcon)) : const {},
      deleteIconSize: kind == ChipKind.input ? n.prop(ChipProps.deleteIconSize) : null,
      deleteIconColor: kind == ChipKind.input ? c(n.prop(ChipProps.deleteIconColor)) : null,
      selected: selectable && n.prop(ChipProps.selected),
      showCheckmark: !selectable || n.prop(ChipProps.showCheckmark),
      checkmarkColor: selectable ? c(n.prop(ChipProps.checkmarkColor)) : null,
      background: c(n.prop(ChipProps.backgroundColor)),
      selectedColor: selectable ? c(n.prop(ChipProps.selectedColor)) : null,
      side: sideModel == null
          ? null
          : BorderSide(color: sideModel.color?.flutter ?? tokens.primaryBorder, width: sideModel.width),
      shape: shape == null ? null : outlinedBorder(shape),
      elevation: n.prop(ChipProps.elevation),
      shadowColor: c(n.prop(ChipProps.shadowColor)),
      padding: n.prop(ChipProps.padding)?.flutter ?? (nodePadding == api.EdgeInsets.zero ? null : nodePadding.flutter),
      labelPadding: n.prop(ChipProps.labelPadding)?.flutter,
      tooltip: kind == ChipKind.chip ? null : n.prop(ChipProps.tooltip),
      autofocus: n.prop(ChipProps.autofocus),
      enabled: kind == ChipKind.chip || n.prop(ChipProps.isEnabled),
      plain: n.prop(ChipProps.variant) == ChipVariant.plain,
      spacing: n.prop(ChipProps.spacing),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChipSpec &&
      other.kind == kind &&
      other.tokens.theme == tokens.theme &&
      other.tokens.dark == tokens.dark &&
      other.tokens.backdrop == tokens.backdrop &&
      other.label == label &&
      other.labelStyle == labelStyle &&
      _sameJson(other.avatar, avatar) &&
      other.avatarSize == avatarSize &&
      other.avatarColor == avatarColor &&
      _sameJson(other.deleteIcon, deleteIcon) &&
      other.deleteIconSize == deleteIconSize &&
      other.deleteIconColor == deleteIconColor &&
      other.selected == selected &&
      other.showCheckmark == showCheckmark &&
      other.checkmarkColor == checkmarkColor &&
      other.background == background &&
      other.selectedColor == selectedColor &&
      other.side == side &&
      other.shape == shape &&
      other.elevation == elevation &&
      other.shadowColor == shadowColor &&
      other.padding == padding &&
      other.labelPadding == labelPadding &&
      other.tooltip == tooltip &&
      other.autofocus == autofocus &&
      other.enabled == enabled &&
      other.plain == plain &&
      other.spacing == spacing;

  @override
  int get hashCode => Object.hash(kind, label, selected, background, enabled, padding, plain);
}

bool _sameJson(Json a, Json b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// A glyph prop as the icon render object draws it: a Material icon given
/// by name alone is looked up by name.
Json _glyph(Json glyph) {
  if (glyph.isEmpty || glyph['show'] == false) return glyph.isEmpty ? const {} : glyph;
  final codepoint = api.readInt(glyph['codepoint']);
  if ((codepoint == null || codepoint <= 0) && api.readString(glyph['image']) == null) {
    if (api.readString(glyph['name']) case final String name when name.isNotEmpty) return iconWithName(glyph, name);
  }
  return glyph;
}

/// The material icon `close` (the delete icon) and `check` (the check mark).
final Json _close = iconWithName(const {}, 'close');
final Json _check = iconWithName(const {}, 'check');

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
    color: own.color?.flutter,
  );
}

/// A chip's geometry at a height.
class _ChipMetrics {
  _ChipMetrics(this.padding, this.fontSize, this.icon, this.check, this.deleteSize, this.gap);
  final EdgeInsets padding;
  final double fontSize, icon, check, deleteSize, gap;
}

typedef _ChipLook = ({Color? fill, Color ink, Color iconInk, BorderSide side});

_ChipLook _lerpChipLook(_ChipLook a, _ChipLook b, double t) => (
      fill: a.fill == null && b.fill == null ? null : Color.lerp(a.fill, b.fill, t),
      ink: Color.lerp(a.ink, b.ink, t)!,
      iconInk: Color.lerp(a.iconInk, b.iconInk, t)!,
      side: BorderSide.lerp(a.side, b.side, t),
    );

/// A chip: its pill, avatar or check mark, label and delete icon, in the
/// states [RenderControl] resolves.
class RenderChip extends RenderControl implements LabelledControl {
  RenderChip() {
    _deleteTap = TapGestureRecognizer(debugOwner: this)..onTap = _delete;
    focusNode.onKey = _key;
  }

  final ControlLabel _label = ControlLabel();
  late final TapGestureRecognizer _deleteTap;

  // The parts: the avatar (or the check mark over it), the delete icon.
  RenderIconGlyph? _avatar, _checkGlyph, _deleteGlyph;

  bool _interactive = false;

  /// Whether it takes pointers and focus (a running app).
  set interactive(bool v) {
    if (v == _interactive) return;
    _interactive = v;
    if (!v) focusNode.leave();
    markNeedsPaint();
  }

  @override
  bool get animatesStates => _interactive;

  bool _pressable = true;

  /// Whether a tap does anything (a plain `chip` without a click reaction
  /// is a label: no hover, no focus).
  set pressable(bool v) {
    if (v == _pressable) return;
    _pressable = v;
    focusNode.canRequestFocus = v && enabled;
    if (!v) focusNode.leave();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get takesInput => _interactive && _pressable;

  @override
  set enabled(bool v) {
    super.enabled = v;
    focusNode.canRequestFocus = v && _pressable;
  }

  /// The delete icon was pressed (an input chip's `deleted`).
  VoidCallback? onDeleted;

  ChipSpec? _spec;
  ChipSpec get spec => _spec!;
  set spec(ChipSpec v) {
    if (v == _spec) return;
    final old = _spec;
    _spec = v;
    transitionDuration = Duration(milliseconds: v.tokens.controlMs);
    if (old == null || old.selected != v.selected) _local = null;
    _syncParts();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  bool? _local;

  /// An unbound selectable chip's own toggle (cleared when its node's
  /// `selected` changes).
  set localSelected(bool v) {
    _local = v;
    super.selected = v;
  }

  /// Takes the node's selection: its bound value ([controlled]), else its
  /// own toggle over its prop; [bound] is a `selected` state set on it.
  void syncSelected(bool prop, {required bool controlled, required bool bound}) {
    if (controlled) _local = null;
    super.selected = bound || (_local ?? prop);
  }

  bool get _showsCheck => spec.hasCheck && selected;

  void _syncParts() {
    final s = spec;
    final a = s.hasAvatar ? (_avatar ??= RenderIconGlyph()) : null;
    a?.icon = s.avatar;
    final c = s.hasCheck ? (_checkGlyph ??= RenderIconGlyph()) : null;
    c?.icon = _check;
    final d = s.hasDelete ? (_deleteGlyph ??= RenderIconGlyph()) : null;
    d?.icon = s.deleteIcon.isEmpty ? _close : s.deleteIcon;
    _setParts([?a, ?c, ?d]);
    _inkParts();
  }

  final List<RenderBox> _parts = [];

  void _setParts(List<RenderBox> parts) {
    for (final p in _parts) {
      if (!parts.contains(p)) dropChild(p);
    }
    for (final p in parts) {
      if (!_parts.contains(p)) adoptChild(p);
    }
    _parts
      ..clear()
      ..addAll(parts);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    _parts.forEach(visitor);
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    _parts.forEach(redepthChild);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final p in _parts) {
      p.attach(owner);
    }
    if (!_interactive || !_pressable) focusNode.leave();
  }

  @override
  void detach() {
    super.detach();
    for (final p in _parts) {
      p.detach();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    if (_spec != null) _inkParts();
  }

  void _inkParts() {
    final look = _look(eased: true);
    _avatar?.color = spec.avatarColor ?? look.iconInk;
    _checkGlyph?.color = spec.checkmarkColor ?? look.iconInk;
    _deleteGlyph?.color = spec.deleteIconColor ?? look.iconInk;
  }

  @override
  String get semanticsName => spec.label;

  // --- input ---------------------------------------------------------------------

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!_interactive || !_pressable) return;
    if (event is PointerDownEvent && enabled && _deleteRect.inflate(4).contains(entry.localPosition) && spec.hasDelete) {
      _deleteTap.addPointer(event);
      return;
    }
    super.handleEvent(event, entry);
  }

  void _delete() {
    if (enabled) onDeleted?.call();
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent || !spec.hasDelete) return false;
    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      _delete();
      return true;
    }
    return false;
  }

  @override
  MouseCursor get cursor => _interactive && _pressable ? super.cursor : MouseCursor.defer;

  @override
  PointerEnterEventListener? get onEnter => _interactive && _pressable ? super.onEnter : null;

  // --- geometry ------------------------------------------------------------------

  static const double _defaultHeight = 24;

  _ChipMetrics _metricsAt(double height) {
    final s = spec;
    final small = !s.plain && height <= 20.5;
    final font = s.labelStyle.fontSize ?? (small ? 11.0 : 12.0);
    final icon = s.avatarSize ?? (s.plain ? 13.0 : 12.0);
    // SSUI's padding is inside its 1 px hairline (a decorated box's border
    // adds to its padding).
    final pad = s.padding ??
        (s.plain ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4) : EdgeInsets.symmetric(horizontal: small ? 9 : 11));
    return _ChipMetrics(pad, font, icon, icon, s.deleteIconSize ?? 12, s.plain ? s.spacing : 6);
  }

  double get _lineHeight => spec.labelStyle.height ?? 1.2;

  /// The height a hugging chip takes.
  double get _naturalHeight {
    final m = _metricsAt(_defaultHeight);
    final content = math.max(m.fontSize * _lineHeight, spec.hasAvatar || spec.hasCheck ? m.icon : 0);
    final own = content + m.padding.vertical + (spec.labelPadding?.vertical ?? 0);
    return spec.plain ? own : math.max(_defaultHeight, own);
  }

  TextStyle _textStyle(_ChipMetrics m, Color color) {
    final own = spec.labelStyle;
    return TextStyle(
      fontFamily: own.fontFamily ?? spec.tokens.fontFamily,
      fontSize: m.fontSize,
      fontWeight: own.fontWeight ?? FontWeight.w500,
      fontStyle: own.fontStyle,
      letterSpacing: own.letterSpacing ?? 0,
      height: _lineHeight,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
    );
  }

  /// The lead (avatar or check) and its gap: its room is kept whenever a
  /// check mark may show.
  double _leadWidth(_ChipMetrics m) => spec.hasAvatar || spec.hasCheck ? m.icon + (spec.label.isEmpty ? 0 : m.gap) : 0;

  double _deleteWidth(_ChipMetrics m) => spec.hasDelete ? m.gap + m.deleteSize : 0;

  double _labelWidth(_ChipMetrics m) {
    _label.update(spec.label, _textStyle(m, const Color(0xFF000000)));
    return _label.intrinsicWidth + (spec.labelPadding?.horizontal ?? 0);
  }

  /// The pill's width for its content at [m].
  double _contentWidth(_ChipMetrics m) => m.padding.horizontal + _leadWidth(m) + _labelWidth(m) + _deleteWidth(m);

  double _heightFor(BoxConstraints c) => c.hasTightHeight ? c.maxHeight : c.constrainHeight(_naturalHeight);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _contentWidth(_metricsAt(height.isFinite && height > 0 ? height : _naturalHeight));

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _naturalHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _naturalHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final h = _heightFor(constraints);
    return constraints.constrain(Size(_contentWidth(_metricsAt(h)), h));
  }

  late _ChipMetrics _m;

  /// Where the pill is drawn: the box, or (a box narrower than the content)
  /// the content's width from the box's start, never squeezed.
  Rect _pill = Rect.zero;
  Rect _leadRect = Rect.zero, _deleteRect = Rect.zero;
  double _labelLeft = 0, _labelSlot = 0;

  @override
  void performLayout() {
    final h = _heightFor(constraints);
    final m = _m = _metricsAt(h);
    final content = _contentWidth(m);
    size = constraints.constrain(Size(content, h));
    _pill = Offset.zero & Size(math.max(size.width, content), size.height);
    final lead = _leadWidth(m), del = _deleteWidth(m);
    _label.update(spec.label, _textStyle(m, const Color(0xFF000000)));
    final labelPad = spec.labelPadding ?? EdgeInsets.zero;
    final inner = _pill.width - m.padding.horizontal;
    _labelSlot = math.max(0, inner - lead - del - labelPad.horizontal);
    _label.layout(_labelSlot);
    // What shows, centred: the check (or avatar) and the label when it is
    // there, else the label alone in the room kept for both.
    final shownLead = spec.hasAvatar || _showsCheck ? lead : 0.0;
    final shown = shownLead + labelPad.horizontal + _label.size.width + del;
    final start = m.padding.left + math.max(0.0, (inner - shown) / 2);
    final cy = m.padding.top + (h - m.padding.vertical) / 2;
    _leadRect = Rect.fromCenter(center: Offset(start + m.icon / 2, cy), width: m.icon, height: m.icon);
    _labelLeft = start + shownLead + labelPad.left;
    _deleteRect = Rect.fromCenter(
        center: Offset(_labelLeft + _label.size.width + labelPad.right + m.gap + m.deleteSize / 2, cy),
        width: m.deleteSize,
        height: m.deleteSize);
    _avatar?.layout(BoxConstraints.tight(_leadRect.size));
    _checkGlyph?.layout(BoxConstraints.tight(_leadRect.size));
    _deleteGlyph?.layout(BoxConstraints.tight(_deleteRect.size));
    for (final (p, r) in [(_avatar, _leadRect), (_checkGlyph, _leadRect), (_deleteGlyph, _deleteRect)]) {
      if (p != null) (p.parentData! as BoxParentData).offset = r.topLeft;
    }
  }

  /// Its centre line, where the label's glyphs are centred.
  double get _centreY => _m.padding.top + (size.height - _m.padding.vertical) / 2;

  // --- look ----------------------------------------------------------------------

  _ChipLook _look({bool eased = false}) {
    if (!eased) return _lookFor(selected: selected);
    final sel = stateValue(api.WidgetState.selected);
    if (sel == 0 || sel == 1) return _lookFor(selected: sel == 1);
    return _lerpChipLook(_lookFor(selected: false), _lookFor(selected: true), sel);
  }

  _ChipLook _lookFor({required bool selected}) {
    final s = spec, t = s.tokens;
    final on = selected && s.showsSelection;
    Color? fill = t.tertiaryBackground;
    var ink = t.onSurface;
    var side = BorderSide(color: t.primaryBorder);
    if (on) {
      fill = t.activeTint;
      ink = t.primary;
      side = BorderSide(color: t.primaryTintBorder);
    }
    final own = on ? (s.selectedColor ?? s.background) : s.background;
    if (own != null) {
      fill = own;
      if (s.labelStyle.color == null) ink = t.readableOn(own, on && own.a < .9 ? t.primary : t.onSurface);
      // A fill of its own draws no hairline unless the node sets one.
      if (s.side == null) side = BorderSide(color: own, width: 0);
    }
    if (s.labelStyle.color case final Color c) ink = c;
    if (s.side case final BorderSide own) side = own;
    return (fill: fill, ink: ink, iconInk: ink, side: side);
  }

  /// The fill now (null: none), before the state layer.
  Color? get fillColor => _look().fill;

  /// The label's colour now.
  Color get labelColor => _look().ink;

  /// The border now.
  BorderSide get borderSide => _look().side;

  /// Its outline.
  OutlinedBorder get shape =>
      spec.shape ?? (spec.plain ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : const StadiumBorder());

  /// Where its check mark (or avatar) is, in its own coordinates.
  Rect get leadRect => _leadRect;

  /// Where its delete icon is.
  Rect get deleteRect => _deleteRect;

  /// The rect it draws its pill in (wider than its box when the box is
  /// narrower than its content).
  Rect get pillRect => _pill;

  /// Whether the check mark shows now.
  bool get showsCheck => _showsCheck;

  /// The overlay of its state now (hover, press), if any.
  Color? get stateOverlay {
    if (pressed) return spec.tokens.pressedOverlay;
    if (hovered) return spec.tokens.hoverOverlay;
    return null;
  }

  Color? _easedOverlay() {
    final t = spec.tokens;
    final h = stateValue(api.WidgetState.hovered), p = stateValue(api.WidgetState.pressed);
    if (h == 0 && p == 0) return null;
    var c = const Color(0x00000000);
    if (h > 0) c = Color.lerp(c, t.hoverOverlay, h)!;
    if (p > 0) c = Color.lerp(c, t.pressedOverlay, p)!;
    return c;
  }

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => spec.label.isEmpty || !hasSize
      ? const []
      : [(text: spec.label, fontFamily: _label.fontFamily, glyphs: _label.glyphBoxes(_labelLeft, _centreY))];

  /// The label's laid-out width and its whole width on one line: equal
  /// when nothing cuts it.
  ({double laidOut, double whole}) get labelWidths => (laidOut: _label.size.width, whole: _label.intrinsicWidth);

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  /// The alpha it was last painted at (255: opaque; a disabled chip 128).
  int get paintedAlpha => _opacity.layer?.alpha ?? 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    final off = stateValue(api.WidgetState.disabled);
    if (off > 0) {
      _opacity.layer = context.pushOpacity(offset, (255 - 127 * off).round(), _paintChip, oldLayer: _opacity.layer);
      return;
    }
    _opacity.layer = null;
    _paintChip(context, offset);
  }

  void _paintChip(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = _pill.shift(offset);
    final look = _look(eased: true);
    final shape = this.shape;
    final path = shape.getOuterPath(rect);
    final e = spec.elevation;
    if (e != null && e > 0) {
      canvas.drawShadow(path, spec.shadowColor ?? const Color(0xFF000000), e, false);
    }
    if (look.fill case final Color fill when fill.a > 0) canvas.drawPath(path, Paint()..color = fill);
    final overlay = _easedOverlay();
    if (overlay != null && overlay.a > 0) canvas.drawPath(path, Paint()..color = overlay);
    if (look.side.width > 0 && look.side.color.a > 0) {
      shape.copyWith(side: look.side.copyWith(strokeAlign: BorderSide.strokeAlignInside)).paint(canvas, rect);
    }
    final ring = stateValue(api.WidgetState.focused);
    if (ring > 0) {
      final c = spec.tokens.focusBorder;
      shape
          .copyWith(side: BorderSide(color: c.withValues(alpha: c.a * ring), width: 1.5, strokeAlign: BorderSide.strokeAlignOutside))
          .paint(canvas, rect);
    }
    _label.update(spec.label, _textStyle(_m, look.ink));
    _label.layout(_labelSlot);
    _label.paint(canvas, offset.dx + _labelLeft, offset.dy + _centreY);
    // The check mark over (in place of) the avatar while selected.
    final lead = _showsCheck ? _checkGlyph : _avatar;
    if (lead != null) context.paintChild(lead, offset + _leadRect.topLeft);
    if (_deleteGlyph case final d?) context.paintChild(d, offset + _deleteRect.topLeft);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final o = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (!_pressable) return;
    config.isButton = true;
    if (spec.selectable) config.isSelected = selected;
    if (spec.tooltip case final String t when t.isNotEmpty) config.tooltip = t;
    if (spec.hasDelete && enabled && onDeleted != null) {
      config.customSemanticsActions = {const CustomSemanticsAction(label: 'Delete'): _delete};
    }
  }

  @override
  void dispose() {
    _deleteTap.dispose();
    _label.dispose();
    _opacity.layer = null;
    super.dispose();
  }
}

// --- badge ----------------------------------------------------------------------

/// The recipe of `badge`.
void badgeRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  chain.add(b.fitBox('fit', l.width.fit, l.height.fit, Size(l.width.value, l.height.value)));
  final t = ControlTokens.of(b);
  final count = n.prop(BadgeProps.count);
  final maxCount = n.prop(BadgeProps.maxCount);
  final label = count != null ? (count > maxCount ? '$maxCount+' : '$count') : n.prop(BadgeProps.label);
  final child = n.slots['child'];
  final own = n.prop(BadgeProps.textStyle);
  final inherited = b.slot.textDefault;
  final s = inherited == null ? own : inherited.merge(own);
  final standalone = child == null && label != null;
  final background = n.prop(BadgeProps.backgroundColor)?.flutter;
  // Over a child: Flutter's badge in the error colour; alone: SSUI's
  // neutral tint with its hairline (a fill of its own: no hairline).
  final fill = background ?? (standalone ? t.tertiaryBackground : t.error);
  final ink = n.prop(BadgeProps.textColor)?.flutter ??
      s.color?.flutter ??
      (standalone && background == null ? t.secondaryText : t.readableOn(fill, const Color(0xFFFFFFFF)));
  final w = s.fontWeight;
  final badge = b.obtain<RenderBadge>('badge', RenderBadge.new)
    ..label = label
    ..isLabelVisible = n.prop(BadgeProps.isLabelVisible)
    ..backgroundColor = fill
    ..borderColor = standalone && background == null ? t.primaryBorder : null
    ..textStyle = TextStyle(
      fontFamily: s.fontFamily ?? t.fontFamily,
      fontSize: s.fontSize ?? 11,
      fontWeight: w == null ? FontWeight.w500 : FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)],
      height: s.height ?? 1.2,
      letterSpacing: s.letterSpacing,
      leadingDistribution: TextLeadingDistribution.even,
      color: ink,
    )
    ..smallSize = n.prop(BadgeProps.smallSize)
    ..largeSize = n.props.has(BadgeProps.largeSize) || !standalone ? n.prop(BadgeProps.largeSize) : 20
    // SSUI's 8, inside its 1 px hairline.
    ..padding = n.props.has(BadgeProps.padding) || !standalone ? n.prop(BadgeProps.padding).flutter : const EdgeInsets.symmetric(horizontal: 9)
    ..radius = standalone && count == null ? t.radius('inner', 5) : null
    ..badgeAlignment = n.prop(BadgeProps.alignment).flutter
    ..offset = Offset(n.prop(BadgeProps.offset).dx, n.prop(BadgeProps.offset).dy);
  b.syncChildren(badge, [?child], Slot(SlotKind.root, n));
  chain.add(badge);
}

/// Flutter's `Badge`: [label] in a stadium (or, without a label, a dot)
/// over its child at [badgeAlignment] + [offset]; without a child, SSUI's
/// badge alone, centred in the box.
class RenderBadge extends RenderStack implements LabelledControl {
  RenderBadge() : super(alignment: AlignmentDirectional.topStart, textDirection: TextDirection.ltr, clipBehavior: Clip.none);

  final ControlLabel _text = ControlLabel();

  String? _label;
  String? get label => _label;
  set label(String? v) {
    if (v == _label) return;
    _label = v;
    markNeedsLayout();
  }

  bool _isLabelVisible = true;
  set isLabelVisible(bool v) {
    if (v == _isLabelVisible) return;
    _isLabelVisible = v;
    markNeedsLayout();
  }

  Color _backgroundColor = const Color(0xFFDC2626);
  Color get backgroundColor => _backgroundColor;
  set backgroundColor(Color v) {
    if (v == _backgroundColor) return;
    _backgroundColor = v;
    markNeedsPaint();
  }

  Color? _borderColor;
  Color? get borderColor => _borderColor;

  /// A 1 px hairline inside the badge (SSUI's), or none.
  set borderColor(Color? v) {
    if (v == _borderColor) return;
    _borderColor = v;
    markNeedsPaint();
  }

  TextStyle _textStyle = const TextStyle();
  TextStyle get textStyle => _textStyle;
  set textStyle(TextStyle v) {
    if (v == _textStyle) return;
    _textStyle = v;
    markNeedsLayout();
  }

  double _smallSize = 6, _largeSize = 16;
  set smallSize(double v) {
    if (v == _smallSize) return;
    _smallSize = v;
    markNeedsLayout();
  }

  set largeSize(double v) {
    if (v == _largeSize) return;
    _largeSize = v;
    markNeedsLayout();
  }

  EdgeInsets _padding = const EdgeInsets.symmetric(horizontal: 4);
  set padding(EdgeInsets v) {
    if (v == _padding) return;
    _padding = v;
    markNeedsLayout();
  }

  double? _radius;

  /// Its corner radius (null: a pill).
  set radius(double? v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  Alignment _alignment = Alignment.topRight;
  set badgeAlignment(Alignment v) {
    if (v == _alignment) return;
    _alignment = v;
    markNeedsLayout();
  }

  Offset _offset = const Offset(4, -4);
  set offset(Offset v) {
    if (v == _offset) return;
    _offset = v;
    markNeedsLayout();
  }

  void _layoutText() {
    _text.update(_label ?? '', _textStyle);
    _text.layout(double.infinity);
  }

  /// The badge's own size (zero when hidden).
  Size get _badgeSize {
    if (!_isLabelVisible) return Size.zero;
    if (_label == null) return Size.square(_smallSize);
    _layoutText();
    final height = math.max(_largeSize, _text.size.height + _padding.vertical);
    return Size(math.max(_text.size.width + _padding.horizontal, height), height);
  }

  Rect _badgeRect = Rect.zero;

  /// Where the badge is drawn, in its own coordinates.
  Rect get badgeRect => _badgeRect;

  @override
  void performLayout() {
    final badge = _badgeSize;
    if (firstChild == null) {
      size = constraints.constrain(badge);
      _badgeRect = Alignment.center.alongOffset(Offset(size.width - badge.width, size.height - badge.height)) & badge;
      return;
    }
    super.performLayout();
    // Flutter's _RenderBadge: the dot's corner (the label's center line)
    // at the alignment point, less the badge's width offset.
    final hasLabel = _label != null;
    var at = (hasLabel ? _offset + const Offset(0, 8) : Offset.zero) +
        _alignment.alongOffset(Offset(size.width - (hasLabel ? _largeSize : _smallSize), size.height));
    if (hasLabel) at -= Offset(0, badge.height / 2);
    _badgeRect = at & badge;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      firstChild == null ? constraints.constrain(_badgeSize) : super.computeDryLayout(constraints);

  @override
  double computeMinIntrinsicWidth(double height) => firstChild == null ? _badgeSize.width : super.computeMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicWidth(double height) => firstChild == null ? _badgeSize.width : super.computeMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) => firstChild == null ? _badgeSize.height : super.computeMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) => firstChild == null ? _badgeSize.height : super.computeMaxIntrinsicHeight(width);

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels {
    final l = _label;
    if (l == null || l.isEmpty || !_isLabelVisible || !hasSize) return const [];
    _layoutText();
    final left = _badgeRect.center.dx - _text.size.width / 2;
    return [(text: l, fontFamily: _text.fontFamily, glyphs: _text.glyphBoxes(left, _badgeRect.center.dy))];
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_isLabelVisible) return;
    final r = _badgeRect.shift(offset);
    final radius = Radius.circular(_label == null ? r.shortestSide / 2 : (_radius ?? r.shortestSide / 2));
    final rrect = RRect.fromRectAndRadius(r, radius);
    context.canvas.drawRRect(rrect, Paint()..color = _backgroundColor);
    if (_borderColor case final Color c when c.a > 0) {
      context.canvas.drawRRect(
          rrect.deflate(.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = c);
    }
    if (_label != null) {
      _layoutText();
      _text.paint(context.canvas, r.center.dx - _text.size.width / 2, r.center.dy);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (_isLabelVisible && _label != null && _label!.isNotEmpty) {
      config
        ..label = _label!
        ..textDirection = TextDirection.ltr;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}
