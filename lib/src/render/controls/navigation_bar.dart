// Navigation bars as render objects: `navigationBar` (Flutter's
// `NavigationBar`) and `bottomNavigationBar` (`BottomNavigationBar`), with
// no Material widget (and no Scaffold or `BottomAppBar`) in their path.
// Unstyled, both are SSUI's tab bar (soft_saas_ui's `SoftSaaSTabBar`: the
// bottom navigation for narrow layouts):
//
// | Part | SSUI | Prop over it |
// |---|---|---|
// | bar | `primaryBackground`, a 1 px `primaryBorder` hairline along the top, 8 / 6 padding | `backgroundColor`, `elevation` (a shadow), node padding |
// | items | equal shares of the width; each 8 / 6 padded, an 18 px icon over an 11.5 px weight-500 label 4 below | `iconSize`, `selectedIconSize`, `labelTextStyle`, `selectedLabelTextStyle`, `labelBehavior` |
// | selected | `primary` ink on an `activeTint` pill (the control radius) | `selectedIconColor`, `indicatorColor` (navigationBar), a destination's `selectedIcon`, `selectedIconColor` |
// | unselected | `secondaryText` ink; hovered or focused: `primaryText` | `iconColor`, a destination's `iconColor` |
//
// A `shifting` bottom bar takes the selected destination's
// `backgroundColor`. Picking an item (a tap, Enter or Space; Left and Right
// move the keyboard between items) fires the node's `changed` with its
// index; a bound `selectedIndex` follows it. In a canvas's
// `bottomNavigationBar` slot the bar keeps the view's bottom safe area
// clear (read from the root's view: kit_bars.dart's `controlViewPadding`).
import 'dart:math' as math;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, NavigationBarProps, Node, SizeFit;
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

import '../convert.dart';
import '../node_tree.dart' show NodeBox, fireTrigger;
import '../recipe.dart';
import 'kit.dart';
import 'kit_bars.dart';
import 'tokens.dart';

/// The recipe of `navigationBar` and `bottomNavigationBar`:
/// lib/src/widgets/controls.dart registers it.
void navigationBarRecipe(NodeBuilder b, Node n, List<RenderBox> chain) {
  final l = n.layout;
  final bottomSlot = b.slot.parent?.slots['bottomNavigationBar'] == b.id;
  // In the canvas's bottom slot the bar grows by the safe area below it.
  chain.add(b.fitBox('fit', controlFit(l.width), bottomSlot && l.height.fit == SizeFit.fixed && l.height.value > 0 ? SizeFit.hug : controlFit(l.height),
      Size(l.width.value, l.height.value)));
  final interactive = b.tree.animates;
  final destinations = n.prop(NavigationBarProps.destinations);
  final bar = b.obtain<RenderNavigationBar>('navigationBar', RenderNavigationBar.new)
    ..interactive = interactive
    ..spec = NavigationBarSpec.of(n, ControlTokens.of(b), inherited: b.slot.textDefault ?? n.behaviors.defaultTextStyle)
    ..safeBottom = bottomSlot
    ..barHeight = bottomSlot && l.height.fit == SizeFit.fixed && l.height.value > 0 ? l.height.value : null
    ..propIndex = destinations.isEmpty ? 0 : n.prop(NavigationBarProps.selectedIndex).clamp(0, destinations.length - 1)
    ..onSelected = interactive ? (i) => fireTrigger(b, 'changed', event: {'value': i}) : null;
  chain.add(bar);
  if (interactive && b is NodeBox) {
    final node = b;
    node.outsideHitTest = (result, position) {
      if (!bar.hitTestTarget(result, node.localToGlobal(position))) return false;
      result.add(BoxHitTestEntry(node, position));
      return true;
    };
  }
}

const _deep = DeepCollectionEquality();

/// One destination as the bar draws it.
@immutable
class NavItem {
  const NavItem({required this.label, this.icon = const {}, this.selectedIcon, this.iconColor, this.selectedIconColor, this.background});
  final String label;
  final Json icon;
  final Json? selectedIcon;
  final Color? iconColor, selectedIconColor, background;

  List<Object?> get _fields => [label, icon, selectedIcon, iconColor, selectedIconColor, background];

  @override
  bool operator ==(Object other) => other is NavItem && _deep.equals(other._fields, _fields);

  @override
  int get hashCode => Object.hash(label, iconColor);
}

/// A navigation bar resolved from its node and tokens.
@immutable
class NavigationBarSpec {
  const NavigationBarSpec({
    required this.tokens,
    required this.items,
    this.bottom = false,
    this.shifting = false,
    this.background,
    this.elevation,
    this.labelBehavior = api.NavigationDestinationLabelBehavior.alwaysShow,
    this.labelStyle = const TextStyle(),
    this.selectedLabelStyle = const TextStyle(),
    this.iconColor,
    this.selectedIconColor,
    this.iconSize,
    this.selectedIconSize,
    this.indicatorColor,
    this.padding,
  });

  final ControlTokens tokens;
  final List<NavItem> items;

  /// A `bottomNavigationBar` (no indicator color of its own).
  final bool bottom;
  final bool shifting;
  final Color? background;
  final double? elevation;
  final api.NavigationDestinationLabelBehavior labelBehavior;
  final TextStyle labelStyle, selectedLabelStyle;
  final Color? iconColor, selectedIconColor;

  /// Null: SSUI's 18.
  final double? iconSize, selectedIconSize;
  final Color? indicatorColor;

  /// The node's padding (null: SSUI's 8 / 6).
  final EdgeInsets? padding;

  factory NavigationBarSpec.of(Node n, ControlTokens tokens, {api.TextStyle? inherited}) {
    final padding = n.layout.padding;
    Color? c(api.Color? v) => v?.flutter;
    return NavigationBarSpec(
      tokens: tokens,
      items: [
        for (final d in n.prop(NavigationBarProps.destinations))
          NavItem(
            label: d.label,
            icon: barGlyph(d.icon),
            selectedIcon: d.selectedIcon == null ? null : barGlyph(d.selectedIcon),
            iconColor: c(d.iconColor),
            selectedIconColor: c(d.selectedIconColor),
            background: c(d.backgroundColor),
          ),
      ],
      bottom: n.type == NavigationBarProps.bottom.type,
      shifting: n.type == NavigationBarProps.bottom.type && n.prop(NavigationBarProps.type) == api.BottomNavigationBarType.shifting,
      background: c(n.prop(NavigationBarProps.backgroundColor)),
      elevation: n.prop(NavigationBarProps.elevation),
      labelBehavior: n.prop(NavigationBarProps.labelBehavior),
      labelStyle: barTextStyle(n.prop(NavigationBarProps.labelTextStyle), inherited),
      selectedLabelStyle: barTextStyle(n.prop(NavigationBarProps.selectedLabelTextStyle)),
      iconColor: c(n.prop(NavigationBarProps.iconColor)),
      selectedIconColor: c(n.prop(NavigationBarProps.selectedIconColor)),
      iconSize: n.props.has(NavigationBarProps.iconSize) ? n.prop(NavigationBarProps.iconSize) : null,
      selectedIconSize: n.props.has(NavigationBarProps.selectedIconSize) ? n.prop(NavigationBarProps.selectedIconSize) : null,
      indicatorColor: n.type == NavigationBarProps.spec.type ? c(n.prop(NavigationBarProps.indicatorColor)) : null,
      padding: padding == api.EdgeInsets.zero ? null : padding.flutter,
    );
  }

  List<Object?> get _fields => [
        tokens.theme, tokens.dark, tokens.backdrop, items, bottom, shifting, background, elevation, labelBehavior, //
        labelStyle, selectedLabelStyle, iconColor, selectedIconColor, iconSize, selectedIconSize, indicatorColor, padding,
      ];

  @override
  bool operator ==(Object other) => other is NavigationBarSpec && _deep.equals(other._fields, _fields);

  @override
  int get hashCode => Object.hash(items.length, bottom, background);

  bool showsLabel(bool selected) => switch (labelBehavior) {
        api.NavigationDestinationLabelBehavior.alwaysShow => true,
        api.NavigationDestinationLabelBehavior.alwaysHide => false,
        api.NavigationDestinationLabelBehavior.onlyShowSelected => selected,
        api.NavigationDestinationLabelBehavior.onlyShowUnselected => !selected,
      };
}

/// A navigation bar: its items, the selected one on SSUI's tint, in the
/// states [RenderItemBar] resolves.
class RenderNavigationBar extends RenderItemBar implements LabeledControl {
  RenderNavigationBar();

  final List<ControlLabel> _labels = [];

  NavigationBarSpec? _spec;
  NavigationBarSpec get spec => _spec!;
  set spec(NavigationBarSpec v) {
    if (v == _spec) return;
    _spec = v;
    while (_labels.length > v.items.length) {
      _labels.removeLast().dispose();
    }
    while (_labels.length < v.items.length) {
      _labels.add(ControlLabel());
    }
    _syncIcons();
    motion.duration = Duration(milliseconds: v.tokens.controlMs);
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  void _syncIcons() {
    final s = spec;
    syncGlyphs([
      for (var i = 0; i < s.items.length; i++)
        i == selectedIndex && s.items[i].selectedIcon != null && s.items[i].selectedIcon!.isNotEmpty ? s.items[i].selectedIcon! : s.items[i].icon,
    ]);
  }

  int? _propIndex;

  /// The node's `selectedIndex` (perhaps bound): the bar shows it whenever
  /// it changes, and the user's pick otherwise.
  set propIndex(int v) {
    if (v == _propIndex) return;
    _propIndex = v;
    selectedIndex = v;
  }

  bool _safeBottom = false;

  /// In a canvas's bottom slot: keeps the view's bottom safe area clear.
  set safeBottom(bool v) {
    if (v == _safeBottom) return;
    _safeBottom = v;
    markNeedsLayout();
  }

  double? _barHeight;

  /// The bar's own height above the safe area (a fixed node in the bottom
  /// slot), null: the box's.
  set barHeight(double? v) {
    if (v == _barHeight) return;
    _barHeight = v;
    markNeedsLayout();
  }

  /// The safe area kept clear below the items.
  double get safeInset => _safeBottom && attached ? controlViewPadding(this).bottom : 0;

  @override
  int get itemCount => _spec?.items.length ?? 0;

  @override
  String itemLabel(int i) => spec.items[i].label;

  @override
  void updateGlyphColors() {
    if (_spec == null) return;
    for (var i = 0; i < itemCount && i < glyphs.glyphs.length; i++) {
      glyphs.color(i, iconColorOf(i));
    }
  }

  @override
  void selectionChanged() {
    super.selectionChanged();
    if (_spec != null) _syncIcons();
    markNeedsLayout();
  }

  // --- geometry ----------------------------------------------------------------------

  ControlTokens get _t => spec.tokens;
  EdgeInsets get _padding => spec.padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
  static const _itemPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
  static const _labelGap = 4.0;

  double _iconSize(bool selected) => (selected ? spec.selectedIconSize ?? spec.iconSize : spec.iconSize) ?? 18;

  TextStyle _style(int i, Color color) {
    final selected = i == selectedIndex;
    final base = TextStyle(fontFamily: _t.fontFamily, fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.2, letterSpacing: 0);
    final own = selected ? spec.labelStyle.merge(spec.selectedLabelStyle) : spec.labelStyle;
    return base.merge(own).copyWith(color: color, leadingDistribution: TextLeadingDistribution.even);
  }

  double _lineHeight(int i) {
    final s = _style(i, const Color(0xFF000000));
    return (s.fontSize ?? 11.5) * (s.height ?? 1.2);
  }

  /// Item [i]'s content (icon over label) height.
  double _contentHeight(int i) {
    final selected = i == selectedIndex;
    final icon = spec.items[i].icon.isNotEmpty ? _iconSize(selected) : 0.0;
    final label = spec.showsLabel(selected) && spec.items[i].label.isNotEmpty ? _lineHeight(i) : 0.0;
    return icon + (icon > 0 && label > 0 ? _labelGap : 0) + label;
  }

  double get _itemHeight {
    var h = 0.0;
    for (var i = 0; i < itemCount; i++) {
      h = math.max(h, _contentHeight(i));
    }
    return h + _itemPadding.vertical;
  }

  double get _naturalHeight => (_barHeight ?? _padding.vertical + _itemHeight + 1) + safeInset;

  double get _naturalWidth {
    var w = 0.0;
    for (var i = 0; i < itemCount; i++) {
      _labels[i].update(spec.items[i].label, _style(i, const Color(0xFF000000)));
      w = math.max(w, math.max(_labels[i].intrinsicWidth, _iconSize(true)) + _itemPadding.horizontal);
    }
    return _padding.horizontal + w * itemCount;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth;
  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;
  @override
  double computeMinIntrinsicHeight(double width) => _naturalHeight;
  @override
  double computeMaxIntrinsicHeight(double width) => _naturalHeight;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(Size(_naturalWidth, _naturalHeight));

  List<Rect> _items = const [];
  List<double> _labelTops = const [];

  @override
  void performLayout() {
    final c = constraints;
    final width = c.hasTightWidth ? c.maxWidth : c.constrainWidth(_naturalWidth);
    final height = c.hasTightHeight ? c.maxHeight : c.constrainHeight(_naturalHeight);
    size = Size(width, height);
    final pad = _padding;
    final inset = safeInset;
    // The items' row: the bar less its padding and the safe area (and the
    // 1 px hairline along the top).
    final row = Rect.fromLTRB(pad.left, pad.top + 1, width - pad.right, math.max(pad.top + 1, height - pad.bottom - inset));
    final n = itemCount;
    final share = n == 0 ? 0.0 : row.width / n;
    final itemH = math.min(_itemHeight, row.height);
    final items = <Rect>[], tops = <double>[];
    for (var i = 0; i < n; i++) {
      final item = Rect.fromLTWH(row.left + share * i, row.center.dy - itemH / 2, share, itemH);
      items.add(item);
      final selected = i == selectedIndex;
      final content = _contentHeight(i);
      var y = item.center.dy - content / 2;
      final hasIcon = spec.items[i].icon.isNotEmpty;
      final iconSize = _iconSize(selected);
      final r = hasIcon ? Rect.fromLTWH(item.center.dx - iconSize / 2, y, iconSize, iconSize) : Rect.fromLTWH(item.center.dx, y, 0, 0);
      if (hasIcon) {
        glyphs.place(i, r);
        y += iconSize + _labelGap;
      }
      tops.add(y);
      _labels[i].update(spec.items[i].label, _style(i, const Color(0xFF000000)));
      _labels[i].layout(math.max(0, share - _itemPadding.horizontal));
    }
    _items = items;
    _labelTops = tops;
  }

  @override
  List<Rect> get itemRects => _items;

  bool _labelShown(int i) => spec.showsLabel(i == selectedIndex) && spec.items[i].label.isNotEmpty;

  double _labelCenter(int i) => _labelTops[i] + _lineHeight(i) / 2;

  double _labelLeft(int i) => _items[i].center.dx - _labels[i].size.width / 2;

  @override
  List<({String text, String? fontFamily, List<Rect> glyphs})> get labels => !hasSize
      ? const []
      : [
          for (var i = 0; i < itemCount && i < _items.length; i++)
            if (_labelShown(i))
              (text: spec.items[i].label, fontFamily: _labels[i].fontFamily, glyphs: _labels[i].glyphBoxes(_labelLeft(i), _labelCenter(i))),
        ];

  // --- colors ---------------------------------------------------------------------------

  /// The bar's fill now.
  Color get backgroundColor {
    final s = spec;
    if (s.shifting && selectedIndex >= 0 && selectedIndex < s.items.length) {
      if (s.items[selectedIndex].background case final Color own) return own;
    }
    return s.background ?? _t.surface;
  }

  /// Item [i]'s label ink now.
  Color labelColorOf(int i) {
    final s = spec;
    if (i == selectedIndex) return s.selectedLabelStyle.color ?? s.labelStyle.color ?? _t.primary;
    if (s.labelStyle.color case final Color own) return own;
    return i == hoveredIndex || i == focusedIndex ? _t.onSurface : _t.secondaryText;
  }

  /// Item [i]'s icon ink now.
  Color iconColorOf(int i) {
    final s = spec, item = s.items[i];
    if (i == selectedIndex) return item.selectedIconColor ?? s.selectedIconColor ?? labelColorOf(i);
    return item.iconColor ?? s.iconColor ?? labelColorOf(i);
  }

  /// The selected item's pill color.
  Color get indicatorColor => spec.indicatorColor ?? _t.activeTint;

  @override
  Rect? get indicatorRectNow {
    if (!hasSize || selectedIndex < 0 || selectedIndex >= _items.length) return null;
    return motion.at(_pillOf(selectedIndex));
  }

  Rect _pillOf(int i) => _items[i];

  // --- paint -------------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final e = spec.elevation;
    if (e != null && e > 0) {
      for (final sh in _t.shadows(e <= 1 ? 'level1' : e <= 3 ? 'level2' : e <= 6 ? 'level3' : 'level4')) {
        canvas.drawRect(rect.shift(sh.offset).inflate(sh.spreadRadius), sh.toPaint());
      }
    }
    canvas.drawRect(rect, Paint()..color = backgroundColor);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 1), Paint()..color = _t.primaryBorder);
    final radius = Radius.circular(_t.radiusFor(ControlScale.compact));
    final pill = indicatorRectNow;
    if (pill != null) canvas.drawRRect(RRect.fromRectAndRadius(pill.shift(offset), radius), Paint()..color = indicatorColor);
    for (final i in {hoveredIndex, pressedIndex}) {
      if (i < 0 || i >= _items.length || i == selectedIndex) continue;
      final o = i == pressedIndex ? _t.pressedOverlay : _t.hoverOverlay;
      canvas.drawRRect(RRect.fromRectAndRadius(_items[i].shift(offset), radius), Paint()..color = o);
    }
    for (var i = 0; i < itemCount && i < _items.length; i++) {
      if (_labelShown(i)) {
        _labels[i].update(spec.items[i].label, _style(i, labelColorOf(i)));
        _labels[i].layout(math.max(0, _items[i].width - _itemPadding.horizontal));
        _labels[i].paint(canvas, offset.dx + _labelLeft(i), offset.dy + _labelCenter(i));
      }
    }
    glyphs.paint(context, offset);
    final f = focusedIndex;
    if (focusHighlight && f >= 0 && f < _items.length) paintItemFocusRing(canvas, _items[f].shift(offset), _t.focusBorder, radius.x);
  }

  @override
  void dispose() {
    for (final l in _labels) {
      l.dispose();
    }
    super.dispose();
  }
}
